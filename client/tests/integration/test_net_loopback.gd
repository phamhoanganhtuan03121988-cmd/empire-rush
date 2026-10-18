## M3 technical spike, end to end: one authoritative MatchHost and four
## NetClients over the deterministic LoopbackNetwork (latency, ordered links,
## a disconnect that drops in-flight frames, client retries, injected
## duplicate commands). Bots choose moves, but every move travels as a
## protocol frame and is validated by the host. Simulated time, no sleeps.
## Note: the test bots read the host engine to choose a move (test harness
## only); a real client decides from its own snapshot + events.
extends TestCase

const STEP_MS := 50


func _setup(n: int, seed_value: int) -> Dictionary:
	var cfg := GameConfig.load_from_dir()
	var seats: Array = []
	var tokens: Array = []
	for i in n:
		seats.append({"player_id": "p%d" % i, "character_id": ["TYCOON", "INVESTOR", "NEGOTIATOR", "TYCOON"][i]})
		tokens.append("tok-%d-%d" % [seed_value, i])
	var host := MatchHost.new()
	host.start(cfg, seats, seed_value, tokens)
	var clients: Array = []
	for i in n:
		clients.append(NetClient.new(tokens[i]))
	var net := LoopbackNetwork.new()
	net.setup(host, clients, seed_value)
	for i in n:
		net.connect_client(i)
	var bots: Array = []
	var brng := ErRng.new(seed_value * 31 + 7)
	for i in n:
		bots.append(BotPlayer.new(i, "p%d" % i, brng, 0))
	return {"host": host, "clients": clients, "net": net, "bots": bots, "cfg": cfg, "seats": seats, "think": {}}


## Who may act now (auction: first bidder in seat order who wants to).
func _actor(h: Dictionary) -> Array:
	var e: GameEngine = h["host"].engine
	var s := e.state
	if s.phase == GameState.AUCTION:
		for k in s.players.size():
			var seat := (s.current_seat + 1 + k) % s.players.size()
			var cmd: Dictionary = h["bots"][seat].decide(e)
			if not cmd.is_empty():
				return [seat, cmd]
		return [-1, {}]
	var actor := s.current_seat
	match s.phase:
		GameState.TRADE_PENDING: actor = s.trade["to"]
		GameState.RESCUE: actor = s.rescue["debtor"]
		GameState.AWAIT_CHOICE: actor = s.choice["seat"]
	return [actor, h["bots"][actor].decide(e)]


## Runs until the match ends. `script` maps a step number to an action.
func _run(h: Dictionary, max_steps: int, script: Callable, dup_every := 0) -> int:
	var net: LoopbackNetwork = h["net"]
	var host: MatchHost = h["host"]
	var sent := 0
	for step in max_steps:
		if host.engine.is_ended():
			return step
		script.call(step)
		var pick := _actor(h)
		var seat: int = pick[0]
		if seat >= 0 and not pick[1].is_empty():
			var c: NetClient = h["clients"][seat]
			# Act only on a fresh view, after a short think time.
			if c.connected and not c.has_pending() and c.state_version == host.engine.state.state_version:
				var think: Dictionary = h["think"]
				var key := "%d@%d" % [seat, c.state_version]
				if not think.has(key):
					think[key] = net.now_ms + 200 + (c.state_version * 37) % 900
				if net.now_ms >= think[key]:
					var cmd: Dictionary = pick[1]
					var id := c.send_command(cmd["type"], cmd["payload"], c.snapshot["match_id"])
					sent += 1
					# Injected duplicate: the same command (same id) again,
					# as a double tap or a retry racing the first send.
					if dup_every > 0 and sent % dup_every == 0:
						net.send_up(c.link, NetProtocol.encode(NetProtocol.COMMAND, {"command": c._pending[id]["cmd"]}))
		net.step(STEP_MS)
		if step % 400 == 0:
			var errs := Invariants.check(host.engine)
			assert_true(errs.is_empty(), "invariants at step %d: %s" % [step, str(errs)])
	return max_steps


func _final_sync(h: Dictionary) -> void:
	var net: LoopbackNetwork = h["net"]
	for c in h["clients"]:
		if c.connected:
			net.send_up(c.link, NetProtocol.encode(NetProtocol.SNAPSHOT_REQ, {}))
	for i in 20:
		net.step(STEP_MS)


