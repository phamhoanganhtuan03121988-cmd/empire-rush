## M3 spike (Phase 2, C3): one player client as its own OS process, over a
## real WebSocket to tools/net/server_main.gd. It never runs rules: it keeps
## the server's snapshot + ordered events (NetClient) and a bot chooses moves
## from that VIEW only (a read-only GameEngine built from the public snapshot).
## Chaos options exercise the protocol: duplicate sends, invalid commands,
## a locally faked state, a voluntary disconnect + reconnect, and automatic
## reconnect with backoff when the server dies.
##   godot --headless --path client --script res://tools/net/client_main.gd -- \
##     --url=ws://127.0.0.1:18765 --dir=OUT (--create=N --code_out=FILE | --join=CODE | --join_file=FILE)
##     [--session=FILE]  (token + room kept here; a restarted process resumes from it)
##     [--tls_ca=CERT --tls_name=localhost]  (wss:// with certificate verification)
##     [--dup_every=7] [--invalid_every=0] [--fake_state_at=0] [--drop_at_s=0 --down_s=0]
##     [--idle_pct=0] [--flood=N]  (send N junk frames at once to trip the rate limit)
## Writes OUT/client_<room>_<seat>.json when the match has ended and it holds the final state.
extends SceneTree


## WebSocket link handed to NetClient (duck-typed like LoopbackNetwork).
class WsLink:
	extends RefCounted
	var ws: WebSocketPeer
	var now_ms := 0
	var sent := 0
	var dropped := 0

	func send_up(_link: int, text: String) -> void:
		if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws.send_text(text)
			sent += 1
		else:
			dropped += 1


var args := {}
var nc: NetClient
var wl := WsLink.new()
var cfg: GameConfig
var bot: BotPlayer
var dir := ""
var url := ""
var t0 := 0
var was_open := false
var next_connect_ms := 0
var backoff_ms := 250
var acted_version := -1
var think_until := 0
var snapshot_asked_for := -1
var sent_cmds := 0
var chaos := {"duplicates": 0, "invalid": 0, "fake_state": 0, "voluntary_drops": 0, "reconnects": 0, "connect_attempts": 0}
var invalid_kinds: Array = []
var drop_done := false
var down_until := 0
var done := false
var ended_seen_ms := -1
var tls: TLSOptions = null
var was_ever_open := false
var fatal := ""
var _session_saved := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() == 2 else "1"
	dir = args.get("dir", "user://net_e2e")
	url = args.get("url", "ws://127.0.0.1:18765")
	Engine.max_fps = 200
	cfg = GameConfig.load_from_dir()
	nc = NetClient.new(args.get("token", ""))
	t0 = Time.get_ticks_msec()
	var saved := _read_session()
	if not saved.is_empty():
		# Process restart: resume the seat with the saved token (Hello).
		nc.token = saved["token"]
		nc.room_code = saved["room_code"]
		chaos["resumed_from_session"] = 1
	elif args.has("create"):
		nc.room_request = {"kind": NetProtocol.CREATE_ROOM, "players": int(args["create"])}
	elif args.has("join"):
		nc.room_request = {"kind": NetProtocol.JOIN_ROOM, "room_code": args["join"]}
	if args.has("tls_ca"):
		var ca := X509Certificate.new()
		if ca.load(args["tls_ca"]) != OK:
			print("[client] TLS_CA_LOAD_FAILED")
			quit(3)
			return
		tls = TLSOptions.client(ca, args.get("tls_name", ""))


func _ms() -> int:
	return Time.get_ticks_msec() - t0


func _connect() -> void:
	chaos["connect_attempts"] += 1
	wl.ws = WebSocketPeer.new()
	wl.ws.inbound_buffer_size = NetProtocol.MAX_FRAME * 4
	wl.ws.connect_to_url(url, tls)


