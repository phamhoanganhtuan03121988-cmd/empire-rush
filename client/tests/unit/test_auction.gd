## Ascending auction, 12 s, anti-snipe +3 s max 2 (GDD §6).
## P_D1_1 price 60 => min bid max(10, 6) = 10, increment 10.
extends TestCase


func _open(n: int = 3) -> ErFixture:
	var f := ErFixture.make(n)
	f.land(0, 1)
	f.cmd(0, ErCommand.PASS_PROPERTY, {"property_id": "P_D1_1"})
	return f


func _bid(f: ErFixture, seat: int, amount: int, id: String = "") -> Dictionary:
	return f.cmd(seat, ErCommand.PLACE_BID, {"auction_id": f.state.auction["auction_id"], "amount": amount}, id)


func test_min_bid_and_increment() -> void:
	var f := _open()
	var h := f.state.state_hash()
	assert_rejected(f, _bid(f, 1, 9), ErCommand.E_BID_TOO_LOW, h, "below min")
	assert_true(_bid(f, 1, 10)["ok"], "min bid")
	h = f.state.state_hash()
	assert_rejected(f, _bid(f, 2, 15), ErCommand.E_BID_TOO_LOW, h, "below increment")
	assert_true(_bid(f, 2, 20)["ok"], "raise")


func test_bid_cannot_exceed_cash() -> void:
	var f := _open()
	f.set_cash(1, 30)
	var h := f.state.state_hash()
	assert_rejected(f, _bid(f, 1, 40), ErCommand.E_INSUFFICIENT_FUNDS, h)


func test_high_bidder_cannot_raise_self() -> void:
	var f := _open()
	_bid(f, 1, 10)
	var h := f.state.state_hash()
	assert_rejected(f, _bid(f, 1, 50), ErCommand.E_INVALID_TARGET, h)


func test_winner_pays_at_deadline() -> void:
	var f := _open()
	_bid(f, 1, 10)
	_bid(f, 2, 30)
	f.expire()
	assert_eq(f.state.owner["P_D1_1"], 2, "highest bidder owns")
	assert_eq(f.cash(2), 1470, "paid 30")
	assert_eq(f.cash(1), 1500, "loser pays nothing")
	assert_eq(f.state.phase, GameState.STRATEGY, "back to the current player's strategy action")
	assert_healthy(f)


func test_no_bids_property_stays_unowned() -> void:
	var f := _open()
	f.expire()
	assert_eq(f.state.owner["P_D1_1"], GameState.BANK, "unowned")
	assert_healthy(f)


func test_bid_after_deadline_rejected() -> void:
	var f := _open()
	f.clock.set_now(f.state.auction["deadline_ms"])
	var h := f.state.state_hash()
	assert_rejected(f, _bid(f, 1, 10), ErCommand.E_DEADLINE_PASSED, h)


func test_anti_snipe_extends_at_most_twice() -> void:
	var f := _open()
	var d0: int = f.state.auction["deadline_ms"]
	f.clock.set_now(d0 - 1000)
	_bid(f, 1, 10)
	assert_eq(f.state.auction["deadline_ms"], d0 + 3000, "first extension")
	f.clock.set_now(d0 + 2500)
	_bid(f, 2, 20)
	assert_eq(f.state.auction["deadline_ms"], d0 + 6000, "second extension")
	f.clock.set_now(d0 + 5500)
	_bid(f, 1, 30)
	assert_eq(f.state.auction["deadline_ms"], d0 + 6000, "no third extension")
	assert_eq(f.state.auction["extensions"], 2, "extensions counted")


func test_early_bid_does_not_extend() -> void:
	var f := _open()
	var d0: int = f.state.auction["deadline_ms"]
	_bid(f, 1, 10)
	assert_eq(f.state.auction["deadline_ms"], d0, "no extension outside window")


func test_duplicate_bid_command_is_idempotent() -> void:
	var f := _open()
	var first := _bid(f, 1, 10, "dup-1")
	assert_true(first["ok"], "first")
	var v := f.state.state_version
	var again := f.engine.submit(ErCommand.make("test", "p1", "dup-1", f.state.state_version, ErCommand.PLACE_BID,
		{"auction_id": f.state.auction["auction_id"], "amount": 10}))
	assert_true(again.get("duplicate", false), "flagged duplicate")
	assert_eq(f.state.state_version, v, "no new version")


func test_turn_timer_paused_during_auction() -> void:
	var f := ErFixture.make(3)
	f.land(0, 1)
	var remaining: int = f.state.turn_deadline_ms - f.clock.now_ms()
	f.cmd(0, ErCommand.PASS_PROPERTY, {"property_id": "P_D1_1"})
	f.expire()
	assert_eq(f.state.turn_deadline_ms - f.clock.now_ms(), remaining, "turn time preserved across the auction")
