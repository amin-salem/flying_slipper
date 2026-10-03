"""End-to-end API tests (fake Bazaar mode, SQLite)."""
from datetime import timedelta

from app import db
from app.models import Run, utcnow

from .conftest import ADMIN, new_player


async def test_health_and_config(client):
    assert (await client.get("/health")).json() == {"ok": True}
    cfg = (await client.get("/v1/config")).json()
    assert cfg["min_version"] >= 1 and "server_time" in cfg and "prices" in cfg


async def test_register_login_and_profile(client):
    p = await new_player(client)
    r = await client.post("/v1/auth/login", json={"player_id": p["player_id"], "secret": p["secret"]})
    assert r.status_code == 200
    bad = await client.post("/v1/auth/login", json={"player_id": p["player_id"], "secret": "nope"})
    assert bad.status_code == 401
    me = (await client.get("/v1/me", headers=p["headers"])).json()
    assert me["player_id"] == p["player_id"] and len(me["invite_code"]) == 6
    r = await client.patch("/v1/me", json={"nickname": "علی کوچولو"}, headers=p["headers"])
    assert r.json()["nickname"] == "علی کوچولو"
    r = await client.patch("/v1/me", json={"nickname": "www.spam.ir"}, headers=p["headers"])
    assert r.status_code == 422
    assert (await client.get("/v1/me")).status_code == 401


async def test_cloud_save_and_conflict(client):
    p = await new_player(client)
    h = p["headers"]
    assert (await client.get("/v1/save", headers=h)).json()["version"] == 0
    r = await client.put("/v1/save", json={"base_version": 0, "data": {"coins": 300, "owned": ["ali"]}}, headers=h)
    assert r.json()["version"] == 1
    # an old copy (base_version 0) is refused with the server copy attached
    r = await client.put("/v1/save", json={"base_version": 0, "data": {"coins": 5}}, headers=h)
    assert r.status_code == 409
    assert r.json()["detail"]["server"]["data"]["coins"] == 300
    # force overwrite
    r = await client.put("/v1/save", json={"base_version": 0, "data": {"coins": 5}, "force": True}, headers=h)
    assert r.json()["version"] == 2
    r = await client.put("/v1/save", json={"base_version": 2, "data": {"coins": "lots"}}, headers=h)
    assert r.status_code == 422


async def test_coin_hack_is_flagged(client):
    p = await new_player(client)
    h = p["headers"]
    await client.put("/v1/save", json={"base_version": 0, "data": {"coins": 100}}, headers=h)
    await client.put("/v1/save", json={"base_version": 1, "data": {"coins": 9_000_000}}, headers=h)
    d = (await client.get(f"/admin/players/{p['player_id']}", headers=ADMIN)).json()
    assert d["player"]["suspicious"] == 1
    assert d["player"]["flags"][0].startswith("coins_jump")


async def _age_run(run_id: str, seconds: int):
    async with db.SessionLocal() as s:
        run = await s.get(Run, run_id)
        run.started_at = utcnow() - timedelta(seconds=seconds)
        await s.commit()


