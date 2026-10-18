## Regression tests for defects found while building M1 (see docs/M1_REPORT.md §6).
extends TestCase


## R1 (found by the 100-match simulation): a Rescue resolved after the turn
## timer had run out returned to StrategyAction with zero time left. A command
## sent at that instant must be rejected and advance() must end the turn
## instead of leaving the match waiting.
func test_r1_rescue_resolved_with_no_turn_time_left() -> void:
	var f := ErFixture.make(2)
	f.give(1, f.district("D1"), 3)
	f.give(0, ["P_D7_1"])
	f.set_cash(0, 400)  # 400 + 130 liquidation covers the v3 level-3 rent of 440
	f.state.turn_deadline_ms = f.clock.now_ms()  # no turn time left
	f.land(0, 1)
	f.cmd(0, ErCommand.LIQUIDATE, {"property_ids": ["P_D7_1"]})
	assert_eq(f.state.phase, GameState.STRATEGY, "debt paid")
	var h := f.state.state_hash()
	assert_rejected(f, f.cmd(0, ErCommand.END_TURN), ErCommand.E_DEADLINE_PASSED, h)
	f.engine.advance()
	assert_eq(f.state.current_seat, 1, "turn ended by the timer, not stuck")
	assert_healthy(f)


## R2: a trade proposed during Rescue shares the rescue deadline. When both
## expire at the same instant, one advance() must resolve the trade AND the
## rescue in deterministic order.
func test_r2_rescue_trade_and_rescue_expire_together() -> void:
	var f := ErFixture.make(3)
	f.give(1, f.district("D1"), 3)
	f.set_cash(0, 100)
	f.land(0, 1)
	f.clock.set_now(f.state.rescue["deadline_ms"] - 5000)
	f.cmd(0, ErCommand.PROPOSE_TRADE, {"to_player_id": "p2",
		"give": {"cash": 0, "property_ids": []}, "take": {"cash": 10, "property_ids": []}})
	assert_eq(f.state.trade["deadline_ms"], f.state.rescue["deadline_ms"], "trade clipped to rescue deadline")
	var ev := f.expire()
	var types := f.types(ev)
	assert_true(types.find("TradeResolved") < types.find("PlayerBankrupt"), "trade expires before bankruptcy")
	assert_true(f.state.player(0)["bankrupt"], "debtor bankrupt")
	assert_healthy(f)


## R3: the original doubles test passed against an engine that granted extra
## rolls (mutation testing). Covered by the strengthened
## test_movement.gd::test_doubles_do_not_grant_extra_roll; this guards the
## mechanism directly on a deterministic seed with doubles.
func test_r3_doubles_end_in_a_non_roll_phase() -> void:
	for seed_value in range(1, 400):
		var f := ErFixture.make(2, seed_value)
		f.give(0, f.config().property_ids)
		f.cmd(0, ErCommand.ROLL_DICE)
		if f.state.last_roll[0] == f.state.last_roll[1]:
			assert_ne(f.state.phase, GameState.AWAIT_ROLL, "seed %d" % seed_value)
			return
	errors.append("no doubles found")


## R4: Godot's JSON parser yields floats; integral values must become ints so
## money math never touches floating point.
func test_r4_json_floats_normalised() -> void:
	var v = GameConfig.normalize_numbers({"a": 1500.0, "b": [200.0, {"c": 3.0}]})
	assert_eq(typeof(v["a"]), TYPE_INT, "top level")
	assert_eq(typeof(v["b"][0]), TYPE_INT, "array")
	assert_eq(typeof(v["b"][1]["c"]), TYPE_INT, "nested")
