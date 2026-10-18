## Upgrades levels 0-3 (GDD §5), one strategic action per turn (G8).
extends TestCase


func test_upgrade_requires_complete_district() -> void:
	var f := ErFixture.make()
	f.give(0, ["P_D1_1", "P_D1_2"])
	f.to_strategy(0)
	var h := f.state.state_hash()
	assert_rejected(f, f.cmd(0, ErCommand.UPGRADE, {"property_id": "P_D1_1"}), ErCommand.E_DISTRICT_INCOMPLETE, h)


func test_upgrade_charges_cost_and_ends_turn() -> void:
	var f := ErFixture.make(2, 1, ["INVESTOR", "TYCOON"])
	f.give(0, f.district("D1"))
	f.to_strategy(0)
	var res := f.cmd(0, ErCommand.UPGRADE, {"property_id": "P_D1_1"})
	assert_true(res["ok"], "upgrade ok")
	assert_eq(f.state.level["P_D1_1"], 1, "level 1")
	assert_eq(f.cash(0), 1470, "paid 30 (v3 tier-1 upgrade cost)")
	assert_eq(f.state.current_seat, 1, "turn passed to next player")
	assert_healthy(f)


func test_tycoon_passive_discount() -> void:
	var f := ErFixture.make(2, 1, ["TYCOON", "INVESTOR"])
	f.give(0, f.district("D7"))
	f.to_strategy(0)
	f.cmd(0, ErCommand.UPGRADE, {"property_id": "P_D7_1"})
	assert_eq(f.cash(0), 1433, "75 - 10% = 67 (floored)")


func test_discounts_add_and_are_capped() -> void:
	var f := ErFixture.make(2, 1, ["TYCOON", "INVESTOR"])
	f.give(0, f.district("D7"))
	f.engine._apply_effects(0, [{"type": "upgrade_discount_next", "pct": 50, "duration_rounds": 2}], "t")
	f.to_strategy(0)
	assert_eq(f.engine.upgrade_quote(0, "P_D7_1")["amount"], 30, "10% + 50% = 60% off 75")
	f.engine._apply_effects(0, [{"type": "upgrade_discount_next", "pct": 50, "duration_rounds": 2}], "t")
	assert_eq(f.engine.upgrade_quote(0, "P_D7_1")["amount"], 30, "only one subsidy is used at a time")
	f.cmd(0, ErCommand.UPGRADE, {"property_id": "P_D7_1"})
	assert_eq(f.state.modifiers.filter(func(m): return m["kind"] == "upgrade_discount").size(), 1, "one subsidy consumed")


func test_max_level_three() -> void:
	var f := ErFixture.make()
	f.give(0, f.district("D1"), 3)
	f.to_strategy(0)
	var h := f.state.state_hash()
	assert_rejected(f, f.cmd(0, ErCommand.UPGRADE, {"property_id": "P_D1_1"}), ErCommand.E_MAX_LEVEL, h)


func test_upgrade_insufficient_funds() -> void:
	var f := ErFixture.make(2, 1, ["INVESTOR", "TYCOON"])
	f.give(0, f.district("D1"))
	f.set_cash(0, 29)  # 1 RC short of the v3 tier-1 upgrade cost (30)
	f.to_strategy(0)
	var h := f.state.state_hash()
	assert_rejected(f, f.cmd(0, ErCommand.UPGRADE, {"property_id": "P_D1_1"}), ErCommand.E_INSUFFICIENT_FUNDS, h)


func test_cannot_upgrade_others_property() -> void:
	var f := ErFixture.make()
	f.give(1, f.district("D1"))
	f.to_strategy(0)
	var h := f.state.state_hash()
	assert_rejected(f, f.cmd(0, ErCommand.UPGRADE, {"property_id": "P_D1_1"}), ErCommand.E_NOT_OWNER, h)


func test_only_one_strategic_action() -> void:
	var f := ErFixture.make()
	f.give(0, f.district("D1"))
	f.to_strategy(0)
	f.state.strategy_used = true
	var h := f.state.state_hash()
	assert_rejected(f, f.cmd(0, ErCommand.UPGRADE, {"property_id": "P_D1_1"}), ErCommand.E_ACTION_USED, h)


func test_upgrade_outside_strategy_phase_rejected() -> void:
	var f := ErFixture.make()
	f.give(0, f.district("D1"))
	var h := f.state.state_hash()
	assert_rejected(f, f.cmd(0, ErCommand.UPGRADE, {"property_id": "P_D1_1"}), ErCommand.E_WRONG_PHASE, h)
