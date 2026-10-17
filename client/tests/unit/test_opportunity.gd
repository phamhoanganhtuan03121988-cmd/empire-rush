## Opportunity tiles (G4): seeded entry, two disclosed deterministic options.
extends TestCase


func test_opportunity_offers_two_options() -> void:
	var f := ErFixture.make()
	f.land(0, 3)
	assert_eq(f.state.phase, GameState.AWAIT_CHOICE, "choice")
	assert_eq(f.state.choice["source"], "opportunity", "source")
	assert_eq(f.state.choice["options"].size(), 2, "two options")


func test_same_seed_same_entry() -> void:
	var a := ErFixture.make(2, 5)
	var b := ErFixture.make(2, 5)
	a.land(0, 3)
	b.land(0, 3)
	assert_eq(a.state.choice["ref_id"], b.state.choice["ref_id"], "entry")


func test_all_entries_reachable() -> void:
	var seen := {}
	for s in range(1, 60):
		var f := ErFixture.make(2, s)
		f.land(0, 3)
		seen[f.state.choice["ref_id"]] = true
	assert_eq(seen.size(), 4, "all 4 entries drawn across seeds")


func test_option_outcome_is_fixed() -> void:
	var f := ErFixture.make()
	f.land(0, 3)
	f.state.choice["ref_id"] = "POPUP_MARKET"
	f.state.choice["options"] = f.config().opportunity_entries()[0]["options"].duplicate(true)
	f.cmd(0, ErCommand.CHOOSE_OPTION, {"choice_id": f.state.choice["choice_id"], "option_id": "STOCK_UP"})
	assert_eq(f.cash(0), 1460, "paid 40")
	f.to_strategy(0)
	f.cmd(0, ErCommand.END_TURN)
	f.to_strategy(1)
	f.cmd(1, ErCommand.END_TURN)
	assert_eq(f.cash(0), 1580, "120 always paid (100% chance)")


func test_timeout_takes_default() -> void:
	var f := ErFixture.make()
	f.land(0, 3)
	var def: Dictionary = f.state.choice["options"][f.state.choice["default_option"]]
	f.expire()
	assert_eq(def["cost"], 0, "default is free")
	assert_ne(f.state.phase, GameState.AWAIT_CHOICE, "resolved")
	assert_healthy(f)


func test_unknown_option_rejected() -> void:
	var f := ErFixture.make()
	f.land(0, 3)
	var h := f.state.state_hash()
	var res := f.cmd(0, ErCommand.CHOOSE_OPTION, {"choice_id": f.state.choice["choice_id"], "option_id": "NOPE"})
	assert_rejected(f, res, ErCommand.E_INVALID_TARGET, h)
