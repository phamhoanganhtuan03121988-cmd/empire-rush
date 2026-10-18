## Balance experiments (M1.1). Runs every variant of a spec on the SAME seeds
## (paired comparison) and prints/writes SimStats.extended() metrics.
## Usage: scripts/run_experiments.sh --spec=res://tests/sim/experiments/<name>.json [--out=/abs/path.json] [--seed_base=N]
##
## Spec format:
## {
##   "players": [2, 3, 4], "matches": {"2": 1000, "3": 1000, "4": 2000}, "seed_base": 500000,
##   "variants": [{
##     "name": "...",
##     "balance": {...},                      # deep-merged into balance.json (experiment only)
##     "max_rounds_by_players": {"2": 35},    # overrides balance.max_rounds per player count
##     "time_model": "m1" | "medium" | "slow" | {...},
##     "seat_cash_delta": 0,                  # experiment only, NOT a game rule
##     "hoarder_freeze_rounds": 0             # seat (seed % n) hoards cash in the last N rounds
##   }]
## }
## Exit code 1 if any match got stuck, broke an invariant or had a bot command rejected.
extends SceneTree

const TIME_MODELS := {
	"m1": {},
	"medium": {"bid": [800, 1500], "roll": [1000, 2000], "trade": [3000, 8000], "strategy": [1200, 3500],
		"other": [2000, 4000], "anim_base": 2200, "anim_per_space": 300},
	"slow": {"bid": [1000, 2000], "roll": [1500, 2500], "trade": [4000, 10000], "strategy": [2000, 6000],
		"other": [3000, 6000], "anim_base": 2500, "anim_per_space": 350},
}


func _initialize() -> void:
	var args := {"spec": "", "out": "", "seed_base": ""}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var spec = GameConfig.normalize_numbers(JSON.parse_string(FileAccess.get_file_as_string(args["spec"])))
	if typeof(spec) != TYPE_DICTIONARY:
		printerr("cannot read spec " + args["spec"])
		quit(2)
		return
	if args["seed_base"] != "":
		spec["seed_base"] = int(args["seed_base"])
	var base := GameConfig.load_from_dir()
	var t0 := Time.get_ticks_msec()
	var report := {"spec": args["spec"], "seed_base": spec["seed_base"], "variants": {}}
	var failures := 0
	for v in spec["variants"]:
		var runs: Array = []
		for np in spec["players"]:
			var patch: Dictionary = v.get("balance", {}).duplicate(true)
			var by_p: Dictionary = v.get("max_rounds_by_players", {})
			if by_p.has(str(np)):
				# Override both keys so the cap applies on v2 (no by-players
				# table) and v3+ (by-players table) data alike.
				patch["max_rounds"] = by_p[str(np)]
				if not patch.has("max_rounds_by_players"):
					patch["max_rounds_by_players"] = {}
				patch["max_rounds_by_players"][str(np)] = by_p[str(np)]
			var cfg := base.with_balance(patch)
			if not cfg.is_valid():
				printerr("variant %s invalid: %s" % [v["name"], str(cfg.errors)])
				quit(2)
				return
			var tm = v.get("time_model", "m1")
			var opts := {"time_model": TIME_MODELS[tm] if typeof(tm) == TYPE_STRING else tm,
				"seat_cash_delta": v.get("seat_cash_delta", 0)}
			var count: int = spec["matches"][str(np)]
			for i in count:
				var seed_value: int = spec["seed_base"] + np * 1000000 + i
				var o := opts.duplicate()
				var freeze: int = v.get("hoarder_freeze_rounds", 0)
				if freeze > 0:
					var bo: Array = []
					for s in np:
						bo.append({"endgame_freeze_rounds": freeze} if s == seed_value % np else {})
					o["bot_opts"] = bo
				var r := MatchSimulator.run(cfg, seed_value, np, o)
				if r["stuck"] or not r["invariant_errors"].is_empty() or not r["rejections"].is_empty():
					failures += 1
					printerr("FAILURE %s seed %d: %s %s" % [v["name"], seed_value, str(r["invariant_errors"].slice(0, 2)), str(r["rejections"].slice(0, 2))])
				runs.append(r)
		var focus := func(r): return r["seed"] % r["players"]
		var ext := SimStats.extended(runs, focus)
		report["variants"][v["name"]] = {"definition": v, "groups": ext}
		print("== %s ==" % v["name"])
		for g in ext:
			var e: Dictionary = ext[g]
			print("  %s n=%d  min med/p90 %s/%s  s/turn %s  rounds %s  end %s  bk %s%% (rd %s)  seats %s spread %spp  chars %s  winner!=book %s%%  hoarder/focus %s%%±%s" % [
				g, e["matches"], e["minutes"]["median"], e["minutes"]["p90"], e["sec_per_turn"], e["rounds_mean"],
				str(e["end_pct"]), e["bankruptcy"]["matches_pct"], e["bankruptcy"]["round_median"],
				str(e["seats"].values().map(func(x): return x["win_pct"])), e["seat_spread_pp"], str(e["characters"]),
				e["valuation"]["winner_changes_under_book_value_pct"], e.get("focus_seat_win_pct", "-"), e.get("focus_seat_ci95", "-")])
	report["failures"] = failures
	report["wall_time_ms"] = Time.get_ticks_msec() - t0
	print("FAILURES: %d  wall %d ms" % [failures, report["wall_time_ms"]])
	if args["out"] != "":
		var f := FileAccess.open(args["out"], FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "  ", true))
		f.close()
		print("wrote " + args["out"])
	quit(0 if failures == 0 else 1)
