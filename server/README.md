# Flying Slipper server (FastAPI)

The backend for «دمپایی پرنده». The game still works **offline**. The server adds:

| Feature | What it does |
|---|---|
| **Accounts** | No password. The phone registers once and keeps a secret. Players can move their account to a new phone with a one-time code. |
| **Cloud save** | The phone uploads its save. If two phones save at once, the server keeps both copies apart (version numbers) and the app decides which to keep. |
| **Anti-cheat** | The server compares each new save with the last one. If coins or XP jump more than possible, the player is flagged and hidden from leaderboards. The save itself is never deleted. |
| **Leaderboards** | Weekly (resets Saturday 00:00 Tehran time) and all-time. The server recomputes the score itself and rejects impossible runs (too fast, too many coins, faster than real time). |
| **Cafe Bazaar purchases** | The server checks every purchase token with Bazaar before the player gets anything. A token works only once. VIP time is controlled by the server. |
| **Gift inbox** | Gifts for one player or for everyone (e.g. a Nowruz gift), plus prizes for the weekly top players. |
| **Invite codes** | The new player gets 500 coins and a mystery box. The inviter gets 1,000 coins (up to 20 invites). Two accounts on the same phone can't invite each other. |
| **Remote config** | Change prices, the weekend event, the season, forced updates and maintenance mode without publishing a new app. |
| **Analytics** | The app can send events like `shop_open` or `run_end`. |
| **Admin API** | Stats, player lookup, ban, clear flags, gifts, config. |

## Run it on your computer (development)

```bash
cd server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt      # in Iran, if slow: add  -i https://mirror-pypi.runflare.com/simple
cp .env.example .env
uvicorn app.main:app --reload --host 0.0.0.0
```

* Interactive API docs: http://127.0.0.1:8000/docs. You can try every endpoint there.
* Run the tests with `pytest`.
* To test from your phone on the same Wi-Fi, use your computer's IP, e.g. `http://192.168.1.5:8000`.

In development, `BAZAAR_MODE=fake` accepts any purchase token that starts with `test-`.

## Put it online (production)

1. Get a Linux server (VPS) with Docker. A server **inside Iran** is best, so players connect fast and the Bazaar API is easy to reach. Examples are ArvanCloud, Pars Pack and Hamravesh, or a platform like Liara.
   - If Docker Hub is blocked on your server, set a registry mirror (e.g. `docker.arvancloud.ir`) in `/etc/docker/daemon.json`.
2. Copy the `server` folder to the server, then set it up:
   ```bash
   cp .env.example .env
   nano .env
   ```
   Set these values in `.env`:
   * `ENV=prod`
   * `JWT_SECRET` and `ADMIN_API_KEY`: make each one with `python3 -c "import secrets; print(secrets.token_urlsafe(48))"`
   * `POSTGRES_PASSWORD`: a strong password
   * `AUTO_CREATE_TABLES=false`
   * `BAZAAR_MODE`, `BAZAAR_PACKAGE_NAME` and the Bazaar keys (see below)
3. Point a domain at the server (for example `api.yourgame.ir`) and write it in `Caddyfile`.
4. Start everything:
   ```bash
   docker compose up -d --build
   docker compose run --rm api alembic upgrade head   # creates the tables (first time, and after updates)
   ```
5. Check that `https://api.yourgame.ir/health` returns `{"ok": true}`.

In production, the server **refuses to start** if the secrets are still the defaults or Bazaar is in fake mode.

To update the server later:
```bash
git pull
docker compose up -d --build
docker compose run --rm api alembic upgrade head
```

### Cafe Bazaar keys

In the Bazaar developer panel (پیشخوان توسعه‌دهندگان), open your app's in-app billing API settings.

* **New method:** create an API secret and set `BAZAAR_MODE=api_secret` and `BAZAAR_API_SECRET=...`.
* **Old method:** create an OAuth client and get a refresh token, then set `BAZAAR_MODE=oauth` and the three `BAZAAR_CLIENT_*` / `BAZAAR_REFRESH_TOKEN` values.

All Bazaar URLs and the header name are in `app/services/bazaar.py`. Before launch, compare them with Bazaar's current documentation at developers.cafebazaar.ir (In-app billing, then API).

## Admin examples

