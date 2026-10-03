"""Shapes of the JSON the app sends and receives."""
from typing import Any

from pydantic import BaseModel, Field


# ---- auth
class RegisterIn(BaseModel):
    device_id: str = Field(min_length=4, max_length=128)
    platform: str = Field(default="android", max_length=16)
    app_version: int = 0


class RegisterOut(BaseModel):
    player_id: str
    secret: str  # the app must keep this safe; it is shown only once
    token: str
    expires_at: int


class LoginIn(BaseModel):
    player_id: str = Field(max_length=32)
    secret: str = Field(max_length=128)
    app_version: int = 0


class TokenOut(BaseModel):
    token: str
    expires_at: int


class TransferIn(BaseModel):
    code: str = Field(min_length=4, max_length=16)
    device_id: str = Field(min_length=4, max_length=128)


class TransferOut(RegisterOut):
    pass


class TransferCodeOut(BaseModel):
    code: str
    expires_at: int


# ---- profile
class ProfileOut(BaseModel):
    player_id: str
    nickname: str
    character: str
    invite_code: str
    referred: bool
    vip_until: int | None
    created_at: int


class ProfileIn(BaseModel):
    nickname: str | None = Field(default=None, min_length=2, max_length=16)
    character: str | None = Field(default=None, max_length=32)


# ---- save
class SaveOut(BaseModel):
    version: int
    data: dict[str, Any]
    updated_at: int


class SaveIn(BaseModel):
    base_version: int  # the version the phone last got from the server
    data: dict[str, Any]
    force: bool = False  # overwrite even if the server has a newer save


class SavePutOut(BaseModel):
    version: int
    flags: list[str] = []


# ---- runs & leaderboard
class RunStartIn(BaseModel):
    character: str = Field(default="ali", max_length=32)


class RunStartOut(BaseModel):
    run_id: str
    server_time: int


class RunFinishIn(BaseModel):
    meters: int
    coins: int
    near_misses: int = 0
    duration_ms: int
    score_mul: int = 1


class RunFinishOut(BaseModel):
    accepted: bool
    reason: str = ""
    score: int = 0
    best_week: int = 0
    best_all: int = 0
    rank_week: int | None = None


class LeaderRow(BaseModel):
    rank: int
    player_id: str
    nickname: str
    character: str
    score: int
    meters: int
    me: bool = False


class LeaderboardOut(BaseModel):
    period: str
    ends_at: int | None
    top: list[LeaderRow]
    me: LeaderRow | None


# ---- purchases
class VerifyIn(BaseModel):
    product_id: str = Field(max_length=64)
    purchase_token: str = Field(min_length=4, max_length=255)


class VerifyOut(BaseModel):
    status: str  # granted | already_granted | rejected
    reason: str = ""
    grants: list[dict] = []
    consume: bool = False  # the app should consume it with Poolakey


# ---- inbox
class InboxRow(BaseModel):
    id: str  # "p12" (personal) or "b3" (for everyone)
    title: str
    message: str
    grants: list[dict]
    expires_at: int | None


class ClaimOut(BaseModel):
    grants: list[dict]


# ---- referral
class RedeemIn(BaseModel):
    code: str = Field(min_length=4, max_length=12)


# ---- analytics
class EventIn(BaseModel):
    name: str = Field(min_length=1, max_length=48)
    props: dict[str, Any] = {}
    ts: int | None = None  # unix seconds on the phone


class EventsIn(BaseModel):
    events: list[EventIn] = Field(max_length=100)


# ---- admin
class GiftIn(BaseModel):
    title: str = Field(max_length=80)
    message: str = Field(default="", max_length=400)
    grants: list[dict]
    player_id: str | None = None  # empty = everyone
    expires_in_days: int | None = 14


class ConfigIn(BaseModel):
    values: dict[str, Any]
