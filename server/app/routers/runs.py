"""Games and the leaderboard (this week + all time)."""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import and_, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from .. import game_rules as rules
from ..config import get_settings
from ..db import get_session
from ..models import LeaderboardEntry, Player, Run, SaveSlot, utcnow
from ..schemas import LeaderboardOut, LeaderRow, RunFinishIn, RunFinishOut, RunStartIn, RunStartOut
from ..security import current_player
from ..util import ts

router = APIRouter(prefix="/v1", tags=["runs"])

RUN_MAX_AGE_SECONDS = 2 * 3600


@router.post("/runs/start", response_model=RunStartOut)
async def start_run(body: RunStartIn, player: Player = Depends(current_player),
                    session: AsyncSession = Depends(get_session)):
    run = Run(player_id=player.id, character=body.character if body.character in rules.CHARACTERS else "ali")
    session.add(run)
    await session.commit()
    return RunStartOut(run_id=run.id, server_time=ts(run.started_at) or 0)


async def _bump(session: AsyncSession, player_id: str, period: str, score: int, meters: int) -> int:
    """Keeps the best score for this period. Returns the best."""
    row = await session.scalar(select(LeaderboardEntry).where(
        LeaderboardEntry.player_id == player_id, LeaderboardEntry.period == period))
    if row is None:
        row = LeaderboardEntry(player_id=player_id, period=period, score=score, meters=meters)
        session.add(row)
    elif score > row.score:
        row.score, row.meters, row.updated_at = score, meters, utcnow()
    return max(row.score, score)


def _visible():
    """Players shown on leaderboards: not banned and not suspicious."""
    return and_(Player.banned.is_(False), Player.suspicious < get_settings().suspicious_threshold)


async def _rank_of(session: AsyncSession, period: str, score: int) -> int:
    better = await session.scalar(
        select(func.count()).select_from(LeaderboardEntry).join(Player, Player.id == LeaderboardEntry.player_id)
        .where(LeaderboardEntry.period == period, LeaderboardEntry.score > score, _visible()))
    return int(better or 0) + 1


@router.post("/runs/{run_id}/finish", response_model=RunFinishOut)
async def finish_run(run_id: str, body: RunFinishIn, player: Player = Depends(current_player),
                     session: AsyncSession = Depends(get_session)):
    run = await session.get(Run, run_id)
    if run is None or run.player_id != player.id:
        raise HTTPException(404, "no_run")
    # A run can be sent again after "continue" (revive), with bigger numbers.
    if run.status == "rejected" or (run.status == "ok" and body.meters < run.meters):
        raise HTTPException(409, "already_finished")
    now = utcnow()
    elapsed = (now - run.started_at).total_seconds()
    slot = await session.get(SaveSlot, player.id)
    result = rules.RunResult(meters=body.meters, coins=body.coins, near_misses=body.near_misses,
                             duration_ms=body.duration_ms, score_mul=body.score_mul)
    reason = "too_old" if elapsed > RUN_MAX_AGE_SECONDS else rules.check_run(result, elapsed, slot.xp if slot else 0)

    run.finished_at = now
    run.meters, run.coins, run.near_misses = body.meters, body.coins, body.near_misses
    run.duration_ms = body.duration_ms
    if reason:
        run.status, run.reject_reason = "rejected", reason
        if reason not in ("too_old",):
            player.suspicious += 1
            player.flags = ([f"run:{reason}"] + list(player.flags or []))[:20]
        await session.commit()
        return RunFinishOut(accepted=False, reason=reason)

    score = rules.score_of(result)
    run.status, run.score = "ok", score
    period = rules.week_period(get_settings().timezone)
    best_week = await _bump(session, player.id, period, score, body.meters)
    best_all = await _bump(session, player.id, "all", score, body.meters)
    try:
        await session.commit()
    except IntegrityError:  # two runs finished at the same moment: rare, try again
        await session.rollback()
        raise HTTPException(409, "busy_try_again")
    return RunFinishOut(accepted=True, score=score, best_week=best_week, best_all=best_all,
                        rank_week=await _rank_of(session, period, best_week))


@router.get("/leaderboard", response_model=LeaderboardOut)
async def leaderboard(period: str = Query("week", pattern="^(week|all)$"),
                      limit: int = Query(50, ge=1, le=100),
                      player: Player = Depends(current_player),
                      session: AsyncSession = Depends(get_session)):
    tz = get_settings().timezone
    key = rules.week_period(tz) if period == "week" else "all"
    rows = (await session.execute(
        select(LeaderboardEntry, Player)
        .join(Player, Player.id == LeaderboardEntry.player_id)
        .where(LeaderboardEntry.period == key, _visible())
        .order_by(LeaderboardEntry.score.desc(), LeaderboardEntry.updated_at.asc())
        .limit(limit))).all()
    top = [
        LeaderRow(rank=i + 1, player_id=p.id[:8], nickname=p.nickname, character=p.character,
                  score=e.score, meters=e.meters, me=p.id == player.id)
        for i, (e, p) in enumerate(rows)
    ]
    mine = await session.scalar(select(LeaderboardEntry).where(
        LeaderboardEntry.player_id == player.id, LeaderboardEntry.period == key))
    me_row = None
    if mine is not None:
        me_row = LeaderRow(rank=await _rank_of(session, key, mine.score), player_id=player.id[:8],
                           nickname=player.nickname, character=player.character,
                           score=mine.score, meters=mine.meters, me=True)
    ends = int(rules.week_ends_at(tz).timestamp()) if period == "week" else None
    return LeaderboardOut(period=key, ends_at=ends, top=top, me=me_row)
