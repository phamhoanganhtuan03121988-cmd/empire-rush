## M3 (Phase 3): checks a finished multi-process run of tools/net/server_main.gd.
## For EVERY room in OUT/rooms:
##  - replaying its journal twice, from its meta (seats, seed) alone, gives the
##    server's final state hash (determinism; rooms are isolated: nothing
##    from another room is needed to rebuild it);
##  - no command id was applied twice; invariants hold; the match ended;
##  - every client of the room ends on the server's public hash.
## Then the chaos that was asked for really happened (flags below).
##   godot --headless --path client --script res://tools/net/verify_e2e.gd -- --dir=OUT
##     [--rooms=N] [--expect_restart=1] [--expect_takeover=1] [--expect_rate_limit=1]
##     [--expect_resume=1] [--expect_duplicates=1] [--expect_invalid=1] [--absent=N]
## Exit code 0 = pass. Writes OUT/verify.json.
extends SceneTree

var args := {}
var failures: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() == 2 else "1"
	var dir: String = args.get("dir", "")
	var cfg := GameConfig.load_from_dir()
	var base := dir.path_join("rooms")
	var codes := DirAccess.get_directories_at(base) if DirAccess.dir_exists_absolute(base) else PackedStringArray()
	if args.has("rooms"):
		_check(codes.size() == int(args["rooms"]), "expected %s rooms, found %d" % [args["rooms"], codes.size()])
	var clients: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("client_") and f.ends_with(".json"):
			clients.append(_read(dir.path_join(f)))
	var server_stats := {}
	var rooms_out := []
	for code in codes:
		var rdir := base.path_join(code)
		var meta := _read(rdir.path_join("meta.json"))
		var result := _read(rdir.path_join("result.json"))
		_check(not result.is_empty(), "room %s has a result (match ended)" % code)
		var entries: Array = []
		for line in FileAccess.get_file_as_string(rdir.path_join("journal.jsonl")).split("\n", false):
			entries.append(NetProtocol._ints(JSON.parse_string(line)))
		var hashes: Array = []
		var replay: MatchHost
		for run in 2:
			replay = MatchHost.new()
			replay.restore(cfg, meta["seats"], meta["seed"], meta["token_hashes"], entries, 1, true, "room-" + code)
			hashes.append(replay.engine.state.state_hash())
		_check(hashes[0] == hashes[1], "room %s: replay is deterministic" % code)
		_check(hashes[0] == result.get("state_hash", ""), "room %s: journal replay = server final state" % code)
		_check(replay.engine.is_ended(), "room %s: replayed match ended" % code)
		_check(Invariants.check(replay.engine).is_empty(), "room %s invariants: %s" % [code, str(Invariants.check(replay.engine))])
		var ids := {}
		for e in entries:
			if e.has("cmd"):
				var key := "%s|%s" % [e["cmd"]["player_id"], e["cmd"]["command_id"]]
				_check(not ids.has(key), "room %s: command applied once: %s" % [code, key])
				ids[key] = true
		var seen := 0
		for c in clients:
			if c.get("room_code", "") != code:
				continue
			seen += 1
			_check(c["public_hash"] == result.get("public_hash"), "room %s seat %d converged on the server state" % [code, c["seat"]])
			_check(c["snapshot_hash"] == result.get("public_hash"), "room %s seat %d snapshot matches its hash" % [code, c["seat"]])
			_check(c["stats"]["hash_mismatch"] == 0, "room %s seat %d: no snapshot hash mismatch" % [code, c["seat"]])
		# --absent=N: clients that left for good (abandon scenario) report nothing.
		_check(seen >= int(meta["players"]) - int(args.get("absent", "0")), "room %s: %d of %d clients reported" % [code, seen, meta["players"]])
		var st: Dictionary = result.get("stats", {})
		for k in st:
			if st[k] is Dictionary:
				var d: Dictionary = server_stats.get(k, {})
				for kk in st[k]:
					d[kk] = int(d.get(kk, 0)) + int(st[k][kk])
				server_stats[k] = d
			else:
				server_stats[k] = int(server_stats.get(k, 0)) + int(st[k])
		rooms_out.append({"code": code, "players": meta["players"], "end_reason": result.get("end_reason"),
			"rounds": result.get("rounds"), "state_version": result.get("state_version"), "journal_entries": entries.size(),
			"commands_applied": ids.size(), "restarts": result.get("restarts"), "stats": st})
	var chaos := {}
	for c in clients:
		for k in c.get("chaos", {}):
			chaos[k] = chaos.get(k, 0) + int(c["chaos"][k])
	var srv := _read(dir.path_join("server_meta.json"))
	if args.has("expect_duplicates"):
		_check(server_stats.get("duplicates", 0) > 0, "duplicate commands reached the server and were deduplicated")
	if args.has("expect_invalid"):
		_check(not (server_stats.get("rejected", {}) as Dictionary).is_empty(), "invalid commands rejected: %s" % str(server_stats.get("rejected")))
		_check(int(srv.get("stats", {}).get("frame_errors", {}).size()) > 0, "malformed frames refused: %s" % str(srv.get("stats", {}).get("frame_errors")))
	if args.has("expect_restart"):
		_check(int(srv.get("restarts", 0)) >= 1, "server was restarted from its journals")
		_check(chaos.get("reconnects", 0) >= clients.size(), "every client reconnected (%d)" % chaos.get("reconnects", 0))
	if args.has("expect_takeover"):
		_check(server_stats.get("bot_takeovers", 0) >= 1, "server bot took over a disconnected seat")
		_check(server_stats.get("bot_commands", 0) >= 1, "server bot made moves")
		_check(server_stats.get("seat_reclaims", 0) >= 1, "a player reclaimed the seat")
	if args.has("expect_rate_limit"):
		_check(int(srv.get("stats", {}).get("rate_limited", 0)) > 0, "flood frames were rate limited")
	if args.has("expect_resume"):
		_check(chaos.get("resumed_from_session", 0) >= 1, "a restarted client process resumed its seat")
	var summary := {"pass": failures.is_empty(), "failures": failures, "rooms": rooms_out, "server_stats": server_stats,
		"server_meta": srv, "client_chaos_total": chaos, "clients": clients.size()}
	var f := FileAccess.open(dir.path_join("verify.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(summary, "  "))
	f.close()
	print("NET_E2E %s failures=%d rooms=%d clients=%d server=%s rs=%s chaos=%s" % ["PASS" if failures.is_empty() else "FAIL",
		failures.size(), codes.size(), clients.size(), JSON.stringify(server_stats), JSON.stringify(srv.get("stats", {})), JSON.stringify(chaos)])
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
