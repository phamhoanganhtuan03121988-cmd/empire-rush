## Desktop bug reproduction (Phase 2, B3): replays the "replay" record of a
## session telemetry file (internal builds) and checks it ends on the same
## state hash. With --until=N it stops after N inputs and prints the state,
## so a reported bug can be inspected at the moment it happened.
##   godot --headless --path client --script res://tools/replay_match.gd -- --file=/abs/session_123.json [--until=N] [--events=1]
extends SceneTree


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() == 2 else "1"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(args.get("file", "")))
	if not data is Dictionary or not data.has("replay"):
		print("REPLAY_ERROR no replay record in ", args.get("file", ""))
		quit(2)
		return
	var rec: Dictionary = data["replay"]
	var until := int(args.get("until", "-1"))
	var r := MatchReplay.replay(GameConfig.load_from_dir(), rec, until)
	var e: GameEngine = r["engine"]
	if args.has("events"):
		for ev in e.event_log:
			print("EV ", JSON.stringify(ev))
	print("STATE ", JSON.stringify(e.public_snapshot()))
	if not r["ok"]:
		print("REPLAY_ERROR ", r["error"])
		quit(1)
		return
	var full := until < 0
	var same: bool = e.state.state_hash() == str(rec["state_hash"])
	print("REPLAY applied=%d/%d phase=%s round=%d hash=%s %s" % [r["applied"], rec["input_log"].size(), e.state.phase,
		e.state.round, e.state.state_hash().left(12), ("MATCHES the recorded final state" if same else "DIFFERS from the recorded final state") if full else "(partial)"])
	quit(0 if same or not full else 1)
