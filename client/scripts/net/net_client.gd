## M3 technical spike: a thin client. It never runs rules: it holds the last
## snapshot the server sent plus the ordered event stream after it, checks
## that the stream has no gaps or duplicates, resynchronises with a snapshot
## when it detects a gap or reconnects, and resends an unanswered command with
## the SAME command_id (the server deduplicates, PROTOCOL.md §3).
class_name NetClient
extends RefCounted

const RETRY_MS := 1500

var token := ""
var player_id := ""
var seat := -1
## Transport: LoopbackNetwork in tests, a WebSocket link in the multi-process
## harness. Duck-typed: needs `now_ms` and `send_up(link, text)`.
var net: Object
var link := -1
var connected := false
## Known server state.
var snapshot: Dictionary = {}
var last_seq := 0
var state_version := 0
var public_hash := ""
var events: Array = []          # events applied after the latest snapshot
var all_events_seen := 0
var stats := {"duplicate_events": 0, "gaps": 0, "snapshots": 0, "resends": 0, "rejections": {}, "hash_checks": 0, "hash_mismatch": 0, "errors": {}}
## Phase 3 rooms: when there is no token yet, the client first sends this
## request ({"kind": CreateRoom|JoinRoom, ...}) and receives its token.
var room_request: Dictionary = {}
var room_code := ""
var welcomed := false
var _cmd_n := 0
var _pending: Dictionary = {}   # command_id -> {cmd, sent_ms}


func _init(p_token: String) -> void:
	token = p_token


func on_connected(p_net: Object, p_link: int) -> void:
	net = p_net
	link = p_link
	connected = true
	welcomed = false
	if token == "" and not room_request.is_empty():
		var body := room_request.duplicate()
		body.erase("kind")
		net.send_up(link, NetProtocol.encode(room_request["kind"], body))
	else:
		_hello()


func _hello() -> void:
	net.send_up(link, NetProtocol.encode(NetProtocol.HELLO, {"token": token, "last_seq": last_seq}))


func on_disconnected() -> void:
	connected = false


func handle_frame(text: String) -> void:
	var dec := NetProtocol.decode(text)
	if not dec["ok"]:
		return
	var m: Dictionary = dec["msg"]
	match m["kind"]:
		NetProtocol.ROOM_JOINED:
			token = m["token"]
			room_code = m["room_code"]
			seat = m["seat"]
			player_id = m["player_id"]
			room_request = {}
		NetProtocol.ROOM_STATE:
			if m["started"] and not welcomed:
				_hello()
		NetProtocol.WELCOME:
			welcomed = true
			seat = m["seat"]
			player_id = m["player_id"]
		NetProtocol.SNAPSHOT:
			stats["snapshots"] += 1
			snapshot = m["snapshot"]
			last_seq = m["seq"]
			state_version = m["state_version"]
			public_hash = m["public_hash"]
			events.clear()
			stats["hash_checks"] += 1
			if NetProtocol.public_hash(snapshot) != public_hash:
				stats["hash_mismatch"] += 1
			# Commands still waiting were built on an older view: resend them
			# (same id) so a lost result is recovered, not re-applied.
			for id in _pending:
				_pending[id]["sent_ms"] = -RETRY_MS
		NetProtocol.EVENTS:
			for ev in m["events"]:
				var s: int = ev["seq"]
				if s <= last_seq:
					stats["duplicate_events"] += 1
					continue
				if s != last_seq + 1:
					stats["gaps"] += 1
					net.send_up(link, NetProtocol.encode(NetProtocol.SNAPSHOT_REQ, {}))
					return
				events.append(ev)
				all_events_seen += 1
				last_seq = s
			state_version = m["state_version"]
			public_hash = m["public_hash"]
		NetProtocol.ERROR:
			stats["errors"][m["code"]] = stats["errors"].get(m["code"], 0) + 1
		NetProtocol.RESULT:
			var id: String = m["command_id"]
			_pending.erase(id)
			if not m["ok"]:
				stats["rejections"][m["error"]] = stats["rejections"].get(m["error"], 0) + 1
			state_version = maxi(state_version, m["state_version"])


## Sends intent built from a decided command (type + payload).
func send_command(type: String, payload: Dictionary, match_id: String) -> String:
	_cmd_n += 1
	var id := "%s-c%d" % [player_id, _cmd_n]
	var cmd := ErCommand.make(match_id, player_id, id, state_version, type, payload)
	_pending[id] = {"cmd": cmd, "sent_ms": net.now_ms}
	net.send_up(link, NetProtocol.encode(NetProtocol.COMMAND, {"command": cmd}))
	return id


func has_pending() -> bool:
	return not _pending.is_empty()


func tick(now_ms: int) -> void:
	if not connected:
		return
	for id in _pending:
		var p: Dictionary = _pending[id]
		if now_ms - p["sent_ms"] >= RETRY_MS:
			p["sent_ms"] = now_ms
			stats["resends"] += 1
			net.send_up(link, NetProtocol.encode(NetProtocol.COMMAND, {"command": p["cmd"]}))
