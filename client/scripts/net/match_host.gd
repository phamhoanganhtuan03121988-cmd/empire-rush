## M3 technical spike: authoritative match host. Owns the rules engine and
## its clock (server time), binds session tokens to seats, validates and
## applies commands, broadcasts ordered events and serves snapshots for
## join / reconnect (PROTOCOL.md §1-§5). Transport-agnostic: it consumes and
## produces text frames per link id. Not used by the offline game.
class_name MatchHost
extends RefCounted

var engine: GameEngine
var clock := MatchClock.new(0)
## token -> {player_id, seat}
var sessions: Dictionary = {}
## link id -> token (authenticated links)
var links: Dictionary = {}
var stats := {"commands": 0, "duplicates": 0, "rejected": {}, "frames_in": 0, "frames_out": 0, "snapshots": 0,
	"bot_takeovers": 0, "bot_commands": 0, "seat_reclaims": 0, "frame_errors": {}}
var policy := DisconnectPolicy.new()
## seat -> server time (ms) when its last link went away.
var seat_down_since: Dictionary = {}
## Prefix for server-made command ids; a restarted host uses a new epoch so
## its ids never collide with ones already in the journal.
var epoch := 0
var _out: Array = []  # [link_id, text]
var _bots: Dictionary = {}       # seat -> BotPlayer (takeover)
var _bot_due: Dictionary = {}    # seat -> [state_version, due_ms]
var _bot_n := 0
var _journaled := 0


func start(config: GameConfig, seats: Array, seed_value: int, tokens: Array) -> void:
	engine = GameEngine.create(config, clock, seats, seed_value, "m3-%d" % seed_value)
	engine.keep_event_log = true
	for i in seats.size():
		sessions[tokens[i]] = {"player_id": seats[i]["player_id"], "seat": i}
		# Until a client says Hello its seat counts as disconnected.
		seat_down_since[i] = clock.now_ms()


## Rebuilds the match after a server restart by replaying the journal (the
## engine is deterministic: same commands + advance times = same state).
func restore(config: GameConfig, seats: Array, seed_value: int, tokens: Array, journal: Array, p_epoch: int) -> void:
	start(config, seats, seed_value, tokens)
	epoch = p_epoch
	for entry in journal:
		var e: Dictionary = NetProtocol._ints(entry)
		clock.set_now(e["at"])
		if e.has("cmd"):
			var r := engine.submit(e["cmd"])
			assert(r["ok"] and not r.get("duplicate", false), "journal replay rejected %s" % str(e["cmd"]))
		else:
			engine.advance()
	_journaled = engine.input_log.size()
	for i in seats.size():
		seat_down_since[i] = clock.now_ms()


## Accepted inputs not yet persisted. The server writes them to its journal
## BEFORE sending any frame, so an acknowledged command is never lost by a crash.
func take_journal() -> Array:
	var out := engine.input_log.slice(_journaled)
	_journaled = engine.input_log.size()
	return out


func public_hash() -> String:
	return NetProtocol.public_hash(engine.public_snapshot())


## Feed one inbound frame from a link. Returns outbound frames.
func handle_frame(link_id: int, text: String) -> Array:
	stats["frames_in"] += 1
	var dec := NetProtocol.decode(text)
	if not dec["ok"]:
		stats["frame_errors"][dec["error"]] = stats["frame_errors"].get(dec["error"], 0) + 1
		_send(link_id, NetProtocol.ERROR, {"code": dec["error"]})
		return _flush()
	var msg: Dictionary = dec["msg"]
	match msg["kind"]:
		NetProtocol.HELLO:
			var token: String = str(msg.get("token", ""))
			if not sessions.has(token):
				_send(link_id, NetProtocol.ERROR, {"code": NetProtocol.E_UNAUTHENTICATED})
			else:
				links[link_id] = token
				var seat: int = sessions[token]["seat"]
				if _bots.has(seat):
					_bots.erase(seat)
					stats["seat_reclaims"] += 1
				seat_down_since.erase(seat)
				_send(link_id, NetProtocol.WELCOME, {"seat": sessions[token]["seat"], "player_id": sessions[token]["player_id"]})
				_send_snapshot(link_id)
		NetProtocol.SNAPSHOT_REQ:
			if links.has(link_id):
				_send_snapshot(link_id)
		NetProtocol.COMMAND:
			_on_command(link_id, msg.get("command", {}))
		_:
			_send(link_id, NetProtocol.ERROR, {"code": NetProtocol.E_BAD_REQUEST})
	return _flush()


