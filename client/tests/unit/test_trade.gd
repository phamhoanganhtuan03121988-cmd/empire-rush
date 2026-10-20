## Trades (GDD §7; G8): atomic, re-validated, 20 s expiry, never blocks.
extends TestCase


func _setup() -> ErFixture:
	var f := ErFixture.make(3)
	f.give(0, ["P_D1_1", "P_D1_2"])
	f.give(1, ["P_D1_3", "P_D2_1"])
	f.to_strategy(0)
	return f


func _offer(f: ErFixture, give_cash: int, give_ids: Array, take_cash: int, take_ids: Array, to: String = "p1") -> Dictionary:
	return f.cmd(0, ErCommand.PROPOSE_TRADE, {"to_player_id": to,
		"give": {"cash": give_cash, "property_ids": give_ids}, "take": {"cash": take_cash, "property_ids": take_ids}})


func _respond(f: ErFixture, accept: bool) -> Dictionary:
	return f.cmd(1, ErCommand.RESPOND_TRADE, {"trade_id": f.state.trade["trade_id"], "accept": accept})


func test_accepted_trade_moves_everything() -> void:
	var f := _setup()
	assert_true(_offer(f, 200, ["P_D1_1"], 50, ["P_D1_3"])["ok"], "propose")
	assert_eq(f.state.phase, GameState.TRADE_PENDING, "pending")
	assert_true(_respond(f, true)["ok"], "accept")
	assert_eq(f.state.owner["P_D1_1"], 1, "given property")
	assert_eq(f.state.owner["P_D1_3"], 0, "taken property")
	assert_eq(f.cash(0), 1500 - 200 + 50, "proposer cash")
	assert_eq(f.cash(1), 1500 + 200 - 50, "receiver cash")
	assert_eq(f.state.current_seat, 1, "proposer's turn ended")
	assert_healthy(f)


func test_rejected_trade_moves_nothing() -> void:
	var f := _setup()
	_offer(f, 200, [], 0, ["P_D1_3"])
	_respond(f, false)
	assert_eq(f.state.owner["P_D1_3"], 1, "unchanged")
	assert_eq(f.cash(0), 1500, "unchanged")
	assert_eq(f.state.current_seat, 1, "turn still ends")


func test_unanswered_trade_expires_after_20s() -> void:
	var f := _setup()
	_offer(f, 100, [], 0, ["P_D1_3"])
	var deadline: int = f.state.trade["deadline_ms"]
	assert_eq(deadline - f.clock.now_ms(), 20000, "20 s window")
	f.clock.set_now(deadline - 1)
	assert_eq(f.engine.advance().size(), 0, "not expired yet")
	var ev := f.expire()
	assert_true(f.types(ev).has("TradeResolved"), "resolved")
	assert_eq(f.state.owner["P_D1_3"], 1, "nothing moved")
	assert_eq(f.state.current_seat, 1, "match moves on")
	assert_healthy(f)


func test_accept_after_deadline_rejected() -> void:
	var f := _setup()
	_offer(f, 100, [], 0, ["P_D1_3"])
	f.clock.set_now(f.state.trade["deadline_ms"])
	var h := f.state.state_hash()
	assert_rejected(f, _respond(f, true), ErCommand.E_DEADLINE_PASSED, h)


func test_invalidated_when_terms_no_longer_hold() -> void:
	var f := _setup()
	_offer(f, 300, [], 0, ["P_D1_3"])
	f.set_cash(0, 100)  # proposer can no longer pay
	var res := _respond(f, true)
	assert_true(res["ok"], "response accepted as a command")
	var resolved: Array = res["events"].filter(func(e): return e["type"] == "TradeResolved")
	assert_eq(resolved[0]["data"]["status"], "invalidated", "status")
	assert_eq(f.state.owner["P_D1_3"], 1, "nothing moved")
	assert_eq(f.cash(0), 100, "cash untouched")
	assert_healthy(f)


func test_only_receiver_can_respond() -> void:
	var f := _setup()
	_offer(f, 100, [], 0, ["P_D1_3"])
	var h := f.state.state_hash()
	var res := f.cmd(2, ErCommand.RESPOND_TRADE, {"trade_id": f.state.trade["trade_id"], "accept": true})
	assert_rejected(f, res, ErCommand.E_NOT_YOUR_TURN, h)


func test_invalid_offers_rejected_without_mutation() -> void:
	var f := _setup()
	f.give(0, ["P_D3_1", "P_D3_2", "P_D3_3"])
	f.state.level["P_D1_2"] = 0
	var h := f.state.state_hash()
	assert_rejected(f, _offer(f, 0, [], 0, []), ErCommand.E_TRADE_INVALID, h, "empty")
	assert_rejected(f, _offer(f, 0, ["P_D1_1", "P_D1_2", "P_D3_1", "P_D3_2"], 0, []), ErCommand.E_TRADE_INVALID, h, "4 properties")
	assert_rejected(f, _offer(f, 9999, [], 0, []), ErCommand.E_INSUFFICIENT_FUNDS, h, "proposer cash")
	assert_rejected(f, _offer(f, 0, [], 9999, []), ErCommand.E_INSUFFICIENT_FUNDS, h, "receiver cash")
	assert_rejected(f, _offer(f, -5, [], 0, ["P_D1_3"]), ErCommand.E_TRADE_INVALID, h, "negative cash")
	assert_rejected(f, _offer(f, 0, ["P_D1_3"], 0, []), ErCommand.E_NOT_OWNER, h, "giving someone else's property")
	assert_rejected(f, _offer(f, 10, [], 0, ["P_D1_3"], "p0"), ErCommand.E_INVALID_TARGET, h, "self trade")
	assert_rejected(f, _offer(f, 0, ["P_D1_1", "P_D1_1"], 0, []), ErCommand.E_TRADE_INVALID, h, "duplicate id")


func test_developed_property_cannot_be_traded() -> void:
	var f := _setup()
	f.give(0, f.district("D3"), 1)
	var h := f.state.state_hash()
	assert_rejected(f, _offer(f, 0, ["P_D3_1"], 100, []), ErCommand.E_TRADE_INVALID, h)


func test_cannot_trade_with_bankrupt_player() -> void:
	var f := _setup()
	f.state.player(2)["bankrupt"] = true
	var h := f.state.state_hash()
	assert_rejected(f, _offer(f, 10, [], 0, [], "p2"), ErCommand.E_INVALID_TARGET, h)


func test_trade_uses_the_strategic_action() -> void:
	var f := _setup()
	f.state.strategy_used = true
	var h := f.state.state_hash()
	assert_rejected(f, _offer(f, 10, [], 0, ["P_D1_3"]), ErCommand.E_ACTION_USED, h)
