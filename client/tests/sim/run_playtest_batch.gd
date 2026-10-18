## M2.3 playtest automation: batch bot matches for 2, 3 and 4 players with
## reproducible seeds, exported as CSV + JSON + a Markdown analysis.
## Uses the real rules engine and the existing BotPlayer through
## MatchSimulator; nothing here changes rules or balance.
##
## Usage (from repo root): scripts/run_playtest_batch.sh --out=/abs/dir
##   [--players=2,3,4] [--matches=100] [--seed=1] [--mode=fast|debug]
##   [--idle=3] [--repro=10]
## - Seeds: match i of every player count uses seed + i (so 2p/3p/4p batches
##   are comparable and any row can be replayed alone).
## - fast: metrics only.  debug: also writes every match's full event log to
##   <out>/events/<players>p_seed<seed>.json and checks invariants after every
##   command (fast checks them too; debug keeps the evidence).
## - --repro=K re-runs the first K matches of each count and compares final
##   state hashes (determinism check).
## Game duration is the simulated match clock (bot think time + animation
## time model, docs/M1_REPORT.md); cpu_ms is how long this machine took.
## Exit code 1 if any match got stuck, broke an invariant, had a bot command
## rejected or failed the reproducibility check.
extends SceneTree

const RULE_FILES := ["balance.json", "board.json", "characters.json", "events.json", "opportunities.json"]
const CSV_COLUMNS := ["players", "seed", "characters", "end_reason", "rounds", "turns", "turns_by_seat",
	"game_duration_s", "game_duration_min", "cpu_ms", "winner_seats", "winner_characters",
	"bankruptcies", "bankrupt_seats", "first_bankruptcy_round", "auctions_opened", "auctions_sold",
	"purchases", "upgrades", "trades_proposed", "trades_accepted", "abilities", "timeouts",
	"rescues", "liquidations", "max_rent", "stuck", "invariant_errors", "rejections", "state_hash",
	"final_cash_by_seat", "final_net_worth_by_seat", "rules"]


func _initialize() -> void:
	var args := {"players": "2,3,4", "matches": "100", "seed": "1", "out": "", "mode": "fast",
		"idle": "3", "repro": "10"}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	if args["out"] == "":
		printerr("--out=/abs/dir is required")
		quit(2)
		return
	var cfg := GameConfig.load_from_dir()
	if not cfg.is_valid():
		printerr("CONFIG ERRORS: ", cfg.errors)
		quit(1)
		return
	var out: String = args["out"]
	var debug: bool = args["mode"] == "debug"
	DirAccess.make_dir_recursive_absolute(out)
	if debug:
		DirAccess.make_dir_recursive_absolute(out.path_join("events"))
	var counts: Array[int] = []
	for p in str(args["players"]).split(","):
		counts.append(int(p))
	var n := int(args["matches"])
	var seed0 := int(args["seed"])
	var opts := {"idle_pct": int(args["idle"]), "keep_event_log": debug, "return_engine": debug}
	var rows: Array = []
	var t_all := Time.get_ticks_msec()
	for pc in counts:
		for i in n:
			var t0 := Time.get_ticks_usec()
			var r := MatchSimulator.run(cfg, seed0 + i, pc, opts)
			var cpu_ms := (Time.get_ticks_usec() - t0) / 1000.0
			rows.append(row_from_run(r, cpu_ms))
			if debug:
				var f := FileAccess.open(out.path_join("events/%dp_seed%d.json" % [pc, seed0 + i]), FileAccess.WRITE)
				f.store_string(JSON.stringify(r["engine"].event_log))
				f.close()
	var repro := _reproducibility(cfg, counts, seed0, mini(int(args["repro"]), n), int(args["idle"]), rows)
	var meta := {
		"generated_unix": int(Time.get_unix_time_from_system()),
		"engine": Engine.get_version_info()["string"],
		"rules": rules_fingerprint(),
		"args": args,
		"time_model": MatchSimulator.TIME_MODEL_M1,
		"total_cpu_ms": Time.get_ticks_msec() - t_all,
		"bot": "BotPlayer (scripted heuristic bot, idle_pct=%s)" % args["idle"],
	}
	var analysis := analyze(rows, counts)
	analysis["reproducibility"] = repro
	_write_csv(out.path_join("matches.csv"), rows)
	var jf := FileAccess.open(out.path_join("batch.json"), FileAccess.WRITE)
	jf.store_string(JSON.stringify({"meta": meta, "analysis": analysis, "matches": rows}, "  ", true))
	jf.close()
	var md := format_markdown(meta, analysis)
	var mf := FileAccess.open(out.path_join("summary.md"), FileAccess.WRITE)
	mf.store_string(md)
	mf.close()
	print(md)
	print("wrote %s/{matches.csv,batch.json,summary.md}" % out)
	var bad: int = analysis["totals"]["stuck"] + analysis["totals"]["invariant_errors"] + analysis["totals"]["rejections"]
	quit(0 if bad == 0 and repro["mismatches"] == 0 else 1)