func _process(_delta: float) -> bool:
	var now := _ms()
	wl.now_ms = now
	if fatal != "":
		print("[client] FATAL ", fatal)
		var f := FileAccess.open(dir.path_join("fatal_%d.txt" % OS.get_process_id()), FileAccess.WRITE)
		f.store_string(fatal)
		f.close()
		return true
	if wl.ws == null:
		if nc.token == "" and nc.room_request.is_empty():
			_wait_for_code()  # --join_file: the creator has not written the code yet
			return false
		if now >= next_connect_ms and now >= down_until:
			var cap := int(args.get("max_connect_attempts", "0"))
			if cap > 0 and chaos["connect_attempts"] >= cap and not was_ever_open:
				fatal = "CONNECT_FAILED after %d attempts" % cap
				return false
			_connect()
		return false
	wl.ws.poll()
	match wl.ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not was_open:
				was_open = true
				was_ever_open = true
				backoff_ms = 250
				if nc.seat >= 0:
					chaos["reconnects"] += 1
				nc.on_connected(wl, 0)
			while wl.ws.get_available_packet_count() > 0:
				var text := wl.ws.get_packet().get_string_from_utf8()
				nc.handle_frame(text)
				if text.contains(NetProtocol.E_ROOM_CLOSED) or text.contains(NetProtocol.E_ROOM_NOT_FOUND):
					fatal = text
			if nc.token != "" and not _session_saved:
				_save_session()
			if args.has("flood") and nc.welcomed and not chaos.has("flood_sent"):
				chaos["flood_sent"] = int(args["flood"])
				for i in int(args["flood"]):
					wl.send_up(0, NetProtocol.encode(NetProtocol.SNAPSHOT_REQ, {}))
			_act(now)
			nc.tick(now)
		WebSocketPeer.STATE_CLOSED:
			if was_open:
				nc.on_disconnected()
				was_open = false
			wl.ws = null
			# Reconnect with capped exponential backoff (server restart / loss).
			next_connect_ms = now + backoff_ms
			backoff_ms = mini(backoff_ms * 2, 2000)
	if done:
		return true
	return false


## The client's own view of the match, from server data only.
func _view() -> GameEngine:
	var e := GameEngine.new()
	e.config = cfg
	e.clock = MatchClock.new(0)
	e.state = GameState.from_dict(nc.snapshot)
	return e


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


func _act(now: int) -> void:
	if nc.seat < 0 or nc.snapshot.is_empty():
		return
	var snap_version: int = nc.snapshot["state_version"]
	# The bot decides from a full snapshot; events newer than it trigger a
	# refresh (a production client would project events into its view).
	if snap_version < nc.state_version or not nc.events.is_empty():
		if snapshot_asked_for != nc.state_version:
			snapshot_asked_for = nc.state_version
			wl.send_up(0, NetProtocol.encode(NetProtocol.SNAPSHOT_REQ, {}))
		return
	if nc.snapshot["phase"] == GameState.ENDED:
		if ended_seen_ms < 0:
			ended_seen_ms = now
			_write_result()
		done = true
		return
	_chaos(now)
	if wl.ws == null or nc.has_pending() or acted_version == snap_version:
		return
	var view := _view()
	if not _may_act(view, nc.seat):
		return
	if bot == null:
		bot = BotPlayer.new(nc.seat, nc.player_id, ErRng.new(hash(nc.token)), int(args.get("idle_pct", "0")))
	if think_until == 0:
		think_until = now + 30 + (hash(str(snap_version) + nc.token) & 0x7f)
	if now < think_until:
		return
	think_until = 0
	acted_version = snap_version
	if bot.wants_to_idle():
		return  # let the server timer act for us
	var cmd := bot.decide(view)
	if cmd.is_empty():
		return
	var id := nc.send_command(cmd["type"], cmd["payload"], nc.snapshot["match_id"])
	sent_cmds += 1
	var dup_every := int(args.get("dup_every", "0"))
	if dup_every > 0 and sent_cmds % dup_every == 0:
		chaos["duplicates"] += 1
		wl.send_up(0, NetProtocol.encode(NetProtocol.COMMAND, {"command": nc._pending[id]["cmd"]}))


