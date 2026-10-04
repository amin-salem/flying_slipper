"""Permanent accounts: phone number (SMS code) and username + password."""
from .conftest import new_player


async def _code(client, phone="09121112233"):
    r = await client.post("/v1/account/otp", json={"phone": phone})
    assert r.status_code == 200, r.text
    return r.json()["dev_code"]


async def test_link_phone_then_recover_on_new_phone(client):
    p = await new_player(client, "phone-a")
    h = p["headers"]
    await client.put("/v1/save", json={"base_version": 0, "data": {"coins": 4321}}, headers=h)
    code = await _code(client, "+98 912 111 2233")
    r = await client.post("/v1/account/phone", json={"phone": "09121112233", "code": code}, headers=h)
    assert r.status_code == 200, r.text
    assert r.json()["grants"] == [{"type": "coins", "amount": 500}]
    assert r.json()["profile"]["secured"] and r.json()["profile"]["phone"] == "0912***2233"

    # new phone: log in with an SMS code, the save comes back
    await client.post("/v1/account/otp", json={"phone": "09121112233"})  # too soon
    from app import db
    from app.models import OtpCode
    from sqlalchemy import update
    from datetime import timedelta
    from app.models import utcnow
    async with db.SessionLocal() as s:  # pretend a minute passed
        await s.execute(update(OtpCode).values(created_at=utcnow() - timedelta(minutes=2)))
        await s.commit()
    code = await _code(client)
    r = await client.post("/v1/account/login/phone",
                          json={"phone": "09121112233", "code": code, "device_id": "phone-b"})
    assert r.status_code == 200 and r.json()["player_id"] == p["player_id"]
    new_h = {"Authorization": f"Bearer {r.json()['token']}"}
    assert (await client.get("/v1/save", headers=new_h)).json()["data"]["coins"] == 4321
    # the old phone was logged out
    assert (await client.get("/v1/me", headers=h)).status_code == 401


async def test_wrong_code_and_resend_limit(client):
    p = await new_player(client)
    await _code(client, "09125556677")
    r = await client.post("/v1/account/otp", json={"phone": "09125556677"})
    assert r.status_code == 429
    r = await client.post("/v1/account/phone", json={"phone": "09125556677", "code": "00000"},
                          headers=p["headers"])
    assert r.status_code in (400,)
    assert (await client.post("/v1/account/otp", json={"phone": "12345"})).status_code == 422


async def test_phone_taken_by_other_account(client):
    a = await new_player(client, "dev-x")
    b = await new_player(client, "dev-y")
    from app import db
    from app.models import Player
    async with db.SessionLocal() as s:
        pa = await s.get(Player, a["player_id"])
        pa.phone = "09129998877"
        await s.commit()
    code = await _code(client, "09129998877")
    r = await client.post("/v1/account/phone", json={"phone": "09129998877", "code": code},
                          headers=b["headers"])
    assert r.status_code == 409
    # the same code still works to log in to that account
    r = await client.post("/v1/account/login/phone",
                          json={"phone": "09129998877", "code": code, "device_id": "dev-y"})
    assert r.status_code == 200 and r.json()["player_id"] == a["player_id"]


async def test_username_password(client):
    p = await new_player(client, "user-dev")
    r = await client.post("/v1/account/username", json={"username": "Shaitoon_1", "password": "abc123"},
                          headers=p["headers"])
    assert r.status_code == 200, r.text
    assert r.json()["profile"]["username"] == "shaitoon_1"
    assert r.json()["grants"]  # first time reward
    # changing the password gives no second reward
    r = await client.post("/v1/account/username", json={"username": "shaitoon_1", "password": "newpass1"},
                          headers=p["headers"])
    assert r.json()["grants"] == []
    other = await new_player(client, "other-dev")
    taken = await client.post("/v1/account/username", json={"username": "shaitoon_1", "password": "zzzzzz"},
                              headers=other["headers"])
    assert taken.status_code == 409
    bad = await client.post("/v1/account/login/password",
                            json={"username": "shaitoon_1", "password": "abc123", "device_id": "d2"})
    assert bad.status_code == 401
    ok = await client.post("/v1/account/login/password",
                           json={"username": "SHAITOON_1", "password": "newpass1", "device_id": "d2"})
    assert ok.status_code == 200 and ok.json()["player_id"] == p["player_id"]


async def test_email_password(client):
    p = await new_player(client, "mail-dev")
    r = await client.post("/v1/account/email", json={"email": " Amin@Gmail.com ", "password": "secret1"},
                          headers=p["headers"])
    assert r.status_code == 200, r.text
    assert r.json()["profile"]["email"] == "am***@gmail.com" and r.json()["profile"]["secured"]
    bad = await client.post("/v1/account/email", json={"email": "not-an-email", "password": "secret1"},
                            headers=p["headers"])
    assert bad.status_code == 422
    other = await new_player(client, "mail-dev-2")
    taken = await client.post("/v1/account/email", json={"email": "amin@gmail.com", "password": "zzzzzz"},
                              headers=other["headers"])
    assert taken.status_code == 409
    wrong = await client.post("/v1/account/login/email",
                              json={"email": "amin@gmail.com", "password": "nope99", "device_id": "x1"})
    assert wrong.status_code == 401
    ok = await client.post("/v1/account/login/email",
                           json={"email": "AMIN@gmail.com", "password": "secret1", "device_id": "x1"})
    assert ok.status_code == 200 and ok.json()["player_id"] == p["player_id"]
    cfg = (await client.get("/v1/config")).json()
    assert cfg["sms_enabled"] is True  # dev + fake provider
