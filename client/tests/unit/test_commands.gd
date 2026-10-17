## Command envelope, idempotency, stale versions, invalid commands (GDD §10).
extends TestCase


func test_stale_state_version_rejected() -> void:
	var f := ErFixture.make()
	var h := f.state.state_hash()
	var res := f.engine.submit(ErCommand.make("test", "p0", "x1", f.state.state_version - 1, ErCommand.ROLL_DICE))
	assert_rejected(f, res, ErCommand.E_STALE_STATE, h)
	assert_eq(res["current_state_version"], f.state.state_version, "server tells current version")


func test_duplicate_command_has_no_second_effect() -> void:
	var f := ErFixture.make()
	f.land(0, 1)
	var first := f.cmd(0, ErCommand.BUY_PROPERTY, {"property_id": "P_D1_1"}, "buy-1")
	assert_true(first["ok"], "first")
	var cash_after := f.cash(0)
	var h := f.state.state_hash()
	var dup := f.engine.submit(ErCommand.make("test", "p0", "buy-1", f.state.state_version, ErCommand.BUY_PROPERTY, {"property_id": "P_D1_1"}))
	assert_true(dup["ok"] and dup["duplicate"], "original result returned")
	assert_eq(dup["events"].size(), 0, "no events replayed")
	assert_eq(f.cash(0), cash_after, "charged once")
	assert_eq(f.state.state_hash(), h, "state unchanged")


func test_same_command_id_from_different_players_is_independent() -> void:
	var f := ErFixture.make()
	f.cmd(0, ErCommand.ROLL_DICE, {}, "same")
	f.to_strategy(1)
	var res := f.cmd(1, ErCommand.END_TURN, {}, "same")
	assert_true(res["ok"] and not res.get("duplicate", false), "ids are scoped per player")


func test_envelope_validation() -> void:
	var f := ErFixture.make()
	var h := f.state.state_hash()
	var base := ErCommand.make("test", "p0", "e1", f.state.state_version, ErCommand.ROLL_DICE)
	var bad_proto := base.duplicate(); bad_proto["protocol_version"] = 2
	assert_rejected(f, f.engine.submit(bad_proto), ErCommand.E_PROTOCOL_UNSUPPORTED, h, "protocol")
	var bad_match := base.duplicate(); bad_match["match_id"] = "other"
	assert_rejected(f, f.engine.submit(bad_match), ErCommand.E_BAD_REQUEST, h, "match id")
	var no_id := base.duplicate(); no_id["command_id"] = ""
	assert_rejected(f, f.engine.submit(no_id), ErCommand.E_BAD_REQUEST, h, "empty id")
	var bad_payload := base.duplicate(); bad_payload["payload"] = "x"
	assert_rejected(f, f.engine.submit(bad_payload), ErCommand.E_BAD_REQUEST, h, "payload type")
	var float_version := base.duplicate(); float_version["expected_state_version"] = 1.0
	assert_rejected(f, f.engine.submit(float_version), ErCommand.E_BAD_REQUEST, h, "version type")
	var stranger := base.duplicate(); stranger["player_id"] = "intruder"
	assert_rejected(f, f.engine.submit(stranger), ErCommand.E_NOT_SEATED, h, "not seated")
	var unknown := base.duplicate(); unknown["type"] = "WinGame"
	assert_rejected(f, f.engine.submit(unknown), ErCommand.E_BAD_REQUEST, h, "unknown type")


func test_not_your_turn() -> void:
	var f := ErFixture.make()
	var h := f.state.state_hash()
	assert_rejected(f, f.cmd(1, ErCommand.ROLL_DICE), ErCommand.E_NOT_YOUR_TURN, h)


func test_commands_after_match_end_rejected() -> void:
	var f := ErFixture.make()
	f.engine._end_match("test")
	f.engine._commit()
	var h := f.state.state_hash()
	assert_rejected(f, f.cmd(0, ErCommand.ROLL_DICE), ErCommand.E_MATCH_ENDED, h)


func test_command_at_deadline_rejected() -> void:
	var f := ErFixture.make()
	f.clock.set_now(f.state.turn_deadline_ms)
	var h := f.state.state_hash()
	assert_rejected(f, f.cmd(0, ErCommand.ROLL_DICE), ErCommand.E_DEADLINE_PASSED, h)


## Random garbage from every seat in every phase: anything rejected must leave
## the state untouched, and invariants must always hold.
func test_fuzz_invalid_commands_never_mutate() -> void:
	var types := [ErCommand.ROLL_DICE, ErCommand.BUY_PROPERTY, ErCommand.PASS_PROPERTY, ErCommand.PLACE_BID,
		ErCommand.CHOOSE_OPTION, ErCommand.UPGRADE, ErCommand.PROPOSE_TRADE, ErCommand.RESPOND_TRADE,
		ErCommand.USE_ABILITY, ErCommand.LIQUIDATE, ErCommand.DECLARE_BANKRUPTCY, ErCommand.END_TURN, "Bogus"]
	var payloads := [{}, {"property_id": "P_D1_1"}, {"property_id": 5}, {"amount": -10, "auction_id": "A1"},
		{"amount": 99999, "auction_id": "A1"}, {"option_id": "X", "choice_id": "C1"}, {"property_ids": "nope"},
		{"property_ids": ["P_D7_3", "P_D7_3"]}, {"to_player_id": "p1", "give": {"cash": 1.5}, "take": {}},
		{"trade_id": "T1", "accept": "yes"}, {"ability_id": 1}]
	var rng := ErRng.new(2024)
	var rejected := 0
	for s in 5:
		var f := ErFixture.make(3, 100 + s)
		for i in 300:
			var h := f.state.state_hash()
			var res := f.cmd(rng.range_int(4), types[rng.range_int(types.size())], payloads[rng.range_int(payloads.size())])
			if not res["ok"]:
				rejected += 1
				if f.state.state_hash() != h:
					errors.append("rejected %s changed state" % str(res))
					return
			var errs := f.invariants()
			if not errs.is_empty():
				errors.append("invariant broken: %s" % str(errs))
				return
			if i % 7 == 0:
				f.expire()
			if f.engine.is_ended():
				break
	assert_true(rejected > 1000, "fuzz exercised the reject paths (%d)" % rejected)
