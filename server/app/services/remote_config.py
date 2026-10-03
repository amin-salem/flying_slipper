"""Settings the app downloads at start, so you can change the game without
publishing a new version (prices, events, forced update, maintenance...)."""
from __future__ import annotations

import copy
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models import ConfigValue

DEFAULTS: dict[str, Any] = {
    # Force update: apps with a lower build number must update.
    "min_version": 1,
    "latest_version": 1,
    "update_url": "https://cafebazaar.ir/app/com.example.flying_slipper",
    "maintenance": False,
    "maintenance_message": "در حال تعمیر سرور هستیم، چند دقیقه دیگه برگرد!",
    # Thursday + Friday double coins (Dart weekday numbers: Mon=1 ... Sun=7)
    "weekend_event": {"enabled": True, "days": [4, 5], "coin_multiplier": 2},
    # null = automatic (Yalda / Nowruz by date). Or "none" / "yalda" / "nowruz".
    "season_override": None,
    # Price labels shown in the shop (the real price is set in the Bazaar panel)
    "prices": {
        "starter_pack": "[قیمت] تومان",
        "coins_small": "[قیمت] تومان",
        "coins_medium": "[قیمت] تومان",
        "coins_large": "[قیمت] تومان",
        "remove_ads": "[قیمت] تومان",
        "piggy_bank": "[قیمت] تومان",
        "vip_monthly": "[قیمت] / ماه",
    },
    "starter_offer_hours": 24,
    "ads": {"interstitial_every_games": 3, "free_coin_ads_per_day": 5, "free_coin_ad_reward": 100},
    "leaderboard_enabled": True,
    # Short news shown on the home screen: [{"title": "...", "body": "..."}]
    "news": [],
}


async def load_config(session: AsyncSession) -> dict[str, Any]:
    cfg = copy.deepcopy(DEFAULTS)
    rows = (await session.execute(select(ConfigValue))).scalars().all()
    for row in rows:
        cfg[row.key] = row.value
    return cfg
