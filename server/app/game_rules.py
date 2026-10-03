"""The game's rules, copied from the Flutter app so the server can check things.

Pure Python (no database, no web): easy to test. Keep the numbers here in
sync with the app when you change prices or rewards there.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

# ------------------------------------------------------------------ catalogs

CHARACTERS = {  # id -> price in coins (lib/game/characters.dart)
    "ali": 0, "sara": 1200, "omid": 1500, "pajama": 2500,
    "football": 3000, "nowruz": 6000, "hero": 10000,
}
SLIPPERS = ["slipper_classic", "slipper_pink", "slipper_green", "slipper_zebra",
            "slipper_isfahan", "slipper_yalda", "slipper_gold"]
BELTS = ["belt_classic", "belt_black", "belt_red", "belt_snake", "belt_gold"]
COSMETICS = set(SLIPPERS) | set(BELTS)
REPAIRS = {"vase": 800, "window": 2000, "tv": 3500, "carpet": 5000, "shelf": 7500, "wedding": 10000}
BOOSTS = ["magnet", "doubleCoins", "skate", "balloon"]
RANK_XP = [0, 3, 8, 15, 25, 40, 60, 85, 120]
PIGGY_MAX = 3000
MACHINE_COST = 1000

# Highest real game speed is 560 units/s = 14 m/s (40 units per meter).
MAX_METERS_PER_SECOND = 16.0


def rank_for_xp(xp: int) -> int:
    r = 0
    for i, need in enumerate(RANK_XP):
        if xp >= need:
            r = i
    return r


# ------------------------------------------------------------------ grants
# A "grant" is something the server gives the player. The app applies it
# exactly like a purchase in the test store (SaveData.applyGrant).
#   {"type": "coins", "amount": 1000}
#   {"type": "pillows" | "grandmas" | "boxes", "amount": n}
#   {"type": "no_ads"}            {"type": "starter_bought"}
#   {"type": "character", "id": "football", "equip": true}
#   {"type": "cosmetic", "id": "slipper_gold"}
#   {"type": "vip_until", "ts": <unix seconds>}
#   {"type": "piggy_break", "amount": n}   (coins from the piggy bank)

GRANT_TYPES = {"coins", "pillows", "grandmas", "boxes", "no_ads", "starter_bought",
               "character", "cosmetic", "vip_until", "piggy_break"}


@dataclass(frozen=True)
class ProductRule:
    id: str
    kind: str  # "consumable" | "permanent" | "subscription"
    grants: tuple[dict, ...] = ()


PRODUCTS: dict[str, ProductRule] = {
    p.id: p
    for p in [
        ProductRule("coins_small", "consumable", ({"type": "coins", "amount": 1000},)),
        ProductRule("coins_medium", "consumable", ({"type": "coins", "amount": 5000},)),
        ProductRule("coins_large", "consumable", ({"type": "coins", "amount": 15000},)),
        ProductRule("remove_ads", "permanent", ({"type": "no_ads"},)),
        ProductRule("starter_pack", "permanent", (
            {"type": "starter_bought"},
            {"type": "no_ads"},
            {"type": "coins", "amount": 5000},
            {"type": "character", "id": "football", "equip": True},
        )),
        # amount is filled in from the player's saved piggy bank
        ProductRule("piggy_bank", "consumable", ({"type": "piggy_break", "amount": 0},)),
        ProductRule("vip_monthly", "subscription", ()),
    ]
}


def grants_for_product(product_id: str, saved: dict | None, vip_until_ts: int | None = None) -> list[dict]:
    rule = PRODUCTS[product_id]
    out: list[dict] = []
    for g in rule.grants:
        g = dict(g)
        if g["type"] == "piggy_break":
            piggy = int((saved or {}).get("piggy", 0) or 0)
            g["amount"] = max(0, min(PIGGY_MAX, piggy))
        out.append(g)
    if rule.kind == "subscription" and vip_until_ts:
        out.append({"type": "vip_until", "ts": int(vip_until_ts)})
    return out


def coins_in(grants: list[dict]) -> int:
    """How many coins a list of grants gives (used by the anti-cheat)."""
    total = 0
    for g in grants:
        if g.get("type") in ("coins", "piggy_break"):
            total += int(g.get("amount", 0))
    return total


def check_grants(grants: list) -> list[dict]:
    """Validate grants written by the admin. Raises ValueError if wrong."""
    out = []
    for g in grants:
        if not isinstance(g, dict) or g.get("type") not in GRANT_TYPES:
            raise ValueError(f"bad grant: {g!r}")
        t = g["type"]
        if t in ("coins", "pillows", "grandmas", "boxes", "piggy_break"):
            n = int(g.get("amount", 0))
            if n <= 0 or n > 1_000_000:
                raise ValueError(f"bad amount in {g!r}")
            out.append({"type": t, "amount": n})
        elif t == "character":
            if g.get("id") not in CHARACTERS:
                raise ValueError(f"unknown character {g.get('id')!r}")
            out.append({"type": t, "id": g["id"], "equip": bool(g.get("equip", False))})
        elif t == "cosmetic":
            if g.get("id") not in COSMETICS:
                raise ValueError(f"unknown cosmetic {g.get('id')!r}")
            out.append({"type": t, "id": g["id"]})
        elif t == "vip_until":
            out.append({"type": t, "ts": int(g["ts"])})
        else:
            out.append({"type": t})
    return out


# ------------------------------------------------------------------ calendar

def local_now(tz: str = "Asia/Tehran") -> datetime:
    return datetime.now(ZoneInfo(tz))


def week_number(d: date) -> int:
    """Same as weekNumber() in lib/services/missions.dart (weeks start on Saturday)."""
    return (d - date(2024, 1, 6)).days // 7


def week_period(tz: str = "Asia/Tehran") -> str:
    return f"w{week_number(local_now(tz).date())}"


def week_ends_at(tz: str = "Asia/Tehran") -> datetime:
    today = local_now(tz).date()
    start = date(2024, 1, 6) + timedelta(days=week_number(today) * 7)
    end = start + timedelta(days=7)
    return datetime(end.year, end.month, end.day, tzinfo=ZoneInfo(tz))


# ------------------------------------------------------------------ runs

@dataclass
class RunResult:
    meters: int
    coins: int
    near_misses: int
    duration_ms: int
    score_mul: int


def score_of(r: RunResult) -> int:
    """Same formula as GameWorld.score in lib/game/world.dart."""
    return (r.meters * 10 + r.coins * 2 + r.near_misses * 50) * r.score_mul


def check_run(r: RunResult, server_seconds: float, saved_xp: int) -> str | None:
    """Returns None if the run looks real, otherwise the reason it was rejected.

    server_seconds: time between /runs/start and /runs/finish on the server.
    """
    if min(r.meters, r.coins, r.near_misses, r.duration_ms) < 0:
        return "negative"
    if r.duration_ms > server_seconds * 1000 + 5000:
        return "longer_than_real_time"
    secs = max(r.duration_ms / 1000, 0.001)
    if r.meters > secs * MAX_METERS_PER_SECOND + 30:
        return "too_fast"
    # coin characters x weekend x double coins can make one coin worth up to 12
    if r.coins > r.meters * 14 + 300:
        return "too_many_coins"
    if r.near_misses > r.meters / 5 + 5:
        return "too_many_near_misses"
    # the score multiplier is the rank + 1; allow one rank of lag in the save
    if r.score_mul < 1 or r.score_mul > rank_for_xp(saved_xp) + 2:
        return "bad_multiplier"
    return None


# ------------------------------------------------------------------ cloud save

# Field name -> expected type, matching SaveData in lib/services/save_data.dart
SAVE_FIELDS: dict[str, type | tuple[type, ...]] = {
    "coins": int, "best": int, "pillows": int, "grandmas": int,
    "noAds": bool, "vip": bool, "starterBought": bool,
    "owned": list, "skin": str, "lastDaily": str, "loginDay": int,
    "freeAdDay": str, "freeAdCount": int, "gamesPlayed": int,
    "soundOn": bool, "musicOn": bool, "tutorialDone": bool,
    "piggy": int, "mysteryBoxes": int, "repairs": list, "huntWeek": int,
    "xp": int, "bestScore": int, "huntTokens": int, "wordDay": str,
    "wordProgress": int, "starterOfferStart": int,
    "powerLevels": dict, "boostLevels": dict,
    "missionDay": str, "missionProgress": list, "missionClaimed": list,
    "ownedCosmetics": list, "equippedSlipper": str, "equippedBelt": str,
    "vipUntil": int,
}


def clean_save(data: dict) -> dict:
    """Keeps only known fields with the right types. Raises ValueError."""
    if not isinstance(data, dict):
        raise ValueError("save must be an object")
    out: dict = {}
    for key, want in SAVE_FIELDS.items():
        if key not in data:
            continue
        v = data[key]
        if want is int and isinstance(v, bool):
            raise ValueError(f"{key} must be a number")
        if not isinstance(v, want):
            raise ValueError(f"{key} has the wrong type")
        hi = 10**13 if key == "starterOfferStart" else 2_000_000_000  # that one is in ms
        if want is int and not (-1 <= v <= hi):
            raise ValueError(f"{key} out of range")
        if want is str and len(v) > 64:
            raise ValueError(f"{key} too long")
        if want in (list, dict) and len(v) > 64:
            raise ValueError(f"{key} too long")
        out[key] = v
    return out


@dataclass
class Allowance:
    """Coins the player could honestly have earned since the last save."""
    run_coins: int = 0          # coins from accepted runs
    bought_coins: int = 0       # from verified purchases
    gift_coins: int = 0         # from inbox / referrals
    hours: float = 0.0          # time since the last save


def allowed_coin_gain(a: Allowance) -> int:
    # run coins are already multiplied (abilities, weekend, double coins);
    # extra margin for the house bonus and piggy bank; plus daily rewards,
    # missions, wheel, word hunt, weekly hunt...
    daily = 4000 * (1 + int(a.hours // 24))
    return int(a.run_coins * 1.5 + a.bought_coins + a.gift_coins + daily + 3000)


def check_save(old: dict, new: dict, a: Allowance) -> list[str]:
    """Returns a list of problems (empty = looks fine)."""
    flags: list[str] = []
    gain = int(new.get("coins", 0)) - int(old.get("coins", 0))
    # spending coins on characters/repairs etc. also counts as "earned"
    if gain > allowed_coin_gain(a):
        flags.append(f"coins_jump:{gain}")
    for cid in new.get("owned", []):
        if cid not in CHARACTERS:
            flags.append(f"unknown_character:{cid}")
    for cid in new.get("ownedCosmetics", []):
        if cid not in COSMETICS:
            flags.append(f"unknown_cosmetic:{cid}")
    for rid in new.get("repairs", []):
        if rid not in REPAIRS:
            flags.append(f"unknown_repair:{rid}")
    if int(new.get("piggy", 0)) > PIGGY_MAX:
        flags.append("piggy_over_max")
    xp_gain = int(new.get("xp", 0)) - int(old.get("xp", 0))
    if xp_gain > 30 * (1 + int(a.hours // 24)):
        flags.append(f"xp_jump:{xp_gain}")
    return flags
