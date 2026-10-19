## Phase 3 (B2/B3): RoomServer - private rooms, concurrent isolated matches,
## restart from meta + journal, hardening (rate limit, handshake timeout,
## replaced sessions, error paths), cleanup without leaks and disconnect
## policy edge cases. In-process over LoopbackNetwork (simulated time); the
## same server runs as an OS process in scripts/run_net_e2e.sh.
extends TestCase

const STEP_MS := 50


func _server(seed_value: int) -> RoomServer:
	var rs := RoomServer.new(GameConfig.load_from_dir())
	rs.time_scale = 1.0
	# Deterministic "random" for tests: codes, tokens and seeds from a counter.
	var n := [seed_value * 1000]
	rs.random_hex = func(bytes: int) -> String:
		n[0] += 1
		return ("%016x" % (n[0] * 2654435761)).repeat(4).left(bytes * 2)
	return rs


## clients[i] gets room_request; returns {rs, net, clients, bots}.
func _world(rs: RoomServer, requests: Array, seed_value: int) -> Dictionary:
	var clients: Array = []
	for r in requests:
		var c := NetClient.new("")
		c.room_request = r
		clients.append(c)
	var net := LoopbackNetwork.new()
	net.setup(rs, clients, seed_value)
	return {"rs": rs, "net": net, "clients": clients, "bots": {}, "think": {}}


func _host_of(w: Dictionary, c: NetClient) -> MatchHost:
	var room: Dictionary = w["rs"].rooms.get(c.room_code, {})
	return room.get("host") if not room.is_empty() else null


func _may_act(e: GameEngine, seat: int) -> bool:
	var s := e.state
	if s.player(seat)["bankrupt"]:
		return false
	match s.phase:
		GameState.AUCTION: return true
		GameState.TRADE_PENDING: return s.trade["to"] == seat
		GameState.RESCUE: return s.rescue["debtor"] == seat
		GameState.AWAIT_CHOICE: return s.choice["seat"] == seat
		GameState.ENDED: return false
	return s.current_seat == seat


## Steps the world; connected, welcomed clients play with a bot that reads
## their room's engine (test harness shortcut, as in test_net_loopback).
func _run(w: Dictionary, max_steps: int, script := Callable()) -> int:
	var net: LoopbackNetwork = w["net"]
	for step in max_steps:
		if script.is_valid():
			script.call(step)
		var all_done := true
		for i in w["clients"].size():
			var c: NetClient = w["clients"][i]
			var host := _host_of(w, c)
			if c.room_code == "" or (host != null and not host.engine.is_ended()):
				all_done = false  # a removed room (host == null) counts as done
			if host == null or not c.connected or not c.welcomed or c.has_pending():
				continue
			var e := host.engine
			if e.is_ended() or c.state_version != e.state.state_version or not _may_act(e, c.seat):
				continue
			var key := "%d@%d" % [i, c.state_version]
			if not w["think"].has(key):
				w["think"][key] = net.now_ms + 200 + (c.state_version * 37 + i * 101) % 700
			if net.now_ms < w["think"][key]:
				continue
			if not w["bots"].has(i):
				w["bots"][i] = BotPlayer.new(c.seat, c.player_id, ErRng.new(i * 7 + 3), 0)
			var cmd: Dictionary = w["bots"][i].decide(e)
			w["think"][key] = 1 << 62
			if not cmd.is_empty():
				c.send_command(cmd["type"], cmd["payload"], e.state.match_id)
		if all_done:
			return step
		net.step(STEP_MS)
	return max_steps


func _sync(w: Dictionary) -> void:
	for c in w["clients"]:
		if c.connected and c.welcomed:
			w["net"].send_up(c.link, NetProtocol.encode(NetProtocol.SNAPSHOT_REQ, {}))
	for i in 20:
		w["net"].step(STEP_MS)