## SHA-256 of every rules data file + the balance status line, so a CSV can
## always be traced back to the exact rules/balance it was produced with.
static func rules_fingerprint() -> Dictionary:
	var files := {}
	var all := ""
	for f in RULE_FILES:
		var text := FileAccess.get_file_as_string("res://data/rules/" + f)
		var h := text.sha256_text()
		files[f] = h
		all += h
	var bal: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/rules/balance.json"))
	return {"combined_sha256": all.sha256_text(), "files": files,
		"balance_status": str(bal.get("_status", "")) if bal is Dictionary else ""}


static func row_from_run(r: Dictionary, cpu_ms: float) -> Dictionary:
	var winners: Array = []
	var winner_chars: Array = []
	for res in r["results"]:
		if int(res["rank"]) == 1:
			winners.append(int(res["seat"]))
			winner_chars.append(res["character_id"])
	var bseats: Array = []
	var first_bk := -1
	for b in r["bankruptcies"]:
		bseats.append(int(b["seat"]))
		if first_bk < 0:
			first_bk = int(b["round"])
	return {
		"players": r["players"], "seed": r["seed"], "characters": "|".join(r["characters"]),
		"end_reason": r["end_reason"], "rounds": r["rounds"], "turns": r["turns"],
		"turns_by_seat": "|".join(r["turns_by_seat"].map(func(x): return str(x))),
		"game_duration_s": snappedf(r["duration_ms"] / 1000.0, 0.1),
		"game_duration_min": snappedf(r["duration_ms"] / 60000.0, 0.01),
		"cpu_ms": snappedf(cpu_ms, 0.1),
		"winner_seats": "|".join(winners.map(func(x): return str(x))),
		"winner_characters": "|".join(winner_chars),
		"bankruptcies": r["bankruptcies"].size(), "bankrupt_seats": "|".join(bseats.map(func(x): return str(x))),
		"first_bankruptcy_round": first_bk,
		"auctions_opened": r["auctions"]["opened"], "auctions_sold": r["auctions"]["sold"],
		"purchases": r["purchases"], "upgrades": r["upgrades"],
		"trades_proposed": r["trades"]["proposed"], "trades_accepted": r["trades"]["accepted"],
		"abilities": r["abilities"], "timeouts": r["timeouts"], "rescues": r["rescues"],
		"liquidations": r["liquidations"], "max_rent": r["max_rent"],
		"stuck": r["stuck"], "invariant_errors": r["invariant_errors"].size(),
		"rejections": r["rejections"].size(), "state_hash": r["state_hash"],
		"final_cash_by_seat": "|".join(_by_seat(r["results"], "cash")),
		"final_net_worth_by_seat": "|".join(_by_seat(r["results"], "net_worth")),
		# Every row carries the rules fingerprint so batches of different
		# balance versions can never be mixed silently.
		"rules": _rules_short(),
	}


static var _rules_cache := ""


static func _rules_short() -> String:
	if _rules_cache == "":
		_rules_cache = str(rules_fingerprint()["combined_sha256"]).substr(0, 16)
	return _rules_cache


static func _by_seat(results: Array, key: String) -> Array:
	var out: Array = []
	out.resize(results.size())
	for res in results:
		out[int(res["seat"])] = str(res[key])
	return out


