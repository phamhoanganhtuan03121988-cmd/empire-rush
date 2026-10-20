## M3 (Phase 3): authoritative room server as its own OS process.
## Godot headless + TCPServer + WebSocketPeer (RFC 6455), optional TLS
## (wss://) with a key/certificate given on the command line - never stored
## in the repository. Hosts many private rooms (RoomServer); every room
## writes its accepted inputs to its own append-only journal BEFORE any frame
## leaves, and with --resume the server rebuilds every unfinished room from
## its meta + journal after a crash (kill -9).
##   godot --headless --path client --script res://tools/net/server_main.gd -- \
##     --dir=OUT [--bind=127.0.0.1] [--port=18765] [--time_scale=1] [--resume]
##     [--hold_ms=60000] [--policy=bot|timers] [--tls_key=K.key --tls_cert=C.crt]
##     [--exit_after_rooms=N]   (tests: stop once N rooms have ended)
##     [--max_rooms=64] [--rate=20] [--burst=40] [--linger_ms=30000]
## Layout: OUT/rooms/<CODE>/{meta.json,journal.jsonl,result.json}, OUT/server_meta.json.
## Log lines never contain tokens (only room codes and link ids).
extends SceneTree

var args := {}
var rs: RoomServer
var tcp := TCPServer.new()
var tls_options: TLSOptions = null
var peers: Dictionary = {}       # link -> {ws, tls?, handshake}
var next_link := 1
var dir := ""
var journals: Dictionary = {}    # room code -> FileAccess
var restarts := 0
var t0 := 0
var _ended_rooms: Dictionary = {}
var _saved_ms := 0
var _saved_guard := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() == 2 else "1"
	dir = args.get("dir", "user://net_server")
	DirAccess.make_dir_recursive_absolute(dir.path_join("rooms"))
	Engine.max_fps = 200
	t0 = Time.get_ticks_msec()
	rs = RoomServer.new(GameConfig.load_from_dir())
	rs.time_scale = float(args.get("time_scale", "1"))
	rs.policy_dict = {"hold_ms": int(args.get("hold_ms", "60000")), "on_expiry": args.get("policy", DisconnectPolicy.BOT)}
	rs.max_rooms = int(args.get("max_rooms", "64"))
	rs.rate_per_s = float(args.get("rate", "20"))
	rs.burst = float(args.get("burst", "40"))
	rs.linger_ms = int(args.get("linger_ms", "30000"))
	if args.has("tls_key"):
		var key := CryptoKey.new()
		var cert := X509Certificate.new()
		if key.load(args["tls_key"]) != OK or cert.load(args["tls_cert"]) != OK:
			_log("TLS_LOAD_FAILED")
			quit(3)
			return
		tls_options = TLSOptions.server(key, cert)
	var meta := _read_json(dir.path_join("server_meta.json"))
	if args.has("resume"):
		restarts = int(meta.get("restarts", 0)) + 1
		_add_stats(rs.stats, meta.get("stats", {}))
		_resume_rooms()
	_write_json(dir.path_join("server_meta.json"), {"restarts": restarts, "pid": OS.get_process_id(), "tls": tls_options != null})
	var bind: String = args.get("bind", "127.0.0.1")
	var port := int(args.get("port", "18765"))
	var err := tcp.listen(port, bind)
	if err != OK:
		_log("LISTEN_FAILED %d" % err)
		quit(2)
		return
	_log("LISTENING bind=%s port=%d tls=%s time_scale=%.1f policy=%s rooms_restored=%d" % [bind, port,
		tls_options != null, rs.time_scale, str(rs.policy_dict), rs.rooms.size()])


func _now() -> int:
	return Time.get_ticks_msec() - t0


func _resume_rooms() -> void:
	var base := dir.path_join("rooms")
	for code in DirAccess.get_directories_at(base):
		var rdir := base.path_join(code)
		if FileAccess.file_exists(rdir.path_join("result.json")):
			continue  # finished before the crash
		var meta := _read_json(rdir.path_join("meta.json"))
		if meta.is_empty():
			continue  # crashed while the room was still waiting for players
		var entries: Array = []
		for line in FileAccess.get_file_as_string(rdir.path_join("journal.jsonl")).split("\n", false):
			var e: Variant = JSON.parse_string(line)
			if e is Dictionary:  # a torn last line from the crash is skipped
				entries.append(e)
		rs.restore_room(meta, entries, restarts, _now())
		# Counters survive the restart (saved about once per second; the last
		# second before a crash can be missing from them, never from the journal).
		_add_stats(rs.rooms[code]["host"].stats, _read_json(rdir.path_join("stats.json")))
		var f := FileAccess.open(rdir.path_join("journal.jsonl"), FileAccess.WRITE)  # drop a torn line
		for entry in rs.rooms[code]["host"].engine.input_log:
			f.store_line(JSON.stringify(entry))
		f.flush()
		journals[code] = f
		_log("RESUMED room=%s entries=%d state_version=%d" % [code, entries.size(), rs.rooms[code]["host"].engine.state.state_version])


