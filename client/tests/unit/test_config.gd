## Board / data validation (GDD §2, §4; G1, G4, G10).
extends TestCase


func _raw() -> Dictionary:
	var out := {}
	for name in ["board", "balance", "events", "characters", "opportunities"]:
		out[name] = JSON.parse_string(FileAccess.get_file_as_string("res://data/rules/%s.json" % name))
	return out


func _build(raw: Dictionary) -> GameConfig:
	return GameConfig.from_dicts(raw["board"], raw["balance"], raw["events"], raw["characters"], raw["opportunities"])


func test_shipped_config_is_valid() -> void:
	var cfg := ErFixture.config()
	assert_true(cfg.is_valid(), "config errors: %s" % str(cfg.errors))


func test_board_composition() -> void:
	var cfg := ErFixture.config()
	assert_eq(cfg.board_size(), 28, "spaces")
	assert_eq(cfg.property_ids.size(), 21, "properties")
	assert_eq(cfg.district_props.size(), 7, "districts")
	for did in cfg.district_props:
		assert_eq(cfg.district_props[did].size(), 3, "props in " + did)
	assert_eq(cfg.space_type(0), "START", "space 0")
	assert_eq(cfg.cards.size(), 12, "event cards")
	assert_eq(cfg.character_by_id.size(), 3, "characters")
	assert_eq(cfg.opportunity_entries().size(), 4, "opportunity entries")


func test_json_numbers_become_ints() -> void:
	var cfg := ErFixture.config()
	assert_eq(typeof(cfg.balance["starting_cash"]), TYPE_INT, "starting cash type")
	assert_eq(cfg.balance["starting_cash"], 1500, "starting cash")
	assert_eq(cfg.balance["start_reward"], 200, "start reward")
	assert_eq(typeof(cfg.tiers[1]["price"]), TYPE_INT, "price type")


func test_rejects_wrong_space_count() -> void:
	var raw := _raw()
	raw["board"]["spaces"].pop_back()
	assert_false(_build(raw).is_valid(), "27-space board must be invalid")


func test_rejects_fractional_money() -> void:
	var raw := _raw()
	raw["balance"]["tiers"][0]["price"] = 60.5
	assert_false(_build(raw).is_valid(), "fractional price must be invalid")


func test_rejects_payment_effect_not_last() -> void:
	var raw := _raw()
	for c in raw["events"]["cards"]:
		if c["card_id"] == "TRAFFIC_FINE":
			c["effects"].append({"type": "cash", "amount": 10})
	assert_false(_build(raw).is_valid(), "payment followed by another effect must be invalid")


func test_rejects_default_option_with_cost() -> void:
	var raw := _raw()
	raw["opportunities"]["entries"][0]["default_option"] = 1  # STOCK_UP costs 40
	assert_false(_build(raw).is_valid(), "costly default option must be invalid")


func test_rejects_wrong_card_mix() -> void:
	var raw := _raw()
	raw["events"]["cards"][0]["category"] = "negative"
	assert_false(_build(raw).is_valid(), "5 negative cards must be invalid")
