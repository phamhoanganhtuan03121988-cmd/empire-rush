## Balance DRAFT v3 (M1.2, owner-approved Option C from docs/M1_BALANCE_REVIEW.md):
## per-player-count round caps 2p 40 / 3p 30 / 4p 25, level rent rows x7/x22/x55,
## upgrade costs 30/30/45/45/60/60/75. Everything else unchanged from v2.
extends TestCase

const PRICES := [60, 90, 120, 150, 180, 220, 260]
const BASE_RENT := [8, 11, 15, 18, 22, 26, 32]
const UPGRADE := [30, 30, 45, 45, 60, 60, 75]
const LIQUIDATION := [30, 45, 60, 75, 90, 110, 130]


func test_shipped_values_match_option_c() -> void:
	var b := ErFixture.config().balance
	assert_eq(b["rent_multiplier_pct"]["level0_incomplete"], 100, "L0 incomplete unchanged")
	assert_eq(b["rent_multiplier_pct"]["level0_district_complete"], 200, "L0 complete unchanged")
	assert_eq(b["rent_multiplier_pct"]["level1"], 700, "L1 x7")
	assert_eq(b["rent_multiplier_pct"]["level2"], 2200, "L2 x22")
	assert_eq(b["rent_multiplier_pct"]["level3"], 5500, "L3 x55")
	for i in 7:
		var t: Dictionary = ErFixture.config().tiers[i + 1]
		assert_eq(t["price"], PRICES[i], "tier %d price unchanged" % (i + 1))
		assert_eq(t["base_rent"], BASE_RENT[i], "tier %d base rent unchanged" % (i + 1))
		assert_eq(t["upgrade_cost"], UPGRADE[i], "tier %d upgrade cost" % (i + 1))
		assert_eq(t["liquidation_value"], LIQUIDATION[i], "tier %d liquidation unchanged" % (i + 1))
	assert_eq(b["start_reward"], 200, "Start reward stays 200 (owner decision 5)")
	assert_eq(b["starting_cash"], 1500, "starting cash unchanged")
	assert_eq(b["max_rounds"], 25, "fallback cap unchanged")
	assert_eq(b["time_cap_ms"], 1800000, "30-minute cap unchanged")
	assert_eq(b["upgrade_refund_pct"], 50, "liquidation formula unchanged (owner decision 4)")


func test_round_caps_by_player_count() -> void:
	var cfg := ErFixture.config()
	assert_eq(cfg.max_rounds_for(2), 40, "2 players")
	assert_eq(cfg.max_rounds_for(3), 30, "3 players")
	assert_eq(cfg.max_rounds_for(4), 25, "4 players")


func test_full_rent_table() -> void:
	# Engine-computed rent for one property of every tier at every level must
	# equal base x row exactly (integer, floored).
	var rows := {0: 200, 1: 700, 2: 2200, 3: 5500}
	for i in 7:
		var did := "D%d" % (i + 1)
		for lv in rows:
			var f := ErFixture.make()
			f.give(1, f.district(did), lv)
			var pid: String = f.district(did)[0]
			assert_eq(f.engine.gross_rent(pid), BASE_RENT[i] * rows[lv] / 100, "%s level %d" % [did, lv])
	var g := ErFixture.make()
	g.give(1, ["P_D7_1"])
	assert_eq(g.engine.gross_rent("P_D7_1"), 32, "incomplete district: base rent only")


func test_max_level3_rent_is_1760() -> void:
	var f := ErFixture.make()
	f.give(1, f.district("D7"), 3)
	assert_eq(f.engine.gross_rent("P_D7_1"), 1760, "32 x 55")
	var before := f.cash(1)
	f.set_cash(0, 2000)
	f.land(0, 25)
	assert_eq(f.cash(0), 240, "payer charged 1760")
	assert_eq(f.cash(1) - before, 1760, "owner receives 1760")
	assert_healthy(f)


func test_1760_rent_bankrupts_a_fresh_player() -> void:
	# A player holding only the starting 1500 RC cannot survive one tier-7 L3
	# hit: rescue opens, then G7 sends all remaining cash to the creditor.
	var f := ErFixture.make(3)
	f.give(1, f.district("D7"), 3)
	f.land(0, 25)
	assert_eq(f.state.phase, GameState.RESCUE, "rescue")
	assert_eq(f.state.rescue["amount"], 1760, "debt")
	f.expire()
	assert_true(f.state.player(0)["bankrupt"], "bankrupt")
	assert_eq(f.cash(1), 1500 + 1500, "creditor receives the remaining 1500")
	assert_healthy(f)


func test_rent_insurance_caps_1760() -> void:
	var f := ErFixture.make()
	f.give(1, f.district("D7"), 3)
	f.engine._apply_effects(0, [{"type": "rent_cap", "cap": 100, "duration_rounds": 2}], "t")
	f.engine._commit()
	f.land(0, 25)
	assert_eq(f.cash(0), 1400, "cap still applies to the maximum rent")


func test_upgrade_costs_and_liquidation_values() -> void:
	var f := ErFixture.make(2, 1, ["INVESTOR", "TYCOON"])
	for i in 7:
		var pid: String = f.district("D%d" % (i + 1))[0]
		f.give(0, f.district("D%d" % (i + 1)), 0)
		assert_eq(f.engine.upgrade_quote(0, pid)["amount"], UPGRADE[i], "tier %d upgrade quote" % (i + 1))
		f.state.level[pid] = 3
		assert_eq(f.engine.liquidation_value(pid), LIQUIDATION[i] + 3 * UPGRADE[i] * 50 / 100, "tier %d L3 liquidation" % (i + 1))


