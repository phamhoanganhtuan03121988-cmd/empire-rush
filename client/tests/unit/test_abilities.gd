## Character abilities (GDD §8; G10): bounded, data-driven, never touch dice.
extends TestCase


func test_investor_dividend() -> void:
	var f := ErFixture.make(2, 1, ["INVESTOR", "TYCOON"])
	f.give(0, ["P_D1_1", "P_D2_1", "P_D3_1", "P_D4_1"])
	f.to_strategy(0)
	assert_true(f.cmd(0, ErCommand.USE_ABILITY, {"ability_id": "DIVIDEND_CALL"})["ok"], "use")
	assert_eq(f.cash(0), 1560, "4 x 15")
	assert_eq(f.state.current_seat, 1, "ability is the strategic action")


func test_investor_dividend_capped() -> void:
	var f := ErFixture.make(2, 1, ["INVESTOR", "TYCOON"])
	f.give(0, f.config().property_ids.slice(0, 12))
	f.to_strategy(0)
	f.cmd(0, ErCommand.USE_ABILITY, {"ability_id": "DIVIDEND_CALL"})
	assert_eq(f.cash(0), 1620, "max 120")


func test_cooldown_and_use_limit() -> void:
	var f := ErFixture.make(2, 1, ["INVESTOR", "TYCOON"])
	f.to_strategy(0)
	f.cmd(0, ErCommand.USE_ABILITY, {"ability_id": "DIVIDEND_CALL"})
	f.state.round = 3
	f.to_strategy(0)
	var h := f.state.state_hash()
	assert_rejected(f, f.cmd(0, ErCommand.USE_ABILITY, {"ability_id": "DIVIDEND_CALL"}), ErCommand.E_ABILITY_UNAVAILABLE, h, "cooldown")
	f.state.round = 4
	assert_true(f.cmd(0, ErCommand.USE_ABILITY, {"ability_id": "DIVIDEND_CALL"})["ok"], "ready after 3 rounds")
	f.state.round = 10
	f.to_strategy(0)
	h = f.state.state_hash()
	assert_rejected(f, f.cmd(0, ErCommand.USE_ABILITY, {"ability_id": "DIVIDEND_CALL"}), ErCommand.E_ABILITY_UNAVAILABLE, h, "2 uses max")


func test_negotiator_halves_next_rent() -> void:
	var f := ErFixture.make(2, 1, ["NEGOTIATOR", "TYCOON"])
	f.to_strategy(0)
	f.cmd(0, ErCommand.USE_ABILITY, {"ability_id": "CONTRACT_CLAUSE"})
	f.give(1, f.district("D1"), 1)
	f.land(0, 1)
	assert_eq(f.cash(0), 1500 - 24, "48 halved")


func test_passive_ability_cannot_be_used() -> void:
	var f := ErFixture.make(2, 1, ["TYCOON", "INVESTOR"])
	f.to_strategy(0)
	var h := f.state.state_hash()
	assert_rejected(f, f.cmd(0, ErCommand.USE_ABILITY, {"ability_id": "BUILDER_DISCOUNT"}), ErCommand.E_ABILITY_UNAVAILABLE, h)


func test_wrong_ability_id_rejected() -> void:
	var f := ErFixture.make(2, 1, ["INVESTOR", "TYCOON"])
	f.to_strategy(0)
	var h := f.state.state_hash()
	assert_rejected(f, f.cmd(0, ErCommand.USE_ABILITY, {"ability_id": "CONTRACT_CLAUSE"}), ErCommand.E_ABILITY_UNAVAILABLE, h)


func test_ability_data_never_references_dice() -> void:
	for ch in ErFixture.config().character_by_id.values():
		var text := JSON.stringify(ch["ability"]).to_lower()
		assert_false(text.contains("dice") or text.contains("roll"), ch["character_id"] + " must not affect dice")
