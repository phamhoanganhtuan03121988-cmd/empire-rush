## M3 (Phase 3, B2/B3): many private rooms in one server process.
## Transport-agnostic like MatchHost: frames in per link id, frames out as
## [link_id, text]; the transport also closes the links listed in `to_close`.
##
## Lifecycle of a room: WAITING (players join with the room code) ->
## PLAYING (one MatchHost with its own engine, clock and journal) -> ENDED
## (kept `linger_ms` so clients can fetch the final snapshot, then removed).
## Rooms share nothing but this dispatcher, so one match cannot see or change
## another (isolation is tested by replaying each room's journal alone).
##
## Hardening (PROTOCOL.md §11):
##  - frames are size/version checked before parsing (NetProtocol.decode);
##  - per-link token bucket rate limit; a link that keeps flooding is closed;
##  - a link must create, join or resume within `handshake_ms`;
##  - session tokens are random 128-bit values, stored only as SHA-256;
##  - identity always comes from the session, never from the payload;
##  - limits on rooms and links protect memory.
class_name RoomServer
extends RefCounted

const WAITING := "waiting"
const PLAYING := "playing"
const ENDED := "ended"
const CODE_ALPHABET := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"  # no 0/O, 1/I/L
const CHARACTERS := ["TYCOON", "INVESTOR", "NEGOTIATOR", "TYCOON"]

var config: GameConfig
var policy_dict: Dictionary = {}
## Server clock speed: 1.0 in production, > 1 only in accelerated tests.
var time_scale := 1.0
var max_rooms := 64
var max_links := 512
var handshake_ms := 10000
var linger_ms := 30000
## Token bucket per link: `rate_per_s` frames/s refill, `burst` capacity.
var rate_per_s := 20.0
var burst := 40.0
## Closed after this many rate-limit violations.
var max_violations := 50
## Callables so tests can make codes, tokens and seeds deterministic.
var random_hex := func(n_bytes: int) -> String: return Crypto.new().generate_random_bytes(n_bytes).hex_encode()

var rooms: Dictionary = {}        # code -> room Dictionary
var to_close: Array = []
var stats := {"rooms_created": 0, "rooms_started": 0, "rooms_ended": 0, "rooms_removed": 0,
	"rate_limited": 0, "rate_closed": 0, "handshake_timeouts": 0, "links_refused": 0, "frame_errors": {}}
var _links: Dictionary = {}       # link -> {opened_ms, room, tokens, last_ms, violations}
var _token_room: Dictionary = {}  # token hash -> room code
var _out: Array = []
var _now := 0                     # server wall time (ms) of the last call


func _init(p_config: GameConfig) -> void:
	config = p_config


# --- transport hooks ---------------------------------------------------------------

## Returns false when the server is at its link limit (transport closes it).
func link_opened(link: int, now_ms: int) -> bool:
	_now = now_ms
	if _links.size() >= max_links:
		stats["links_refused"] += 1
		return false
	_links[link] = {"opened_ms": now_ms, "room": "", "tokens": burst, "last_ms": now_ms, "violations": 0}
	return true


func link_closed(link: int) -> void:
	var l: Dictionary = _links.get(link, {})
	_links.erase(link)
	var room: Dictionary = rooms.get(l.get("room", ""), {})
	if room.has("host") and room["host"] != null:
		room["host"].disconnect_link(link)


## One inbound frame. Returns outbound frames [[link, text], ...].
func handle_frame(link: int, text: String, now_ms: int) -> Array:
	_now = now_ms
	var l: Dictionary = _links.get(link, {})
	if l.is_empty():
		return []
	if not _take_token(l):
		stats["rate_limited"] += 1
		l["violations"] += 1
		if l["violations"] >= max_violations:
			stats["rate_closed"] += 1
			to_close.append(link)
		# One error per burst is enough; the frame itself is dropped unread.
		if l["violations"] % 10 == 1:
			_send(link, NetProtocol.ERROR, {"code": NetProtocol.E_RATE_LIMITED})
		return _flush()
	var dec := NetProtocol.decode(text)
	if not dec["ok"]:
		stats["frame_errors"][dec["error"]] = stats["frame_errors"].get(dec["error"], 0) + 1
		_send(link, NetProtocol.ERROR, {"code": dec["error"]})
		return _flush()
	var msg: Dictionary = dec["msg"]
	match msg["kind"]:
		NetProtocol.CREATE_ROOM:
			_create_room(link, l, msg)
		NetProtocol.JOIN_ROOM:
			_join_room(link, l, msg)
		NetProtocol.HELLO:
			var code: String = _token_room.get(NetProtocol.token_hash(str(msg.get("token", ""))), "")
			var room: Dictionary = rooms.get(code, {})
			if room.is_empty():
				_send(link, NetProtocol.ERROR, {"code": NetProtocol.E_UNAUTHENTICATED})
			elif room["state"] == WAITING:
				l["room"] = code
				_send_room_state(room)
			else:
				l["room"] = code
				_route(room, link, text)
		_:
			var room: Dictionary = rooms.get(l["room"], {})
			if room.is_empty() or room["state"] == WAITING:
				_send(link, NetProtocol.ERROR, {"code": NetProtocol.E_UNAUTHENTICATED})
			else:
				_route(room, link, text)
	return _flush()