async def test_runs_and_leaderboard(client):
    a = await new_player(client, "dev-a")
    b = await new_player(client, "dev-b")
    for player, meters in ((a, 800), (b, 1200)):
        run = (await client.post("/v1/runs/start", json={"character": "ali"}, headers=player["headers"])).json()
        await _age_run(run["run_id"], 120)
        r = await client.post(f"/v1/runs/{run['run_id']}/finish", headers=player["headers"],
                              json={"meters": meters, "coins": 100, "near_misses": 2,
                                    "duration_ms": 110_000, "score_mul": 1})
        out = r.json()
        assert out["accepted"], out
        assert out["score"] == meters * 10 + 200 + 100
        # can't send a smaller result again
        again = await client.post(f"/v1/runs/{run['run_id']}/finish", headers=player["headers"],
                                  json={"meters": 1, "coins": 0, "duration_ms": 1000})
        assert again.status_code == 409
    # after "continue" the same run is sent again with bigger numbers
    run_a = (await client.post("/v1/runs/start", json={}, headers=a["headers"])).json()
    await _age_run(run_a["run_id"], 200)
    first = (await client.post(f"/v1/runs/{run_a['run_id']}/finish", headers=a["headers"],
                               json={"meters": 300, "coins": 10, "duration_ms": 60_000})).json()
    assert first["accepted"]
    cont = (await client.post(f"/v1/runs/{run_a['run_id']}/finish", headers=a["headers"],
                              json={"meters": 700, "coins": 30, "duration_ms": 150_000})).json()
    assert cont["accepted"] and cont["score"] == 7060
    lb = (await client.get("/v1/leaderboard?period=week", headers=a["headers"])).json()
    mine = lb["me"]
    assert mine["me"] and mine["score"] == 8000 + 300
    names = [row["player_id"] for row in lb["top"]]
    assert names.index(b["player_id"][:8]) < names.index(a["player_id"][:8])


async def test_fake_run_is_rejected(client):
    p = await new_player(client)
    run = (await client.post("/v1/runs/start", json={}, headers=p["headers"])).json()
    # claims a 2 minute run one second after starting
    r = await client.post(f"/v1/runs/{run['run_id']}/finish", headers=p["headers"],
                          json={"meters": 1500, "coins": 50, "duration_ms": 120_000})
    assert r.json() == {"accepted": False, "reason": "longer_than_real_time", "score": 0,
                        "best_week": 0, "best_all": 0, "rank_week": None}


async def test_purchase_verify_once(client):
    p = await new_player(client)
    h = p["headers"]
    r = (await client.post("/v1/purchases/verify", headers=h,
                           json={"product_id": "coins_medium", "purchase_token": "test-abc-1"})).json()
    assert r["status"] == "granted" and r["consume"] is True
    assert r["grants"] == [{"type": "coins", "amount": 5000}]
    again = (await client.post("/v1/purchases/verify", headers=h,
                               json={"product_id": "coins_medium", "purchase_token": "test-abc-1"})).json()
    assert again["status"] == "already_granted" and again["grants"] == []
    other = await new_player(client, "thief-device")
    stolen = (await client.post("/v1/purchases/verify", headers=other["headers"],
                                json={"product_id": "coins_medium", "purchase_token": "test-abc-1"})).json()
    assert stolen == {"status": "rejected", "reason": "token_used", "grants": [], "consume": False}
    fake = (await client.post("/v1/purchases/verify", headers=h,
                              json={"product_id": "coins_small", "purchase_token": "made-up-token"})).json()
    assert fake["status"] == "rejected"


async def test_starter_piggy_and_vip(client):
    p = await new_player(client)
    h = p["headers"]
    await client.put("/v1/save", json={"base_version": 0, "data": {"piggy": 1800}}, headers=h)
    piggy = (await client.post("/v1/purchases/verify", headers=h,
                               json={"product_id": "piggy_bank", "purchase_token": "test-piggy"})).json()
    assert piggy["grants"] == [{"type": "piggy_break", "amount": 1800}]
    starter = (await client.post("/v1/purchases/verify", headers=h,
                                 json={"product_id": "starter_pack", "purchase_token": "test-starter"})).json()
    assert {"type": "character", "id": "football", "equip": True} in starter["grants"]
    assert starter["consume"] is False
    vip = (await client.post("/v1/purchases/verify", headers=h,
                             json={"product_id": "vip_monthly", "purchase_token": "test-vip"})).json()
    assert vip["grants"][0]["type"] == "vip_until"
    assert (await client.get("/v1/me", headers=h)).json()["vip_until"] == vip["grants"][0]["ts"]