func _reproducibility(cfg: GameConfig, counts: Array[int], seed0: int, k: int, idle: int, rows: Array) -> Dictionary:
	var checked := 0
	var mismatches: Array = []
	for pc in counts:
		for i in k:
			var r := MatchSimulator.run(cfg, seed0 + i, pc, {"idle_pct": idle})
			for row in rows:
				if row["players"] == pc and row["seed"] == seed0 + i:
					checked += 1
					if row["state_hash"] != r["state_hash"]:
						mismatches.append("%dp seed %d" % [pc, seed0 + i])
	return {"checked": checked, "mismatches": mismatches.size(), "mismatch_list": mismatches}


static func analyze(rows: Array, counts: Array[int]) -> Dictionary:
	var groups := {}
	var totals := {"matches": rows.size(), "stuck": 0, "invariant_errors": 0, "rejections": 0}
	for r in rows:
		totals["stuck"] += 1 if r["stuck"] else 0
		totals["invariant_errors"] += r["invariant_errors"]
		totals["rejections"] += r["rejections"]
	for pc in counts:
		var g := rows.filter(func(r): return r["players"] == pc)
		var n := g.size()
		var dur: Array = g.map(func(r): return r["game_duration_min"])
		var reasons := {}
		var seat_wins := []
		seat_wins.resize(pc)
		seat_wins.fill(0.0)
		var with_bk := 0
		var bk_total := 0
		var long_matches: Array = []
		for r in g:
			reasons[r["end_reason"]] = reasons.get(r["end_reason"], 0) + 1
			# A shared first place counts as a fraction of a win for each seat.
			var ws: PackedStringArray = str(r["winner_seats"]).split("|", false)
			for w in ws:
				seat_wins[int(w)] += 1.0 / ws.size()
			if r["bankruptcies"] > 0:
				with_bk += 1
			bk_total += r["bankruptcies"]
			if r["game_duration_min"] > 35.0:
				long_matches.append({"seed": r["seed"], "minutes": r["game_duration_min"]})
		var seat_rows: Array = []
		for s in pc:
			var p: float = 100.0 * seat_wins[s] / maxi(1, n)
			seat_rows.append({"seat": s, "win_pct": snappedf(p, 0.1), "ci95": SimStats.ci95(p, n)})
		var reason_pct := {}
		for k in reasons:
			reason_pct[k] = snappedf(100.0 * reasons[k] / maxi(1, n), 0.1)
		long_matches.sort_custom(func(a, b): return a["minutes"] > b["minutes"])
		groups[str(pc)] = {
			"matches": n,
			"duration_min": {"min": _q(dur, 0.0), "p10": _q(dur, 0.10), "p25": _q(dur, 0.25),
				"median": snappedf(SimStats._median(dur), 0.01), "p75": _q(dur, 0.75),
				"p90": _q(dur, 0.90), "p95": _q(dur, 0.95), "max": _q(dur, 1.0),
				"mean": snappedf(SimStats._mean(dur), 0.01)},
			"end_reason_pct": reason_pct,
			"matches_with_bankruptcy_pct": snappedf(100.0 * with_bk / maxi(1, n), 0.1),
			"bankruptcies_per_match": snappedf(float(bk_total) / maxi(1, n), 0.01),
			"seat_win": seat_rows,
			"turns_mean": snappedf(SimStats._mean(g.map(func(r): return r["turns"])), 0.1),
			"auctions_per_match": snappedf(SimStats._mean(g.map(func(r): return r["auctions_opened"])), 0.01),
			"upgrades_per_match": snappedf(SimStats._mean(g.map(func(r): return r["upgrades"])), 0.01),
			"trades_proposed_per_match": snappedf(SimStats._mean(g.map(func(r): return r["trades_proposed"])), 0.01),
			"trades_accepted_per_match": snappedf(SimStats._mean(g.map(func(r): return r["trades_accepted"])), 0.01),
			"timeouts_per_match": snappedf(SimStats._mean(g.map(func(r): return r["timeouts"])), 0.01),
			"cpu_ms_median": snappedf(SimStats._median(g.map(func(r): return r["cpu_ms"])), 0.1),
			"over_35_min": long_matches.size(),
			"longest": long_matches.slice(0, 5),
			"stuck": g.filter(func(r): return r["stuck"]).size(),
			"invalid": g.filter(func(r): return r["invariant_errors"] > 0 or r["rejections"] > 0).size(),
		}
	return {"totals": totals, "by_players": groups}


