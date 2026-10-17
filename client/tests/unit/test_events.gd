## City Event cards (GDD §8; G10).
extends TestCase


func _draw(f: ErFixture, card_id: String, seat: int = 0) -> Array:
	f.state.event_deck = [card_id]
	return f.land(seat, 8)


func test_city_grant() -> void:
	var f := ErFixture.make()
	_draw(f, "CITY_GRANT")
	assert_eq(f.cash(0), 1600, "+100")
	assert_eq(f.state.phase, GameState.STRATEGY, "then strategy")


func test_traffic_fine() -> void:
	var f := ErFixture.make()
	_draw(f, "TRAFFIC_FINE")
	assert_eq(f.cash(0), 1450, "-50")


func test_express_train_goes_to_start_with_reward() -> void:
	var f := ErFixture.make()
	_draw(f, "EXPRESS_TRAIN")
	assert_eq(f.state.player(0)["position"], 0, "on Start")
	assert_eq(f.cash(0), 1700, "+200 reward")


func test_market_downturn_charges_level2_plus() -> void:
	var f := ErFixture.make()
	f.give(0, f.district("D1"), 2)
	f.give(0, ["P_D7_1"], 0)
	_draw(f, "MARKET_DOWNTURN")
	assert_eq(f.cash(0), 1500 - 3 * 40, "3 properties at level 2")


func test_property_repairs_per_level() -> void:
	var f := ErFixture.make()
	f.give(0, f.district("D1"), 2)
	_draw(f, "PROPERTY_REPAIRS")
	assert_eq(f.cash(0), 1500 - 6 * 20, "6 levels")


func test_subsidy_and_blackout_add_modifiers() -> void:
	var f := ErFixture.make()
	_draw(f, "UPGRADE_SUBSIDY")
	assert_eq(f.state.modifiers[0]["kind"], "upgrade_discount", "subsidy")
	f.to_strategy(0)
	_draw(f, "BLACKOUT")
	assert_eq(f.state.modifiers[1]["kind"], "rent_pct", "blackout")
	assert_eq(f.state.modifiers[1]["pct"], -50, "blackout pct")


func test_choice_card_prompts_and_charges_cost() -> void:
	var f := ErFixture.make()
	_draw(f, "SMART_INVESTMENT")
	assert_eq(f.state.phase, GameState.AWAIT_CHOICE, "choice")
	var res := f.cmd(0, ErCommand.CHOOSE_OPTION, {"choice_id": f.state.choice["choice_id"], "option_id": "INVEST"})
	assert_true(res["ok"], "choose")
	assert_eq(f.cash(0), 1400, "paid 100")
	assert_eq(f.state.pending_payouts.size(), 1, "payout scheduled")
	assert_healthy(f)


func test_choice_timeout_uses_free_default() -> void:
	var f := ErFixture.make()
	_draw(f, "RENT_INSURANCE")
	f.expire()
	assert_eq(f.cash(0), 1500, "declined, nothing paid")
	assert_ne(f.state.phase, GameState.AWAIT_CHOICE, "moved on")


func test_unaffordable_option_rejected() -> void:
	var f := ErFixture.make()
	f.set_cash(0, 50)
	_draw(f, "SMART_INVESTMENT")
	var h := f.state.state_hash()
	var res := f.cmd(0, ErCommand.CHOOSE_OPTION, {"choice_id": f.state.choice["choice_id"], "option_id": "INVEST"})
	assert_rejected(f, res, ErCommand.E_INSUFFICIENT_FUNDS, h)


func test_portfolio_bonus_per_property() -> void:
	var f := ErFixture.make()
	f.give(0, ["P_D1_1", "P_D2_1", "P_D3_1", "P_D4_1", "P_D5_1"])
	_draw(f, "PORTFOLIO_BONUS")
	f.cmd(0, ErCommand.CHOOSE_OPTION, {"choice_id": f.state.choice["choice_id"], "option_id": "PER_PROPERTY"})
	assert_eq(f.cash(0), 1600, "5 x 20")


func test_delayed_payout_is_deterministic_per_seed() -> void:
	var outcomes := []
	for run in 2:
		var f := ErFixture.make(2, 99)
		_draw(f, "SMART_INVESTMENT")
		f.cmd(0, ErCommand.CHOOSE_OPTION, {"choice_id": f.state.choice["choice_id"], "option_id": "INVEST"})
		f.to_strategy(0)
		f.cmd(0, ErCommand.END_TURN)
		f.to_strategy(1)
		f.cmd(1, ErCommand.END_TURN)
		assert_eq(f.state.pending_payouts.size(), 0, "resolved at seat 0's next turn")
		outcomes.append(f.cash(0))
	assert_eq(outcomes[0], outcomes[1], "same seed, same payout outcome")
	assert_true(outcomes[0] == 1400 or outcomes[0] == 1650, "either lost or won 250")


func test_modifier_expires_after_one_full_round() -> void:
	var f := ErFixture.make(2)
	_draw(f, "TOURISM_BOOM")
	assert_eq(f.state.modifiers.size(), 1, "active")
	f.to_strategy(0)
	f.cmd(0, ErCommand.END_TURN)
	assert_eq(f.state.modifiers.size(), 1, "still active during the other player's turn")
	f.to_strategy(1)
	f.cmd(1, ErCommand.END_TURN)
	assert_eq(f.state.modifiers.size(), 0, "expired when the drawing player's next turn starts")


func test_deck_reshuffles_after_twelve_cards() -> void:
	var f := ErFixture.make()
	var drawn := {}
	for i in 12:
		var ev := f.land(0, 8)
		for e in ev:
			if e["type"] == "EventCardDrawn":
				drawn[e["data"]["card_id"]] = true
		f.state.choice = {}
		f.state.rescue = {}
		f.set_cash(0, 1500)
	assert_eq(drawn.size(), 12, "every card drawn exactly once per deck")
	var ev13 := f.land(0, 8)
	assert_true(f.types(ev13).has("EventDeckReshuffled"), "reshuffled on 13th draw")
