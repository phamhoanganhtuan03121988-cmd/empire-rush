## Rent, district completion and level multipliers (GDD §5; G6).
## Tier 1 base rent is 8 RC; tier 2 (tourist district D2) is 11 RC.
extends TestCase


func _rent_paid(f: ErFixture, owner_seat: int, payer: int, index: int) -> int:
	var before := f.cash(payer)
	f.land(payer, index)
	assert_eq(f.cash(owner_seat) - 1500, before - f.cash(payer), "owner receives exactly what payer pays")
	return before - f.cash(payer)


func test_base_rent_incomplete_district() -> void:
	var f := ErFixture.make()
	f.give(1, ["P_D1_1"])
	assert_eq(_rent_paid(f, 1, 0, 1), 8, "level 0, incomplete")
	assert_healthy(f)


func test_complete_district_doubles_level0() -> void:
	var f := ErFixture.make()
	f.give(1, f.district("D1"))
	assert_eq(_rent_paid(f, 1, 0, 1), 16, "level 0, complete = 2x")


func test_levels_use_their_own_row_without_stacking() -> void:
	var expected := {1: 48, 2: 144, 3: 360}  # 8 x 6, x18, x45 (never x2 on top)
	for lv in expected:
		var f := ErFixture.make()
		f.give(1, f.district("D1"), lv)
		assert_eq(_rent_paid(f, 1, 0, 1), expected[lv], "level %d" % lv)


func test_rent_events_are_emitted() -> void:
	var f := ErFixture.make()
	f.give(1, ["P_D1_1"])
	var ev := f.land(0, 1)
	assert_true(f.types(ev).has("RentCharged"), "RentCharged")
	assert_true(f.types(ev).has("CashChanged"), "CashChanged")


func test_tourism_boom_adds_50_percent() -> void:
	var f := ErFixture.make()
	f.give(1, ["P_D2_1"])
	f.engine._apply_effects(0, f.config().cards["TOURISM_BOOM"]["effects"], "test")
	f.engine._commit()
	assert_eq(_rent_paid(f, 1, 0, 5), 16, "11 * 150% floored")


func test_owner_modifiers_add_not_multiply() -> void:
	var f := ErFixture.make()
	f.give(1, ["P_D2_1"])
	f.engine._apply_effects(0, f.config().cards["TOURISM_BOOM"]["effects"], "test")
	f.engine._apply_effects(1, f.config().cards["BLACKOUT"]["effects"], "test")
	f.engine._commit()
	assert_eq(_rent_paid(f, 1, 0, 5), 11, "+50% and -50% cancel")


func test_rent_discount_is_single_use() -> void:
	var f := ErFixture.make()
	f.give(1, ["P_D1_1", "P_D1_2"])
	f.engine._apply_effects(0, [{"type": "rent_discount_next", "pct": 50, "duration_rounds": 2}], "test")
	f.engine._commit()
	assert_eq(_rent_paid(f, 1, 0, 1), 4, "first rent halved")
	var before := f.cash(0)
	f.land(0, 2)
	assert_eq(before - f.cash(0), 8, "second rent full")
	assert_eq(f.state.modifiers.size(), 0, "discount consumed")


func test_rent_cap() -> void:
	var f := ErFixture.make()
	f.give(1, f.district("D1"), 3)
	f.engine._apply_effects(0, [{"type": "rent_cap", "cap": 100, "duration_rounds": 2}], "test")
	f.engine._commit()
	assert_eq(_rent_paid(f, 1, 0, 1), 100, "capped from 360")


func test_rent_never_negative() -> void:
	var f := ErFixture.make()
	f.give(1, ["P_D1_1"])
	f.engine._apply_effects(1, [{"type": "rent_modifier", "target": "owner_self", "pct": -200, "duration_rounds": 1}], "test")
	f.engine._commit()
	assert_eq(_rent_paid(f, 1, 0, 1), 0, "clamped to 0")
