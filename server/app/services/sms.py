"""Sends login codes by SMS through an Iranian SMS service.

Both services have a special fast "verify" route for one-time codes that
works even for numbers that blocked advertising SMS:
  * Kavenegar  - "Verify Lookup" with a template (panel: Verification > templates)
  * SMS.ir     - "Verify" with a template id (panel: Developers > templates)
"""
from __future__ import annotations

import logging

import httpx

from ..config import Settings, get_settings

log = logging.getLogger("sms")


class SmsError(Exception):
    pass


async def send_code(phone: str, code: str, s: Settings | None = None,
                    http: httpx.AsyncClient | None = None) -> None:
    s = s or get_settings()
    if s.sms_provider == "fake":
        log.warning("FAKE SMS to %s: code %s", phone, code)
        return
    client = http or httpx.AsyncClient(timeout=15)
    try:
        if s.sms_provider == "kavenegar":
            r = await client.get(
                f"https://api.kavenegar.com/v1/{s.kavenegar_api_key}/verify/lookup.json",
                params={"receptor": phone, "token": code, "template": s.kavenegar_template},
            )
            body = r.json() if r.content else {}
            status = (body.get("return") or {}).get("status")
            if r.status_code != 200 or status != 200:
                raise SmsError(f"kavenegar:{r.status_code}:{status}")
        elif s.sms_provider == "smsir":
            r = await client.post(
                "https://api.sms.ir/v1/send/verify",
                headers={"x-api-key": s.sms_ir_api_key, "Accept": "application/json"},
                json={"mobile": phone, "templateId": s.sms_ir_template_id,
                      "parameters": [{"name": s.sms_ir_param, "value": code}]},
            )
            body = r.json() if r.content else {}
            if r.status_code != 200 or body.get("status") != 1:
                raise SmsError(f"smsir:{r.status_code}:{body.get('status')}")
        else:
            raise SmsError(f"unknown provider {s.sms_provider!r}")
    except httpx.HTTPError as e:
        raise SmsError(f"network:{type(e).__name__}") from e
    finally:
        if http is None:
            await client.aclose()
