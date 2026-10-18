## Runs one complete bot match against the rules engine with a simulated clock
## and returns structured metrics. Fully deterministic per seed: the engine RNG
## is seeded with `seed_value`, bot behaviour and think times use a separate
## RNG derived from it.
##
## Time model (presentation time the real game will spend; documented in
## docs/M1_REPORT.md): decisions take 0.6-5 s, the dice + token animation takes
## 1.8 s + 0.25 s per space, auctions run until their timer, idle bots wait
## out the full timer. opts["time_model"] overrides any of TIME_MODEL_M1.
##
## Experiment-only options (M1.1 balance review; NOT game rules):
##   seat_cash_delta  - extra starting RC per seat index (seat k gets +k*delta)
##   bot_opts         - per-seat Dictionary of BotPlayer overrides
## Defaults reproduce M1 results exactly.
class_name MatchSimulator
extends RefCounted

const CHARACTER_ORDER := ["TYCOON", "INVESTOR", "NEGOTIATOR"]
const MAX_STEPS := 50000
## [min_ms, random_span_ms] per decision kind, plus dice/token animation.
const TIME_MODEL_M1 := {
	"bid": [600, 1400], "roll": [800, 1700], "trade": [2000, 7000], "strategy": [700, 2300],
	"other": [1500, 3500], "anim_base": 1800, "anim_per_space": 250,
}


static func run(config: GameConfig, seed_value: int, n_players: int, opts: Dictionary = {}) -> Dictionary:
	var idle_pct: int = opts.get("idle_pct", 3)
	var check_inv: bool = opts.get("check_invariants", true)
	var sim_rng := ErRng.new(seed_value * 7919 + 17)
	var seats: Array = []
	for i in n_players:
		var ch: String = opts["characters"][i] if opts.has("characters") else CHARACTER_ORDER[(seed_value + i) % CHARACTER_ORDER.size()]
		seats.append({"player_id": "p%d" % i, "character_id": ch})
	var clock := MatchClock.new(0)
	var engine := GameEngine.create(config, clock, seats, seed_value, "sim-%d" % seed_value)
	engine.keep_event_log = opts.get("keep_event_log", false)
	var tm: Dictionary = TIME_MODEL_M1.duplicate()
	tm.merge(opts.get("time_model", {}), true)
	var seat_delta: int = opts.get("seat_cash_delta", 0)
	if seat_delta != 0:
		for i in n_players:
			engine.state.player(i)["cash"] += i * seat_delta
			engine.state.bank_net_issued += i * seat_delta
	var bots: Array = []
	var bot_opts: Array = opts.get("bot_opts", [])
	for i in n_players:
		var bot := BotPlayer.new(i, "p%d" % i, sim_rng, idle_pct)
		if i < bot_opts.size():
			for k in bot_opts[i]:
				bot.set(k, bot_opts[i][k])
		bots.append(bot)

	var st := {
		"seed": seed_value, "players": n_players,
		"characters": seats.map(func(x): return x["character_id"]),
		"invariant_errors": [], "rejections": [], "timeouts": 0, "events": 0,
		"trades": {"proposed": 0, "accepted": 0, "rejected": 0, "expired": 0, "invalidated": 0},
		"auctions": {"opened": 0, "sold": 0}, "purchases": 0, "upgrades": 0, "rescues": 0,
		"liquidations": 0, "abilities": 0, "rent_paid": 0, "rent_events": 0,
		"bankruptcies": [], "round_samples": {}, "stuck": false, "flows": {},
		"rent_by_level": {}, "max_rent": 0, "rents_ge_1000": 0,
	}
	var tracker := {"seq": 0, "tx": 0}
	# Events emitted by create() (MatchStarted/TurnStarted) are not returned by
	# submit/advance; account for them from the engine state.
	tracker["seq"] = engine.state.seq
	_sample_round(engine, st)

	var steps := 0
	while not engine.is_ended() and steps < MAX_STEPS:
		steps += 1
		var s := engine.state
		var deadline := engine.current_deadline_ms()
		if clock.now_ms() >= deadline:
			# e.g. Rescue settled with no turn time left: the timer has run out.
			_absorb(engine.advance(), engine, st, tracker, check_inv)
			continue
		var cmd := {}
		var delay := 0
		if s.phase == GameState.AUCTION:
			for k in n_players:
				var bseat := (s.current_seat + 1 + k) % n_players
				cmd = bots[bseat].decide(engine)
				if not cmd.is_empty():
					break
			delay = tm["bid"][0] + sim_rng.range_int(tm["bid"][1])
		else:
			var actor := s.current_seat
			match s.phase:
				GameState.TRADE_PENDING: actor = s.trade["to"]
				GameState.RESCUE: actor = s.rescue["debtor"]
				GameState.AWAIT_CHOICE: actor = s.choice["seat"]
			if not bots[actor].wants_to_idle():
				cmd = bots[actor].decide(engine)
			match s.phase:
				GameState.AWAIT_ROLL: delay = tm["roll"][0] + sim_rng.range_int(tm["roll"][1])
				GameState.TRADE_PENDING: delay = tm["trade"][0] + sim_rng.range_int(tm["trade"][1])
				GameState.STRATEGY: delay = tm["strategy"][0] + sim_rng.range_int(tm["strategy"][1])
				_: delay = tm["other"][0] + sim_rng.range_int(tm["other"][1])
		if cmd.is_empty():
			clock.set_now(maxi(clock.now_ms(), deadline))
			_absorb(engine.advance(), engine, st, tracker, check_inv)
			continue
		clock.advance(clampi(delay, 0, maxi(0, deadline - clock.now_ms() - 1)))
		var res := engine.submit(cmd)
		if not res["ok"]:
			st["rejections"].append("%s %s in %s" % [cmd["type"], res["error"], s.phase])
			clock.set_now(maxi(clock.now_ms(), engine.current_deadline_ms()))
			_absorb(engine.advance(), engine, st, tracker, check_inv)
			continue
		_absorb(res["events"], engine, st, tracker, check_inv)
		if cmd["type"] == ErCommand.ROLL_DICE and not engine.is_ended():
			var steps_moved: int = s.last_roll[0] + s.last_roll[1] if s.last_roll.size() == 2 else 0
			var anim: int = tm["anim_base"] + tm["anim_per_space"] * steps_moved
			clock.advance(clampi(anim, 0, maxi(0, engine.current_deadline_ms() - clock.now_ms() - 1)))
	if not engine.is_ended():
		st["stuck"] = true
	var s2 := engine.state
	st["end_reason"] = s2.end_reason
	st["rounds"] = s2.round
	st["turns"] = s2.turn_number
	st["duration_ms"] = clock.now_ms() - s2.match_start_ms
	st["results"] = s2.results
	st["state_hash"] = s2.state_hash()
	st["final_seq"] = s2.seq
	st["unowned_at_end"] = s2.owner.values().filter(func(o): return o == GameState.BANK).size()
	# Final per-seat valuation under alternative formulas (balance review).
	var final: Array = []
	for p in s2.players:
		var book: int = p["cash"]
		var levels := 0
		for pid in s2.properties_of(p["seat"]):
			var t := engine.config.tier_of(pid)
			book += t["price"] + s2.level[pid] * t["upgrade_cost"]
			levels += s2.level[pid]
		final.append({"seat": p["seat"], "bankrupt": p["bankrupt"], "cash": p["cash"],
			"liquidation_nw": engine.net_worth(p["seat"]), "book_value": book if not p["bankrupt"] else 0,
			"properties": s2.properties_of(p["seat"]).size(), "levels": levels,
			"districts": engine.completed_districts(p["seat"]) if not p["bankrupt"] else 0})
	st["final"] = final
	if opts.get("return_engine", false):
		st["engine"] = engine
	return st


