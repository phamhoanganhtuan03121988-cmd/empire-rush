## M1.1 balance-review tooling: experiment knobs must not leak into the rules
## or weaken invariants, and the default path must match M1 exactly.
extends TestCase


func test_with_balance_does_not_mutate_base() -> void:
	var base := ErFixture.config()
	var before: int = base.balance["max_rounds"]
	var tiers_before: String = JSON.stringify(base.balance["tiers"])
	var v := base.with_balance({"max_rounds": 40, "rent_multiplier_pct": {"level3": 9999}})
	assert_true(v.is_valid(), "patched config valid: %s" % str(v.errors))
	assert_eq(v.balance["max_rounds"], 40, "patched")
	assert_eq(v.balance["rent_multiplier_pct"]["level3"], 9999, "nested patch")
	assert_eq(v.balance["rent_multiplier_pct"]["level1"], base.balance["rent_multiplier_pct"]["level1"], "untouched keys kept")
	assert_eq(base.balance["max_rounds"], before, "base unchanged")
	assert_eq(JSON.stringify(base.balance["tiers"]), tiers_before, "base tiers unchanged")


func test_with_balance_still_validates() -> void:
	var v := ErFixture.config().with_balance({"start_reward": 150.5})
	assert_false(v.is_valid(), "fractional money rejected in patches too")


func test_round_cap_override_is_respected() -> void:
	var cfg := ErFixture.config().with_balance({"max_rounds": 30})
	var r := MatchSimulator.run(cfg, 77, 2, {})
	assert_true(r["rounds"] <= 30, "cap 30")
	assert_true(r["rounds"] > 25 or r["end_reason"] != "round_cap", "ran past the default 25 when capped at 30")
	assert_eq(r["invariant_errors"].size(), 0, "invariants")


func test_seat_cash_delta_keeps_money_conserved() -> void:
	var r := MatchSimulator.run(ErFixture.config(), 5, 4, {"seat_cash_delta": 50, "return_engine": true})
	assert_eq(r["invariant_errors"].size(), 0, "conservation holds with experiment cash")
	assert_false(r["stuck"], "finished")


func test_default_options_reproduce_m1() -> void:
	var cfg := ErFixture.config()
	var a := MatchSimulator.run(cfg, 4242, 4, {})
	var b := MatchSimulator.run(cfg, 4242, 4, {"time_model": {}, "seat_cash_delta": 0, "bot_opts": []})
	assert_eq(a["state_hash"], b["state_hash"], "explicit defaults == implicit defaults")


func test_time_model_changes_time_not_outcome() -> void:
	var cfg := ErFixture.config()
	var fast := MatchSimulator.run(cfg, 31, 2, {})
	var slow := MatchSimulator.run(cfg, 31, 2, {"time_model": {"roll": [2000, 1], "other": [4000, 1], "strategy": [3000, 1]}})
	assert_true(slow["duration_ms"] > fast["duration_ms"], "slower model takes longer")
	assert_eq(slow["results"].map(func(x): return x["seat"]), fast["results"].map(func(x): return x["seat"]), "same ranking (no time cap hit)")


func test_hoarder_stops_investing_in_final_rounds() -> void:
	var cfg := ErFixture.config()
	var r := MatchSimulator.run(cfg, 12, 3, {"bot_opts": [{"endgame_freeze_rounds": 25}], "return_engine": true})
	var e: GameEngine = r["engine"]
	assert_eq(e.state.properties_of(0).size(), 0, "a whole-match hoarder never buys")
	assert_eq(r["invariant_errors"].size(), 0, "invariants")
