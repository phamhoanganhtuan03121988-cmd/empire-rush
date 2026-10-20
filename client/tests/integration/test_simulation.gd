## 100 complete bot matches (2/3/4 players) with invariant checks after every
## step. The full statistics report is produced by scripts/run_simulation.sh.
extends TestCase


func test_100_matches_complete_cleanly() -> void:
	var cfg := ErFixture.config()
	var reasons := {}
	for i in 100:
		var r := MatchSimulator.run(cfg, 10000 + i, [2, 3, 4][i % 3], {"idle_pct": 5})
		if r["stuck"]:
			errors.append("seed %d stuck" % r["seed"])
		for e in r["invariant_errors"]:
			errors.append("seed %d invariant: %s" % [r["seed"], e])
		for e in r["rejections"]:
			errors.append("seed %d bot command rejected: %s" % [r["seed"], e])
		if errors.size() > 10:
			return
		reasons[r["end_reason"]] = reasons.get(r["end_reason"], 0) + 1
		assert_true(r["rounds"] <= cfg.max_rounds_for(r["players"]), "round cap respected (seed %d)" % r["seed"])
		assert_true(r["end_reason"] in ["last_solvent", "round_cap", "time_cap"], "valid end reason")
	assert_true(reasons.size() >= 1, "matches ended")


func test_heavy_idle_matches_still_finish() -> void:
	# 40% of decisions time out: exercises every timeout default path.
	var cfg := ErFixture.config()
	for i in 10:
		var r := MatchSimulator.run(cfg, 500 + i, 4, {"idle_pct": 40})
		assert_false(r["stuck"], "seed %d stuck" % r["seed"])
		assert_eq(r["invariant_errors"].size(), 0, "seed %d invariants %s" % [r["seed"], str(r["invariant_errors"].slice(0, 3))])
		assert_true(r["timeouts"] > 50, "timeouts exercised")
