## M3 spike (Phase 2, C3): checks a finished multi-process run.
##  - every client's final state hash equals the server's (convergence);
##  - replaying the server journal twice in fresh engines gives the server's
##    exact final state (determinism; duplicates had no second effect);
##  - invariants hold; the chaos that was requested really happened.
##   godot --headless --path client --script res://tools/net/verify_e2e.gd -- --dir=OUT [--players=4] [--seed=404] [--expect_restart=1]
## Exit code 0 = pass. Writes OUT/verify.json.
extends SceneTree

var args := {}
var failures: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() == 2 else "1"
	var dir: String = args.get("dir", "")
	var n := int(args.get("players", "4"))
	var seed_value := int(args.get("seed", "404"))
	var server := _read(dir.path_join("server_result.json"))
	_check(not server.is_empty(), "server_result.json exists")
	var seats: Array = []
	for i in n:
		seats.append({"player_id": "p%d" % i, "character_id": ["TYCOON", "INVESTOR", "NEGOTIATOR", "TYCOON"][i]})
	var entries: Array = []
	for line in FileAccess.get_file_as_string(dir.path_join("journal.jsonl")).split("\n", false):
		entries.append(NetProtocol._ints(JSON.parse_string(line)))
	var hashes: Array = []
	var replay: GameEngine
	for run in 2:
		replay = GameEngine.create(GameConfig.load_from_dir(), MatchClock.new(0), seats, seed_value, "m3-%d" % seed_value)
		for e in entries:
			replay.clock.set_now(e["at"])
			if e.has("cmd"):
				var r := replay.submit(e["cmd"])
				_check(r["ok"] and not r.get("duplicate", false), "journal command applies once: %s" % e["cmd"].get("command_id", "?"))
			else:
				replay.advance()
		hashes.append(replay.state.state_hash())
	_check(hashes[0] == hashes[1], "replay is deterministic")
	_check(hashes[0] == server.get("state_hash", ""), "journal replay = server final state")
	_check(replay.is_ended(), "replayed match ended (%s)" % replay.state.end_reason)
	_check(Invariants.check(replay).is_empty(), "invariants: %s" % str(Invariants.check(replay)))
	var ids := {}
	for e in entries:
		if e.has("cmd"):
			var key := "%s|%s" % [e["cmd"]["player_id"], e["cmd"]["command_id"]]
			_check(not ids.has(key), "command applied at most once: " + key)
			ids[key] = true
	var clients: Array = []
	for i in n:
		var c := _read(dir.path_join("client_%d.json" % i))
		_check(not c.is_empty(), "client_%d.json exists" % i)
		if c.is_empty():
			continue
		clients.append(c)
		_check(c["public_hash"] == server["public_hash"], "client %d converged on the server state" % i)
		_check(c["snapshot_hash"] == server["public_hash"], "client %d snapshot matches its hash" % i)
		_check(c["state_version"] == server["state_version"], "client %d state_version" % i)
		_check(c["stats"]["hash_mismatch"] == 0, "client %d: no snapshot hash mismatch" % i)
	var st: Dictionary = server.get("stats", {})
	var chaos := {}
	for c in clients:
		for k in c["chaos"]:
			chaos[k] = chaos.get(k, 0) + c["chaos"][k]
	if chaos.get("duplicates", 0) > 0:
		_check(st.get("duplicates", 0) > 0, "duplicate commands reached the server and were deduplicated")
	if chaos.get("invalid", 0) > 0:
		_check(not (st.get("rejected", {}) as Dictionary).is_empty(), "invalid commands were rejected: %s" % str(st.get("rejected")))
	if args.has("expect_restart"):
		_check(int(server.get("restarts", 0)) >= 1, "server was restarted from its journal")
		_check(chaos.get("reconnects", 0) >= n, "every client reconnected after the restart (%d)" % chaos.get("reconnects", 0))
	if args.has("expect_takeover"):
		_check(st.get("bot_takeovers", 0) >= 1, "server bot took over the disconnected seat")
		_check(st.get("bot_commands", 0) >= 1, "server bot made moves")
		_check(st.get("seat_reclaims", 0) >= 1, "the player reclaimed the seat on reconnect")
	if chaos.get("invalid", 0) > 0:
		_check(not (st.get("frame_errors", {}) as Dictionary).is_empty(), "malformed frames were refused: %s" % str(st.get("frame_errors")))
	var summary := {"pass": failures.is_empty(), "failures": failures, "journal_entries": entries.size(),
		"commands_applied": ids.size(), "server": {"end_reason": server.get("end_reason"), "state_version": server.get("state_version"),
		"rounds": server.get("rounds"), "server_ms": server.get("server_ms"), "restarts": server.get("restarts"), "stats": st,
		"policy": server.get("policy")}, "client_chaos_total": chaos,
		"client_stats": clients.map(func(c: Dictionary) -> Dictionary: return {"seat": c["seat"], "stats": c["stats"], "chaos": c["chaos"], "commands_sent": c["commands_sent"]})}
	var f := FileAccess.open(dir.path_join("verify.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(summary, "  "))
	f.close()
	print("NET_E2E %s failures=%d entries=%d applied=%d server=%s chaos=%s" % ["PASS" if failures.is_empty() else "FAIL",
		failures.size(), entries.size(), ids.size(), JSON.stringify(st), JSON.stringify(chaos)])
	for x in failures:
		print("  FAIL: ", x)
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return NetProtocol._ints(v) if v is Dictionary else {}