func test_four_clients_complete_a_match_with_reconnect_and_duplicates() -> void:
	var h := _setup(4, 404)
	var net: LoopbackNetwork = h["net"]
	var host: MatchHost = h["host"]
	# Disconnect client 2 while one of its commands is in flight, reconnect
	# 20 s later (the lost command is retried with the same id).
	var plan := {"down_at": -1}
	var script := func(step: int) -> void:
		if plan["down_at"] < 0 and step >= 1500 and h["clients"][2].has_pending():
			net.disconnect_client(2)
			plan["down_at"] = step
		elif plan["down_at"] >= 0 and step == plan["down_at"] + 400:
			net.connect_client(2)
	var steps := _run(h, 400000, script, 7)
	assert_true(host.engine.is_ended(), "match ended (after %d steps, %d s simulated)" % [steps, net.now_ms / 1000])
	assert_true(host.engine.state.end_reason in ["round_cap", "last_solvent", "time_cap"], "normal end: %s" % host.engine.state.end_reason)
	assert_true(Invariants.check(host.engine).is_empty(), "final invariants")
	assert_true(host.stats["duplicates"] > 0, "duplicate commands reached the host (%d)" % host.stats["duplicates"])
	_final_sync(h)
	var expect := host.public_hash()
	for c in h["clients"]:
		var nc: NetClient = c
		assert_eq(nc.public_hash, expect, "client %d converged on the server state" % nc.seat)
		assert_eq(nc.state_version, host.engine.state.state_version, "client %d state_version" % nc.seat)
		assert_eq(nc.stats["gaps"], 0, "client %d: ordered stream without gaps" % nc.seat)
		assert_eq(nc.stats["hash_mismatch"], 0, "client %d: snapshots match their hash" % nc.seat)
	# The reconnecting client resynchronised from a snapshot.
	assert_true(h["clients"][2].stats["snapshots"] >= 3, "client 2: join + reconnect + final snapshot")
	assert_true(net.frames_dropped > 0, "the disconnect dropped frames in flight (%d)" % net.frames_dropped)
	# Duplicates had no second effect: replaying only the applied commands
	# reproduces the exact final state.
	var replay := GameEngine.create(h["cfg"], MatchClock.new(0), h["seats"], 404, host.engine.state.match_id)
	var rclock: MatchClock = replay.clock
	for entry in host.engine.input_log:
		rclock.set_now(entry["at"])
		if entry.has("cmd"):
			assert_true(replay.submit(entry["cmd"])["ok"], "replayed command accepted")
		else:
			replay.advance()
	assert_eq(replay.state.state_hash(), host.engine.state.state_hash(), "server state = replay of applied commands")
	assert_true(plan["down_at"] >= 0, "the disconnect happened")
	print("NET_SPIKE steps=%d sim_s=%d commands=%d duplicates=%d rejected=%s frames_in=%d frames_out=%d dropped=%d snapshots=%d" % [
		steps, net.now_ms / 1000, host.stats["commands"], host.stats["duplicates"], str(host.stats["rejected"]),
		host.stats["frames_in"], host.stats["frames_out"], net.frames_dropped, host.stats["snapshots"]])
	net.teardown()


func test_identity_and_frame_validation() -> void:
	var h := _setup(2, 9)
	var host: MatchHost = h["host"]
	var net: LoopbackNetwork = h["net"]
	for i in 10:
		net.step(STEP_MS)
	var c0: NetClient = h["clients"][0]
	# Spoofing another seat's player_id is rejected by the session binding.
	var spoof := ErCommand.make(c0.snapshot["match_id"], "p1", "spoof-1", host.engine.state.state_version, ErCommand.ROLL_DICE, {})
	var out := host.handle_frame(0, NetProtocol.encode(NetProtocol.COMMAND, {"command": spoof}))
	assert_true(out[0][1].contains(NetProtocol.E_UNAUTHENTICATED), "spoofed player_id rejected")
	# Unknown token.
	out = host.handle_frame(7, NetProtocol.encode(NetProtocol.HELLO, {"token": "nope"}))
	assert_true(out[0][1].contains(NetProtocol.E_UNAUTHENTICATED), "unknown token rejected")
	# Oversized frame and wrong protocol version.
	out = host.handle_frame(0, "x".repeat(NetProtocol.MAX_FRAME + 1))
	assert_true(out[0][1].contains(NetProtocol.E_PAYLOAD_TOO_LARGE), "oversized frame rejected")
	out = host.handle_frame(0, JSON.stringify({"kind": "Command", "protocol_version": 99}))
	assert_true(out[0][1].contains(NetProtocol.E_PROTOCOL_UNSUPPORTED), "unsupported protocol rejected")
	# Stale state version is rejected, not applied.
	var stale := ErCommand.make(c0.snapshot["match_id"], "p0", "stale-1", host.engine.state.state_version - 1, ErCommand.ROLL_DICE, {})
	out = host.handle_frame(0, NetProtocol.encode(NetProtocol.COMMAND, {"command": stale}))
	assert_true(out[0][1].contains("STALE_STATE"), "stale command rejected")
	# Snapshot frames stay within the 16 KiB frame budget (PROTOCOL.md §2).
	var snap_out := host.handle_frame(0, NetProtocol.encode(NetProtocol.SNAPSHOT_REQ, {}))
	var size: int = snap_out[0][1].to_utf8_buffer().size()
	assert_true(size <= NetProtocol.MAX_FRAME, "snapshot frame %d bytes <= %d" % [size, NetProtocol.MAX_FRAME])
	print("NET_SPIKE snapshot_frame_bytes=%d" % size)
	net.teardown()