static func _absorb(events: Array, engine: GameEngine, st: Dictionary, tracker: Dictionary, check_inv: bool) -> void:
	if events.is_empty():
		return
	var chk := Invariants.check_events(events, tracker["seq"], tracker["tx"])
	tracker["seq"] = chk["seq"]
	tracker["tx"] = chk["tx"]
	st["invariant_errors"].append_array(chk["errors"])
	st["events"] += events.size()
	for ev in events:
		var d: Dictionary = ev["data"]
		match ev["type"]:
			"DeadlineExpired": st["timeouts"] += 1
			"TradeProposed": st["trades"]["proposed"] += 1
			"TradeResolved": st["trades"][d["status"]] += 1
			"AuctionOpened": st["auctions"]["opened"] += 1
			"AuctionClosed":
				if d["winner"] != GameState.BANK:
					st["auctions"]["sold"] += 1
			"PropertyBought": st["purchases"] += 1
			"UpgradeBuilt": st["upgrades"] += 1
			"RescueStarted": st["rescues"] += 1
			"PropertyLiquidated": st["liquidations"] += 1
			"AbilityUsed": st["abilities"] += 1
			"CashChanged":
				var bucket: String = str(d["reason"]).get_slice(":", 0)
				st["flows"][bucket] = st["flows"].get(bucket, 0) + d["amount"]
			"RentCharged":
				st["rent_paid"] += d["amount"]
				st["rent_events"] += 1
				var lv: String = str(engine.state.level[d["property_id"]])
				if not st["rent_by_level"].has(lv):
					st["rent_by_level"][lv] = [0, 0]
				st["rent_by_level"][lv][0] += 1
				st["rent_by_level"][lv][1] += d["amount"]
				st["max_rent"] = maxi(st["max_rent"], d["amount"])
				if d["amount"] >= 1000:
					st["rents_ge_1000"] += 1
			"PlayerBankrupt":
				st["bankruptcies"].append({"seat": d["seat"], "turn": engine.state.turn_number, "debt": d["debt"],
					"round": engine.state.round, "reason": d["reason"],
					"character": engine.state.player(d["seat"])["character_id"]})
			"TurnStarted":
				_sample_round(engine, st)
	if check_inv:
		var errs := Invariants.check(engine)
		for e in errs:
			st["invariant_errors"].append("v%d: %s" % [engine.state.state_version, e])


## Records cash / net worth / property counts at the first turn of each round.
static func _sample_round(engine: GameEngine, st: Dictionary) -> void:
	var s := engine.state
	if st["round_samples"].has(s.round):
		return
	var cash: Array = []
	var worth: Array = []
	var props: Array = []
	var book: Array = []
	for p in s.players:
		cash.append(p["cash"])
		worth.append(engine.net_worth(p["seat"]))
		props.append(s.properties_of(p["seat"]).size())
		# Book value = cash + purchase price + building cost paid (leader metric
		# that does not punish investing the way liquidation-based net worth does).
		var bv: int = p["cash"]
		for pid in s.properties_of(p["seat"]):
			var t := engine.config.tier_of(pid)
			bv += t["price"] + s.level[pid] * t["upgrade_cost"]
		book.append(bv)
	st["round_samples"][s.round] = {"cash": cash, "net_worth": worth, "properties": props, "book_value": book,
		"t_ms": engine.clock.now_ms() - s.match_start_ms}