func _replay_matches(rs: RoomServer, code: String) -> bool:
	var host: MatchHost = rs.rooms[code]["host"]
	var meta := rs.room_meta(code)
	var fresh := MatchHost.new()
	fresh.restore(rs.config, meta["seats"], meta["seed"], meta["token_hashes"], host.engine.input_log.duplicate(true), 1, true, "room-" + code)
	return fresh.engine.state.state_hash() == host.engine.state.state_hash()


func test_three_concurrent_rooms_play_to_the_end_in_isolation() -> void:
	var rs := _server(11)
	rs.linger_ms = 1 << 40  # keep ended rooms for the checks below
	# Room A: 4 players, room B: 2, room C: 3. Creators connect first.
	var create := func(n: int) -> Dictionary: return {"kind": NetProtocol.CREATE_ROOM, "players": n}
	var w := _world(rs, [create.call(4), create.call(2), create.call(3)], 11)
	var net: LoopbackNetwork = w["net"]
	for i in 3:
		net.connect_client(i)
	for k in 10:
		net.step(STEP_MS)
	var codes: Array = w["clients"].map(func(c: NetClient) -> String: return c.room_code)
	assert_eq(codes.filter(func(x: String) -> bool: return x != "").size(), 3, "three rooms created: %s" % str(codes))
	assert_eq(rs.rooms.size(), 3, "server holds three rooms")
	# Joiners: 3 for A, 1 for B, 2 for C.
	var joins := [0, 0, 0, 1, 2, 2]
	for r in joins:
		var c := NetClient.new("")
		c.room_request = {"kind": NetProtocol.JOIN_ROOM, "room_code": codes[r]}
		w["clients"].append(c)
	net.teardown()
	net = LoopbackNetwork.new()
	net.setup(rs, w["clients"], 12)
	w["net"] = net
	for i in w["clients"].size():
		if i >= 3:
			net.connect_client(i)
	# Creators' links were rebuilt: resume them with their tokens (Hello).
	for i in 3:
		net.connect_client(i)
	var steps := _run(w, 400000)
	assert_eq(rs.stats["rooms_started"], 3, "all rooms started")
	for code in codes:
		var host: MatchHost = rs.rooms[code]["host"]
		assert_true(host.engine.is_ended(), "room %s ended (%d steps)" % [code, steps])
		assert_true(Invariants.check(host.engine).is_empty(), "room %s invariants" % code)
		assert_true(_replay_matches(rs, code), "room %s = replay of its own journal alone (isolation)" % code)
	assert_eq(rs.rooms[codes[0]]["seats"].size(), 4, "room A has 4 seats")
	_sync(w)
	for c in w["clients"]:
		assert_eq(c.public_hash, _host_of(w, c).public_hash(), "client of room %s seat %d converged" % [c.room_code, c.seat])
	# Different rooms really are different matches.
	var hashes := {}
	for code in codes:
		hashes[rs.rooms[code]["host"].engine.state.state_hash()] = true
	assert_eq(hashes.size(), 3, "three distinct final states")
	net.teardown()