## Phase 2: a state rebuilt from to_dict() is identical (hash), and a client
## view built from a public snapshot reproduces that snapshot.
func test_state_round_trips_through_dict_and_public_snapshot() -> void:
	var h := _setup(3, 77)
	var host: MatchHost = h["host"]
	_run(h, 3000, func(_s: int) -> void: pass)
	var s := host.engine.state
	assert_eq(GameState.from_dict(s.to_dict()).state_hash(), s.state_hash(), "full state round trip")
	var view := GameEngine.new()
	view.config = h["cfg"]
	var snap := host.engine.public_snapshot()
	view.state = GameState.from_dict(snap)
	var again := view.public_snapshot()
	# The public snapshot only carries the deck SIZE; a view cannot rebuild the order.
	assert_eq(again["event_deck"], 0, "view holds no event-deck order")
	again["event_deck"] = snap["event_deck"]
	assert_eq(NetProtocol.public_hash(again), host.public_hash(), "client view = public snapshot")
	h["net"].teardown()


## Phase 2: a restarted host rebuilt from its journal holds exactly the same
## state, keeps deduplicating old command ids and plays on to a normal end.
func test_host_restores_from_journal_and_finishes() -> void:
	var h := _setup(4, 505)
	var host: MatchHost = h["host"]
	_run(h, 2500, func(_s: int) -> void: pass, 6)
	var journal: Array = []
	for e in host.take_journal():
		journal.append(JSON.parse_string(JSON.stringify(e)))  # through text, like the file
	var restored := MatchHost.new()
	restored.restore(h["cfg"], h["seats"], 505, h["host"].sessions.keys(), journal, 1)
	assert_eq(restored.engine.state.state_hash(), host.engine.state.state_hash(), "restored state = live state")
	var any_cmd: Dictionary = {}
	for e in host.engine.input_log:
		if e.has("cmd"):
			any_cmd = e["cmd"]
	var res := restored.engine.submit(any_cmd)
	assert_true(res.get("duplicate", false), "an already applied command id stays deduplicated after restart")
	# Swap the restored host in; clients reconnect and the match finishes.
	var net: LoopbackNetwork = h["net"]
	for i in 4:
		net.disconnect_client(i)
	net.host = restored
	h["host"] = restored
	for i in 4:
		net.connect_client(i)
	h["think"] = {}
	var steps := _run(h, 400000, func(_s: int) -> void: pass)
	assert_true(restored.engine.is_ended(), "match ended after the restart (%d steps)" % steps)
	_final_sync(h)
	for c in h["clients"]:
		assert_eq(c.public_hash, restored.public_hash(), "client %d converged after restart" % c.seat)
	net.teardown()


## Phase 2 (C4): with the "bot" policy, a seat whose client stays away longer
## than the hold time is played by the server bot; the player reclaims it on
## reconnect. With "timers" the server never moves for the seat itself.
func test_disconnect_policy_bot_takeover_and_reclaim() -> void:
	for mode in [DisconnectPolicy.BOT, DisconnectPolicy.TIMERS]:
		var h := _setup(3, 606)
		var host: MatchHost = h["host"]
		host.policy = DisconnectPolicy.from_dict({"hold_ms": 5000, "on_expiry": mode, "bot_think_ms": 300})
		var net: LoopbackNetwork = h["net"]
		var plan := {"down": -1}
		var script := func(step: int) -> void:
			if step == 600:
				net.disconnect_client(1)
				plan["down"] = step
			elif step == 600 + 800:  # 40 s simulated away (hold is 5 s)
				net.connect_client(1)
		_run(h, 400000, script)
		assert_true(host.engine.is_ended(), "%s: match ended" % mode)
		assert_true(Invariants.check(host.engine).is_empty(), "%s: invariants" % mode)
		if mode == DisconnectPolicy.BOT:
			assert_eq(host.stats["bot_takeovers"], 1, "bot took over the seat once")
			assert_true(host.stats["bot_commands"] > 0, "bot moved for the seat (%d)" % host.stats["bot_commands"])
			assert_eq(host.stats["seat_reclaims"], 1, "player reclaimed the seat")
		else:
			assert_eq(host.stats["bot_commands"], 0, "timers policy: no server moves")
		net.teardown()
