## Heuristic scripted player for simulations and soak tests. It only reads
## engine queries and state, and acts by building ordinary commands, exactly
## like a remote client would. Bots are deliberately simple; they exist to
## exercise every rule path, not to play well.
class_name BotPlayer
extends RefCounted

var seat: int
var player_id: String
var reserve: int            # cash the bot tries to keep
var buy_factor: int         # % of price it values property at in auctions
var trade_premium: int      # % of price it offers to complete a district
var trade_chance_pct: int
var idle_chance_pct: int    # chance to let a timer expire (exercises timeouts)
## Experiment knob (M1.1): in the last N rounds the bot stops buying, bidding,
## upgrading and proposing trades (an end-game cash-hoarding strategy).
var endgame_freeze_rounds := 0
var _rng: ErRng
var _cmd_counter := 0


func _init(p_seat: int, p_player_id: String, rng: ErRng, p_idle_chance_pct: int = 3) -> void:
	seat = p_seat
	player_id = p_player_id
	_rng = rng
	reserve = 60 + rng.range_int(5) * 40           # 60..220
	buy_factor = 80 + rng.range_int(5) * 15        # 80..140
	trade_premium = 170 + rng.range_int(5) * 30    # 170..290
	trade_chance_pct = 25 + rng.range_int(4) * 15  # 25..70
	idle_chance_pct = p_idle_chance_pct


func wants_to_idle() -> bool:
	return _rng.range_int(100) < idle_chance_pct


func _cmd(engine: GameEngine, type: String, payload: Dictionary = {}) -> Dictionary:
	_cmd_counter += 1
	return ErCommand.make(engine.state.match_id, player_id, "%s-%d" % [player_id, _cmd_counter],
		engine.state.state_version, type, payload)


func _cash(engine: GameEngine) -> int:
	return engine.state.player(seat)["cash"]


## Returns a command, or {} when the bot chooses to do nothing right now.
func decide(engine: GameEngine) -> Dictionary:
	var s := engine.state
	match s.phase:
		GameState.AWAIT_ROLL:
			return _cmd(engine, ErCommand.ROLL_DICE)
		GameState.AWAIT_BUY:
			return _decide_buy(engine)
		GameState.AWAIT_CHOICE:
			return _decide_choice(engine)
		GameState.STRATEGY:
			return _decide_strategy(engine)
		GameState.AUCTION:
			return _decide_bid(engine)
		GameState.TRADE_PENDING:
			return _decide_trade_response(engine)
		GameState.RESCUE:
			return _decide_rescue(engine)
	return {}


func _frozen(engine: GameEngine) -> bool:
	return endgame_freeze_rounds > 0 and engine.state.round > engine.config.balance["max_rounds"] - endgame_freeze_rounds


func _would_complete(engine: GameEngine, pid: String, for_seat: int) -> bool:
	var did: String = engine.config.property_district[pid]
	for other in engine.config.district_props[did]:
		if other != pid and engine.state.owner[other] != for_seat:
			return false
	return true


func _decide_buy(engine: GameEngine) -> Dictionary:
	var pid := engine.property_at(engine.state.player(seat)["position"])
	var price: int = engine.config.tier_of(pid)["price"]
	var cash := _cash(engine)
	if _frozen(engine):
		return _cmd(engine, ErCommand.PASS_PROPERTY, {"property_id": pid})
	if price <= cash and (cash - price >= reserve or _would_complete(engine, pid, seat)):
		return _cmd(engine, ErCommand.BUY_PROPERTY, {"property_id": pid})
	return _cmd(engine, ErCommand.PASS_PROPERTY, {"property_id": pid})


func _decide_bid(engine: GameEngine) -> Dictionary:
	var a := engine.state.auction
	if engine.state.player(seat)["bankrupt"] or a["high_seat"] == seat or _frozen(engine):
		return {}
	var price: int = engine.config.tier_of(a["property_id"])["price"]
	var value := price * buy_factor / 100
	if _would_complete(engine, a["property_id"], seat):
		value = value * 3 / 2
	var cap := mini(value, _cash(engine) - reserve / 2)
	var cfg: Dictionary = engine.config.balance["auction"]
	var need: int = a["min_bid"] if a["high_seat"] == GameState.BANK else a["high_bid"] + cfg["min_increment"]
	if need > cap:
		return {}
	# Bid the minimum plus a small random step so auctions vary.
	var bid := mini(cap, need + _rng.range_int(3) * cfg["min_increment"])
	return _cmd(engine, ErCommand.PLACE_BID, {"auction_id": a["auction_id"], "amount": bid})


