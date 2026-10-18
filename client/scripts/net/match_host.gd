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
var stats := {"commands": 0, "duplicates": 0, "rejected": {}, "frames_in": 0, "frames_out": 0, "snapshots": 0}
var _out: Array = []  # [link_id, text]


func start(config: GameConfig, seats: Array, seed_value: int, tokens: Array) -> void:
	engine = GameEngine.create(config, clock, seats, seed_value, "m3-%d" % seed_value)
	engine.keep_event_log = true
	for i in seats.size():
		sessions[tokens[i]] = {"player_id": seats[i]["player_id"], "seat": i}


func public_hash() -> String:
	return NetProtocol.public_hash(engine.public_snapshot())


## Feed one inbound frame from a link. Returns outbound frames.
func handle_frame(link_id: int, text: String) -> Array:
	stats["frames_in"] += 1
	var dec := NetProtocol.decode(text)
	if not dec["ok"]:
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
	return _flush()


func disconnect_link(link_id: int) -> void:
	links.erase(link_id)


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