func test_room_errors_and_identity() -> void:
	var rs := _server(21)
	rs.max_rooms = 1
	rs.link_opened(1, 0)
	var out := rs.handle_frame(1, NetProtocol.encode(NetProtocol.JOIN_ROOM, {"room_code": "NOPE42"}), 0)
	assert_true(out[0][1].contains(NetProtocol.E_ROOM_NOT_FOUND), "unknown room code")
	out = rs.handle_frame(1, NetProtocol.encode(NetProtocol.CREATE_ROOM, {"players": 7}), 0)
	assert_true(out[0][1].contains(NetProtocol.E_BAD_REQUEST), "7 players refused")
	out = rs.handle_frame(1, NetProtocol.encode(NetProtocol.COMMAND, {"command": {}}), 0)
	assert_true(out[0][1].contains(NetProtocol.E_UNAUTHENTICATED), "command before any room")
	out = rs.handle_frame(1, NetProtocol.encode(NetProtocol.HELLO, {"token": "guess"}), 0)
	assert_true(out[0][1].contains(NetProtocol.E_UNAUTHENTICATED), "guessed token")
	out = rs.handle_frame(1, NetProtocol.encode(NetProtocol.CREATE_ROOM, {"players": 2, "character_id": "HACKER"}), 0)
	var joined: Dictionary = JSON.parse_string(out[0][1])
	assert_eq(joined["kind"], NetProtocol.ROOM_JOINED, "room created")
	assert_eq(rs.rooms[joined["room_code"]]["seats"][0]["character_id"], "TYCOON", "unknown character replaced by the server default")
	assert_eq(str(joined["token"]).length(), 32, "128-bit token")
	assert_false(JSON.stringify(rs.room_meta(joined["room_code"])).contains(joined["token"]), "meta holds no plain token")
	rs.link_opened(2, 0)
	out = rs.handle_frame(2, NetProtocol.encode(NetProtocol.CREATE_ROOM, {"players": 2}), 0)
	assert_true(out[0][1].contains(NetProtocol.E_SERVER_FULL), "room limit")
	out = rs.handle_frame(2, NetProtocol.encode(NetProtocol.JOIN_ROOM, {"room_code": str(joined["room_code"]).to_lower()}), 0)
	assert_true(out[0][1].contains(NetProtocol.ROOM_JOINED), "join (code is case-insensitive)")
	rs.link_opened(3, 0)
	out = rs.handle_frame(3, NetProtocol.encode(NetProtocol.JOIN_ROOM, {"room_code": joined["room_code"]}), 0)
	assert_true(out[0][1].contains(NetProtocol.E_ROOM_FULL), "started room refuses joins")
	# Same token on two links: the older one is replaced and closed.
	rs.link_opened(4, 0)
	rs.handle_frame(1, NetProtocol.encode(NetProtocol.HELLO, {"token": joined["token"]}), 0)
	out = rs.handle_frame(4, NetProtocol.encode(NetProtocol.HELLO, {"token": joined["token"]}), 0)
	var kinds: Array = out.map(func(o: Array) -> String: return "%d:%s" % [o[0], JSON.parse_string(o[1])["kind"]])
	assert_true("1:Error" in kinds and out.any(func(o: Array) -> bool: return o[0] == 1 and o[1].contains(NetProtocol.E_SESSION_REPLACED)), "old link told SESSION_REPLACED: %s" % str(kinds))
	assert_true(1 in rs.to_close, "old link closed")
	assert_true("4:Welcome" in kinds, "new link welcomed")


## Phase 4 security review: one link could send CreateRoom/JoinRoom again
## and again (filling every room, or several seats of one room), and a room
## that never filled lived forever. 64 abandoned rooms = SERVER_FULL for
## everyone. Now: one room per link, and waiting rooms expire.
func test_one_room_per_link_and_waiting_rooms_expire() -> void:
	var rs := _server(25)
	rs.max_rooms = 4
	rs.link_opened(1, 0)
	var out := rs.handle_frame(1, NetProtocol.encode(NetProtocol.CREATE_ROOM, {"players": 3}), 0)
	var code: String = JSON.parse_string(out[0][1])["room_code"]
	for i in 3:
		out = rs.handle_frame(1, NetProtocol.encode(NetProtocol.CREATE_ROOM, {"players": 2}), 0)
		assert_true(out[0][1].contains(NetProtocol.E_BAD_REQUEST), "second CreateRoom on the same link refused")
	out = rs.handle_frame(1, NetProtocol.encode(NetProtocol.JOIN_ROOM, {"room_code": code}), 0)
	assert_true(out[0][1].contains(NetProtocol.E_BAD_REQUEST), "the creator cannot take a second seat")
	assert_eq(rs.rooms.size(), 1, "one room for one link")
	assert_eq(rs.rooms[code]["seats"].size(), 1, "one seat for one link")
	# The creator leaves; nobody joins. The room is removed after the wait limit.
	rs.link_closed(1)
	rs.tick(rs.waiting_ttl_ms - 1)
	assert_true(rs.rooms.has(code), "still open inside the wait limit")
	rs.link_opened(2, rs.waiting_ttl_ms)
	out = rs.handle_frame(2, NetProtocol.encode(NetProtocol.JOIN_ROOM, {"room_code": code}), rs.waiting_ttl_ms)
	assert_true(out[0][1].contains(NetProtocol.ROOM_JOINED), "a late friend can still join")
	rs.tick(rs.waiting_ttl_ms + 1)
	assert_false(rs.rooms.has(code), "unfilled room removed after the wait limit")
	assert_true(2 in rs.to_close, "its remaining links are closed (ROOM_CLOSED)")
	assert_eq(rs.stats["rooms_expired"], 1, "counted")
	rs.link_opened(3, rs.waiting_ttl_ms + 2)
	out = rs.handle_frame(3, NetProtocol.encode(NetProtocol.CREATE_ROOM, {"players": 2}), rs.waiting_ttl_ms + 2)
	assert_true(out[0][1].contains(NetProtocol.ROOM_JOINED), "the slot is free again")


