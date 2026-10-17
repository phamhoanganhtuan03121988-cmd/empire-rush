## Special tile wealth tax (G3): min(200, floor(10% x net worth)).
extends TestCase


func test_tax_is_ten_percent_of_net_worth() -> void:
	var f := ErFixture.make()
	f.land(0, 24)
	assert_eq(f.cash(0), 1350, "10% of 1500")


func test_tax_counts_property_liquidation_value() -> void:
	var f := ErFixture.make()
	f.set_cash(0, 1000)
	f.give(0, ["P_D7_1"])  # liquidation 130
	assert_eq(f.engine.wealth_tax(0), 113, "floor(1130 * 10%)")


func test_tax_is_capped() -> void:
	var f := ErFixture.make()
	f.set_cash(0, 5000)
	f.land(0, 24)
	assert_eq(f.cash(0), 4800, "capped at 200")


func test_zero_wealth_zero_tax() -> void:
	var f := ErFixture.make()
	f.set_cash(0, 0)
	f.land(0, 24)
	assert_eq(f.state.phase, GameState.STRATEGY, "nothing to pay")
	assert_eq(f.cash(0), 0, "still zero")


func test_tax_never_causes_bankruptcy() -> void:
	var f := ErFixture.make()
	f.set_cash(0, 5)
	f.give(0, ["P_D7_1"])  # net worth 135 -> tax 13
	f.land(0, 24)
	assert_eq(f.state.phase, GameState.RESCUE, "cash 5 < 13")
	f.expire()
	assert_false(f.state.player(0)["bankrupt"], "liquidation always covers a 10% tax")
	assert_eq(f.cash(0), 5 + 130 - 13, "paid after forced liquidation")
	assert_healthy(f)