static func _q(a: Array, q: float) -> float:
	return snappedf(SimStats._quantile(a, q) if q > 0.0 else (a.min() if not a.is_empty() else 0.0), 0.01)


func _write_csv(path: String, rows: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_line(",".join(CSV_COLUMNS))
	for r in rows:
		var cells := PackedStringArray()
		for c in CSV_COLUMNS:
			var v := str(r[c])
			if v.contains(",") or v.contains("\""):
				v = "\"" + v.replace("\"", "\"\"") + "\""
			cells.append(v)
		f.store_line(",".join(cells))
	f.close()


static func format_markdown(meta: Dictionary, a: Dictionary) -> String:
	var L := PackedStringArray()
	L.append("# Bot batch simulation")
	L.append("")
	L.append("- Engine: %s · rules fingerprint `%s`" % [meta["engine"], str(meta["rules"]["combined_sha256"]).substr(0, 16)])
	L.append("- Balance: %s" % meta["rules"]["balance_status"])
	L.append("- Args: %s" % JSON.stringify(meta["args"]))
	L.append("- %s. Durations use the simulated game clock (time model in batch.json), not CPU time." % meta["bot"])
	L.append("- Total CPU time: %.1f s. Matches: %d. Stuck: %d. Invariant errors: %d. Rejected bot commands: %d." % [
		meta["total_cpu_ms"] / 1000.0, a["totals"]["matches"], a["totals"]["stuck"], a["totals"]["invariant_errors"], a["totals"]["rejections"]])
	var rp: Dictionary = a["reproducibility"]
	L.append("- Reproducibility: %d matches re-run, %d final-state hash mismatches." % [rp["checked"], rp["mismatches"]])
	L.append("")
	L.append("| Players | n | min | p10 | p25 | median | p75 | p90 | p95 | max (min) | > 35 min |")
	L.append("|---|---|---|---|---|---|---|---|---|---|---|")
	for k in a["by_players"]:
		var g: Dictionary = a["by_players"][k]
		var d: Dictionary = g["duration_min"]
		L.append("| %s | %d | %.1f | %.1f | %.1f | **%.1f** | %.1f | %.1f | %.1f | %.1f | %d |" % [k, g["matches"], d["min"], d["p10"], d["p25"], d["median"], d["p75"], d["p90"], d["p95"], d["max"], g["over_35_min"]])
	L.append("")
	L.append("| Players | End reasons (%) | Matches with a bankruptcy | Bankruptcies / match | Turns | Auctions | Upgrades | Trades (proposed / accepted) | Timeouts | Stuck / invalid |")
	L.append("|---|---|---|---|---|---|---|---|---|---|")
	for k in a["by_players"]:
		var g: Dictionary = a["by_players"][k]
		L.append("| %s | %s | %.1f%% | %.2f | %.1f | %.2f | %.2f | %.2f / %.2f | %.2f | %d / %d |" % [k, JSON.stringify(g["end_reason_pct"]),
			g["matches_with_bankruptcy_pct"], g["bankruptcies_per_match"], g["turns_mean"], g["auctions_per_match"],
			g["upgrades_per_match"], g["trades_proposed_per_match"], g["trades_accepted_per_match"], g["timeouts_per_match"], g["stuck"], g["invalid"]])
	L.append("")
	L.append("Seat win rates (shared first places split; ±95% CI):")
	L.append("")
	for k in a["by_players"]:
		var g: Dictionary = a["by_players"][k]
		var parts := PackedStringArray()
		for s in g["seat_win"]:
			parts.append("seat %d %.1f%% ±%.1f" % [s["seat"], s["win_pct"], s["ci95"]])
		L.append("- %sp: %s (fair share %.1f%%)" % [k, ", ".join(parts), 100.0 / int(k)])
	L.append("")
	L.append("Bots are scripted heuristics, not people: this measures rules flow and pacing under a time model, not fun or real human turn times.")
	return "\n".join(L) + "\n"
