"""Real-money purchases: the app sends the Bazaar purchase token, the server
checks it with Bazaar and answers with what to give the player.

App flow (Poolakey):
  1. purchase succeeds in Bazaar -> app gets purchaseToken
  2. POST /v1/purchases/verify {product_id, purchase_token}
  3. status "granted": apply "grants"; if "consume" is true, consume it in Poolakey
  4. status "already_granted": don't give it again (just consume if asked)
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .. import game_rules as rules
from ..db import get_session
from ..models import Player, Purchase, SaveSlot, utcnow
from ..schemas import VerifyIn, VerifyOut
from ..security import current_player
from ..services.bazaar import BazaarClient, get_bazaar
from ..util import from_ts, ts

router = APIRouter(prefix="/v1/purchases", tags=["purchases"])


@router.post("/verify", response_model=VerifyOut)
async def verify(body: VerifyIn, player: Player = Depends(current_player),
                 session: AsyncSession = Depends(get_session),
                 bazaar: BazaarClient = Depends(get_bazaar)):
    rule = rules.PRODUCTS.get(body.product_id)
    if rule is None:
        raise HTTPException(422, "unknown_product")
    consume = rule.kind == "consumable"

    existing = await session.scalar(select(Purchase).where(Purchase.purchase_token == body.purchase_token))
    if existing is not None and existing.player_id != player.id:
        return VerifyOut(status="rejected", reason="token_used")
    if existing is not None and existing.product_id != body.product_id:
        return VerifyOut(status="rejected", reason="wrong_product")
    if existing is not None and existing.status == "granted" and rule.kind != "subscription":
        return VerifyOut(status="already_granted", consume=consume)

    # ask Bazaar
    if rule.kind == "subscription":
        check = await bazaar.check_subscription(body.product_id, body.purchase_token)
    else:
        check = await bazaar.check_inapp(body.product_id, body.purchase_token)
    if check.reason.startswith("bazaar_unreachable"):
        raise HTTPException(503, "bazaar_unreachable_try_later")

    if not check.valid:
        if existing is None:
            existing = Purchase(player_id=player.id, product_id=body.product_id,
                                purchase_token=body.purchase_token, status="rejected")
            session.add(existing)
        existing.status = "refunded" if check.refunded else "rejected"
        existing.raw = check.raw
        await session.commit()
        return VerifyOut(status="rejected", reason=check.reason or "invalid")

    vip_ts = None
    if rule.kind == "subscription" and check.valid_until_ms:
        until = from_ts(check.valid_until_ms // 1000)
        if player.vip_until is None or until > player.vip_until:
            player.vip_until = until
        vip_ts = ts(player.vip_until)

    slot = await session.get(SaveSlot, player.id)
    grants = rules.grants_for_product(body.product_id, slot.data if slot else None, vip_ts)

    renewal = existing is not None and existing.status == "granted"
    if existing is None:
        existing = Purchase(player_id=player.id, product_id=body.product_id,
                            purchase_token=body.purchase_token, status="granted")
        session.add(existing)
    existing.status = "granted"
    existing.grants = grants
    existing.coins = rules.coins_in(grants)
    existing.raw = check.raw
    existing.created_at = existing.created_at or utcnow()
    await session.commit()
    return VerifyOut(status="already_granted" if renewal and not grants else "granted",
                     grants=grants, consume=consume)