Every admin call needs the header `X-Admin-Key`.

```bash
KEY="your ADMIN_API_KEY"
API=https://api.yourgame.ir

# numbers
curl -H "X-Admin-Key: $KEY" $API/admin/stats

# Nowruz gift for everyone (expires in 14 days)
curl -X POST -H "X-Admin-Key: $KEY" -H "Content-Type: application/json" $API/admin/gifts \
  -d '{"title":"عیدی نوروز","message":"نوروز مبارک!","grants":[{"type":"coins","amount":1000},{"type":"boxes","amount":2}]}'

# force everyone below build 15 to update
curl -X PUT -H "X-Admin-Key: $KEY" -H "Content-Type: application/json" $API/admin/config \
  -d '{"values":{"min_version":15}}'

# real prices in the shop
curl -X PUT -H "X-Admin-Key: $KEY" -H "Content-Type: application/json" $API/admin/config \
  -d '{"values":{"prices":{"coins_small":"۲۹٬۰۰۰ تومان","coins_medium":"۹۹٬۰۰۰ تومان","coins_large":"۲۴۹٬۰۰۰ تومان","starter_pack":"۴۹٬۰۰۰ تومان","remove_ads":"۷۹٬۰۰۰ تومان","piggy_bank":"۳۹٬۰۰۰ تومان","vip_monthly":"۵۹٬۰۰۰ / ماه"}}}'

# suspicious players, then look at one
curl -H "X-Admin-Key: $KEY" "$API/admin/players?suspicious=true"
curl -H "X-Admin-Key: $KEY" $API/admin/players/<player_id>

# prizes for last week's top 10 (week numbers appear in /v1/leaderboard as "period")
curl -X POST -H "X-Admin-Key: $KEY" -H "Content-Type: application/json" $API/admin/leaderboard/reward \
  -d '{"period":"w143","tiers":[
        {"from_rank":1,"to_rank":1,"title":"نفر اول هفته!","grants":[{"type":"coins","amount":5000},{"type":"cosmetic","id":"slipper_gold"}]},
        {"from_rank":2,"to_rank":3,"title":"سکوی هفته!","grants":[{"type":"coins","amount":2500}]},
        {"from_rank":4,"to_rank":10,"title":"ده نفر برتر","grants":[{"type":"coins","amount":1000}]}]}'
```

These are the grant types the app understands:
* `coins`, `pillows`, `grandmas`, `boxes` (each with `amount`)
* `no_ads` and `starter_bought`
* `character` (`id`, optional `equip`)
* `cosmetic` (`id`)
* `vip_until` (`ts`)
* `piggy_break` (`amount`)

## API overview (all under `/v1`)

| Method | Path | Login | |
|---|---|---|---|
| GET | `/config` | no | remote config + server time |
| POST | `/auth/register` | no | first start → player_id, secret, token |
| POST | `/auth/login` | no | player_id + secret → token |
| POST | `/auth/transfer-code` | yes | code for moving to a new phone |
| POST | `/auth/transfer` | no | new phone uses the code |
| GET/PATCH | `/me` | yes | profile, nickname |
| GET/PUT | `/save` | yes | cloud save (`base_version`, `force`) |
| POST | `/runs/start`, `/runs/{id}/finish` | yes | game result → leaderboard |
| GET | `/leaderboard?period=week\|all` | yes | top 50 + your rank |
| POST | `/purchases/verify` | yes | Bazaar purchase token → grants |
| GET | `/inbox`, POST `/inbox/{id}/claim` | yes | gifts |
| POST | `/referrals/redeem` | yes | friend's invite code |
| POST | `/events` | yes | analytics (up to 100 per call) |

## Files

```
app/main.py              app setup
app/config.py            settings (.env)
app/models.py            database tables
app/game_rules.py        game numbers, copied from the Flutter app
                         (prices, products, score formula, anti-cheat)
app/routers/             the endpoints
app/services/bazaar.py   Cafe Bazaar purchase checking
app/services/remote_config.py   default remote config
tests/                   pytest tests
```

When you change prices or rewards in the app, change `app/game_rules.py` too.

**Database migrations:** after changing `app/models.py`, run `alembic revision --autogenerate -m "what changed"` and then `alembic upgrade head`.
