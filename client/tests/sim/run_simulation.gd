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
	var report := aggregate(runs)
	report["wall_time_ms"] = Time.get_ticks_msec() - t0
	report["args"] = args
	print(format_report(report))
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


static func _pct(part: float, whole: float) -> float:
	return 0.0 if whole == 0 else snappedf(100.0 * part / whole, 0.1)


static func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	var m := b.size() / 2
	return float(b[m]) if b.size() % 2 == 1 else (b[m - 1] + b[m]) / 2.0


static func _quantile(a: Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return float(b[clampi(int(ceil(q * b.size())) - 1, 0, b.size() - 1)])


static func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return s / a.size()


static func aggregate(runs: Array) -> Dictionary:
	var by_players := {}
	for r in runs:
		var k: int = r["players"]
		if not by_players.has(k):
			by_players[k] = []
		by_players[k].append(r)
	var groups := {}
	for k in by_players:
		groups[str(k) + "p"] = _aggregate_group(by_players[k])
	var fails := {"stuck": 0, "invariant_errors": 0, "rejections": 0, "examples": []}
	for r in runs:
		if r["stuck"]:
			fails["stuck"] += 1
		fails["invariant_errors"] += r["invariant_errors"].size()
		fails["rejections"] += r["rejections"].size()
		for e in r["invariant_errors"] + r["rejections"]:
			if fails["examples"].size() < 10:
				fails["examples"].append("seed %d: %s" % [r["seed"], e])
	fails["total"] = fails["stuck"] + fails["invariant_errors"] + fails["rejections"]
	return {"matches": runs.size(), "groups": groups, "failures": fails}


static func _aggregate_group(runs: Array) -> Dictionary:
	var n_players: int = runs[0]["players"]
	var minutes: Array = []
	var rounds: Array = []
	var reasons := {}
	var seat_wins := {}
	var seat_games := {}
	var char_wins := {}
	var char_games := {}
	var bankrupt_rounds: Array = []
	var bankrupt_total := 0
	var matches_with_bankruptcy := 0
	var cash_by_round := {}
	var comebacks := 0
	var comeback_eligible := 0
	var leader_share: Array = []
	var totals := {"timeouts": 0, "trades_proposed": 0, "trades_accepted": 0, "trades_expired": 0,
		"auctions": 0, "auctions_sold": 0, "upgrades": 0, "rescues": 0, "liquidations": 0,
		"abilities": 0, "rent_paid": 0, "unowned_at_end": 0}
	for r in runs:
		minutes.append(r["duration_ms"] / 60000.0)
		rounds.append(r["rounds"])
		reasons[r["end_reason"]] = reasons.get(r["end_reason"], 0) + 1
		var winners: Array = r["results"].filter(func(x): return x["rank"] == 1)
		for row in r["results"]:
			seat_games[row["seat"]] = seat_games.get(row["seat"], 0) + 1
			char_games[row["character_id"]] = char_games.get(row["character_id"], 0) + 1
		for w in winners:
			seat_wins[w["seat"]] = seat_wins.get(w["seat"], 0.0) + 1.0 / winners.size()
			char_wins[w["character_id"]] = char_wins.get(w["character_id"], 0.0) + 1.0 / winners.size()
		bankrupt_total += r["bankruptcies"].size()
		if not r["bankruptcies"].is_empty():
			matches_with_bankruptcy += 1
		for b in r["bankruptcies"]:
			bankrupt_rounds.append(b["round"])
		for rd in [1, 5, 10, 15, 20, 25]:
			if r["round_samples"].has(rd):
				if not cash_by_round.has(rd):
					cash_by_round[rd] = []
				cash_by_round[rd].append(_mean(r["round_samples"][rd]["cash"]))
		# Comeback: winner was not the book-value leader at round 10.
		if r["round_samples"].has(10) and not winners.is_empty():
			comeback_eligible += 1
			var nw: Array = r["round_samples"][10]["book_value"]
			var lead := 0
			for i in nw.size():
				if nw[i] > nw[lead]:
					lead = i
			if not winners.any(func(w): return w["seat"] == lead):
				comebacks += 1
		var worth_sum := 0
		var worth_max := 0
		for row in r["results"]:
			worth_sum += row["net_worth"]
			worth_max = maxi(worth_max, row["net_worth"])
		if worth_sum > 0:
			leader_share.append(100.0 * worth_max / worth_sum)
		totals["timeouts"] += r["timeouts"]
		totals["trades_proposed"] += r["trades"]["proposed"]
		totals["trades_accepted"] += r["trades"]["accepted"]
		totals["trades_expired"] += r["trades"]["expired"]
		totals["auctions"] += r["auctions"]["opened"]
		totals["auctions_sold"] += r["auctions"]["sold"]
		totals["upgrades"] += r["upgrades"]
		totals["rescues"] += r["rescues"]
		totals["liquidations"] += r["liquidations"]
		totals["abilities"] += r["abilities"]
		totals["rent_paid"] += r["rent_paid"]
		totals["unowned_at_end"] += r["unowned_at_end"]
	var n := runs.size()
	var seat_rate := {}
	for s in seat_games:
		seat_rate["seat%d" % s] = _pct(seat_wins.get(s, 0.0), seat_games[s])
	var char_rate := {}
	for c in char_games:
		char_rate[c] = {"games": char_games[c], "win_pct": _pct(char_wins.get(c, 0.0), char_games[c])}
	var cash_round := {}
	for rd in cash_by_round:
		cash_round["round%d" % rd] = int(_mean(cash_by_round[rd]))
	var per_match := {}
	for k in totals:
		per_match[k] = snappedf(totals[k] / float(n), 0.01)
	return {
		"matches": n, "players": n_players,
		"duration_min": {"mean": snappedf(_mean(minutes), 0.1), "median": snappedf(_median(minutes), 0.1),
			"p90": snappedf(_quantile(minutes, 0.9), 0.1), "min": snappedf(_quantile(minutes, 0.0), 0.1),
			"max": snappedf(_quantile(minutes, 1.0), 0.1)},
		"rounds": {"mean": snappedf(_mean(rounds), 0.1), "median": _median(rounds)},
		"end_reasons_pct": _map_pct(reasons, n),
		"win_pct_by_seat": seat_rate, "win_pct_by_character": char_rate,
		"fair_share_pct": snappedf(100.0 / n_players, 0.1),
		"bankruptcy": {"per_match": snappedf(bankrupt_total / float(n), 0.01),
			"matches_with_any_pct": _pct(matches_with_bankruptcy, n),
			"round_median": _median(bankrupt_rounds), "round_mean": snappedf(_mean(bankrupt_rounds), 0.1)},
		"avg_cash_per_player_at": cash_round,
		"winner_net_worth_share_pct": snappedf(_mean(leader_share), 0.1),
		"comeback_pct": _pct(comebacks, comeback_eligible),
		"per_match": per_match,
	}


static func _map_pct(m: Dictionary, n: int) -> Dictionary:
	var out := {}
	for k in m:
		out[k] = _pct(m[k], n)
	return out


static func format_report(rep: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("SIMULATION: %d matches, wall %d ms" % [rep["matches"], rep.get("wall_time_ms", 0)])
	for g in rep["groups"]:
		lines.append("== %s ==" % g)
		lines.append(JSON.stringify(rep["groups"][g], "  ", true))
	lines.append("FAILURES: " + JSON.stringify(rep["failures"]))
	return "\n".join(lines)
