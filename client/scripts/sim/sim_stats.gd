## Aggregate statistics over simulated matches (shared by run_simulation.gd
## and run_experiments.gd). aggregate() reproduces the M1 report format
## exactly; extended() adds the M1.1 balance-review metrics.
class_name SimStats
extends RefCounted


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


# =============================================================================
# M1.1 balance-review metrics
# =============================================================================

## 95% normal-approximation half-width (percentage points) for a share p of n.
static func ci95(p_pct: float, n: int) -> float:
	if n == 0:
		return 0.0
	var p := p_pct / 100.0
	return snappedf(196.0 * sqrt(p * (1.0 - p) / n), 0.1)


## Winner seats under an alternative valuation key (solvent players only;
## ties broken by districts then cash, full ties shared).
static func _winners_by(final: Array, key: String) -> Array:
	var best: Array = []
	for f in final:
		if f["bankrupt"]:
			continue
		if best.is_empty():
			best = [f]
			continue
		var b: Dictionary = best[0]
		var cmp := 0
		for k in [key, "districts", "cash"]:
			if f[k] != b[k]:
				cmp = 1 if f[k] > b[k] else -1
				break
		if cmp > 0:
			best = [f]
		elif cmp == 0:
			best.append(f)
	return best.map(func(x): return x["seat"])


static func extended(runs: Array, focus_seat_fn: Callable = Callable()) -> Dictionary:
	var by_players := {}
	for r in runs:
		if not by_players.has(r["players"]):
			by_players[r["players"]] = []
		by_players[r["players"]].append(r)
	var out := {}
	for k in by_players:
		out[str(k) + "p"] = _extended_group(by_players[k], focus_seat_fn)
	return out