func _option_score(engine: GameEngine, opt: Dictionary) -> int:
	var score: int = -opt["cost"]
	var props := engine.state.properties_of(seat).size()
	for e in opt["effects"]:
		match e["type"]:
			"cash": score += e["amount"]
			"per_property_cash": score += mini(e["max_total"], props * e["amount"])
			"delayed_payout": score += e["reward"] * e["chance_pct"] / 100
			"rent_cap": score += 50
			"rent_discount_next": score += 35
			"upgrade_discount_next": score += 50 if engine.completed_districts(seat) > 0 else 5
			"rent_modifier": score += e["pct"] * maxi(1, props) / 4
	return score


func _decide_choice(engine: GameEngine) -> Dictionary:
	var c := engine.state.choice
	var best := -1
	var best_score := -(1 << 30)
	for i in c["options"].size():
		var opt: Dictionary = c["options"][i]
		if opt["cost"] > 0 and _cash(engine) - opt["cost"] < reserve:
			continue
		var sc := _option_score(engine, opt)
		if sc > best_score:
			best_score = sc
			best = i
	if best < 0:
		best = c["default_option"]
	return _cmd(engine, ErCommand.CHOOSE_OPTION, {"choice_id": c["choice_id"], "option_id": c["options"][best]["option_id"]})


func _decide_strategy(engine: GameEngine) -> Dictionary:
	var s := engine.state
	if s.strategy_used:
		return _cmd(engine, ErCommand.END_TURN)
	if _frozen(engine):
		return _cmd(engine, ErCommand.END_TURN)
	var cash := _cash(engine)
	# 1) Upgrade: lowest level first, then cheapest.
	var best_pid := ""
	var best_key := 1 << 30
	for pid in s.properties_of(seat):
		if engine.can_upgrade(seat, pid) != "":
			continue
		var cost: int = engine.upgrade_quote(seat, pid)["amount"]
		if cash - cost < reserve:
			continue
		var key: int = s.level[pid] * 100000 + cost
		if key < best_key:
			best_key = key
			best_pid = pid
	if best_pid != "":
		return _cmd(engine, ErCommand.UPGRADE, {"property_id": best_pid})
	# 2) Trade to complete a district (own 2 of 3, third held by a rival).
	if _rng.range_int(100) < trade_chance_pct:
		var offer := _find_trade(engine)
		if not offer.is_empty():
			return _cmd(engine, ErCommand.PROPOSE_TRADE, offer)
	# 3) Character ability.
	if engine.ability_available(seat):
		var ability: Dictionary = engine.config.character_by_id[s.player(seat)["character_id"]]["ability"]
		var useful := true
		if ability["ability_id"] == "DIVIDEND_CALL":
			useful = s.properties_of(seat).size() >= 3
		if useful:
			return _cmd(engine, ErCommand.USE_ABILITY, {"ability_id": ability["ability_id"]})
	return _cmd(engine, ErCommand.END_TURN)


func _find_trade(engine: GameEngine) -> Dictionary:
	var s := engine.state
	for did in engine.config.district_props:
		var mine := 0
		var target := ""
		for pid in engine.config.district_props[did]:
			if s.owner[pid] == seat:
				mine += 1
			elif s.owner[pid] != GameState.BANK and s.level[pid] == 0:
				target = pid
		if mine == 2 and target != "":
			var price: int = engine.config.tier_of(target)["price"]
			var offer := price * trade_premium / 100
			if _cash(engine) - offer >= reserve:
				var to_id: String = s.player(s.owner[target])["player_id"]
				return {"to_player_id": to_id, "give": {"cash": offer, "property_ids": []},
					"take": {"cash": 0, "property_ids": [target]}}
	return {}


func _decide_trade_response(engine: GameEngine) -> Dictionary:
	var t := engine.state.trade
	if t["to"] != seat:
		return {}
	var value_out := 0
	for pid in t["take"]["property_ids"]:
		var price: int = engine.config.tier_of(pid)["price"]
		value_out += price * (180 if _would_complete(engine, pid, t["from"]) else 120) / 100
	var value_in := 0
	for pid in t["give"]["property_ids"]:
		value_in += engine.config.tier_of(pid)["price"]
	var net: int = t["give"]["cash"] - t["take"]["cash"] + value_in - value_out
	return _cmd(engine, ErCommand.RESPOND_TRADE, {"trade_id": t["trade_id"], "accept": net >= 0})


func _decide_rescue(engine: GameEngine) -> Dictionary:
	var r := engine.state.rescue
	if r["debtor"] != seat:
		return {}
	var owned := engine.state.properties_of(seat)
	owned.sort_custom(func(a, b): return engine.liquidation_value(a) < engine.liquidation_value(b))
	var cash := _cash(engine)
	var pick: Array = []
	for pid in owned:
		if cash >= r["amount"]:
			break
		pick.append(pid)
		cash += engine.liquidation_value(pid)
	if cash < r["amount"] or pick.is_empty():
		return _cmd(engine, ErCommand.DECLARE_BANKRUPTCY)
	return _cmd(engine, ErCommand.LIQUIDATE, {"property_ids": pick})
