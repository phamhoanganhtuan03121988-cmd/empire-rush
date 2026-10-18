## M3 spike (Phase 2, C3): authoritative match server as its own OS process.
## Godot headless + TCPServer + WebSocketPeer (RFC 6455 over TCP, plain ws://
## on 127.0.0.1 for the test; production would terminate TLS in front of it).
## Runs one MatchHost, writes every accepted input to an append-only journal
## BEFORE sending any frame, and with --resume rebuilds the match from that
## journal after a crash (kill -9) and continues on the same port.
##   godot --headless --path client --script res://tools/net/server_main.gd -- \
##     --port=18765 --dir=OUT [--players=4] [--seed=404] [--time_scale=10] [--resume]
##     [--hold_ms=20000] [--policy=bot|timers]
## Writes OUT/journal.jsonl, OUT/server_result.json, OUT/server.log lines on stdout.
extends SceneTree

const CHARACTERS := ["TYCOON", "INVESTOR", "NEGOTIATOR", "TYCOON"]

var args := {}
var host: MatchHost
var tcp := TCPServer.new()
var peers: Dictionary = {}       # link id -> WebSocketPeer
var next_link := 1
var dir := ""
var journal: FileAccess
var time_scale := 10.0
var clock_base := 0
var t0 := 0
var ended_at := -1
var restarts := 0
var _meta_saved_ms := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() == 2 else "1"
	dir = args.get("dir", "user://net_e2e")
	DirAccess.make_dir_recursive_absolute(dir)
	time_scale = float(args.get("time_scale", "10"))
	Engine.max_fps = 200
	var n := int(args.get("players", "4"))
	var seed_value := int(args.get("seed", "404"))
	var seats: Array = []
	var tokens: Array = []
	for i in n:
		seats.append({"player_id": "p%d" % i, "character_id": CHARACTERS[i]})
		tokens.append("tok-%d-%d" % [seed_value, i])
	var cfg := GameConfig.load_from_dir()
	host = MatchHost.new()
	host.policy = DisconnectPolicy.from_dict({"hold_ms": int(args.get("hold_ms", "20000")),
		"on_expiry": args.get("policy", DisconnectPolicy.BOT)})
	var jpath := dir.path_join("journal.jsonl")
	if args.has("resume") and FileAccess.file_exists(jpath):
		var entries: Array = []
		for line in FileAccess.get_file_as_string(jpath).split("\n", false):
			var e: Variant = JSON.parse_string(line)
			if e is Dictionary:  # a torn last line from the crash is skipped
				entries.append(e)
		var meta := _read_json(dir.path_join("server_meta.json"))
		restarts = int(meta.get("restarts", 0)) + 1
		host.restore(cfg, seats, seed_value, tokens, entries, restarts)
		# Counters survive the restart (saved about once per second; the last
		# second before a crash can be missing from them, never from the journal).
		_add_stats(host.stats, meta.get("stats", {}))
		clock_base = host.clock.now_ms()
		_log("RESUMED entries=%d state_version=%d hash=%s" % [entries.size(), host.engine.state.state_version, host.engine.state.state_hash().left(12)])
	else:
		host.start(cfg, seats, seed_value, tokens)
	_write_json(dir.path_join("server_meta.json"), {"restarts": restarts, "pid": OS.get_process_id()})
	# Rewrite the journal from the replayed inputs: drops a torn last line.
	journal = FileAccess.open(jpath, FileAccess.WRITE)
	for entry in host.engine.input_log:
		journal.store_line(JSON.stringify(entry))
	journal.flush()
	var port := int(args.get("port", "18765"))
	var err := tcp.listen(port, "127.0.0.1")
	if err != OK:
		_log("LISTEN_FAILED %d" % err)
		quit(2)
		return
	t0 = Time.get_ticks_msec()
	_log("LISTENING port=%d players=%d seed=%d time_scale=%.1f policy=%s" % [port, n, seed_value, time_scale, str(host.policy.to_dict())])


func _now() -> int:
	return clock_base + int((Time.get_ticks_msec() - t0) * time_scale)


func _process(_delta: float) -> bool:
	while tcp.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.inbound_buffer_size = NetProtocol.MAX_FRAME * 2
		ws.accept_stream(tcp.take_connection())
		peers[next_link] = ws
		next_link += 1
	var out: Array = []
	for link in peers.keys():
		var ws: WebSocketPeer = peers[link]
		ws.poll()
		match ws.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				while ws.get_available_packet_count() > 0:
					out.append_array(host.handle_frame(link, ws.get_packet().get_string_from_utf8()))
			WebSocketPeer.STATE_CLOSED:
				host.disconnect_link(link)
				peers.erase(link)
				_log("LINK_CLOSED %d" % link)
	out.append_array(host.tick(_now()))
	# Write-ahead: persist accepted inputs before any result/event leaves.
	for entry in host.take_journal():
		journal.store_line(JSON.stringify(entry))
	journal.flush()
	for o in out:
		var ws: WebSocketPeer = peers.get(o[0])
		if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws.send_text(o[1])
	if Time.get_ticks_msec() - _meta_saved_ms > 1000:
		_meta_saved_ms = Time.get_ticks_msec()
		_write_json(dir.path_join("server_meta.json"), {"restarts": restarts, "pid": OS.get_process_id(), "stats": host.stats})
	if host.engine.is_ended():
		if ended_at < 0:
			ended_at = Time.get_ticks_msec()
			_log("MATCH_ENDED reason=%s state_version=%d" % [host.engine.state.end_reason, host.engine.state.state_version])
		# Let clients fetch the final snapshot, then stop.
		if Time.get_ticks_msec() - ended_at > 4000 or (peers.is_empty() and Time.get_ticks_msec() - ended_at > 500):
			_finish()
			return true
	return false


func _finish() -> void:
	_write_json(dir.path_join("server_result.json"), {
		"state_hash": host.engine.state.state_hash(), "public_hash": host.public_hash(),
		"state_version": host.engine.state.state_version, "end_reason": host.engine.state.end_reason,
		"rounds": host.engine.state.round, "server_ms": host.clock.now_ms(), "restarts": restarts,
		"stats": host.stats, "policy": host.policy.to_dict(), "results": host.engine.state.results,
		"static_mem_peak_mb": snappedf(OS.get_static_memory_peak_usage() / 1048576.0, 0.1),
	})
	journal.close()
	tcp.stop()
	_log("FINISHED")


func _log(s: String) -> void:
	print("[server %d ms] %s" % [_now() if t0 > 0 else 0, s])


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
