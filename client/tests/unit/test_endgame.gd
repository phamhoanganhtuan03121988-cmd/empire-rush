## Net worth and ranking (GDD §5, §9; G9, G11).
extends TestCase


func _end(f: ErFixture) -> Array:
	f.engine._end_match("test")
	f.engine._commit()
	return f.state.results


func test_net_worth_formula() -> void:
	var f := ErFixture.make()
	f.set_cash(0, 500)
	f.give(0, f.district("D1"), 2)  # 3 x (30 + 2 x 40 x 50%) = 3 x 70
	assert_eq(f.engine.net_worth(0), 500 + 210, "cash + liquidation incl. buildings, no objective bonus")


func test_rank_by_net_worth() -> void:
	var f := ErFixture.make(3)
	f.set_cash(0, 100)
	f.set_cash(1, 900)
	f.set_cash(2, 500)
	var r := _end(f)
	assert_eq(r.map(func(x): return x["seat"]), [1, 2, 0], "order")
	assert_eq(r.map(func(x): return x["rank"]), [1, 2, 3], "ranks")


func test_tie_break_districts_then_cash() -> void:
	var f := ErFixture.make(3)
	f.set_cash(0, 910)
	f.set_cash(1, 1000)
	f.set_cash(2, 1000)
	f.give(0, f.district("D1"))  # +90 liquidation => 1000, 1 district
	var r := _end(f)
	assert_eq(r[0]["seat"], 0, "district wins the net-worth tie")
	f = ErFixture.make(2)
	f.set_cash(0, 955)
	f.set_cash(1, 1000)
	f.give(0, ["P_D2_1"])  # +45 => 1000, 0 districts, less cash
	r = _end(f)
	assert_eq(r[0]["seat"], 1, "more cash wins the next tie")


func test_full_tie_shares_rank() -> void:
	var f := ErFixture.make(3)
	f.set_cash(2, 10)
	var r := _end(f)
	assert_eq(r[0]["rank"], 1, "first")
	assert_eq(r[1]["rank"], 1, "shared first")
	assert_eq(r[2]["rank"], 3, "competition ranking")


func test_bankrupt_players_rank_last_later_is_better() -> void:
	var f := ErFixture.make(4)
	f.set_cash(0, 0)
	f.set_cash(1, 0)
	f.state.player(0)["bankrupt"] = true
	f.state.player(0)["bankrupt_turn"] = 10
	f.state.player(1)["bankrupt"] = true
	f.state.player(1)["bankrupt_turn"] = 20
	f.set_cash(2, 1)
	var r := _end(f)
	assert_eq(r.map(func(x): return x["seat"]), [3, 2, 1, 0], "solvent first, later bankruptcy ranks higher")


func test_match_ended_payload() -> void:
	var f := ErFixture.make()
	f.engine._end_match("round_cap")
	var ev := f.engine._commit()
	var me: Dictionary = ev.filter(func(e): return e["type"] == "MatchEnded")[0]["data"]
	assert_eq(me["reason"], "round_cap", "reason")
	assert_eq(me["results"].size(), 2, "every player ranked")
	assert_eq(me["results"], f.state.results, "payload equals stored results")
