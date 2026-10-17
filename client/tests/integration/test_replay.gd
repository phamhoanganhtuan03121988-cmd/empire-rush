## Determinism: same seed => same match; recorded inputs replay exactly.
extends TestCase


func test_same_seed_identical_match() -> void:
	var cfg := ErFixture.config()
	var a := MatchSimulator.run(cfg, 4242, 4, {"keep_event_log": true, "return_engine": true})
	var b := MatchSimulator.run(cfg, 4242, 4, {"keep_event_log": true, "return_engine": true})
	assert_eq(a["state_hash"], b["state_hash"], "final state hash")
	var la: String = JSON.stringify(a["engine"].event_log, "", true)
	var lb: String = JSON.stringify(b["engine"].event_log, "", true)
	assert_eq(la.sha256_text(), lb.sha256_text(), "full event log")
	assert_true(a["engine"].event_log.size() > 100, "log is non-trivial")


func test_different_seed_different_match() -> void:
	var cfg := ErFixture.config()
	var a := MatchSimulator.run(cfg, 1, 3, {})
	var b := MatchSimulator.run(cfg, 2, 3, {})
	assert_ne(a["state_hash"], b["state_hash"], "hash")


func test_input_log_replays_exactly() -> void:
	var cfg := ErFixture.config()
	for seed_value in [7, 8, 9]:
		var r := MatchSimulator.run(cfg, seed_value, 3, {"return_engine": true})
		var original: GameEngine = r["engine"]
		var seats: Array = []
		for p in original.state.players:
			seats.append({"player_id": p["player_id"], "character_id": p["character_id"]})
		var clock := MatchClock.new(0)
		var replay := GameEngine.create(cfg, clock, seats, seed_value, original.state.match_id)
		for entry in original.input_log:
			clock.set_now(entry["at"])
			if entry.has("cmd"):
				var res := replay.submit(entry["cmd"])
				if not res["ok"]:
					errors.append("seed %d: replayed command rejected: %s" % [seed_value, res["error"]])
					return
			else:
				replay.advance()
		assert_eq(replay.state.state_hash(), original.state.state_hash(), "seed %d replay hash" % seed_value)


func test_public_snapshot_hides_rng_and_deck_order() -> void:
	var f := ErFixture.make()
	var snap := f.engine.public_snapshot()
	assert_false(snap.has("rng"), "no rng state")
	assert_false(snap.has("seed"), "no seed")
	assert_eq(typeof(snap["event_deck"]), TYPE_INT, "deck size only")