## Server timers for every playing room, handshake timeouts, room cleanup.
func tick(now_ms: int) -> Array:
	_now = now_ms
	for link in _links.keys():
		var l: Dictionary = _links[link]
		if l["room"] == "" and now_ms - l["opened_ms"] > handshake_ms:
			stats["handshake_timeouts"] += 1
			_send(link, NetProtocol.ERROR, {"code": NetProtocol.E_HANDSHAKE_TIMEOUT})
			to_close.append(link)
			l["room"] = "-"  # report once
	for code in rooms.keys():
		var room: Dictionary = rooms[code]
		if room["state"] == PLAYING:
			_absorb(room, room["host"].tick(room_clock(room, now_ms)))
			if room["host"].engine.is_ended():
				room["state"] = ENDED
				room["ended_ms"] = now_ms
				stats["rooms_ended"] += 1
		elif room["state"] == ENDED and now_ms - room["ended_ms"] > linger_ms:
			_remove_room(code)
	return _flush()


func room_clock(room: Dictionary, now_ms: int) -> int:
	return room["clock_base"] + int((now_ms - room["started_ms"]) * time_scale)


# --- rooms ----------------------------------------------------------------------------

func _create_room(link: int, l: Dictionary, msg: Dictionary) -> void:
	var n := int(msg.get("players", 0))
	if n < 2 or n > 4:
		_send(link, NetProtocol.ERROR, {"code": NetProtocol.E_BAD_REQUEST})
		return
	if rooms.size() >= max_rooms:
		_send(link, NetProtocol.ERROR, {"code": NetProtocol.E_SERVER_FULL})
		return
	var code := _new_code()
	var room := {"code": code, "players": n, "state": WAITING, "seats": [], "token_hashes": [], "host": null,
		"seed": 0, "clock_base": 0, "started_ms": 0, "ended_ms": 0, "epoch": 0, "created_ms": _now}
	rooms[code] = room
	stats["rooms_created"] += 1
	_seat(link, l, room, msg)


func _join_room(link: int, l: Dictionary, msg: Dictionary) -> void:
	var room: Dictionary = rooms.get(str(msg.get("room_code", "")).to_upper(), {})
	if room.is_empty():
		_send(link, NetProtocol.ERROR, {"code": NetProtocol.E_ROOM_NOT_FOUND})
	elif room["state"] != WAITING:
		_send(link, NetProtocol.ERROR, {"code": NetProtocol.E_ROOM_FULL})
	else:
		_seat(link, l, room, msg)


func _seat(link: int, l: Dictionary, room: Dictionary, msg: Dictionary) -> void:
	var seat: int = room["seats"].size()
	var ch := str(msg.get("character_id", ""))
	if not config.character_by_id.has(ch):
		ch = CHARACTERS[seat]  # unknown or missing: server default, never trusted
	var token: String = random_hex.call(16)
	var th := NetProtocol.token_hash(token)
	room["seats"].append({"player_id": "p%d" % seat, "character_id": ch})
	room["token_hashes"].append(th)
	_token_room[th] = room["code"]
	l["room"] = room["code"]
	# The plain token is sent once, to this link only, and never stored.
	_send(link, NetProtocol.ROOM_JOINED, {"room_code": room["code"], "token": token, "seat": seat,
		"player_id": "p%d" % seat, "players": room["players"], "joined": room["seats"].size()})
	if room["seats"].size() == room["players"]:
		_start(room, int(random_hex.call(4).hex_to_int() & 0x7fffffff))
	else:
		_send_room_state(room)


