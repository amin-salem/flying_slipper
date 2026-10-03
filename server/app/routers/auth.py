"""Accounts without passwords.

First start: the app calls /register and keeps player_id + secret on the
phone. Later starts: /login with them to get a fresh token.
New phone: the old phone makes a transfer code, the new phone enters it.
"""
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_session
from ..models import Player, SaveSlot, TransferCode, utcnow
from ..schemas import (LoginIn, RegisterIn, RegisterOut, TokenOut, TransferCodeOut, TransferIn,
                       TransferOut)
from ..security import current_player, hash_secret, make_token, new_secret, random_code, secret_matches
from ..util import default_nickname, ts, unique_invite_code

router = APIRouter(prefix="/v1/auth", tags=["auth"])


@router.post("/register", response_model=RegisterOut)
async def register(body: RegisterIn, session: AsyncSession = Depends(get_session)):
    secret = new_secret()
    player = Player(
        secret_hash=hash_secret(secret),
        device_id=body.device_id,
        platform=body.platform,
        app_version=body.app_version,
        nickname=default_nickname(),
        invite_code=await unique_invite_code(session),
        flags=[],
        token_gen=0,
    )
    session.add(player)
    await session.flush()
    session.add(SaveSlot(player_id=player.id, version=0, data={}))
    await session.commit()
    token, exp = make_token(player.id)
    return RegisterOut(player_id=player.id, secret=secret, token=token, expires_at=exp)


@router.post("/login", response_model=TokenOut)
async def login(body: LoginIn, session: AsyncSession = Depends(get_session)):
    player = await session.get(Player, body.player_id)
    if player is None or not secret_matches(body.secret, player.secret_hash):
        raise HTTPException(401, "wrong_login")
    if player.banned:
        raise HTTPException(403, "banned")
    player.last_seen = utcnow()
    if body.app_version:
        player.app_version = body.app_version
    await session.commit()
    token, exp = make_token(player.id, player.token_gen)
    return TokenOut(token=token, expires_at=exp)


@router.post("/transfer-code", response_model=TransferCodeOut)
async def make_transfer_code(player: Player = Depends(current_player),
                             session: AsyncSession = Depends(get_session)):
    """The old phone asks for a code (valid 24 hours, works once)."""
    code = random_code(8)
    exp = utcnow() + timedelta(hours=24)
    session.add(TransferCode(code=code, player_id=player.id, expires_at=exp))
    await session.commit()
    return TransferCodeOut(code=code, expires_at=ts(exp))


@router.post("/transfer", response_model=TransferOut)
async def use_transfer_code(body: TransferIn, session: AsyncSession = Depends(get_session)):
    """The new phone enters the code and takes over the account."""
    row = await session.scalar(
        select(TransferCode).where(TransferCode.code == body.code.strip().upper()))
    if row is None or row.used or row.expires_at < utcnow():
        raise HTTPException(404, "bad_code")
    player = await session.get(Player, row.player_id)
    if player is None or player.banned:
        raise HTTPException(404, "bad_code")
    row.used = True
    # a new secret: the old phone is logged out
    secret = new_secret()
    player.secret_hash = hash_secret(secret)
    player.device_id = body.device_id
    player.token_gen += 1
    await session.commit()
    token, exp = make_token(player.id, player.token_gen)
    return TransferOut(player_id=player.id, secret=secret, token=token, expires_at=exp)
