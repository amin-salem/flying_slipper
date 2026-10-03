"""Pure rule tests (no database)."""
from app import game_rules as r


def test_score_formula_matches_app():
    res = r.RunResult(meters=500, coins=100, near_misses=3, duration_ms=60000, score_mul=2)
    assert r.score_of(res) == (5000 + 200 + 150) * 2


def test_honest_run_passes():
    res = r.RunResult(meters=900, coins=250, near_misses=8, duration_ms=80_000, score_mul=1)
    assert r.check_run(res, server_seconds=85, saved_xp=0) is None


def test_impossible_runs_fail():
    assert r.check_run(r.RunResult(5000, 10, 0, 60_000, 1), 65, 0) == "too_fast"
    assert r.check_run(r.RunResult(100, 10, 0, 60_000, 1), 10, 0) == "longer_than_real_time"
    assert r.check_run(r.RunResult(100, 900, 0, 60_000, 1), 65, 0) == "too_many_coins"
    assert r.check_run(r.RunResult(100, 10, 0, 60_000, 9), 65, 0) == "bad_multiplier"


def test_week_number_matches_app_anchor():
    from datetime import date
    assert r.week_number(date(2024, 1, 6)) == 0
    assert r.week_number(date(2024, 1, 12)) == 0
    assert r.week_number(date(2024, 1, 13)) == 1


def test_piggy_grant_uses_saved_piggy_and_cap():
    assert r.grants_for_product("piggy_bank", {"piggy": 1200}) == [{"type": "piggy_break", "amount": 1200}]
    assert r.grants_for_product("piggy_bank", {"piggy": 99999})[0]["amount"] == r.PIGGY_MAX


def test_save_cleaning_and_cheat_flags():
    assert r.clean_save({"coins": 10, "unknown": 1}) == {"coins": 10}
    flags = r.check_save({"coins": 0}, {"coins": 10_000_000}, r.Allowance(hours=1))
    assert any(f.startswith("coins_jump") for f in flags)
    assert r.check_save({"coins": 0}, {"coins": 2000}, r.Allowance(hours=1)) == []


def test_admin_grants_are_checked():
    assert r.check_grants([{"type": "coins", "amount": 5}]) == [{"type": "coins", "amount": 5}]
    for bad in ([{"type": "coins", "amount": -1}], [{"type": "character", "id": "batman"}], [{"type": "x"}]):
        try:
            r.check_grants(bad)
        except ValueError:
            continue
        raise AssertionError(f"accepted {bad}")
