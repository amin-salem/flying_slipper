"""Permanent accounts (optional): like Quiz of Kings, players start as guests
and can later secure their account with
  * a phone number (SMS code) - for recovery on any phone, and/or
  * a username + password      - works even when SMS is not delivered.
Logging in on a new phone moves the account there (the old phone is logged out).
"""
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from .. import accounts as acc
from ..config import get_settings
from ..db import get_session
from ..models import OtpCode, Player, utcnow
from ..schemas import (OtpIn, OtpOut, PasswordLoginIn, PhoneCodeIn, PhoneLoginIn, RegisterOut,
                       SecureOut, UsernameIn)
from ..security import current_player, hash_secret, make_token, new_secret
from ..services.sms import SmsError, send_code
from .inbox import add_gift
from .profile import _profile

router = APIRouter(prefix="/v1/account", tags=["account"])

OTP_TTL = timedelta(minutes=3)
OTP_RESEND_SECONDS = 60
OTP_MAX_PER_HOUR_PHONE = 5
OTP_MAX_PER_HOUR_IP = 20
OTP_MAX_ATTEMPTS = 5
SECURE_REWARD = [{"type": "coins", "amount": 500}]


def _ip(request: Request) -> str:
    fwd = request.headers.get("x-forwarded-for", "")
    return (request.headers.get("x-real-ip") or fwd.split(",")[0].strip()
            or (request.client.host if request.client else ""))[:64]


def _phone_or_422(raw: str) -> str:
    phone = acc.normalize_phone(raw)
    if phone is None:
        raise HTTPException(422, "bad_phone")
    return phone


async def _check_code(session: AsyncSession, phone: str, code: str) -> None:
    """Raises if the SMS code is wrong; marks it used when right."""
    otp = await session.scalar(
        select(OtpCode).where(OtpCode.phone == phone, OtpCode.used.is_(False))
        .order_by(OtpCode.id.desc()).limit(1))
    if otp is None or otp.expires_at < utcnow():
        raise HTTPException(400, "code_expired")
    if otp.attempts >= OTP_MAX_ATTEMPTS:
        raise HTTPException(429, "too_many_attempts")
    code = code.strip().translate(str.maketrans("۰۱۲۳۴۵۶۷۸۹", "0123456789"))
    if acc.hash_otp(phone, code) != otp.code_hash:
        otp.attempts += 1
        await session.commit()
        raise HTTPException(400, "wrong_code")
    otp.used = True


async def _reward_once(session: AsyncSession, player: Player) -> list[dict]:
    if player.secure_rewarded:
        return []
    player.secure_rewarded = True
    gift = add_gift(session, player.id, "حسابت امن شد!", SECURE_REWARD, source="secure")
    gift.claimed_at = utcnow()
    return SECURE_REWARD


async def _login_as(session: AsyncSession, player: Player, device_id: str) -> RegisterOut:
    if player.banned:
        raise HTTPException(403, "banned")
    secret = new_secret()
    player.secret_hash = hash_secret(secret)
    player.device_id = device_id
    player.token_gen += 1  # the previous phone is logged out
    player.last_seen = utcnow()
    await session.commit()
    token, exp = make_token(player.id, player.token_gen)
    return RegisterOut(player_id=player.id, secret=secret, token=token, expires_at=exp)


# ---------------------------------------------------------------- SMS code

@router.post("/otp", response_model=OtpOut)
async def send_otp(body: OtpIn, request: Request, session: AsyncSession = Depends(get_session)):
    phone = _phone_or_422(body.phone)
    now = utcnow()
    hour = now - timedelta(hours=1)
    last = await session.scalar(select(func.max(OtpCode.created_at)).where(OtpCode.phone == phone))
    if last is not None and (now - last).total_seconds() < OTP_RESEND_SECONDS:
        wait = OTP_RESEND_SECONDS - int((now - last).total_seconds())
        raise HTTPException(429, {"error": "wait", "retry_after": wait})
    by_phone = await session.scalar(select(func.count()).select_from(OtpCode).where(
        OtpCode.phone == phone, OtpCode.created_at >= hour))
    ip = _ip(request)
    by_ip = await session.scalar(select(func.count()).select_from(OtpCode).where(
        OtpCode.ip == ip, OtpCode.created_at >= hour))
    if (by_phone or 0) >= OTP_MAX_PER_HOUR_PHONE or (by_ip or 0) >= OTP_MAX_PER_HOUR_IP:
        raise HTTPException(429, {"error": "too_many_codes", "retry_after": 3600})

    code = acc.new_otp()
    session.add(OtpCode(phone=phone, code_hash=acc.hash_otp(phone, code), ip=ip,
                        expires_at=now + OTP_TTL))
    await session.commit()
    s = get_settings()
    try:
        await send_code(phone, code, s)
    except SmsError:
        raise HTTPException(502, "sms_failed")
    dev = code if (s.sms_provider == "fake" and s.env == "dev") else None
    return OtpOut(sent=True, retry_after=OTP_RESEND_SECONDS, dev_code=dev)


# ---------------------------------------------------------------- secure this account

@router.post("/phone", response_model=SecureOut)
async def link_phone(body: PhoneCodeIn, player: Player = Depends(current_player),
                     session: AsyncSession = Depends(get_session)):
    phone = _phone_or_422(body.phone)
    await _check_code(session, phone, body.code)
    owner = await session.scalar(select(Player).where(Player.phone == phone))
    if owner is not None and owner.id != player.id:
        # keep the code unused: the app offers "log in to that account" with it
        await session.rollback()
        raise HTTPException(409, "phone_taken")
    player.phone = phone
    grants = await _reward_once(session, player)
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise HTTPException(409, "phone_taken")
    return SecureOut(profile=_profile(player), grants=grants)


@router.post("/username", response_model=SecureOut)
async def set_username(body: UsernameIn, player: Player = Depends(current_player),
                       session: AsyncSession = Depends(get_session)):
    """Choose a username + password (or change the password)."""
    name = acc.normalize_username(body.username)
    if name is None:
        raise HTTPException(422, "bad_username")
    if not acc.password_ok(body.password):
        raise HTTPException(422, "bad_password")
    if player.username and player.username != name:
        raise HTTPException(409, "username_cant_change")
    taken = await session.scalar(select(Player.id).where(Player.username == name))
    if taken is not None and taken != player.id:
        raise HTTPException(409, "username_taken")
    player.username = name
    player.password_hash = acc.hash_password(body.password)
    grants = await _reward_once(session, player)
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise HTTPException(409, "username_taken")
    return SecureOut(profile=_profile(player), grants=grants)


# ---------------------------------------------------------------- log in on a phone

@router.post("/login/phone", response_model=RegisterOut)
async def login_phone(body: PhoneLoginIn, session: AsyncSession = Depends(get_session)):
    phone = _phone_or_422(body.phone)
    await _check_code(session, phone, body.code)
    player = await session.scalar(select(Player).where(Player.phone == phone))
    if player is None:
        # keep the code unused: the app can link this number with it instead
        await session.rollback()
        raise HTTPException(404, "no_account")
    return await _login_as(session, player, body.device_id)


@router.post("/login/password", response_model=RegisterOut)
async def login_password(body: PasswordLoginIn, session: AsyncSession = Depends(get_session)):
    name = acc.normalize_username(body.username)
    player = await session.scalar(select(Player).where(Player.username == name)) if name else None
    if player is None or not acc.check_password(body.password, player.password_hash):
        raise HTTPException(401, "wrong_login")
    return await _login_as(session, player, body.device_id)