func _play_to_cap(n: int, bankrupt_seat: int = -1) -> Dictionary:
	var f := ErFixture.make(n)
	if bankrupt_seat >= 0:
		f.set_cash(bankrupt_seat, 0)
		f.state.player(bankrupt_seat)["bankrupt"] = true
	var cap := f.config().max_rounds_for(n)
	f.state.round = cap
	f.state.current_seat = 0 if bankrupt_seat != 0 else 1
	var ended_before_last := false
	var active := f.state.active_seats()
	for i in active.size():
		var seat: int = active[i]
		f.to_strategy(seat)
		f.cmd(seat, ErCommand.END_TURN)
		if i < active.size() - 1 and f.state.phase == GameState.ENDED:
			ended_before_last = true
	return {"f": f, "ended_early": ended_before_last}


func test_cap_ends_after_last_seat_for_each_player_count() -> void:
	for n in [2, 3, 4]:
		var r := _play_to_cap(n)
		var f: ErFixture = r["f"]
		assert_false(r["ended_early"], "%dp: not before the last seat" % n)
		assert_eq(f.state.phase, GameState.ENDED, "%dp: ended" % n)
		assert_eq(f.state.end_reason, "round_cap", "%dp: reason" % n)
		assert_eq(f.state.round, f.config().max_rounds_for(n), "%dp: final round == cap" % n)
		assert_healthy(f, "%dp" % n)


func test_two_players_continue_past_round_25() -> void:
	var f := ErFixture.make(2)
	f.state.round = 25
	for seat in [0, 1]:
		f.to_strategy(seat)
		f.cmd(seat, ErCommand.END_TURN)
	assert_ne(f.state.phase, GameState.ENDED, "2p keeps playing after round 25")
	assert_eq(f.state.round, 26, "round 26 starts")


func test_three_players_continue_past_round_25_and_end_at_30() -> void:
	var f := ErFixture.make(3)
	f.state.round = 29
	for seat in [0, 1, 2]:
		f.to_strategy(seat)
		f.cmd(seat, ErCommand.END_TURN)
	assert_eq(f.state.round, 30, "round 30 starts")
	assert_ne(f.state.phase, GameState.ENDED, "not ended at 29")


func test_cap_uses_seated_count_after_bankruptcy() -> void:
	# A 3-player match keeps the 3-player cap (30) after one player goes
	# bankrupt; it does not switch to the 2-player cap (40).
	var r := _play_to_cap(3, 2)
	var f: ErFixture = r["f"]
	assert_eq(f.state.phase, GameState.ENDED, "ended at the 3-player cap")
	assert_eq(f.state.round, 30, "round 30")


func test_invalid_round_cap_config_rejected() -> void:
	for bad in [{"2": 0}, {"2": 40.5}, {"5": 20}, {"3": "30"}]:
		var cfg := ErFixture.config().with_balance({"max_rounds_by_players": bad})
		assert_false(cfg.is_valid(), "rejects %s" % str(bad))


func test_missing_player_count_falls_back_to_max_rounds() -> void:
	var cfg := ErFixture.config().with_balance({"max_rounds_by_players": {"2": 40, "3": 30, "4": 25}})
	var raw := cfg.balance.duplicate(true)
	raw["max_rounds_by_players"].erase("3")
	var c2 := GameConfig.from_dicts(cfg.board, raw, cfg.events, cfg.characters, cfg.opportunities)
	assert_true(c2.is_valid(), "partial table is valid")
	assert_eq(c2.max_rounds_for(3), 25, "falls back to max_rounds")


func test_simulated_matches_respect_per_count_caps() -> void:
	var cfg := ErFixture.config()
	var beyond_25 := 0
	for i in 30:
		var n: int = [2, 3, 4][i % 3]
		var r := MatchSimulator.run(cfg, 20000 + i, n, {})
		assert_true(r["rounds"] <= cfg.max_rounds_for(n), "seed %d %dp rounds %d" % [r["seed"], n, r["rounds"]])
		assert_eq(r["invariant_errors"].size(), 0, "seed %d invariants" % r["seed"])
		assert_false(r["stuck"], "seed %d stuck" % r["seed"])
		if n < 4 and r["rounds"] > 25:
			beyond_25 += 1
	assert_true(beyond_25 > 5, "2p/3p matches actually use the longer caps (%d)" % beyond_25)


func test_rent_ladder_query_matches_gross_rent() -> void:
	# The HUD shows rent_ladder(); it must agree with the rent actually charged.
	for i in 7:
		var did := "D%d" % (i + 1)
		var f := ErFixture.make()
		var pid: String = f.district(did)[0]
		var ladder := f.engine.rent_ladder(pid)
		f.give(1, [pid])
		assert_eq(ladder[0], f.engine.gross_rent(pid), "%s incomplete" % did)
		for lv in 4:
			f.give(1, f.district(did), lv)
			assert_eq(ladder[lv + 1], f.engine.gross_rent(pid), "%s level %d" % [did, lv])
