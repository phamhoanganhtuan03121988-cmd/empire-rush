## Buy / pass (GDD §3.5).
extends TestCase


func test_buy_deducts_price_and_sets_owner() -> void:
	var f := ErFixture.make()
	f.land(0, 1)
	assert_eq(f.state.phase, GameState.AWAIT_BUY, "buy prompt")
	var res := f.cmd(0, ErCommand.BUY_PROPERTY, {"property_id": "P_D1_1"})
	assert_true(res["ok"], "buy ok")
	assert_eq(f.cash(0), 1440, "paid 60")
	assert_eq(f.state.owner["P_D1_1"], 0, "owner")
	assert_eq(f.state.phase, GameState.STRATEGY, "then strategy")
	assert_healthy(f)


func test_buy_with_exact_cash_reaches_zero() -> void:
	var f := ErFixture.make()
	f.set_cash(0, 60)
	f.land(0, 1)
	assert_true(f.cmd(0, ErCommand.BUY_PROPERTY, {"property_id": "P_D1_1"})["ok"], "exact cash buy")
	assert_eq(f.cash(0), 0, "zero cash")
	assert_healthy(f)


func test_buy_without_funds_is_rejected() -> void:
	var f := ErFixture.make()
	f.set_cash(0, 59)
	f.land(0, 1)
	var h := f.state.state_hash()
	assert_rejected(f, f.cmd(0, ErCommand.BUY_PROPERTY, {"property_id": "P_D1_1"}), ErCommand.E_INSUFFICIENT_FUNDS, h)


func test_buy_wrong_property_is_rejected() -> void:
	var f := ErFixture.make()
	f.land(0, 1)
	var h := f.state.state_hash()
	assert_rejected(f, f.cmd(0, ErCommand.BUY_PROPERTY, {"property_id": "P_D7_3"}), ErCommand.E_INVALID_TARGET, h)


func test_other_player_cannot_buy() -> void:
	var f := ErFixture.make()
	f.land(0, 1)
	var h := f.state.state_hash()
	assert_rejected(f, f.cmd(1, ErCommand.BUY_PROPERTY, {"property_id": "P_D1_1"}), ErCommand.E_NOT_YOUR_TURN, h)


func test_pass_opens_auction() -> void:
	var f := ErFixture.make()
	f.land(0, 1)
	var res := f.cmd(0, ErCommand.PASS_PROPERTY, {"property_id": "P_D1_1"})
	assert_true(res["ok"], "pass ok")
	assert_eq(f.state.phase, GameState.AUCTION, "auction")
	assert_eq(f.state.auction["property_id"], "P_D1_1", "auctioned property")
	assert_eq(f.state.owner["P_D1_1"], GameState.BANK, "still unowned")


func test_landing_on_own_property_is_free() -> void:
	var f := ErFixture.make()
	f.give(0, ["P_D1_1"])
	f.land(0, 1)
	assert_eq(f.cash(0), 1500, "no charge")
	assert_eq(f.state.phase, GameState.STRATEGY, "strategy")
