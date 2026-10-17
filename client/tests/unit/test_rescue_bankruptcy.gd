## Rescue, liquidation and bankruptcy (GDD §5; G7).
## D1 at level 3 => rent 360. Liquidation: P_D7_1 130, P_D6_1 110.
extends TestCase


func _debt(cash: int, own: Array, n: int = 2) -> ErFixture:
	var f := ErFixture.make(n)
	f.give(1, f.district("D1"), 3)
	f.give(0, own)
	f.set_cash(0, cash)
	f.land(0, 1)
	return f


func test_unaffordable_rent_opens_rescue() -> void:
	var f := _debt(100, ["P_D7_1"])
	assert_eq(f.state.phase, GameState.RESCUE, "rescue")
	assert_eq(f.state.rescue["amount"], 360, "amount")
	assert_eq(f.state.rescue["creditor"], 1, "creditor")
	assert_eq(f.cash(0), 100, "nothing taken yet")
	assert_eq(f.state.rescue["deadline_ms"] - f.clock.now_ms(), 30000, "30 s rescue window")
	assert_healthy(f)


func test_liquidation_pays_debt() -> void:
	var f := _debt(300, ["P_D7_1"])
	var res := f.cmd(0, ErCommand.LIQUIDATE, {"property_ids": ["P_D7_1"]})
	assert_true(res["ok"], "liquidate")
	assert_eq(f.state.owner["P_D7_1"], GameState.BANK, "back to bank")
	assert_eq(f.cash(0), 300 + 130 - 360, "cash after paying")
	assert_eq(f.cash(1), 1500 + 360, "creditor paid in full")
	assert_eq(f.state.phase, GameState.STRATEGY, "turn continues")
	assert_healthy(f)


func test_partial_liquidation_keeps_rescue_open() -> void:
	var f := _debt(100, ["P_D6_1", "P_D7_1"])
	f.cmd(0, ErCommand.LIQUIDATE, {"property_ids": ["P_D6_1"]})
	assert_eq(f.state.phase, GameState.RESCUE, "still short (210 < 360)")
	assert_eq(f.cash(0), 210, "proceeds credited")
	assert_healthy(f)


func test_timeout_force_liquidates_cheapest_first_when_solvent() -> void:
	var f := _debt(300, ["P_D6_1", "P_D7_1"])
	f.expire()
	assert_eq(f.state.owner["P_D6_1"], GameState.BANK, "cheapest liquidated")
	assert_eq(f.state.owner["P_D7_1"], 0, "kept: debt already covered")
	assert_false(f.state.player(0)["bankrupt"], "survives")
	assert_eq(f.cash(0), 300 + 110 - 360, "paid")
	assert_healthy(f)


func test_bankruptcy_pays_cash_to_player_creditor_and_returns_properties() -> void:
	var f := _debt(100, ["P_D7_1"], 3)
	var issued_before := f.state.bank_net_issued
	f.expire()
	assert_true(f.state.player(0)["bankrupt"], "bankrupt")
	assert_eq(f.state.owner["P_D7_1"], GameState.BANK, "property returned unowned")
	assert_eq(f.state.level["P_D7_1"], 0, "no buildings")
	assert_eq(f.cash(0), 0, "no cash left")
	assert_eq(f.cash(1), 1600, "creditor receives remaining 100 only (G7)")
	assert_eq(f.state.bank_net_issued, issued_before, "no money created or destroyed")
	assert_eq(f.state.current_seat, 1, "next player")
	assert_healthy(f)


func test_bankruptcy_to_bank_for_card_payment() -> void:
	var f := ErFixture.make(3)
	f.set_cash(0, 20)
	f.state.event_deck = ["TRAFFIC_FINE"]
	f.land(0, 8)
	assert_eq(f.state.phase, GameState.RESCUE, "cannot pay fine")
	assert_eq(f.state.rescue["creditor"], GameState.BANK, "bank is creditor")
	var issued := f.state.bank_net_issued
	f.cmd(0, ErCommand.DECLARE_BANKRUPTCY)
	assert_true(f.state.player(0)["bankrupt"], "bankrupt")
	assert_eq(f.state.bank_net_issued, issued - 20, "remaining 20 returned to the bank")
	assert_eq(f.cash(1) + f.cash(2), 3000, "other players unaffected")
	assert_healthy(f)


func test_declare_bankruptcy_cannot_dodge_payable_debt() -> void:
	var f := _debt(300, ["P_D7_1"])
	f.cmd(0, ErCommand.DECLARE_BANKRUPTCY)
	assert_false(f.state.player(0)["bankrupt"], "liquidation covers debt => not bankrupt")
	assert_eq(f.cash(1), 1860, "creditor paid in full")


func test_last_solvent_player_wins() -> void:
	var f := _debt(100, [])
	f.expire()
	assert_eq(f.state.phase, GameState.ENDED, "ended")
	assert_eq(f.state.end_reason, "last_solvent", "reason")
	assert_eq(f.state.results[0]["seat"], 1, "winner")
	assert_healthy(f)


func test_bankrupt_player_is_skipped_and_loses_modifiers() -> void:
	var f := _debt(100, [], 3)
	f.engine._apply_effects(0, [{"type": "delayed_payout", "reward": 50, "chance_pct": 100},
		{"type": "rent_cap", "cap": 10, "duration_rounds": 5}], "t")
	f.engine._commit()
	f.expire()
	assert_eq(f.state.modifiers.filter(func(m): return m["seat"] == 0).size(), 0, "modifiers removed")
	assert_eq(f.state.pending_payouts.size(), 0, "payouts removed")
	f.to_strategy(1)
	f.cmd(1, ErCommand.END_TURN)
	f.to_strategy(2)
	f.cmd(2, ErCommand.END_TURN)
	assert_eq(f.state.current_seat, 1, "seat 0 skipped")


func test_rescue_trade_can_raise_cash() -> void:
	var f := _debt(300, [], 3)
	f.give(2, ["P_D5_1"])
	var res := f.cmd(0, ErCommand.PROPOSE_TRADE, {"to_player_id": "p2",
		"give": {"cash": 0, "property_ids": []}, "take": {"cash": 60, "property_ids": []}})
	assert_true(res["ok"], "propose in rescue")
	assert_true(f.state.trade["deadline_ms"] <= f.state.rescue["deadline_ms"], "trade cannot outlive rescue")
	f.cmd(2, ErCommand.RESPOND_TRADE, {"trade_id": f.state.trade["trade_id"], "accept": true})
	assert_eq(f.state.phase, GameState.STRATEGY, "debt paid after the trade")
	assert_eq(f.cash(1), 1860, "creditor paid")
	var again := f.cmd(0, ErCommand.PROPOSE_TRADE, {"to_player_id": "p2",
		"give": {"cash": 0, "property_ids": []}, "take": {"cash": 1, "property_ids": []}})
	assert_true(again["ok"], "rescue trade does not consume the normal strategic action")
	assert_healthy(f)


func test_only_debtor_can_liquidate() -> void:
	var f := _debt(100, ["P_D7_1"], 3)
	f.give(2, ["P_D5_1"])
	var h := f.state.state_hash()
	assert_rejected(f, f.cmd(2, ErCommand.LIQUIDATE, {"property_ids": ["P_D5_1"]}), ErCommand.E_NOT_YOUR_TURN, h)
	assert_rejected(f, f.cmd(0, ErCommand.LIQUIDATE, {"property_ids": ["P_D5_1"]}), ErCommand.E_NOT_OWNER, h, "not owner")
