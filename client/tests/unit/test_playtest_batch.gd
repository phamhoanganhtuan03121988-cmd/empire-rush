## M2.3 playtest automation: the batch tool's row extraction, analysis and
## reproducibility, on a few real simulated matches.
extends TestCase

const Batch := preload("res://tests/sim/run_playtest_batch.gd")


func _rows(counts: Array[int], n: int) -> Array:
	var cfg := GameConfig.load_from_dir()
	var rows: Array = []
	for pc in counts:
		for i in n:
			rows.append(Batch.row_from_run(MatchSimulator.run(cfg, 100 + i, pc), 1.0))
	return rows


func test_rows_have_every_csv_column_and_consistent_turns() -> void:
	var rows := _rows([2, 4] as Array[int], 2)
	for r in rows:
		for c in Batch.CSV_COLUMNS:
			assert_true(r.has(c), "column %s" % c)
		var per_seat := 0
		for t in str(r["turns_by_seat"]).split("|"):
			per_seat += int(t)
		assert_eq(per_seat, r["turns"], "turns by seat add up to total turns (seed %d)" % r["seed"])
		assert_true(str(r["winner_seats"]) != "", "a winner is recorded")
		assert_true(r["game_duration_s"] > 0.0, "game clock duration")
		assert_false(r["stuck"], "not stuck")


func test_same_seed_same_row() -> void:
	var a := _rows([3] as Array[int], 2)
	var b := _rows([3] as Array[int], 2)
	for i in a.size():
		var ra: Dictionary = a[i].duplicate()
		var rb: Dictionary = b[i].duplicate()
		ra.erase("cpu_ms")
		rb.erase("cpu_ms")
		assert_eq(JSON.stringify(ra), JSON.stringify(rb), "row %d reproducible" % i)


func test_analysis_counts_and_seat_shares() -> void:
	var rows := _rows([2, 3] as Array[int], 3)
	var a := Batch.analyze(rows, [2, 3] as Array[int])
	assert_eq(a["totals"]["matches"], 6, "total")
	for k in ["2", "3"]:
		var g: Dictionary = a["by_players"][k]
		assert_eq(g["matches"], 3, "%s players" % k)
		var share := 0.0
		for s in g["seat_win"]:
			share += s["win_pct"]
		assert_true(absf(share - 100.0) < 0.5, "%sp seat win shares sum to 100%% (%.1f)" % [k, share])
		var pct := 0.0
		for reason in g["end_reason_pct"]:
			pct += g["end_reason_pct"][reason]
		assert_true(absf(pct - 100.0) < 0.5, "end reasons sum to 100%")
		var d: Dictionary = g["duration_min"]
		assert_true(d["min"] <= d["median"] and d["median"] <= d["max"], "quantiles ordered")


func test_rules_fingerprint_is_stable() -> void:
	var a := Batch.rules_fingerprint()
	var b := Batch.rules_fingerprint()
	assert_eq(a["combined_sha256"], b["combined_sha256"], "stable")
	assert_eq(a["files"].size(), Batch.RULE_FILES.size(), "every rules file hashed")
	assert_true(str(a["balance_status"]).begins_with("DRAFT v3"), "balance status recorded")