func _process(_delta: float) -> bool:
	var now := _now()
	while tcp.is_connection_available():
		var conn := tcp.take_connection()
		var link := next_link
		next_link += 1
		if not rs.link_opened(link, now):
			conn.disconnect_from_host()
			continue
		var ws := WebSocketPeer.new()
		ws.inbound_buffer_size = NetProtocol.MAX_FRAME * 2  # bigger frames are cut by the socket
		ws.max_queued_packets = 64
		if tls_options != null:
			var tls := StreamPeerTLS.new()
			tls.accept_stream(conn, tls_options)
			peers[link] = {"ws": ws, "tls": tls, "handshake": true}
		else:
			ws.accept_stream(conn)
			peers[link] = {"ws": ws, "handshake": false}
	var out: Array = []
	for link in peers.keys():
		var p: Dictionary = peers[link]
		if p["handshake"]:
			var tls: StreamPeerTLS = p["tls"]
			tls.poll()
			match tls.get_status():
				StreamPeerTLS.STATUS_CONNECTED:
					p["ws"].accept_stream(tls)
					p["handshake"] = false
				StreamPeerTLS.STATUS_HANDSHAKING:
					continue
				_:
					_drop(link, "TLS_FAILED")
					continue
		var ws: WebSocketPeer = p["ws"]
		ws.poll()
		match ws.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				while ws.get_available_packet_count() > 0:
					out.append_array(rs.handle_frame(link, ws.get_packet().get_string_from_utf8(), now))
			WebSocketPeer.STATE_CLOSED:
				_drop(link, "CLOSED")
	out.append_array(rs.tick(now))
	_persist()
	for o in out:
		var p: Dictionary = peers.get(o[0], {})
		if not p.is_empty() and not p["handshake"] and p["ws"].get_ready_state() == WebSocketPeer.STATE_OPEN:
			p["ws"].send_text(o[1])
	for link in rs.to_close:
		if peers.has(link):
			peers[link]["ws"].close(1008, "policy")
	rs.to_close.clear()
	var exiting: bool = args.has("exit_after_rooms") and _ended_rooms.size() >= int(args["exit_after_rooms"]) and rs.rooms.is_empty()
	# Abuse counters are written at once: a crash (the chaos test SIGKILLs the
	# server) inside the 1 s save window must not lose them.
	var guard := "%d/%d/%d" % [rs.stats["rate_limited"], rs.stats["rate_closed"], rs.stats["frame_errors"].size()]
	if now - _saved_ms > 1000 or exiting or guard != _saved_guard:
		_saved_ms = now
		_saved_guard = guard
		_write_json(dir.path_join("server_meta.json"), {"restarts": restarts, "pid": OS.get_process_id(),
			"tls": tls_options != null, "stats": rs.stats, "links": rs.link_count(), "rooms": rs.rooms.size(),
			"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
			"static_mem_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1)})
		for code in journals:
			_write_json(dir.path_join("rooms").path_join(code).path_join("stats.json"), rs.rooms[code]["host"].stats)
	if exiting:
		_log("EXIT all %d rooms ended and removed; objects=%d static_mem_mb=%.1f" % [_ended_rooms.size(),
			Performance.get_monitor(Performance.OBJECT_COUNT), OS.get_static_memory_usage() / 1048576.0])
		tcp.stop()
		return true
	return false


## Write-ahead: meta when a room starts, journal lines before frames leave,
## result once a room ends.
func _persist() -> void:
	for code in rs.rooms:
		var room: Dictionary = rs.rooms[code]
		# Ended rooms closed their journal; never reopen it (WRITE would truncate it).
		if room["state"] != RoomServer.WAITING and not journals.has(code) and not _ended_rooms.has(code):
			var rdir := dir.path_join("rooms").path_join(code)
			DirAccess.make_dir_recursive_absolute(rdir)
			_write_json(rdir.path_join("meta.json"), rs.room_meta(code))
			journals[code] = FileAccess.open(rdir.path_join("journal.jsonl"), FileAccess.WRITE)
			_log("ROOM_STARTED room=%s players=%d" % [code, room["players"]])
	var j := rs.take_journals()
	for code in j:
		for entry in j[code]:
			journals[code].store_line(JSON.stringify(entry))
		journals[code].flush()
	for code in rs.rooms:
		var room: Dictionary = rs.rooms[code]
		if room["state"] == RoomServer.ENDED and not _ended_rooms.has(code):
			_ended_rooms[code] = true
			var host: MatchHost = room["host"]
			_write_json(dir.path_join("rooms").path_join(code).path_join("result.json"), {
				"code": code, "state_hash": host.engine.state.state_hash(), "public_hash": host.public_hash(),
				"state_version": host.engine.state.state_version, "end_reason": host.engine.state.end_reason,
				"rounds": host.engine.state.round, "server_ms": host.clock.now_ms(), "restarts": restarts,
				"stats": host.stats, "results": host.engine.state.results})
			journals[code].close()
			journals.erase(code)
			_log("ROOM_ENDED room=%s reason=%s state_version=%d" % [code, host.engine.state.end_reason, host.engine.state.state_version])


func _drop(link: int, why: String) -> void:
	rs.link_closed(link)
	peers.erase(link)
	_log("LINK_%s %d" % [why, link])


func _log(s: String) -> void:
	print("[server %d ms] %s" % [_now(), s])


static func _add_stats(into: Dictionary, prev: Dictionary) -> void:
	for k in prev:
		if prev[k] is Dictionary:
			var d: Dictionary = into.get(k, {})
			for kk in prev[k]:
				d[kk] = int(d.get(kk, 0)) + int(prev[k][kk])
			into[k] = d
		elif into.has(k):
			into[k] = int(into[k]) + int(prev[k])


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


static func _write_json(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "  "))
	f.close()