## Protocol abuse that a hostile or buggy client could send. The server must
## reject all of it without changing state.
func _chaos(now: int) -> void:
	var inv := int(args.get("invalid_every", "0"))
	if inv > 0 and sent_cmds > 0 and sent_cmds % inv == 0 and chaos["invalid"] < sent_cmds / inv:
		chaos["invalid"] += 1
		var v: int = nc.state_version
		var mid: String = nc.snapshot["match_id"]
		var k: int = chaos["invalid"] % 6
		var frame := ""
		match k:
			0: frame = NetProtocol.encode(NetProtocol.COMMAND, {"command": ErCommand.make(mid, "p%d" % ((nc.seat + 1) % 4), "spoof-%d" % chaos["invalid"], v, ErCommand.ROLL_DICE, {})})
			1: frame = NetProtocol.encode(NetProtocol.COMMAND, {"command": ErCommand.make(mid, nc.player_id, "stale-%d" % chaos["invalid"], v - 3, ErCommand.END_TURN, {})})
			2: frame = NetProtocol.encode(NetProtocol.COMMAND, {"command": ErCommand.make(mid, nc.player_id, "bogus-%d" % chaos["invalid"], v, "TeleportToStart", {})})
			3: frame = "x".repeat(NetProtocol.MAX_FRAME + 10)
			4: frame = JSON.stringify({"kind": "Command", "protocol_version": 99})
			5: frame = "{not json"
		invalid_kinds.append(k)
		wl.send_up(0, frame)
	# Fake client state: the client edits its own view (pretends to be rich and
	# to own every property) and acts on it. The server judges by ITS state.
	var fake_at := int(args.get("fake_state_at", "0"))
	if fake_at > 0 and chaos["fake_state"] == 0 and sent_cmds >= fake_at:
		chaos["fake_state"] = 1
		nc.snapshot["players"][nc.seat]["cash"] = 999999
		for pid in nc.snapshot["owner"]:
			nc.snapshot["owner"][pid] = nc.seat
		var pid0: String = cfg.property_ids[0]
		nc.send_command(ErCommand.UPGRADE, {"property_id": pid0}, nc.snapshot["match_id"])
		nc.send_command(ErCommand.BUY_PROPERTY, {"property_id": cfg.property_ids[5]}, nc.snapshot["match_id"])
		# Ask for the truth again; the fake view is overwritten.
		wl.send_up(0, NetProtocol.encode(NetProtocol.SNAPSHOT_REQ, {}))
	# Voluntary disconnect (app killed / network change), then reconnect.
	var drop_at := float(args.get("drop_at_s", "0"))
	if drop_at > 0.0 and not drop_done and now >= int(drop_at * 1000):
		drop_done = true
		chaos["voluntary_drops"] += 1
		down_until = now + int(float(args.get("down_s", "5")) * 1000)
		wl.ws.close()


func _wait_for_code() -> void:
	var path: String = args.get("join_file", "")
	if path != "" and FileAccess.file_exists(path):
		var code := FileAccess.get_file_as_string(path).strip_edges()
		if code != "":
			nc.room_request = {"kind": NetProtocol.JOIN_ROOM, "room_code": code}


func _read_session() -> Dictionary:
	var path: String = args.get("session", "")
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary and v.has("token") else {}


## The token is a secret: it stays in the client's own session file (test
## output dir here, app storage on a phone) and is never logged.
func _save_session() -> void:
	_session_saved = true
	if args.has("code_out") and args.has("create"):
		var c := FileAccess.open(args["code_out"], FileAccess.WRITE)
		c.store_string(nc.room_code)
		c.close()
	var path: String = args.get("session", "")
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"token": nc.token, "room_code": nc.room_code, "seat": nc.seat}))
		f.close()


func _write_result() -> void:
	var f := FileAccess.open(dir.path_join("client_%s_%d.json" % [nc.room_code, nc.seat]), FileAccess.WRITE)
	f.store_string(JSON.stringify({"room_code": nc.room_code, "seat": nc.seat, "public_hash": nc.public_hash,
		"snapshot_hash": NetProtocol.public_hash(nc.snapshot), "state_version": nc.state_version,
		"last_seq": nc.last_seq, "stats": nc.stats, "chaos": chaos, "invalid_kinds": invalid_kinds,
		"frames_sent": wl.sent, "frames_dropped_local": wl.dropped, "commands_sent": sent_cmds}, "  "))
	f.close()
	print("[client %s/%d] DONE version=%d hash=%s" % [nc.room_code, nc.seat, nc.state_version, nc.public_hash.left(12)])
