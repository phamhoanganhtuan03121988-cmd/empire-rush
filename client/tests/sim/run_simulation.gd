## Batch simulation + metrics report.
## Usage (from repo root): scripts/run_simulation.sh --matches=100 --players=4 --seed=1 [--out=/abs/path.json] [--summary=1]
##   --players accepts a comma list (e.g. 2,3,4); matches are spread round-robin.
##   --summary=1 writes only the aggregate (no per-match rows) to --out.
## Exit code 1 if any match got stuck, broke an invariant or had a bot command
## rejected (which would indicate a rules/bot mismatch).
extends SceneTree


func _initialize() -> void:
	var args := {"matches": "100", "players": "4", "seed": "1", "out": "", "idle": "3", "summary": "0"}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var cfg := GameConfig.load_from_dir()
	if not cfg.is_valid():
		printerr("CONFIG ERRORS: ", cfg.errors)
		quit(1)
		return
	var counts: Array[int] = []
	for p in str(args["players"]).split(","):
		counts.append(int(p))
	var n := int(args["matches"])
	var seed0 := int(args["seed"])
	var t0 := Time.get_ticks_msec()
	var runs: Array = []
	for i in n:
		var r := MatchSimulator.run(cfg, seed0 + i, counts[i % counts.size()], {"idle_pct": int(args["idle"])})
		runs.append(r)
	var report := SimStats.aggregate(runs)
	report["wall_time_ms"] = Time.get_ticks_msec() - t0
	report["args"] = args
	print(SimStats.format_report(report))
	if args["out"] != "":
		var f := FileAccess.open(args["out"], FileAccess.WRITE)
		var payload := {"summary": report}
		if args["summary"] != "1":
			payload["matches"] = _slim(runs)
		f.store_string(JSON.stringify(payload, "  ", true))
		f.close()
		print("wrote " + args["out"])
	quit(0 if report["failures"]["total"] == 0 else 1)


static func _slim(runs: Array) -> Array:
	var out: Array = []
	for r in runs:
		var c: Dictionary = r.duplicate()
		c.erase("engine")
		out.append(c)
	return out