func test_rate_limit_and_handshake_timeout() -> void:
	var rs := _server(31)
	rs.link_opened(1, 0)
	var limited := 0
	for i in 200:
		for o in rs.handle_frame(1, NetProtocol.encode(NetProtocol.SNAPSHOT_REQ, {}), 1000):
			if o[1].contains(NetProtocol.E_RATE_LIMITED):
				limited += 1
	assert_true(rs.stats["rate_limited"] >= 150, "frames over the burst dropped (%d)" % rs.stats["rate_limited"])
	assert_true(limited > 0 and limited < 30, "few error replies, not one per frame (%d)" % limited)
	assert_true(1 in rs.to_close, "flooding link closed")
	# Refill: after 2 s a well-behaved link may send again.
	rs.link_opened(5, 0)
	for i in 40:
		rs.handle_frame(5, "{}", 3000)
	var before: int = rs.stats["rate_limited"]
	rs.handle_frame(5, "{}", 5000)
	assert_eq(rs.stats["rate_limited"], before, "bucket refilled after 2 s")
	# A link that never creates, joins or resumes is dropped.
	rs.link_opened(2, 10000)
	rs.tick(15000)
	assert_false(2 in rs.to_close, "still inside the handshake window")
	rs.tick(20001)
	assert_true(2 in rs.to_close, "handshake timeout closes the link")
	assert_eq(rs.stats["handshake_timeouts"], 3, "counted once per link (links 1 and 5 never joined either)")
	rs.max_links = rs.link_count()
	assert_false(rs.link_opened(9, 20001), "link limit refuses new connections")


func test_restart_restores_rooms_and_match_finishes() -> void:
	var rs := _server(41)
	var create := {"kind": NetProtocol.CREATE_ROOM, "players": 3}
	var w := _world(rs, [create], 41)
	var net: LoopbackNetwork = w["net"]
	net.connect_client(0)
	for k in 10:
		net.step(STEP_MS)
	var code: String = w["clients"][0].room_code
	for k in 2:
		var c := NetClient.new("")
		c.room_request = {"kind": NetProtocol.JOIN_ROOM, "room_code": code}
		w["clients"].append(c)
	net.teardown()
	net = LoopbackNetwork.new()
	net.setup(rs, w["clients"], 42)
	w["net"] = net
	for i in 3:
		net.connect_client(i)
	_run(w, 1500)
	var host: MatchHost = rs.rooms[code]["host"]
	assert_false(host.engine.is_ended(), "mid-match")
	# "Crash": keep only what the server wrote to disk (meta + journal, as JSON text).
	var meta: Dictionary = JSON.parse_string(JSON.stringify(rs.room_meta(code)))
	var journal: Array = JSON.parse_string(JSON.stringify(host.engine.input_log))
	var live_hash := host.engine.state.state_hash()
	var rs2 := _server(43)
	rs2.restore_room(meta, journal, 1, net.now_ms)
	assert_eq(rs2.rooms[code]["host"].engine.state.state_hash(), live_hash, "restored = state before the crash")
	for i in 3:
		net.disconnect_client(i)
	net.host = rs2
	w["rs"] = rs2
	w["think"] = {}
	for i in 3:
		net.connect_client(i)  # tokens kept by the clients -> Hello
	_run(w, 400000)
	assert_true(rs2.rooms[code]["host"].engine.is_ended(), "match finished after the restart")
	_sync(w)
	for c in w["clients"]:
		assert_eq(c.public_hash, rs2.rooms[code]["host"].public_hash(), "seat %d converged after restart" % c.seat)
	net.teardown()


