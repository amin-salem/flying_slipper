"""Profile (nickname, character) and the cloud save."""
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from .. import game_rules as rules
from ..db import get_session
from ..models import InboxItem, Player, Purchase, Run, SaveSlot, utcnow
from ..schemas import ProfileIn, ProfileOut, SaveIn, SaveOut, SavePutOut
from ..security import current_player
from ..accounts import mask_phone
from ..util import clean_nickname, ts

router = APIRouter(prefix="/v1", tags=["profile"])


def _profile(p: Player) -> ProfileOut:
    return ProfileOut(
        player_id=p.id, nickname=p.nickname, character=p.character,
        invite_code=p.invite_code, referred=p.referred_by is not None,
        vip_until=ts(p.vip_until), created_at=ts(p.created_at) or 0,
        phone=mask_phone(p.phone), username=p.username,
        secured=bool(p.phone or p.username),
    )


@router.get("/me", response_model=ProfileOut)
async def me(player: Player = Depends(current_player)):
    return _profile(player)


@router.patch("/me", response_model=ProfileOut)
async def update_me(body: ProfileIn, player: Player = Depends(current_player),
                    session: AsyncSession = Depends(get_session)):
    if body.nickname is not None:
        name = clean_nickname(body.nickname)
        if name is None:
            raise HTTPException(422, "bad_nickname")
        player.nickname = name
    if body.character is not None:
        if body.character not in rules.CHARACTERS:
            raise HTTPException(422, "bad_character")
        player.character = body.character
    await session.commit()
    return _profile(player)


# ---------------------------------------------------------------- cloud save

async def _slot(session: AsyncSession, player_id: str) -> SaveSlot:
    slot = await session.get(SaveSlot, player_id)
    if slot is None:
        slot = SaveSlot(player_id=player_id, version=0, data={})
        session.add(slot)
        await session.flush()
    return slot


def _save_out(slot: SaveSlot) -> SaveOut:
    return SaveOut(version=slot.version, data=slot.data or {}, updated_at=ts(slot.updated_at) or 0)


@router.get("/save", response_model=SaveOut)
async def get_save(player: Player = Depends(current_player),
                   session: AsyncSession = Depends(get_session)):
    return _save_out(await _slot(session, player.id))


async def _allowance(session: AsyncSession, player_id: str, since: datetime) -> rules.Allowance:
    run_coins = await session.scalar(
        select(func.coalesce(func.sum(Run.coins), 0)).where(
            Run.player_id == player_id, Run.status == "ok", Run.finished_at >= since))
    bought = await session.scalar(
        select(func.coalesce(func.sum(Purchase.coins), 0)).where(
            Purchase.player_id == player_id, Purchase.status == "granted", Purchase.created_at >= since))
    gifts = await session.scalar(
        select(func.coalesce(func.sum(InboxItem.coins), 0)).where(
            InboxItem.player_id == player_id, InboxItem.claimed_at >= since))
    hours = (utcnow() - since).total_seconds() / 3600
    # broadcast gifts are small and rare; they are covered by the daily margin
    return rules.Allowance(run_coins=int(run_coins or 0), bought_coins=int(bought or 0),
                           gift_coins=int(gifts or 0), hours=hours)


@router.put("/save", response_model=SavePutOut)
async def put_save(body: SaveIn, player: Player = Depends(current_player),
                   session: AsyncSession = Depends(get_session)):
    slot = await _slot(session, player.id)
    if not body.force and body.base_version != slot.version:
        # another phone (or an older copy) saved in between: let the app decide
        raise HTTPException(409, {"error": "conflict", "server": _save_out(slot).model_dump()})
    try:
        data = rules.clean_save(body.data)
    except ValueError as e:
        raise HTTPException(422, f"bad_save: {e}")

    # anti-cheat: compare with the previous save
    if slot.version > 0:
        flags = rules.check_save(slot.data or {}, data, await _allowance(session, player.id, slot.updated_at))
    else:
        flags = ["first_save_rich"] if int(data.get("coins", 0)) > 200_000 else []
    if flags:
        player.suspicious += 1
        player.flags = (flags + list(player.flags or []))[:20]

    # the server is the boss of VIP time (it comes from verified purchases)
    data["vipUntil"] = ts(player.vip_until) or 0
    data["vip"] = bool(player.vip_until and player.vip_until > utcnow())

    slot.data = data
    slot.version += 1
    slot.coins = int(data.get("coins", 0))
    slot.xp = int(data.get("xp", 0))
    slot.updated_at = utcnow()
    if data.get("skin") in rules.CHARACTERS:
        player.character = data["skin"]
    await session.commit()
    # flags are kept on the server only (don't teach cheaters what we check)
    return SavePutOut(version=slot.version)