async def test_gifts_and_broadcast(client):
    p = await new_player(client)
    h = p["headers"]
    r = await client.post("/admin/gifts", headers=ADMIN, json={
        "title": "ببخشید!", "grants": [{"type": "coins", "amount": 777}], "player_id": p["player_id"]})
    assert r.status_code == 200
    r = await client.post("/admin/gifts", headers=ADMIN, json={
        "title": "عیدی نوروز", "grants": [{"type": "boxes", "amount": 2}]})
    assert r.json()["sent_to"] == "everyone"
    items = (await client.get("/v1/inbox", headers=h)).json()
    titles = {i["title"]: i["id"] for i in items}
    assert "ببخشید!" in titles and "عیدی نوروز" in titles
    for title in ("ببخشید!", "عیدی نوروز"):
        ok = await client.post(f"/v1/inbox/{titles[title]}/claim", headers=h)
        assert ok.status_code == 200
        twice = await client.post(f"/v1/inbox/{titles[title]}/claim", headers=h)
        assert twice.status_code == 409
    assert (await client.get("/v1/inbox", headers=h)).json() == []
    bad = await client.post("/admin/gifts", headers=ADMIN, json={
        "title": "x", "grants": [{"type": "coins", "amount": -5}]})
    assert bad.status_code == 422


async def test_referral(client):
    inviter = await new_player(client, "inviter-phone")
    friend = await new_player(client, "friend-phone")
    code = (await client.get("/v1/me", headers=inviter["headers"])).json()["invite_code"]
    r = await client.post("/v1/referrals/redeem", json={"code": code}, headers=friend["headers"])
    assert r.status_code == 200 and r.json()["grants"][0]["type"] == "coins"
    assert (await client.post("/v1/referrals/redeem", json={"code": code},
                              headers=friend["headers"])).status_code == 409
    gifts = (await client.get("/v1/inbox", headers=inviter["headers"])).json()
    assert any(g["grants"] == [{"type": "coins", "amount": 1000}] for g in gifts)
    # same phone can't invite itself with a second account
    alt = await new_player(client, "inviter-phone")
    assert (await client.post("/v1/referrals/redeem", json={"code": code},
                              headers=alt["headers"])).status_code == 409


async def test_transfer_moves_account_and_logs_out_old_phone(client):
    p = await new_player(client, "old-phone")
    code = (await client.post("/v1/auth/transfer-code", headers=p["headers"])).json()["code"]
    r = await client.post("/v1/auth/transfer", json={"code": code, "device_id": "new-phone"})
    assert r.status_code == 200 and r.json()["player_id"] == p["player_id"]
    assert (await client.get("/v1/me", headers=p["headers"])).status_code == 401
    new_headers = {"Authorization": f"Bearer {r.json()['token']}"}
    assert (await client.get("/v1/me", headers=new_headers)).status_code == 200
    assert (await client.post("/v1/auth/transfer", json={"code": code, "device_id": "x-phone"})).status_code == 404


async def test_admin_config_and_auth(client):
    assert (await client.get("/admin/stats")).status_code == 403
    r = await client.put("/admin/config", headers=ADMIN, json={"values": {"min_version": 9}})
    assert r.json()["min_version"] == 9
    assert (await client.get("/v1/config")).json()["min_version"] == 9
    await client.delete("/admin/config/min_version", headers=ADMIN)
    assert (await client.get("/v1/config")).json()["min_version"] == 1
    assert (await client.put("/admin/config", headers=ADMIN,
                             json={"values": {"made_up": 1}})).status_code == 422
    stats = (await client.get("/admin/stats", headers=ADMIN)).json()
    assert stats["players"] >= 1


async def test_banned_player_is_locked_out(client):
    p = await new_player(client)
    await client.post(f"/admin/players/{p['player_id']}/ban", headers=ADMIN, json={"banned": True})
    assert (await client.get("/v1/me", headers=p["headers"])).status_code == 403


async def test_events(client):
    p = await new_player(client)
    r = await client.post("/v1/events", headers=p["headers"],
                          json={"events": [{"name": "shop_open"}, {"name": "run_end", "props": {"m": 300}}]})
    assert r.json() == {"stored": 2}
