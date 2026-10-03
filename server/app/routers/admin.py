"""Admin tools. Every call needs the header  X-Admin-Key: <ADMIN_API_KEY>.

Easiest way to use: open http://<server>/docs , click "Authorize"... or
use curl (examples in server/README.md).
"""
from datetime import timedelta
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from .. import game_rules as rules
from ..config import get_settings
from ..db import get_session
from ..models import (Broadcast, ConfigValue, LeaderboardEntry, Player, Purchase, Run, SaveSlot, utcnow)
from ..schemas import ConfigIn, GiftIn
from ..security import require_admin
from ..services.remote_config import DEFAULTS, load_config
from ..util import ts
from .inbox import add_gift

router = APIRouter(prefix="/admin", tags=["admin"], dependencies=[Depends(require_admin)])


@router.get("/stats")
async def stats(session: AsyncSession = Depends(get_session)):
    now = utcnow()
    day, month = now - timedelta(days=1), now - timedelta(days=30)

    async def count(stmt) -> int:
        return int(await session.scalar(stmt) or 0)

    by_product = (await session.execute(
        select(Purchase.product_id, func.count()).where(
            Purchase.status == "granted", Purchase.created_at >= month)
        .group_by(Purchase.product_id))).all()
    return {
        "players": await count(select(func.count()).select_from(Player)),
        "new_24h": await count(select(func.count()).select_from(Player).where(Player.created_at >= day)),
        "active_24h": await count(select(func.count()).select_from(Player).where(Player.last_seen >= day)),
        "active_30d": await count(select(func.count()).select_from(Player).where(Player.last_seen >= month)),
        "runs_24h": await count(select(func.count()).select_from(Run).where(Run.started_at >= day)),
        "suspicious": await count(select(func.count()).select_from(Player).where(
            Player.suspicious >= get_settings().suspicious_threshold)),
        "banned": await count(select(func.count()).select_from(Player).where(Player.banned.is_(True))),
        "purchases_30d": {p: n for p, n in by_product},
    }


@router.get("/players")
async def find_players(q: str = Query("", max_length=40), suspicious: bool = False,
                       limit: int = Query(30, le=200), session: AsyncSession = Depends(get_session)):
    stmt = select(Player).order_by(Player.last_seen.desc()).limit(limit)
    if q:
        stmt = stmt.where(or_(Player.nickname.contains(q), Player.invite_code == q.upper(),
                              Player.id.startswith(q)))
    if suspicious:
        stmt = stmt.where(Player.suspicious >= get_settings().suspicious_threshold)
    players = (await session.execute(stmt)).scalars().all()
    return [{"id": p.id, "nickname": p.nickname, "invite_code": p.invite_code,
             "suspicious": p.suspicious, "banned": p.banned, "last_seen": ts(p.last_seen)}
            for p in players]