func _on_command(link_id: int, cmd: Dictionary) -> void:
	if not links.has(link_id):
		_send(link_id, NetProtocol.ERROR, {"code": NetProtocol.E_UNAUTHENTICATED})
		return
	# Identity comes from the session, never from the payload alone (GDD §10).
	var session: Dictionary = sessions[links[link_id]]
	if str(cmd.get("player_id", "")) != session["player_id"]:
		_send(link_id, NetProtocol.RESULT, {"command_id": cmd.get("command_id", ""), "ok": false, "error": NetProtocol.E_UNAUTHENTICATED})
		return
	stats["commands"] += 1
	var res := engine.submit(cmd)
	if res.get("duplicate", false):
		stats["duplicates"] += 1
	if not res["ok"]:
		stats["rejected"][res["error"]] = stats["rejected"].get(res["error"], 0) + 1
	var body := {"command_id": cmd.get("command_id", ""), "ok": res["ok"], "state_version": engine.state.state_version,
		"duplicate": res.get("duplicate", false)}
	if not res["ok"]:
		body["error"] = res["error"]
	_send(link_id, NetProtocol.RESULT, body)
	if res["ok"] and not res["events"].is_empty():
		_broadcast(res["events"])


## Server timers: apply expired deadlines at server time `now_ms`.
func tick(now_ms: int) -> Array:
	if now_ms > clock.now_ms():
		clock.set_now(now_ms)
	var evs := engine.advance()
	if not evs.is_empty():
		_broadcast(evs)
	_takeover()
	return _flush()


func disconnect_link(link_id: int) -> void:
	if not links.has(link_id):
		return
	var seat: int = sessions[links[link_id]]["seat"]
	links.erase(link_id)
	if not links.values().any(func(t: String) -> bool: return sessions[t]["seat"] == seat):
		seat_down_since[seat] = clock.now_ms()


## Seat that may act now (auction: every solvent seat may bid).
func _may_act(seat: int) -> bool:
	var s := engine.state
	if s.player(seat)["bankrupt"]:
		return false
	match s.phase:
		GameState.AUCTION: return true
		GameState.TRADE_PENDING: return s.trade["to"] == seat
		GameState.RESCUE: return s.rescue["debtor"] == seat
		GameState.AWAIT_CHOICE: return s.choice["seat"] == seat
		GameState.ENDED: return false
	return s.current_seat == seat


## Disconnect policy: after the hold time a server-side bot plays the seat.
## The bot reads the authoritative engine (legitimate on the server) and its
## moves go through submit() like any client command, so they are validated,
## journaled and broadcast.
func _takeover() -> void:
	if policy.on_expiry != DisconnectPolicy.BOT or engine.is_ended():
		return
	var now := clock.now_ms()
	for seat in seat_down_since.keys():
		if now - int(seat_down_since[seat]) < policy.hold_ms or not _may_act(seat):
			continue
		if not _bots.has(seat):
			_bots[seat] = BotPlayer.new(seat, engine.state.player(seat)["player_id"], ErRng.new(engine.state.seed_value + seat * 977 + epoch), 0)
			stats["bot_takeovers"] += 1
		var v := engine.state.state_version
		var due: Array = _bot_due.get(seat, [-1, 0])
		if due[0] != v:
			_bot_due[seat] = [v, now + policy.bot_think_ms]
			continue
		if now < due[1]:
			continue
		var cmd: Dictionary = _bots[seat].decide(engine)
		_bot_due[seat] = [v, 1 << 62]  # at most one try per state version
		if cmd.is_empty():
			continue
		_bot_n += 1
		cmd["command_id"] = "srv%d-%d" % [epoch, _bot_n]
		var res := engine.submit(cmd)
		stats["bot_commands"] += 1
		if res["ok"] and not res["events"].is_empty():
			_broadcast(res["events"])
		return  # one server move per tick keeps the order simple


func _broadcast(events: Array) -> void:
	var body := {"events": events, "state_version": engine.state.state_version, "public_hash": public_hash()}
	for l in links:
		_send(l, NetProtocol.EVENTS, body)


func _send_snapshot(link_id: int) -> void:
	stats["snapshots"] += 1
	var snap := engine.public_snapshot()
	_send(link_id, NetProtocol.SNAPSHOT, {"snapshot": snap, "seq": engine.state.seq,
		"state_version": engine.state.state_version, "public_hash": NetProtocol.public_hash(snap)})


func _send(link_id: int, kind: String, body: Dictionary) -> void:
	_out.append([link_id, NetProtocol.encode(kind, body)])


func _flush() -> Array:
	var o := _out
	_out = []
	stats["frames_out"] += o.size()
	return o