## Policy edge cases: a player leaves for good (bot plays to the end and the
## match ends normally, assets untouched by any forfeit), and the server
## restarts while the bot holds the seat (takeover resumes after the hold).
func test_player_never_returns_and_restart_during_takeover() -> void:
	var rs := _server(51)
	rs.policy_dict = {"hold_ms": 60000, "on_expiry": DisconnectPolicy.BOT, "bot_think_ms": 300}
	var w := _world(rs, [{"kind": NetProtocol.CREATE_ROOM, "players": 2}], 51)
	var net: LoopbackNetwork = w["net"]
	net.connect_client(0)
	for k in 10:
		net.step(STEP_MS)
	var c1 := NetClient.new("")
	c1.room_request = {"kind": NetProtocol.JOIN_ROOM, "room_code": w["clients"][0].room_code}
	w["clients"].append(c1)
	net.teardown()
	net = LoopbackNetwork.new()
	net.setup(rs, w["clients"], 52)
	w["net"] = net
	net.connect_client(0)
	net.connect_client(1)
	var code: String = w["clients"][0].room_code
	_run(w, 400)
	net.disconnect_client(1)
	# 59 s: still held, no bot yet.
	_run(w, 59000 / STEP_MS)
	assert_eq(rs.rooms[code]["host"].stats["bot_takeovers"], 0, "no takeover inside the 60 s hold")
	_run(w, 3000 / STEP_MS)
	assert_eq(rs.rooms[code]["host"].stats["bot_takeovers"], 1, "bot took over after 60 s")
	# Server restart while the bot holds the seat.
	var meta: Dictionary = JSON.parse_string(JSON.stringify(rs.room_meta(code)))
	var journal: Array = JSON.parse_string(JSON.stringify(rs.rooms[code]["host"].engine.input_log))
	var rs2 := _server(53)
	rs2.policy_dict = rs.policy_dict
	rs2.restore_room(meta, journal, 1, net.now_ms)
	net.disconnect_client(0)
	net.host = rs2
	w["rs"] = rs2
	w["think"] = {}
	net.connect_client(0)
	_run(w, 400000)
	var host: MatchHost = rs2.rooms[code]["host"]
	assert_true(host.engine.is_ended(), "match ended with the player still away")
	assert_true(host.engine.state.end_reason in ["round_cap", "last_solvent", "time_cap"], "normal end: %s" % host.engine.state.end_reason)
	assert_eq(host.stats["bot_takeovers"], 1, "takeover resumed after the restart")
	assert_true(host.stats["bot_commands"] > 0, "bot kept playing (%d moves)" % host.stats["bot_commands"])
	assert_true(Invariants.check(host.engine).is_empty(), "invariants")
	net.teardown()