@router.get("/players/{player_id}")
async def player_detail(player_id: str, session: AsyncSession = Depends(get_session)):
    p = await session.get(Player, player_id)
    if p is None:
        raise HTTPException(404, "no_player")
    slot = await session.get(SaveSlot, p.id)
    purchases = (await session.execute(select(Purchase).where(Purchase.player_id == p.id)
                                       .order_by(Purchase.id.desc()).limit(50))).scalars().all()
    runs = (await session.execute(select(Run).where(Run.player_id == p.id)
                                  .order_by(Run.started_at.desc()).limit(30))).scalars().all()
    return {
        "player": {"id": p.id, "nickname": p.nickname, "character": p.character,
                   "device_id": p.device_id, "app_version": p.app_version,
                   "invite_code": p.invite_code, "referred_by": p.referred_by,
                   "vip_until": ts(p.vip_until), "banned": p.banned, "suspicious": p.suspicious,
                   "flags": p.flags, "created_at": ts(p.created_at), "last_seen": ts(p.last_seen)},
        "save": {"version": slot.version, "data": slot.data, "updated_at": ts(slot.updated_at)} if slot else None,
        "purchases": [{"product": x.product_id, "status": x.status, "grants": x.grants,
                       "at": ts(x.created_at)} for x in purchases],
        "runs": [{"status": r.status, "reason": r.reject_reason, "meters": r.meters, "coins": r.coins,
                  "score": r.score, "secs": r.duration_ms // 1000, "at": ts(r.started_at)} for r in runs],
    }


class BanIn(BaseModel):
    banned: bool = True


@router.post("/players/{player_id}/ban")
async def ban(player_id: str, body: BanIn, session: AsyncSession = Depends(get_session)):
    p = await session.get(Player, player_id)
    if p is None:
        raise HTTPException(404, "no_player")
    p.banned = body.banned
    await session.commit()
    return {"id": p.id, "banned": p.banned}


@router.post("/players/{player_id}/clear-flags")
async def clear_flags(player_id: str, session: AsyncSession = Depends(get_session)):
    """After checking a player by hand: show them on the leaderboard again."""
    p = await session.get(Player, player_id)
    if p is None:
        raise HTTPException(404, "no_player")
    p.suspicious, p.flags = 0, []
    await session.commit()
    return {"id": p.id, "suspicious": 0}


# ---------------------------------------------------------------- remote config

@router.get("/config")
async def get_config(session: AsyncSession = Depends(get_session)):
    return await load_config(session)


@router.put("/config")
async def set_config(body: ConfigIn, session: AsyncSession = Depends(get_session)):
    unknown = [k for k in body.values if k not in DEFAULTS]
    if unknown:
        raise HTTPException(422, f"unknown keys: {unknown}")
    for key, value in body.values.items():
        row = await session.get(ConfigValue, key)
        if row is None:
            session.add(ConfigValue(key=key, value=value))
        else:
            row.value, row.updated_at = value, utcnow()
    await session.commit()
    return await load_config(session)


@router.delete("/config/{key}")
async def reset_config(key: str, session: AsyncSession = Depends(get_session)):
    """Back to the default value."""
    await session.execute(delete(ConfigValue).where(ConfigValue.key == key))
    await session.commit()
    return await load_config(session)


# ---------------------------------------------------------------- gifts

@router.post("/gifts")
async def send_gift(body: GiftIn, session: AsyncSession = Depends(get_session)):
    try:
        grants = rules.check_grants(body.grants)
    except (ValueError, KeyError, TypeError) as e:
        raise HTTPException(422, str(e))
    exp = utcnow() + timedelta(days=body.expires_in_days) if body.expires_in_days else None
    if body.player_id:
        if await session.get(Player, body.player_id) is None:
            raise HTTPException(404, "no_player")
        item = add_gift(session, body.player_id, body.title, grants, message=body.message, expires_at=exp)
        await session.commit()
        return {"sent_to": body.player_id, "id": f"p{item.id}"}
    b = Broadcast(title=body.title, message=body.message, grants=grants,
                  coins=rules.coins_in(grants), expires_at=exp)
    session.add(b)
    await session.commit()
    return {"sent_to": "everyone", "id": f"b{b.id}"}


class RewardTier(BaseModel):
    from_rank: int
    to_rank: int
    title: str
    grants: list[dict[str, Any]]


class WeekRewardIn(BaseModel):
    period: str  # e.g. "w143" (the week that just ended) or "all"
    tiers: list[RewardTier]


@router.post("/leaderboard/reward")
async def reward_leaderboard(body: WeekRewardIn, session: AsyncSession = Depends(get_session)):
    """Send prizes to the top players of a week (run it after the week ends)."""
    top_n = max((t.to_rank for t in body.tiers), default=0)
    s = get_settings()
    rows = (await session.execute(
        select(LeaderboardEntry.player_id)
        .join(Player, Player.id == LeaderboardEntry.player_id)
        .where(LeaderboardEntry.period == body.period, Player.banned.is_(False),
               Player.suspicious < s.suspicious_threshold)
        .order_by(LeaderboardEntry.score.desc(), LeaderboardEntry.updated_at.asc())
        .limit(top_n))).scalars().all()
    sent = 0
    for rank, pid in enumerate(rows, start=1):
        for t in body.tiers:
            if t.from_rank <= rank <= t.to_rank:
                try:
                    grants = rules.check_grants(t.grants)
                except (ValueError, KeyError, TypeError) as e:
                    raise HTTPException(422, str(e))
                add_gift(session, pid, t.title, grants, message=f"رتبه {rank} جدول هفته!",
                         source="leaderboard", expires_at=utcnow() + timedelta(days=14))
                sent += 1
                break
    await session.commit()
    return {"sent": sent}


@router.get("/purchases")
async def purchases(limit: int = Query(50, le=500), session: AsyncSession = Depends(get_session)):
    rows = (await session.execute(select(Purchase).order_by(Purchase.id.desc()).limit(limit))).scalars().all()
    return [{"player": x.player_id, "product": x.product_id, "status": x.status,
             "at": ts(x.created_at)} for x in rows]
