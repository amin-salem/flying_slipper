"""Database tables. All times are stored as UTC (without timezone info)."""
import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Index, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


def utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def new_id() -> str:
    return uuid.uuid4().hex


class Player(Base):
    __tablename__ = "players"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    secret_hash: Mapped[str] = mapped_column(String(64))
    token_gen: Mapped[int] = mapped_column(Integer, default=0)  # +1 logs out old phones
    device_id: Mapped[str] = mapped_column(String(128), index=True)
    platform: Mapped[str] = mapped_column(String(16), default="android")
    app_version: Mapped[int] = mapped_column(Integer, default=0)

    nickname: Mapped[str] = mapped_column(String(24), default="")
    character: Mapped[str] = mapped_column(String(32), default="ali")
    invite_code: Mapped[str] = mapped_column(String(12), unique=True, index=True)
    referred_by: Mapped[str | None] = mapped_column(String(32), nullable=True)
    invites_rewarded: Mapped[int] = mapped_column(Integer, default=0)

    # Permanent account (optional): email + password and/or phone number (SMS code)
    phone: Mapped[str | None] = mapped_column(String(15), unique=True, nullable=True)
    username: Mapped[str | None] = mapped_column(String(24), unique=True, nullable=True)
    email: Mapped[str | None] = mapped_column(String(120), unique=True, nullable=True)
    password_hash: Mapped[str | None] = mapped_column(String(200), nullable=True)
    secure_rewarded: Mapped[bool] = mapped_column(Boolean, default=False)

    vip_until: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    banned: Mapped[bool] = mapped_column(Boolean, default=False)
    suspicious: Mapped[int] = mapped_column(Integer, default=0)
    flags: Mapped[list] = mapped_column(JSON, default=list)  # last anti-cheat notes

    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    last_seen: Mapped[datetime] = mapped_column(DateTime, default=utcnow)


class SaveSlot(Base):
    """The player's cloud save (the same data the app keeps on the phone)."""

    __tablename__ = "saves"

    player_id: Mapped[str] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), primary_key=True)
    version: Mapped[int] = mapped_column(Integer, default=0)
    data: Mapped[dict] = mapped_column(JSON, default=dict)
    coins: Mapped[int] = mapped_column(Integer, default=0)
    xp: Mapped[int] = mapped_column(Integer, default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)


class Run(Base):
    """One game (started on the server, finished with the result)."""

    __tablename__ = "runs"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), index=True)
    started_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    finished_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    status: Mapped[str] = mapped_column(String(12), default="started")  # started|ok|rejected
    reject_reason: Mapped[str] = mapped_column(String(64), default="")
    character: Mapped[str] = mapped_column(String(32), default="ali")
    meters: Mapped[int] = mapped_column(Integer, default=0)
    coins: Mapped[int] = mapped_column(Integer, default=0)
    near_misses: Mapped[int] = mapped_column(Integer, default=0)
    duration_ms: Mapped[int] = mapped_column(Integer, default=0)
    score: Mapped[int] = mapped_column(Integer, default=0)


class LeaderboardEntry(Base):
    """Best score per player per period ("all" or "w<week number>")."""

    __tablename__ = "leaderboard"
    __table_args__ = (
        UniqueConstraint("player_id", "period", name="uq_lb_player_period"),
        Index("ix_lb_period_score", "period", "score"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"))
    period: Mapped[str] = mapped_column(String(12))
    score: Mapped[int] = mapped_column(Integer, default=0)
    meters: Mapped[int] = mapped_column(Integer, default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)


class Purchase(Base):
    """A Cafe Bazaar purchase. purchase_token is unique so it can't be used twice."""

    __tablename__ = "purchases"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), index=True)
    product_id: Mapped[str] = mapped_column(String(64))
    purchase_token: Mapped[str] = mapped_column(String(255), unique=True)
    status: Mapped[str] = mapped_column(String(16))  # granted|rejected|refunded
    grants: Mapped[list] = mapped_column(JSON, default=list)
    coins: Mapped[int] = mapped_column(Integer, default=0)  # coins given (for anti-cheat)
    raw: Mapped[dict] = mapped_column(JSON, default=dict)  # Bazaar's answer
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)


class InboxItem(Base):
    """A gift for one player (referral reward, admin gift, compensation...)."""

    __tablename__ = "inbox"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(80))
    message: Mapped[str] = mapped_column(String(400), default="")
    grants: Mapped[list] = mapped_column(JSON, default=list)
    coins: Mapped[int] = mapped_column(Integer, default=0)
    source: Mapped[str] = mapped_column(String(24), default="admin")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    claimed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class Broadcast(Base):
    """A gift for everyone (e.g. Nowruz gift). Each player can claim it once."""

    __tablename__ = "broadcasts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(80))
    message: Mapped[str] = mapped_column(String(400), default="")
    grants: Mapped[list] = mapped_column(JSON, default=list)
    coins: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class BroadcastClaim(Base):
    __tablename__ = "broadcast_claims"
    __table_args__ = (UniqueConstraint("broadcast_id", "player_id", name="uq_bc_claim"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    broadcast_id: Mapped[int] = mapped_column(ForeignKey("broadcasts.id", ondelete="CASCADE"))
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), index=True)
    claimed_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)


class TransferCode(Base):
    """One-time code to move an account to a new phone."""

    __tablename__ = "transfer_codes"

    code: Mapped[str] = mapped_column(String(16), primary_key=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime)
    used: Mapped[bool] = mapped_column(Boolean, default=False)


class ConfigValue(Base):
    """Remote config overrides set by the admin (key -> JSON value)."""

    __tablename__ = "config"

    key: Mapped[str] = mapped_column(String(64), primary_key=True)
    value: Mapped[Any] = mapped_column(JSON, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)


class Event(Base):
    """Analytics event sent by the app (game started, shop opened...)."""

    __tablename__ = "events"
    __table_args__ = (Index("ix_events_name_ts", "name", "ts"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    player_id: Mapped[str] = mapped_column(String(32), index=True)
    name: Mapped[str] = mapped_column(String(48))
    props: Mapped[dict] = mapped_column(JSON, default=dict)
    ts: Mapped[datetime] = mapped_column(DateTime, default=utcnow)


class OtpCode(Base):
    """An SMS code sent to a phone number (stored hashed)."""

    __tablename__ = "otp_codes"
    __table_args__ = (Index("ix_otp_phone_created", "phone", "created_at"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    phone: Mapped[str] = mapped_column(String(15))
    code_hash: Mapped[str] = mapped_column(String(64))
    ip: Mapped[str] = mapped_column(String(64), default="")
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    used: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    expires_at: Mapped[datetime] = mapped_column(DateTime)
