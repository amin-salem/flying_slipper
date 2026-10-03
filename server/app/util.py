"""Small helpers shared by the routers."""
import re
import secrets
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .models import Player
from .security import random_code


def ts(dt: datetime | None) -> int | None:
    """UTC datetime (stored without tz) -> unix seconds."""
    if dt is None:
        return None
    return int(dt.replace(tzinfo=timezone.utc).timestamp())


def from_ts(seconds: int) -> datetime:
    return datetime.fromtimestamp(seconds, timezone.utc).replace(tzinfo=None)


async def unique_invite_code(session: AsyncSession) -> str:
    for _ in range(20):
        code = random_code(6)
        found = await session.scalar(select(Player.id).where(Player.invite_code == code))
        if not found:
            return code
    return random_code(10)


def default_nickname() -> str:
    return f"شیطون{secrets.randbelow(9000) + 1000}"


_URL = re.compile(r"(https?://|www\.|\.ir\b|\.com\b|@|t\.me)", re.I)
_BLOCKED = ["کس", "کیر", "کون", "جنده", "fuck", "sex", "admin", "مدیر"]


def clean_nickname(name: str) -> str | None:
    """Returns a tidy nickname, or None if it is not allowed."""
    name = " ".join(name.split())
    if not (2 <= len(name) <= 16):
        return None
    if _URL.search(name):
        return None
    low = name.lower().replace(" ", "")
    if any(b in low for b in _BLOCKED):
        return None
    if sum(ch.isdigit() for ch in name) > 6:  # phone numbers
        return None
    return name
