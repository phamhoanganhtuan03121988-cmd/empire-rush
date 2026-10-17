## Runs one complete bot match against the rules engine with a simulated clock
## and returns structured metrics. Fully deterministic per seed: the engine RNG
## is seeded with `seed_value`, bot behaviour and think times use a separate
## RNG derived from it.
##
## Time model (presentation time the real game will spend; documented in
## docs/M1_REPORT.md): decisions take 0.6-5 s, the dice + token animation takes
## 1.8 s + 0.25 s per space, auctions run until their timer, idle bots wait
## out the full timer.
class_name MatchSimulator
extends RefCounted

const CHARACTER_ORDER := ["TYCOON", "INVESTOR", "NEGOTIATOR"]
const MAX_STEPS := 50000


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
	var bots: Array = []
	for i in n_players:
		bots.append(BotPlayer.new(i, "p%d" % i, sim_rng, idle_pct))

	var st := {
		"seed": seed_value, "players": n_players,
		"characters": seats.map(func(x): return x["character_id"]),
		"invariant_errors": [], "rejections": [], "timeouts": 0, "events": 0,
		"trades": {"proposed": 0, "accepted": 0, "rejected": 0, "expired": 0, "invalidated": 0},
		"auctions": {"opened": 0, "sold": 0}, "purchases": 0, "upgrades": 0, "rescues": 0,
		"liquidations": 0, "abilities": 0, "rent_paid": 0, "rent_events": 0,
		"bankruptcies": [], "round_samples": {}, "stuck": false,
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
			delay = 600 + sim_rng.range_int(1400)
		else:
			var actor := s.current_seat
			match s.phase:
				GameState.TRADE_PENDING: actor = s.trade["to"]
				GameState.RESCUE: actor = s.rescue["debtor"]
				GameState.AWAIT_CHOICE: actor = s.choice["seat"]
			if not bots[actor].wants_to_idle():
				cmd = bots[actor].decide(engine)
			match s.phase:
				GameState.AWAIT_ROLL: delay = 800 + sim_rng.range_int(1700)
				GameState.TRADE_PENDING: delay = 2000 + sim_rng.range_int(7000)
				GameState.STRATEGY: delay = 700 + sim_rng.range_int(2300)
				_: delay = 1500 + sim_rng.range_int(3500)
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
			var anim := 1800 + 250 * steps_moved
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
			"RentCharged":
				st["rent_paid"] += d["amount"]
				st["rent_events"] += 1
			"PlayerBankrupt":
				st["bankruptcies"].append({"seat": d["seat"], "turn": engine.state.turn_number,
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