## Ended rooms are removed after the linger time; tokens stop working and
## the object count returns to its level after the first match (no leak).
func test_ended_rooms_are_removed_without_leaks() -> void:
	var rs := _server(61)
	rs.linger_ms = 2000
	var counts: Array = []
	for round_i in 4:
		var w := _world(rs, [{"kind": NetProtocol.CREATE_ROOM, "players": 2}], 61 + round_i)
		var net: LoopbackNetwork = w["net"]
		net.connect_client(0)
		for k in 10:
			net.step(STEP_MS)
		var c1 := NetClient.new("")
		c1.room_request = {"kind": NetProtocol.JOIN_ROOM, "room_code": w["clients"][0].room_code}
		w["clients"].append(c1)
		var now: int = net.now_ms
		net.teardown()
		net = LoopbackNetwork.new()
		net.setup(rs, w["clients"], 70 + round_i)
		net.now_ms = now
		w["net"] = net
		net.connect_client(0)
		net.connect_client(1)
		_run(w, 400000)
		var token: String = w["clients"][0].token
		for k in 3000 / STEP_MS:
			net.step(STEP_MS)
		assert_eq(rs.rooms.size(), 0, "round %d: ended room removed" % round_i)
		net.teardown()
		w.clear()
		var probe := rs.handle_frame(99, NetProtocol.encode(NetProtocol.HELLO, {"token": token}), now)
		assert_true(probe.is_empty(), "unknown link ignored")
		rs.link_opened(99, now)
		probe = rs.handle_frame(99, NetProtocol.encode(NetProtocol.HELLO, {"token": token}), now)
		assert_true(probe[0][1].contains(NetProtocol.E_UNAUTHENTICATED), "token of a removed room no longer works")
		rs.link_closed(99)
		for link in [0, 1]:
			rs.link_closed(link)
		counts.append(Performance.get_monitor(Performance.OBJECT_COUNT))
	assert_eq(rs.stats["rooms_removed"], 4, "four rooms removed")
	assert_eq(rs.link_count(), 0, "no links left")
	assert_true(absi(int(counts[3]) - int(counts[1])) < 200, "object count stable across matches: %s" % str(counts))


## 2-player room with both seats connected (creator, then joiner).
func _two_player_room(seed_value: int) -> Dictionary:
	var rs := _server(seed_value)
	rs.policy_dict = {"hold_ms": 60000, "on_expiry": DisconnectPolicy.BOT, "bot_think_ms": 300}
	var w := _world(rs, [{"kind": NetProtocol.CREATE_ROOM, "players": 2}], seed_value)
	w["net"].connect_client(0)
	for k in 10:
		w["net"].step(STEP_MS)
	var c1 := NetClient.new("")
	c1.room_request = {"kind": NetProtocol.JOIN_ROOM, "room_code": w["clients"][0].room_code}
	w["clients"].append(c1)
	w["net"].teardown()
	var net := LoopbackNetwork.new()
	net.setup(rs, w["clients"], seed_value + 1)
	w["net"] = net
	net.connect_client(0)
	net.connect_client(1)
	return w