static func _extended_group(runs: Array, focus_seat_fn: Callable) -> Dictionary:
	var n := runs.size()
	var np: int = runs[0]["players"]
	var minutes: Array = []
	var turn_s: Array = []
	var rounds: Array = []
	var reasons := {}
	var bk_rounds: Array = []
	var bk_matches := 0
	var bk_total := 0
	var seat_wins := {}
	var char_wins := {}
	var char_games := {}
	var props_r5 := {}
	var flows := {}
	var turns_total := 0
	var winner_changes_book := 0
	var winner_most_cash := 0
	var winner_cash_share: Array = []
	var other_cash_share: Array = []
	var focus_wins := 0.0
	var focus_wins_book := 0.0
	var comebacks := 0
	var comeback_n := 0
	var cash_r := {}
	for r in runs:
		minutes.append(r["duration_ms"] / 60000.0)
		turn_s.append(r["duration_ms"] / 1000.0 / maxi(1, r["turns"]))
		turns_total += r["turns"]
		rounds.append(r["rounds"])
		reasons[r["end_reason"]] = reasons.get(r["end_reason"], 0) + 1
		if not r["bankruptcies"].is_empty():
			bk_matches += 1
		bk_total += r["bankruptcies"].size()
		for b in r["bankruptcies"]:
			bk_rounds.append(b["round"])
		var winners: Array = r["results"].filter(func(x): return x["rank"] == 1)
		var wseats: Array = winners.map(func(x): return x["seat"])
		for w in winners:
			seat_wins[w["seat"]] = seat_wins.get(w["seat"], 0.0) + 1.0 / winners.size()
			char_wins[w["character_id"]] = char_wins.get(w["character_id"], 0.0) + 1.0 / winners.size()
		for row in r["results"]:
			char_games[row["character_id"]] = char_games.get(row["character_id"], 0) + 1
		if focus_seat_fn.is_valid():
			var fs: int = focus_seat_fn.call(r)
			if fs in wseats:
				focus_wins += 1.0 / wseats.size()
			var bw := _winners_by(r["final"], "book_value")
			if fs in bw:
				focus_wins_book += 1.0 / bw.size()
		if r["round_samples"].has(5):
			for i in np:
				props_r5[i] = props_r5.get(i, 0) + r["round_samples"][5]["properties"][i]
		for f in r["flows"]:
			flows[f] = flows.get(f, 0) + r["flows"][f]
		var final: Array = r["final"]
		var book_w := _winners_by(final, "book_value")
		book_w.sort()
		var liq_w := wseats.duplicate()
		liq_w.sort()
		if book_w != liq_w:
			winner_changes_book += 1
		var max_cash := 0
		for f in final:
			max_cash = maxi(max_cash, f["cash"])
		if winners.any(func(w): return final[w["seat"]]["cash"] == max_cash):
			winner_most_cash += 1
		for f in final:
			if f["bankrupt"] or f["liquidation_nw"] == 0:
				continue
			var share: float = 100.0 * f["cash"] / f["liquidation_nw"]
			if f["seat"] in wseats:
				winner_cash_share.append(share)
			else:
				other_cash_share.append(share)
		if r["round_samples"].has(10) and not winners.is_empty():
			comeback_n += 1
			var bv: Array = r["round_samples"][10]["book_value"]
			var lead := 0
			for i in bv.size():
				if bv[i] > bv[lead]:
					lead = i
			if not lead in wseats:
				comebacks += 1
		for rd in [5, 10, 15, 20, 25, 30, 35, 40]:
			if r["round_samples"].has(rd):
				if not cash_r.has(rd):
					cash_r[rd] = []
				cash_r[rd].append(_mean(r["round_samples"][rd]["cash"]))
	var seats := {}
	var seat_list: Array = []
	for i in np:
		var p := _pct(seat_wins.get(i, 0.0), n)
		seat_list.append(p)
		seats["seat%d" % i] = {"win_pct": p, "ci95": ci95(p, n), "props_round5": snappedf(props_r5.get(i, 0) / float(n), 0.01)}
	var chars := {}
	for c in char_games:
		chars[c] = _pct(char_wins.get(c, 0.0), char_games[c])
	var per_turn := {}
	for f in flows:
		per_turn[f] = snappedf(flows[f] / float(turns_total), 0.1)
	var cash := {}
	for rd in cash_r:
		cash["r%d" % rd] = int(_mean(cash_r[rd]))
	var res := {
		"matches": n, "players": np, "fair_pct": snappedf(100.0 / np, 0.1),
		"minutes": {"median": snappedf(_median(minutes), 0.1), "p90": snappedf(_quantile(minutes, 0.9), 0.1),
			"p10": snappedf(_quantile(minutes, 0.1), 0.1)},
		"sec_per_turn": snappedf(_mean(turn_s), 0.1),
		"rounds_mean": snappedf(_mean(rounds), 0.1),
		"end_pct": _map_pct(reasons, n),
		"bankruptcy": {"matches_pct": _pct(bk_matches, n), "per_match": snappedf(bk_total / float(n), 0.01),
			"round_median": _median(bk_rounds)},
		"seats": seats, "seat_spread_pp": snappedf(seat_list.max() - seat_list.min(), 0.1),
		"characters": chars,
		"flows_per_turn": per_turn,
		"valuation": {"winner_changes_under_book_value_pct": _pct(winner_changes_book, n),
			"winner_has_most_cash_pct": _pct(winner_most_cash, n),
			"winner_cash_share_of_nw_pct": snappedf(_mean(winner_cash_share), 0.1),
			"others_cash_share_of_nw_pct": snappedf(_mean(other_cash_share), 0.1)},
		"comeback_pct": _pct(comebacks, comeback_n),
		"avg_cash": cash,
	}
	if focus_seat_fn.is_valid():
		res["focus_seat_win_pct"] = _pct(focus_wins, n)
		res["focus_seat_ci95"] = ci95(res["focus_seat_win_pct"], n)
		res["focus_seat_win_pct_if_ranked_by_book_value"] = _pct(focus_wins_book, n)
	return res
