## Turn order, rounds, timers, safe timeout defaults and caps (GDD §2, §3, §9; G9).
extends TestCase


func test_turn_order_and_rounds() -> void:
	var f := ErFixture.make(3)
	var order := []
	for i in 6:
		order.append(f.state.current_seat)
		f.to_strategy(f.state.current_seat)
		f.cmd(f.state.current_seat, ErCommand.END_TURN)
	assert_eq(order, [0, 1, 2, 0, 1, 2], "seat order")
	assert_eq(f.state.round, 3, "two full rounds completed")
	assert_eq(f.state.turn_number, 7, "turn counter")


func test_turn_timer_is_45s() -> void:
	var f := ErFixture.make()
	assert_eq(f.state.turn_deadline_ms - f.clock.now_ms(), 45000, "45 s")


func test_idle_turn_resolves_with_safe_defaults() -> void:
	var f := ErFixture.make(2, 3)
	var start_turn := f.state.turn_number
	var guard := 0
	while f.state.turn_number == start_turn and guard < 10:
		f.expire()
		guard += 1
	assert_eq(f.state.current_seat, 1, "idle player's turn ended")
	for pid in f.state.owner:
		assert_ne(f.state.owner[pid], 0, "idle player never buys")
	assert_eq(f.state.properties_of(0).size(), 0, "nothing bought")
	assert_true(f.state.player(0)["position"] > 0, "server rolled for the idle player")
	assert_healthy(f)


func test_buy_timeout_passes_and_auctions() -> void:
	var f := ErFixture.make()
	f.land(0, 1)
	var ev := f.expire()
	assert_true(f.types(ev).has("AuctionOpened"), "auction after timeout")


func test_strategy_timeout_ends_turn() -> void:
	var f := ErFixture.make()
	f.to_strategy(0)
	f.expire()
	assert_eq(f.state.current_seat, 1, "next player")


func test_round_cap_ends_match() -> void:
	var f := ErFixture.make(2)
	var cap := f.config().max_rounds_for(2)  # v3: 40 rounds for 2 players
	f.state.round = cap
	f.to_strategy(0)
	f.cmd(0, ErCommand.END_TURN)
	assert_ne(f.state.phase, GameState.ENDED, "last round not complete yet")
	f.to_strategy(1)
	f.cmd(1, ErCommand.END_TURN)
	assert_eq(f.state.phase, GameState.ENDED, "ended after the last seat of the last round")
	assert_eq(f.state.end_reason, "round_cap", "reason")
	assert_healthy(f)


func test_time_cap_checked_only_at_turn_end() -> void:
	var f := ErFixture.make(2)
	f.clock.set_now(f.state.match_start_ms + 1800000)
	f.state.turn_deadline_ms = f.clock.now_ms() + 45000
	f.to_strategy(0)
	assert_ne(f.state.phase, GameState.ENDED, "not ended mid-turn")
	f.cmd(0, ErCommand.END_TURN)
	assert_eq(f.state.phase, GameState.ENDED, "ended at turn boundary")
	assert_eq(f.state.end_reason, "time_cap", "reason")


func test_just_below_time_cap_continues() -> void:
	var f := ErFixture.make(2)
	f.clock.set_now(f.state.match_start_ms + 1799999)
	f.state.turn_deadline_ms = f.clock.now_ms() + 45000
	f.to_strategy(0)
	f.cmd(0, ErCommand.END_TURN)
	assert_ne(f.state.phase, GameState.ENDED, "1 ms before cap keeps playing")


func test_end_turn_only_in_strategy() -> void:
	var f := ErFixture.make()
	var h := f.state.state_hash()
	assert_rejected(f, f.cmd(0, ErCommand.END_TURN), ErCommand.E_WRONG_PHASE, h)


func test_roll_timeout_without_auto_roll_ends_turn() -> void:
	var f := ErFixture.make()
	f.config().balance["timeout_auto_roll"] = false
	f.expire()
	f.config().balance["timeout_auto_roll"] = true
	assert_eq(f.state.player(0)["position"], 0, "idle player did not move")
	assert_eq(f.state.current_seat, 1, "turn ended")
	assert_healthy(f)