func _start(room: Dictionary, seed_value: int) -> void:
	room["seed"] = seed_value
	room["started_ms"] = _now
	var host := MatchHost.new()
	host.policy = DisconnectPolicy.from_dict(policy_dict)
	host.start(config, room["seats"], seed_value, room["token_hashes"], true, "room-" + room["code"])
	room["host"] = host
	room["state"] = PLAYING
	stats["rooms_started"] += 1
	# Clients answer RoomState{started} with Hello and get Welcome + Snapshot,
	# the same path as a reconnect.
	_send_room_state(room)


## Rebuilds a room after a server restart from its saved meta + journal.
func restore_room(meta: Dictionary, journal: Array, epoch: int, now_ms: int) -> void:
	_now = now_ms
	var room := {"code": meta["code"], "players": int(meta["players"]), "state": PLAYING, "seats": meta["seats"],
		"token_hashes": meta["token_hashes"], "host": null, "seed": int(meta["seed"]), "clock_base": 0,
		"started_ms": _now, "ended_ms": 0, "epoch": epoch, "created_ms": _now}
	var host := MatchHost.new()
	host.policy = DisconnectPolicy.from_dict(meta.get("policy", policy_dict))
	host.restore(config, room["seats"], room["seed"], room["token_hashes"], journal, epoch, true, "room-" + room["code"])
	room["host"] = host
	room["clock_base"] = host.clock.now_ms()  # downtime does not count as match time
	if host.engine.is_ended():
		room["state"] = ENDED
		room["ended_ms"] = _now
	rooms[room["code"]] = room
	for th in room["token_hashes"]:
		_token_room[th] = room["code"]


## Everything a restart needs except the journal. No plain tokens.
func room_meta(code: String) -> Dictionary:
	var r: Dictionary = rooms[code]
	return {"code": code, "players": r["players"], "seats": r["seats"], "token_hashes": r["token_hashes"],
		"seed": r["seed"], "policy": policy_dict, "format": 1}


func _remove_room(code: String) -> void:
	var room: Dictionary = rooms[code]
	for th in room["token_hashes"]:
		_token_room.erase(th)
	for link in _links:
		if _links[link]["room"] == code:
			_send(link, NetProtocol.ERROR, {"code": NetProtocol.E_ROOM_CLOSED})
			to_close.append(link)
	room["host"] = null
	rooms.erase(code)
	stats["rooms_removed"] += 1


func _route(room: Dictionary, link: int, text: String) -> void:
	_absorb(room, room["host"].handle_frame(link, text))


func _absorb(room: Dictionary, frames: Array) -> void:
	_out.append_array(frames)
	var host: MatchHost = room["host"]
	if not host.to_close.is_empty():
		for link in host.to_close:
			if _links.has(link):
				_links[link]["room"] = "-"
			to_close.append(link)
		host.to_close.clear()


func _send_room_state(room: Dictionary) -> void:
	for link in _links:
		if _links[link]["room"] == room["code"]:
			_send(link, NetProtocol.ROOM_STATE, {"room_code": room["code"], "players": room["players"],
				"joined": room["seats"].size(), "started": room["state"] != WAITING})


func _new_code() -> String:
	for attempt in 100:
		var hex: String = random_hex.call(6)
		var code := ""
		for i in 6:
			code += CODE_ALPHABET[hex.substr(i * 2, 2).hex_to_int() % CODE_ALPHABET.length()]
		if not rooms.has(code):
			return code
	assert(false, "could not allocate a room code")
	return ""


func _take_token(l: Dictionary) -> bool:
	var dt := maxf(0.0, (_now - l["last_ms"]) / 1000.0)
	l["last_ms"] = _now
	l["tokens"] = minf(burst, l["tokens"] + dt * rate_per_s)
	if l["tokens"] < 1.0:
		return false
	l["tokens"] -= 1.0
	return true


func _send(link: int, kind: String, body: Dictionary) -> void:
	_out.append([link, NetProtocol.encode(kind, body)])


func _flush() -> Array:
	var o := _out
	_out = []
	return o


## Accepted inputs not yet persisted, per room: {code: [entries]}.
func take_journals() -> Dictionary:
	var out := {}
	for code in rooms:
		var host: MatchHost = rooms[code]["host"]
		if host != null:
			var e := host.take_journal()
			if not e.is_empty():
				out[code] = e
	return out


func link_count() -> int:
	return _links.size()
