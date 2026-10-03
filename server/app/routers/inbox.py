"""Gift inbox (admin gifts, event gifts, referral rewards) and invite codes."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from .. import game_rules as rules
from ..db import get_session
from ..models import Broadcast, BroadcastClaim, InboxItem, Player, utcnow
from ..schemas import ClaimOut, InboxRow, RedeemIn
from ..security import current_player
from ..util import ts

router = APIRouter(prefix="/v1", tags=["inbox"])

# Invite rewards
NEW_PLAYER_GRANTS = [{"type": "coins", "amount": 500}, {"type": "boxes", "amount": 1}]
INVITER_GRANTS = [{"type": "coins", "amount": 1000}]
MAX_REWARDED_INVITES = 20


def add_gift(session: AsyncSession, player_id: str, title: str, grants: list[dict],
             message: str = "", source: str = "admin", expires_at=None) -> InboxItem:
    item = InboxItem(player_id=player_id, title=title, message=message, grants=grants,
                     coins=rules.coins_in(grants), source=source, expires_at=expires_at)
    session.add(item)
    return item


@router.get("/inbox", response_model=list[InboxRow])
async def inbox(player: Player = Depends(current_player), session: AsyncSession = Depends(get_session)):
    now = utcnow()
    personal = (await session.execute(
        select(InboxItem).where(
            InboxItem.player_id == player.id, InboxItem.claimed_at.is_(None),
            or_(InboxItem.expires_at.is_(None), InboxItem.expires_at > now))
        .order_by(InboxItem.id.desc()).limit(50))).scalars().all()
    claimed = select(BroadcastClaim.broadcast_id).where(BroadcastClaim.player_id == player.id)
    shared = (await session.execute(
        select(Broadcast).where(
            Broadcast.id.not_in(claimed),
            or_(Broadcast.expires_at.is_(None), Broadcast.expires_at > now))
        .order_by(Broadcast.id.desc()).limit(20))).scalars().all()
    rows = [InboxRow(id=f"p{i.id}", title=i.title, message=i.message, grants=i.grants,
                     expires_at=ts(i.expires_at)) for i in personal]
    rows += [InboxRow(id=f"b{b.id}", title=b.title, message=b.message, grants=b.grants,
                      expires_at=ts(b.expires_at)) for b in shared]
    return rows


@router.post("/inbox/{item_id}/claim", response_model=ClaimOut)
async def claim(item_id: str, player: Player = Depends(current_player),
                session: AsyncSession = Depends(get_session)):
    now = utcnow()
    if len(item_id) < 2 or not item_id[1:].isdigit() or item_id[0] not in "pb":
        raise HTTPException(404, "no_item")
    num = int(item_id[1:])
    if item_id[0] == "p":
        item = await session.get(InboxItem, num)
        if item is None or item.player_id != player.id:
            raise HTTPException(404, "no_item")
        if item.claimed_at is not None:
            raise HTTPException(409, "already_claimed")
        if item.expires_at is not None and item.expires_at < now:
            raise HTTPException(410, "expired")
        item.claimed_at = now
        await session.commit()
        return ClaimOut(grants=item.grants)

    b = await session.get(Broadcast, num)
    if b is None:
        raise HTTPException(404, "no_item")
    if b.expires_at is not None and b.expires_at < now:
        raise HTTPException(410, "expired")
    session.add(BroadcastClaim(broadcast_id=b.id, player_id=player.id))
    # record the coins as a claimed personal item so the anti-cheat counts them
    gift = add_gift(session, player.id, b.title, b.grants, source="broadcast")
    gift.claimed_at = now
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise HTTPException(409, "already_claimed")
    return ClaimOut(grants=b.grants)


@router.post("/referrals/redeem", response_model=ClaimOut)
async def redeem(body: RedeemIn, player: Player = Depends(current_player),
                 session: AsyncSession = Depends(get_session)):
    """A new player enters a friend's invite code. Both get a gift."""
    code = body.code.strip().upper()
    if player.referred_by is not None:
        raise HTTPException(409, "already_redeemed")
    if (utcnow() - player.created_at).days > 7:
        raise HTTPException(410, "only_for_new_players")
    inviter = await session.scalar(select(Player).where(Player.invite_code == code))
    if inviter is None or inviter.id == player.id:
        raise HTTPException(404, "bad_code")
    if inviter.device_id == player.device_id or inviter.referred_by == player.id:
        raise HTTPException(409, "same_device")
    player.referred_by = inviter.id
    if inviter.invites_rewarded < MAX_REWARDED_INVITES:
        inviter.invites_rewarded += 1
        add_gift(session, inviter.id, "یه دوست با کد تو اومد!", INVITER_GRANTS,
                 message=f"{player.nickname} با کد دعوت تو وارد بازی شد.", source="referral")
    # the new player's reward is given right away (recorded for the anti-cheat)
    gift = add_gift(session, player.id, "هدیه دعوت", NEW_PLAYER_GRANTS, source="referral")
    gift.claimed_at = utcnow()
    await session.commit()
    return ClaimOut(grants=NEW_PLAYER_GRANTS)
