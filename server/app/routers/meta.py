"""Remote config, server time, analytics and health check."""
from datetime import timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from .. import game_rules as rules
from ..config import get_settings
from ..db import get_session
from ..models import Event, Player, utcnow
from ..schemas import EventsIn
from ..security import current_player
from ..services.remote_config import load_config
from ..util import from_ts

router = APIRouter(tags=["meta"])


@router.get("/health")
async def health(session: AsyncSession = Depends(get_session)):
    await session.execute(text("SELECT 1"))
    return {"ok": True}


@router.get("/v1/config")
async def config(session: AsyncSession = Depends(get_session)):
    """No login needed: the app reads this first (forced update, maintenance)."""
    s = get_settings()
    now = rules.local_now(s.timezone)
    cfg = await load_config(session)
    cfg["server_time"] = int(now.timestamp())
    # the app uses this instead of the phone clock for daily rewards etc.
    cfg["today"] = now.date().isoformat()
    cfg["weekday"] = now.isoweekday()  # same numbering as Dart (Mon=1..Sun=7)
    cfg["week"] = rules.week_number(now.date())
    return cfg


@router.post("/v1/events")
async def events(body: EventsIn, player: Player = Depends(current_player),
                 session: AsyncSession = Depends(get_session)):
    now = utcnow()
    for e in body.events:
        when = now
        if e.ts:
            t = from_ts(e.ts)
            # ignore crazy phone clocks
            if now - timedelta(days=7) < t <= now + timedelta(minutes=5):
                when = t
        props = {k: v for k, v in list(e.props.items())[:20]}
        session.add(Event(player_id=player.id, name=e.name, props=props, ts=when))
    await session.commit()
    return {"stored": len(body.events)}
