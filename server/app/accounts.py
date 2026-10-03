"""Helpers for permanent accounts: phone numbers, usernames, passwords."""
from __future__ import annotations

import base64
import hashlib
import hmac
import re
import secrets

_FA = str.maketrans("۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩", "01234567890123456789")


def normalize_phone(raw: str) -> str | None:
    """Iranian mobile number -> "09xxxxxxxxx" (or None if it isn't one)."""
    d = re.sub(r"\D", "", (raw or "").translate(_FA))
    if d.startswith("0098"):
        d = d[4:]
    elif d.startswith("98") and len(d) == 12:
        d = d[2:]
    if d.startswith("0"):
        d = d[1:]
    if len(d) == 10 and d.startswith("9"):
        return "0" + d
    return None


def mask_phone(phone: str | None) -> str | None:
    if not phone:
        return None
    return phone[:4] + "***" + phone[-4:]


_USERNAME = re.compile(r"^[a-z][a-z0-9_]{2,15}$")


def normalize_username(raw: str) -> str | None:
    """3-16 English letters/digits/_ starting with a letter; stored lowercase."""
    u = (raw or "").strip().lower()
    return u if _USERNAME.match(u) else None


def password_ok(pw: str) -> bool:
    return 6 <= len(pw or "") <= 64


def hash_password(pw: str) -> str:
    salt = secrets.token_bytes(16)
    h = hashlib.scrypt(pw.encode(), salt=salt, n=2**14, r=8, p=1, dklen=32)
    return "scrypt$" + base64.b64encode(salt).decode() + "$" + base64.b64encode(h).decode()


def check_password(pw: str, stored: str | None) -> bool:
    if not stored or not stored.startswith("scrypt$"):
        return False
    _, salt_b64, h_b64 = stored.split("$")
    h = hashlib.scrypt(pw.encode(), salt=base64.b64decode(salt_b64), n=2**14, r=8, p=1, dklen=32)
    return hmac.compare_digest(h, base64.b64decode(h_b64))


def new_otp() -> str:
    return f"{secrets.randbelow(100000):05d}"


def hash_otp(phone: str, code: str) -> str:
    return hashlib.sha256(f"{phone}:{code}".encode()).hexdigest()