## Phase 4: the link drops at the exact step a trade becomes pending - for
## the recipient (who must answer) and, in another room, for the proposer.
## The trade must still resolve exactly once (answered or expired), the match
## must finish, the journal must replay to the same state, and the player who
## comes back inside the hold reclaims the seat and converges.
func test_disconnect_while_trade_is_pending() -> void:
	for who in ["to", "from"]:
		var w: Dictionary
		var hit := {}
		for seed_value in [71, 73, 75, 77, 79, 81, 83, 85]:
			w = _two_player_room(seed_value + (0 if who == "to" else 100))
			var net: LoopbackNetwork = w["net"]
			# Watch every step; drop the link the moment a trade is pending.
			_run(w, 400000, func(_step: int) -> void:
				if not hit.is_empty():
					if net.now_ms == hit["back_at"]:
						net.connect_client(hit["seat"])
					return
				var host := _host_of(w, w["clients"][0])
				if host == null or host.engine.state.phase != GameState.TRADE_PENDING:
					return
				var t: Dictionary = host.engine.state.trade
				var seat: int = t[who]
				var link := -1
				for i in w["clients"].size():
					if w["clients"][i].seat == seat:
						link = i
				# merge, not assign: a lambda cannot rebind a captured local
				hit.merge({"seat": link, "trade_id": t["trade_id"], "back_at": net.now_ms + 30000})
				net.disconnect_client(link))
			if not hit.is_empty():
				break
			net.teardown()
		assert_false(hit.is_empty(), "a bot proposed a trade in one of the seeds (%s)" % who)
		if hit.is_empty():
			return
		var code: String = w["clients"][0].room_code
		var host: MatchHost = w["rs"].rooms[code]["host"]
		var outcomes: Array = []
		for ev in host.engine.event_log:
			if ev["type"] == "TradeResolved" and ev["data"]["trade_id"] == hit["trade_id"]:
				outcomes.append(ev["data"]["status"])
		assert_eq(outcomes.size(), 1, "%s: the trade resolved exactly once (%s)" % [who, outcomes])
		if who == "to":  # away 30 s > 20 s trade timer, inside the 60 s hold: no bot answers
			assert_eq(outcomes, ["expired"], "recipient away: the trade expired")
		assert_true(host.engine.is_ended(), "%s: match ended" % who)
		assert_true(Invariants.check(host.engine).is_empty(), "%s: invariants" % who)
		assert_true(_replay_matches(w["rs"], code), "%s: journal replays to the same state" % who)
		var back: NetClient = w["clients"][hit["seat"]]
		assert_true(back.connected and back.welcomed, "%s: player reconnected after 30 s" % who)
		assert_false(host.seat_down_since.has(back.seat), "%s: seat no longer held as away" % who)
		assert_eq(host.stats["bot_takeovers"], 0, "%s: no takeover inside the 60 s hold" % who)
		_sync(w)
		for c in w["clients"]:
			assert_eq(c.public_hash, host.public_hash(), "%s: seat %d converged" % [who, c.seat])
		w["net"].teardown()


## Phase 4: the link of the seat whose turn just started drops at that exact
## step and stays away past the hold: the bot takes the seat, the player
## returns mid-match and plays on; the match ends normally and replays.
func test_disconnect_at_turn_change() -> void:
	var w := _two_player_room(91)
	var net: LoopbackNetwork = w["net"]
	var st := {"last": -1, "changes": 0, "dropped_at": -1, "link": -1}
	_run(w, 400000, func(_step: int) -> void:
		var host := _host_of(w, w["clients"][0])
		if host == null:
			return
		if st["dropped_at"] >= 0:
			if net.now_ms == st["dropped_at"] + 70000:
				net.connect_client(st["link"])
			return
		var seat: int = host.engine.state.current_seat
		if seat != st["last"]:
			st["last"] = seat
			st["changes"] += 1
			if st["changes"] == 6:  # a few turns in, at the exact turn change
				for i in w["clients"].size():
					if w["clients"][i].seat == seat:
						st["link"] = i
				st["dropped_at"] = net.now_ms
				net.disconnect_client(st["link"]))
	assert_true(st["dropped_at"] >= 0, "dropped a link at a turn change")
	var code: String = w["clients"][0].room_code
	var host: MatchHost = w["rs"].rooms[code]["host"]
	assert_true(host.engine.is_ended(), "match ended")
	assert_true(host.engine.state.end_reason in ["round_cap", "last_solvent", "time_cap"], "normal end: %s" % host.engine.state.end_reason)
	assert_eq(host.stats["bot_takeovers"], 1, "bot held the seat after 60 s")
	assert_true(host.stats["seat_reclaims"] >= 1, "player reclaimed the seat at 70 s")
	assert_true(Invariants.check(host.engine).is_empty(), "invariants")
	assert_true(_replay_matches(w["rs"], code), "journal replays to the same state")
	_sync(w)
	for c in w["clients"]:
		assert_eq(c.public_hash, host.public_hash(), "seat %d converged" % c.seat)
	net.teardown()
