## Authoritative EMPIRE RUSH rules engine (offline + future server).
##
## Pure GDScript: no Node, no scene tree, no rendering, no transport. Time comes
## from an injected MatchClock and randomness from the RNG stored in GameState,
## so the same seed + the same command/advance log always yields the same state.
##
## Two entry points mutate state:
##   submit(command)  - a player's intent (validated, idempotent, versioned)
##   advance()        - applies every deadline that has expired at clock.now_ms()
## Each accepted command / timeout step bumps state_version exactly once.
## Every handler validates first and mutates only after validation passed, so a
## rejected command never changes state.
class_name GameEngine
extends RefCounted

const BANK := GameState.BANK
const MAX_ADVANCE_STEPS := 64

var config: GameConfig
var state: GameState
var clock: MatchClock

## Structured match log: every emitted event, in order.
var event_log: Array = []
## Replay log: [{"at": ms, "cmd": Dictionary}] or [{"at": ms, "advance": true}].
var input_log: Array = []
## When false, event_log is not kept (large simulations keep only counters).
var keep_event_log := true

var _pending: Array = []


## seats: [{player_id, character_id}] in turn order (2-4 entries).
static func create(p_config: GameConfig, p_clock: MatchClock, seats: Array, seed_value: int,
		match_id: String = "local") -> GameEngine:
	assert(p_config != null and p_config.is_valid(), "invalid GameConfig: %s" % str(p_config.errors if p_config else "null"))
	assert(seats.size() >= 2 and seats.size() <= 4, "2-4 players")
	var e := GameEngine.new()
	e.config = p_config
	e.clock = p_clock
	var s := GameState.new()
	e.state = s
	s.match_id = match_id
	s.seed_value = seed_value
	s.rng.set_seed(seed_value)
	s.match_start_ms = p_clock.now_ms()
	var bal := p_config.balance
	for i in seats.size():
		var ch: Dictionary = p_config.character_by_id.get(seats[i]["character_id"], {})
		assert(not ch.is_empty(), "unknown character " + str(seats[i]["character_id"]))
		var ability: Dictionary = ch["ability"]
		s.players.append({
			"seat": i, "player_id": seats[i]["player_id"], "character_id": seats[i]["character_id"],
			"cash": bal["starting_cash"], "position": 0, "bankrupt": false, "bankrupt_turn": 0,
			"ability_uses_left": ability.get("uses_per_match", 0), "ability_ready_round": 1,
		})
	for pid in p_config.property_ids:
		s.owner[pid] = BANK
		s.level[pid] = 0
	s.bank_net_issued = bal["starting_cash"] * seats.size()
	s.event_deck = p_config.card_ids.duplicate()
	s.rng.shuffle(s.event_deck)
	s.phase = GameState.AWAIT_ROLL
	s.turn_deadline_ms = p_clock.now_ms() + bal["turn_timer_ms"]
	e._emit("MatchStarted", {
		"seats": s.players.duplicate(true), "board_id": p_config.board.get("board_id", ""),
		"seed_commitment": str(seed_value).sha256_text(),
	})
	e._emit("TurnStarted", {"seat": 0, "round": 1, "turn_number": 1, "deadline_ms": s.turn_deadline_ms})
	e._commit()
	return e


# =============================================================================
# Public API
# =============================================================================

func submit(cmd: Dictionary) -> Dictionary:
	var shape_err := _validate_shape(cmd)
	if shape_err != "":
		return _reject(shape_err)
	var seat := state.seat_of_player_id(cmd["player_id"])
	if seat < 0:
		return _reject(ErCommand.E_NOT_SEATED)
	var key := "%d|%s" % [seat, cmd["command_id"]]
	if state.processed.has(key):
		var dup: Dictionary = state.processed[key].duplicate()
		dup["duplicate"] = true
		dup["events"] = []
		return dup
	if state.phase == GameState.ENDED:
		return _reject(ErCommand.E_MATCH_ENDED)
	if cmd["expected_state_version"] != state.state_version:
		var r := _reject(ErCommand.E_STALE_STATE)
		r["current_state_version"] = state.state_version
		return r
	if clock.now_ms() >= current_deadline_ms():
		return _reject(ErCommand.E_DEADLINE_PASSED)
	var payload: Dictionary = cmd["payload"]
	var err := ""
	match cmd["type"]:
		ErCommand.ROLL_DICE: err = _cmd_roll(seat)
		ErCommand.BUY_PROPERTY: err = _cmd_buy(seat, payload)
		ErCommand.PASS_PROPERTY: err = _cmd_pass(seat, payload)
		ErCommand.PLACE_BID: err = _cmd_bid(seat, payload)
		ErCommand.CHOOSE_OPTION: err = _cmd_choose(seat, payload)
		ErCommand.UPGRADE: err = _cmd_upgrade(seat, payload)
		ErCommand.PROPOSE_TRADE: err = _cmd_propose_trade(seat, payload)
		ErCommand.RESPOND_TRADE: err = _cmd_respond_trade(seat, payload)
		ErCommand.USE_ABILITY: err = _cmd_use_ability(seat, payload)
		ErCommand.LIQUIDATE: err = _cmd_liquidate(seat, payload)
		ErCommand.DECLARE_BANKRUPTCY: err = _cmd_declare_bankruptcy(seat)
		ErCommand.END_TURN: err = _cmd_end_turn(seat)
		_: err = ErCommand.E_BAD_REQUEST
	if err != "":
		assert(_pending.is_empty(), "handler emitted events before rejecting")
		return _reject(err)
	var events := _commit()
	var result := {"ok": true, "command_id": cmd["command_id"], "state_version": state.state_version}
	state.processed[key] = result.duplicate()
	result["events"] = events
	input_log.append({"at": clock.now_ms(), "cmd": cmd.duplicate(true)})
	return result


## Applies all expired deadlines at the current clock time. Returns the events.
func advance() -> Array:
	var all: Array = []
	var steps := 0
	while state.phase != GameState.ENDED and steps < MAX_ADVANCE_STEPS:
		if clock.now_ms() < current_deadline_ms():
			break
		_handle_timeout()
		all.append_array(_commit())
		steps += 1
	assert(steps < MAX_ADVANCE_STEPS, "advance() did not converge")
	if steps > 0:
		input_log.append({"at": clock.now_ms(), "advance": true})
	return all


func current_deadline_ms() -> int:
	match state.phase:
		GameState.AUCTION: return state.auction["deadline_ms"]
		GameState.TRADE_PENDING: return state.trade["deadline_ms"]
		GameState.RESCUE: return state.rescue["deadline_ms"]
		GameState.ENDED: return 1 << 62
	return state.turn_deadline_ms


func is_ended() -> bool:
	return state.phase == GameState.ENDED


## State a client may see: hides RNG state and the event-deck order.
func public_snapshot() -> Dictionary:
	var d := state.to_dict()
	d.erase("rng")
	d.erase("seed")
	d["event_deck"] = state.event_deck.size()
	return d


# --- pure queries (also used by bots and UI previews) -------------------------

func property_at(position: int) -> String:
	var sp: Dictionary = config.spaces[position]
	return sp.get("property_id", "")


func district_complete(district_id: String) -> bool:
	var props: Array = config.district_props[district_id]
	var o = state.owner[props[0]]
	if o == BANK:
		return false
	for pid in props:
		if state.owner[pid] != o:
			return false
	return true


func completed_districts(seat: int) -> int:
	var n := 0
	for did in config.district_props:
		if district_complete(did) and state.owner[config.district_props[did][0]] == seat:
			n += 1
	return n


func liquidation_value(pid: String) -> int:
	var t := config.tier_of(pid)
	return t["liquidation_value"] + state.level[pid] * t["upgrade_cost"] * config.balance["upgrade_refund_pct"] / 100


## MVP net worth (GDD §5): cash + liquidation value of owned properties
## (buildings included). Objective bonuses excluded (G11); no debt in MVP.
func net_worth(seat: int) -> int:
	var p := state.player(seat)
	if p["bankrupt"]:
		return 0
	var total: int = p["cash"]
	for pid in state.properties_of(seat):
		total += liquidation_value(pid)
	return total


## G3: taxable wealth == MVP net worth.
func wealth_tax(seat: int) -> int:
	var wt: Dictionary = config.balance["wealth_tax"]
	return mini(wt["cap"], net_worth(seat) * wt["pct"] / 100)


## Rent before payer-side modifiers. G6: exactly one multiplier row applies.
func gross_rent(pid: String) -> int:
	var o: int = state.owner[pid]
	if o == BANK:
		return 0
	var t := config.tier_of(pid)
	var mult: Dictionary = config.balance["rent_multiplier_pct"]
	var lv: int = state.level[pid]
	var pct: int
	if lv == 0:
		pct = mult["level0_district_complete"] if district_complete(config.property_district[pid]) else mult["level0_incomplete"]
	else:
		pct = mult["level%d" % lv]
	var rent: int = t["base_rent"] * pct / 100
	# Event modifiers on the owner side are summed (additive, never compounded).
	var adj := 0
	var tags: Array = config.district_tags[config.property_district[pid]]
	for m in state.modifiers:
		if m["kind"] != "rent_pct":
			continue
		if (m["seat"] == o) or (m["tag"] != "" and m["tag"] in tags):
			adj += m["pct"]
	return maxi(0, rent * (100 + adj) / 100)


## Final rent for `payer` plus the payer modifier it would consume.
func rent_quote(pid: String, payer: int) -> Dictionary:
	var rent := gross_rent(pid)
	var used_id := ""
	for m in state.modifiers:
		if m["kind"] == "rent_discount" and m["seat"] == payer and m["uses"] > 0:
			rent = rent * (100 - m["pct"]) / 100
			used_id = m["modifier_id"]
			break
	for m in state.modifiers:
		if m["kind"] == "rent_cap" and m["seat"] == payer:
			rent = mini(rent, m["cap"])
	return {"amount": rent, "consumes": used_id}


func upgrade_quote(seat: int, pid: String) -> Dictionary:
	var pct := 0
	var ability: Dictionary = config.character_by_id[state.player(seat)["character_id"]]["ability"]
	if ability.get("kind") == "passive":
		pct += ability.get("upgrade_discount_pct", 0)
	var used_id := ""
	for m in state.modifiers:
		if m["kind"] == "upgrade_discount" and m["seat"] == seat and m["uses"] > 0:
			pct += m["pct"]
			used_id = m["modifier_id"]
			break
	pct = mini(pct, config.balance["max_total_discount_pct"])
	var cost: int = config.tier_of(pid)["upgrade_cost"] * (100 - pct) / 100
	return {"amount": cost, "consumes": used_id}


func can_upgrade(seat: int, pid: String) -> String:
	if not state.owner.has(pid):
		return ErCommand.E_INVALID_TARGET
	if state.owner[pid] != seat:
		return ErCommand.E_NOT_OWNER
	if not district_complete(config.property_district[pid]):
		return ErCommand.E_DISTRICT_INCOMPLETE
	if state.level[pid] >= config.balance["max_level"]:
		return ErCommand.E_MAX_LEVEL
	if upgrade_quote(seat, pid)["amount"] > state.player(seat)["cash"]:
		return ErCommand.E_INSUFFICIENT_FUNDS
	return ""


func ability_available(seat: int) -> bool:
	var p := state.player(seat)
	var ability: Dictionary = config.character_by_id[p["character_id"]]["ability"]
	return ability.get("kind") == "active" and p["ability_uses_left"] > 0 and state.round >= p["ability_ready_round"]


# =============================================================================
# Command handlers: validate fully, then mutate. Return "" on success.
# =============================================================================

func _require_turn(seat: int, phase: String) -> String:
	if state.phase != phase:
		return ErCommand.E_WRONG_PHASE
	if seat != state.current_seat:
		return ErCommand.E_NOT_YOUR_TURN
	return ""


func _cmd_roll(seat: int) -> String:
	var err := _require_turn(seat, GameState.AWAIT_ROLL)
	if err != "":
		return err
	_do_roll()
	return ""


func _cmd_buy(seat: int, payload: Dictionary) -> String:
	var err := _require_turn(seat, GameState.AWAIT_BUY)
	if err != "":
		return err
	var pid := property_at(state.player(seat)["position"])
	if payload.get("property_id") != pid:
		return ErCommand.E_INVALID_TARGET
	var price: int = config.tier_of(pid)["price"]
	if state.player(seat)["cash"] < price:
		return ErCommand.E_INSUFFICIENT_FUNDS
	_transfer(seat, BANK, price, "purchase")
	state.owner[pid] = seat
	_emit("PropertyBought", {"seat": seat, "property_id": pid, "price": price})
	_to_strategy()
	return ""


func _cmd_pass(seat: int, payload: Dictionary) -> String:
	var err := _require_turn(seat, GameState.AWAIT_BUY)
	if err != "":
		return err
	var pid := property_at(state.player(seat)["position"])
	if payload.get("property_id") != pid:
		return ErCommand.E_INVALID_TARGET
	_emit("PropertyPassed", {"seat": seat, "property_id": pid})
	_open_auction(pid)
	return ""


func _cmd_bid(seat: int, payload: Dictionary) -> String:
	if state.phase != GameState.AUCTION:
		return ErCommand.E_WRONG_PHASE
	var a := state.auction
	if payload.get("auction_id") != a["auction_id"]:
		return ErCommand.E_INVALID_TARGET
	if state.player(seat)["bankrupt"]:
		return ErCommand.E_INVALID_TARGET
	var amount = payload.get("amount")
	if typeof(amount) != TYPE_INT:
		return ErCommand.E_BAD_REQUEST
	if seat == a["high_seat"]:
		return ErCommand.E_INVALID_TARGET
	var cfg: Dictionary = config.balance["auction"]
	var minimum: int = a["min_bid"] if a["high_seat"] == BANK else a["high_bid"] + cfg["min_increment"]
	if amount < minimum:
		return ErCommand.E_BID_TOO_LOW
	if amount > state.player(seat)["cash"]:
		return ErCommand.E_INSUFFICIENT_FUNDS
	a["high_bid"] = amount
	a["high_seat"] = seat
	_emit("BidPlaced", {"auction_id": a["auction_id"], "seat": seat, "amount": amount})
	var now := clock.now_ms()
	if a["deadline_ms"] - now <= cfg["anti_snipe_window_ms"] and a["extensions"] < cfg["max_extensions"]:
		a["deadline_ms"] += cfg["anti_snipe_extension_ms"]
		a["extensions"] += 1
		_emit("AuctionExtended", {"auction_id": a["auction_id"], "deadline_ms": a["deadline_ms"], "extensions": a["extensions"]})
	return ""


func _cmd_choose(seat: int, payload: Dictionary) -> String:
	if state.phase != GameState.AWAIT_CHOICE:
		return ErCommand.E_WRONG_PHASE
	if seat != state.choice["seat"]:
		return ErCommand.E_NOT_YOUR_TURN
	if payload.get("choice_id") != state.choice["choice_id"]:
		return ErCommand.E_INVALID_TARGET
	var options: Array = state.choice["options"]
	var idx := -1
	for i in options.size():
		if options[i]["option_id"] == payload.get("option_id"):
			idx = i
	if idx < 0:
		return ErCommand.E_INVALID_TARGET
	if options[idx]["cost"] > state.player(seat)["cash"]:
		return ErCommand.E_INSUFFICIENT_FUNDS
	_resolve_choice(idx, false)
	return ""


func _cmd_upgrade(seat: int, payload: Dictionary) -> String:
	var err := _require_turn(seat, GameState.STRATEGY)
	if err != "":
		return err
	if state.strategy_used:
		return ErCommand.E_ACTION_USED
	var pid = payload.get("property_id")
	if typeof(pid) != TYPE_STRING:
		return ErCommand.E_BAD_REQUEST
	err = can_upgrade(seat, pid)
	if err != "":
		return err
	var q := upgrade_quote(seat, pid)
	_transfer(seat, BANK, q["amount"], "upgrade")
	_consume_modifier(q["consumes"])
	state.level[pid] += 1
	_emit("UpgradeBuilt", {"seat": seat, "property_id": pid, "level": state.level[pid], "cost": q["amount"]})
	state.strategy_used = true
	_end_turn("action")
	return ""


func _cmd_use_ability(seat: int, payload: Dictionary) -> String:
	var err := _require_turn(seat, GameState.STRATEGY)
	if err != "":
		return err
	if state.strategy_used:
		return ErCommand.E_ACTION_USED
	var p := state.player(seat)
	var ability: Dictionary = config.character_by_id[p["character_id"]]["ability"]
	if payload.get("ability_id") != ability["ability_id"] or not ability_available(seat):
		return ErCommand.E_ABILITY_UNAVAILABLE
	p["ability_uses_left"] -= 1
	p["ability_ready_round"] = state.round + ability["cooldown_rounds"]
	_emit("AbilityUsed", {"seat": seat, "ability_id": ability["ability_id"], "uses_left": p["ability_uses_left"]})
	var paid := _apply_effects(seat, ability.get("effects", []), "ability:" + ability["ability_id"])
	assert(paid, "abilities must not charge the player")
	state.strategy_used = true
	_end_turn("action")
	return ""


func _cmd_propose_trade(seat: int, payload: Dictionary) -> String:
	var in_rescue := state.phase == GameState.RESCUE
	if in_rescue:
		if seat != state.rescue["debtor"]:
			return ErCommand.E_NOT_YOUR_TURN
		if state.rescue["trade_used"]:
			return ErCommand.E_ACTION_USED
	else:
		var err := _require_turn(seat, GameState.STRATEGY)
		if err != "":
			return err
		if state.strategy_used:
			return ErCommand.E_ACTION_USED
	var to_seat := state.seat_of_player_id(str(payload.get("to_player_id", "")))
	var give = payload.get("give")
	var take = payload.get("take")
	if typeof(give) != TYPE_DICTIONARY or typeof(take) != TYPE_DICTIONARY:
		return ErCommand.E_BAD_REQUEST
	var terms_err := _validate_trade_terms(seat, to_seat, give, take)
	if terms_err != "":
		return terms_err
	var now := clock.now_ms()
	var deadline: int = now + config.balance["trade_timer_ms"]
	if in_rescue:
		deadline = mini(deadline, state.rescue["deadline_ms"])
		state.rescue["trade_used"] = true
	else:
		state.strategy_used = true
		_pause_turn()
	state.trade = {
		"trade_id": state.alloc_id("T"), "from": seat, "to": to_seat,
		"give": _norm_side(give), "take": _norm_side(take),
		"deadline_ms": deadline, "return_phase": state.phase,
	}
	state.phase = GameState.TRADE_PENDING
	_emit("TradeProposed", state.trade.duplicate(true))
	return ""


func _cmd_respond_trade(seat: int, payload: Dictionary) -> String:
	if state.phase != GameState.TRADE_PENDING:
		return ErCommand.E_WRONG_PHASE
	var t := state.trade
	if seat != t["to"]:
		return ErCommand.E_NOT_YOUR_TURN
	if payload.get("trade_id") != t["trade_id"] or typeof(payload.get("accept")) != TYPE_BOOL:
		return ErCommand.E_BAD_REQUEST
	if not payload["accept"]:
		_finish_trade("rejected")
		return ""
	# Re-validate at acceptance time (GDD §7); invalid now => nothing moves.
	if _validate_trade_terms(t["from"], t["to"], t["give"], t["take"]) != "":
		_finish_trade("invalidated")
		return ""
	_transfer(t["from"], t["to"], t["give"]["cash"], "trade")
	_transfer(t["to"], t["from"], t["take"]["cash"], "trade")
	for pid in t["give"]["property_ids"]:
		state.owner[pid] = t["to"]
		_emit("PropertyTransferred", {"property_id": pid, "from": t["from"], "to": t["to"], "reason": "trade"})
	for pid in t["take"]["property_ids"]:
		state.owner[pid] = t["from"]
		_emit("PropertyTransferred", {"property_id": pid, "from": t["to"], "to": t["from"], "reason": "trade"})
	_finish_trade("accepted")
	return ""


func _cmd_liquidate(seat: int, payload: Dictionary) -> String:
	if state.phase != GameState.RESCUE:
		return ErCommand.E_WRONG_PHASE
	if seat != state.rescue["debtor"]:
		return ErCommand.E_NOT_YOUR_TURN
	var ids = payload.get("property_ids")
	if typeof(ids) != TYPE_ARRAY or ids.is_empty():
		return ErCommand.E_BAD_REQUEST
	var seen := {}
	for pid in ids:
		if typeof(pid) != TYPE_STRING or seen.has(pid) or not state.owner.has(pid):
			return ErCommand.E_INVALID_TARGET
		if state.owner[pid] != seat:
			return ErCommand.E_NOT_OWNER
		seen[pid] = true
	for pid in ids:
		_liquidate(seat, pid)
	_check_rescue_paid()
	return ""


func _cmd_declare_bankruptcy(seat: int) -> String:
	if state.phase != GameState.RESCUE:
		return ErCommand.E_WRONG_PHASE
	if seat != state.rescue["debtor"]:
		return ErCommand.E_NOT_YOUR_TURN
	_force_settle()
	return ""


func _cmd_end_turn(seat: int) -> String:
	var err := _require_turn(seat, GameState.STRATEGY)
	if err != "":
		return err
	_end_turn("ended")
	return ""


# =============================================================================
# Turn flow
# =============================================================================

func _do_roll() -> void:
	var d1 := state.rng.roll_die()
	var d2 := state.rng.roll_die()
	var seat := state.current_seat
	state.last_roll = [d1, d2]
	_emit("DiceRolled", {"seat": seat, "d1": d1, "d2": d2})
	# G5: doubles grant no extra roll.
	_move_by(seat, d1 + d2, "dice")
	_resolve_landing(seat)


func _move_by(seat: int, steps: int, via: String) -> void:
	var p := state.player(seat)
	var from: int = p["position"]
	var raw: int = from + steps
	var to := raw % config.board_size()
	var passed := raw >= config.board_size()
	p["position"] = to
	_emit("TokenMoved", {"seat": seat, "from": from, "to": to, "passed_start": passed, "via": via})
	if passed:
		_transfer(BANK, seat, config.balance["start_reward"], "start_reward")


func _resolve_landing(seat: int) -> void:
	var pos: int = state.player(seat)["position"]
	match config.space_type(pos):
		"PROPERTY":
			var pid := property_at(pos)
			var o: int = state.owner[pid]
			if o == BANK:
				state.phase = GameState.AWAIT_BUY
				return
			if o == seat:
				_to_strategy()
				return
			var q := rent_quote(pid, seat)
			_consume_modifier(q["consumes"])
			_emit("RentCharged", {"payer": seat, "owner": o, "property_id": pid, "amount": q["amount"]})
			if _charge(seat, o, q["amount"], "rent"):
				_to_strategy()
		"CITY_EVENT":
			_draw_event_card(seat)
		"OPPORTUNITY":
			var entries := config.opportunity_entries()
			var entry: Dictionary = entries[state.rng.range_int(entries.size())]
			_open_choice(seat, "opportunity", entry["entry_id"], entry)
		"SPECIAL":
			var tax := wealth_tax(seat)
			_emit("WealthTaxCharged", {"seat": seat, "amount": tax, "taxable_wealth": net_worth(seat)})
			if _charge(seat, BANK, tax, "wealth_tax"):
				_to_strategy()
		_:
			# START (reward already paid by movement) and REST (G2) have no effect.
			_to_strategy()


func _draw_event_card(seat: int) -> void:
	if state.event_deck.is_empty():
		state.event_deck = config.card_ids.duplicate()
		state.rng.shuffle(state.event_deck)
		_emit("EventDeckReshuffled", {})
	var card_id: String = state.event_deck.pop_front()
	var card: Dictionary = config.cards[card_id]
	_emit("EventCardDrawn", {"seat": seat, "card_id": card_id})
	if card.has("options"):
		_open_choice(seat, "event", card_id, card)
		return
	if _apply_effects(seat, card["effects"], "card:" + card_id):
		_to_strategy()


func _open_choice(seat: int, source: String, ref_id: String, def: Dictionary) -> void:
	state.choice = {
		"choice_id": state.alloc_id("C"), "seat": seat, "source": source, "ref_id": ref_id,
		"options": def["options"].duplicate(true), "default_option": def.get("default_option", 0),
	}
	state.phase = GameState.AWAIT_CHOICE
	_emit("ChoicePrompted", state.choice.duplicate(true))


func _resolve_choice(idx: int, timed_out: bool) -> void:
	var c := state.choice
	var seat: int = c["seat"]
	var opt: Dictionary = c["options"][idx]
	state.choice = {}
	_emit("ChoiceResolved", {"choice_id": c["choice_id"], "seat": seat, "option_id": opt["option_id"], "timed_out": timed_out})
	_transfer(seat, BANK, opt["cost"], "choice:" + c["ref_id"])
	if _apply_effects(seat, opt["effects"], c["source"] + ":" + c["ref_id"]):
		_to_strategy()


func _to_strategy() -> void:
	_resume_turn()
	state.phase = GameState.STRATEGY


func _pause_turn() -> void:
	if state.paused_turn_remaining_ms < 0:
		state.paused_turn_remaining_ms = maxi(0, state.turn_deadline_ms - clock.now_ms())


func _resume_turn() -> void:
	if state.paused_turn_remaining_ms >= 0:
		state.turn_deadline_ms = clock.now_ms() + state.paused_turn_remaining_ms
		state.paused_turn_remaining_ms = -1


func _end_turn(reason: String) -> void:
	var seat := state.current_seat
	_emit("TurnEnded", {"seat": seat, "reason": reason, "turn_number": state.turn_number})
	state.phase = GameState.STRATEGY  # transient; replaced below
	if state.active_seats().size() <= 1:
		_end_match("last_solvent")
		return
	var n := state.players.size()
	var next := seat
	for i in range(1, n + 1):
		var cand := (seat + i) % n
		if not state.player(cand)["bankrupt"]:
			next = cand
			break
	var wrapped := next <= seat
	if wrapped and state.round >= config.balance["max_rounds"]:
		_end_match("round_cap")
		return
	# G9: time cap checked at the end of every turn (deterministic boundary).
	if clock.now_ms() - state.match_start_ms >= config.balance["time_cap_ms"]:
		_end_match("time_cap")
		return
	if wrapped:
		state.round += 1
	state.current_seat = next
	state.turn_number += 1
	state.strategy_used = false
	state.paused_turn_remaining_ms = -1
	state.last_roll = []
	_expire_modifiers()
	state.phase = GameState.AWAIT_ROLL
	state.turn_deadline_ms = clock.now_ms() + config.balance["turn_timer_ms"]
	_emit("TurnStarted", {"seat": next, "round": state.round, "turn_number": state.turn_number, "deadline_ms": state.turn_deadline_ms})
	_resolve_payouts(next)


func _expire_modifiers() -> void:
	var keep: Array = []
	for m in state.modifiers:
		if m["expires_turn"] <= state.turn_number or m["uses"] == 0:
			_emit("ModifierExpired", {"modifier_id": m["modifier_id"]})
		else:
			keep.append(m)
	state.modifiers = keep


func _resolve_payouts(seat: int) -> void:
	var keep: Array = []
	for po in state.pending_payouts:
		if po["seat"] != seat:
			keep.append(po)
			continue
		var win: bool = po["chance_pct"] >= 100 or state.rng.range_int(100) < po["chance_pct"]
		_emit("PayoutResolved", {"payout_id": po["payout_id"], "seat": seat, "won": win, "reward": po["reward"] if win else 0})
		if win:
			_transfer(BANK, seat, po["reward"], "payout")
	state.pending_payouts = keep


func _end_match(reason: String) -> void:
	var rows: Array = []
	for p in state.players:
		var s: int = p["seat"]
		rows.append({
			"seat": s, "player_id": p["player_id"], "character_id": p["character_id"],
			"bankrupt": p["bankrupt"], "bankrupt_turn": p["bankrupt_turn"],
			"net_worth": net_worth(s), "districts": 0 if p["bankrupt"] else completed_districts(s),
			"cash": p["cash"],
		})
	rows.sort_custom(_rank_before)
	# Equal on every tie-break key => shared rank (no hidden seat-order bias).
	for i in rows.size():
		if i > 0 and not _rank_before(rows[i - 1], rows[i]):
			rows[i]["rank"] = rows[i - 1]["rank"]
		else:
			rows[i]["rank"] = i + 1
	state.results = rows
	state.end_reason = reason
	state.phase = GameState.ENDED
	_emit("MatchEnded", {"reason": reason, "results": rows.duplicate(true), "round": state.round,
		"turn_number": state.turn_number, "duration_ms": clock.now_ms() - state.match_start_ms,
		"seed": state.seed_value})


## Ranking order (GDD §9): solvent before bankrupt; solvent by net worth, then
## completed districts, then cash; bankrupt players by later bankruptcy first.
static func _rank_before(a: Dictionary, b: Dictionary) -> bool:
	if a["bankrupt"] != b["bankrupt"]:
		return not a["bankrupt"]
	if a["bankrupt"]:
		return a["bankrupt_turn"] > b["bankrupt_turn"]
	if a["net_worth"] != b["net_worth"]:
		return a["net_worth"] > b["net_worth"]
	if a["districts"] != b["districts"]:
		return a["districts"] > b["districts"]
	return a["cash"] > b["cash"]


# =============================================================================
# Auction, trade, rescue
# =============================================================================

func _open_auction(pid: String) -> void:
	_pause_turn()
	var cfg: Dictionary = config.balance["auction"]
	var price: int = config.tier_of(pid)["price"]
	state.auction = {
		"auction_id": state.alloc_id("A"), "property_id": pid,
		"min_bid": maxi(cfg["min_bid_floor"], price * cfg["min_bid_pct_of_price"] / 100),
		"high_bid": 0, "high_seat": BANK,
		"deadline_ms": clock.now_ms() + cfg["timer_ms"], "extensions": 0,
	}
	state.phase = GameState.AUCTION
	_emit("AuctionOpened", state.auction.duplicate())


func _close_auction() -> void:
	var a := state.auction
	var winner: int = a["high_seat"]
	state.auction = {}
	if winner != BANK and state.owner[a["property_id"]] == BANK and state.player(winner)["cash"] >= a["high_bid"]:
		_transfer(winner, BANK, a["high_bid"], "auction")
		state.owner[a["property_id"]] = winner
		_emit("AuctionClosed", {"auction_id": a["auction_id"], "property_id": a["property_id"], "winner": winner, "price": a["high_bid"]})
	else:
		_emit("AuctionClosed", {"auction_id": a["auction_id"], "property_id": a["property_id"], "winner": BANK, "price": 0})
	_to_strategy()


func _norm_side(side: Dictionary) -> Dictionary:
	var ids: Array = side.get("property_ids", []).duplicate()
	ids.sort()
	return {"cash": side.get("cash", 0), "property_ids": ids}


func _validate_trade_terms(from_seat: int, to_seat: int, give: Dictionary, take: Dictionary) -> String:
	if to_seat < 0 or to_seat == from_seat:
		return ErCommand.E_INVALID_TARGET
	if state.player(to_seat)["bankrupt"] or state.player(from_seat)["bankrupt"]:
		return ErCommand.E_INVALID_TARGET
	var max_props: int = config.balance["trade"]["max_properties_per_side"]
	var seen := {}
	var sides := [[give, from_seat], [take, to_seat]]
	var empty := true
	for pair in sides:
		var side: Dictionary = pair[0]
		var owner_seat: int = pair[1]
		var cash = side.get("cash", 0)
		var ids = side.get("property_ids", [])
		if typeof(cash) != TYPE_INT or cash < 0 or typeof(ids) != TYPE_ARRAY or ids.size() > max_props:
			return ErCommand.E_TRADE_INVALID
		if cash > state.player(owner_seat)["cash"]:
			return ErCommand.E_INSUFFICIENT_FUNDS
		if cash > 0 or not ids.is_empty():
			empty = false
		for pid in ids:
			if typeof(pid) != TYPE_STRING or seen.has(pid) or not state.owner.has(pid):
				return ErCommand.E_TRADE_INVALID
			seen[pid] = true
			if state.owner[pid] != owner_seat:
				return ErCommand.E_NOT_OWNER
			# Only undeveloped properties can change hands (keeps buildings tied
			# to the district owner who paid for them).
			if state.level[pid] != 0:
				return ErCommand.E_TRADE_INVALID
	if empty:
		return ErCommand.E_TRADE_INVALID
	return ""


func _finish_trade(status: String) -> void:
	var t := state.trade
	state.trade = {}
	_emit("TradeResolved", {"trade_id": t["trade_id"], "status": status, "from": t["from"], "to": t["to"]})
	if t["return_phase"] == GameState.RESCUE:
		state.phase = GameState.RESCUE
		_check_rescue_paid()
	else:
		_resume_turn()
		_end_turn("action")


## Pays immediately when possible; otherwise opens Rescue. Returns true if paid.
func _charge(debtor: int, creditor: int, amount: int, reason: String) -> bool:
	if amount <= 0:
		return true
	if state.player(debtor)["cash"] >= amount:
		_transfer(debtor, creditor, amount, reason)
		return true
	assert(debtor == state.current_seat, "only the current player can owe money")
	_pause_turn()
	state.rescue = {
		"debtor": debtor, "creditor": creditor, "amount": amount, "reason": reason,
		"deadline_ms": clock.now_ms() + config.balance["rescue_timer_ms"], "trade_used": false,
	}
	state.phase = GameState.RESCUE
	_emit("RescueStarted", state.rescue.duplicate())
	return false


func _liquidate(seat: int, pid: String) -> void:
	var value := liquidation_value(pid)
	state.owner[pid] = BANK
	state.level[pid] = 0
	_emit("PropertyLiquidated", {"seat": seat, "property_id": pid, "value": value})
	_transfer(BANK, seat, value, "liquidation")


func _check_rescue_paid() -> void:
	var r := state.rescue
	if state.player(r["debtor"])["cash"] < r["amount"]:
		return
	_transfer(r["debtor"], r["creditor"], r["amount"], r["reason"])
	state.rescue = {}
	_emit("RescueResolved", {"seat": r["debtor"], "outcome": "paid"})
	_to_strategy()


## Rescue deadline / DeclareBankruptcy. If liquidating can still cover the debt
## the server liquidates (cheapest first, then board order) and the player
## survives. Otherwise G7: properties return to the bank unowned (no proceeds)
## and remaining cash goes to the creditor (player) or the bank (tax/cards).
func _force_settle() -> void:
	var r := state.rescue
	var seat: int = r["debtor"]
	var p := state.player(seat)
	var owned := state.properties_of(seat)
	var total: int = p["cash"]
	for pid in owned:
		total += liquidation_value(pid)
	if total >= r["amount"]:
		owned.sort_custom(func(a, b):
			var va := liquidation_value(a)
			var vb := liquidation_value(b)
			return va < vb if va != vb else config.property_index[a] < config.property_index[b])
		for pid in owned:
			if p["cash"] >= r["amount"]:
				break
			_liquidate(seat, pid)
		_check_rescue_paid()
		return
	for pid in owned:
		state.owner[pid] = BANK
		state.level[pid] = 0
		_emit("PropertyTransferred", {"property_id": pid, "from": seat, "to": BANK, "reason": "bankruptcy"})
	_transfer(seat, r["creditor"], p["cash"], "bankruptcy")
	p["bankrupt"] = true
	p["bankrupt_turn"] = state.turn_number
	var mods: Array = []
	for m in state.modifiers:
		if m["seat"] != seat:
			mods.append(m)
	state.modifiers = mods
	state.pending_payouts = state.pending_payouts.filter(func(po): return po["seat"] != seat)
	state.rescue = {}
	_emit("PlayerBankrupt", {"seat": seat, "creditor": r["creditor"], "debt": r["amount"], "reason": r["reason"]})
	_end_turn("bankrupt")


# =============================================================================
# Effects (event cards, opportunities, abilities)
# =============================================================================

## Applies effects in order. Returns false if a payment opened Rescue (config
## validation guarantees a payment is always the last effect of a list).
func _apply_effects(seat: int, effects: Array, source: String) -> bool:
	var active_n := state.active_seats().size()
	for e in effects:
		var expires: int = state.turn_number + e.get("duration_rounds", 0) * active_n
		match e["type"]:
			"cash":
				if e["amount"] >= 0:
					_transfer(BANK, seat, e["amount"], source)
				elif not _charge(seat, BANK, -e["amount"], source):
					return false
			"advance_to_start":
				var steps: int = config.board_size() - state.player(seat)["position"]
				_move_by(seat, steps, "card")
			"pay_per_level":
				var levels := 0
				for pid in state.properties_of(seat):
					levels += state.level[pid]
				if not _charge(seat, BANK, levels * e["amount"], source):
					return false
			"pay_per_property_at_level":
				var count := 0
				for pid in state.properties_of(seat):
					if state.level[pid] >= e["min_level"]:
						count += 1
				if not _charge(seat, BANK, count * e["amount"], source):
					return false
			"per_property_cash":
				_transfer(BANK, seat, mini(e["max_total"], state.properties_of(seat).size() * e["amount"]), source)
			"rent_modifier":
				_add_modifier({"kind": "rent_pct", "seat": seat if e["target"] == "owner_self" else BANK,
					"tag": e.get("tag", "") if e["target"] == "district_tag" else "", "pct": e["pct"],
					"uses": -1, "expires_turn": expires, "source": source})
			"upgrade_discount_next":
				_add_modifier({"kind": "upgrade_discount", "seat": seat, "tag": "", "pct": e["pct"],
					"uses": 1, "expires_turn": expires, "source": source})
			"rent_discount_next":
				_add_modifier({"kind": "rent_discount", "seat": seat, "tag": "", "pct": e["pct"],
					"uses": 1, "expires_turn": expires, "source": source})
			"rent_cap":
				_add_modifier({"kind": "rent_cap", "seat": seat, "tag": "", "cap": e["cap"],
					"uses": -1, "expires_turn": expires, "source": source})
			"delayed_payout":
				var po := {"payout_id": state.alloc_id("D"), "seat": seat, "reward": e["reward"], "chance_pct": e["chance_pct"]}
				state.pending_payouts.append(po)
				_emit("PayoutScheduled", po.duplicate())
	return true


func _add_modifier(m: Dictionary) -> void:
	m["modifier_id"] = state.alloc_id("M")
	if not m.has("cap"):
		m["cap"] = 0
	state.modifiers.append(m)
	_emit("ModifierAdded", m.duplicate())


func _consume_modifier(modifier_id: String) -> void:
	if modifier_id == "":
		return
	for m in state.modifiers:
		if m["modifier_id"] == modifier_id:
			m["uses"] -= 1
	var keep: Array = []
	for m in state.modifiers:
		if m["uses"] == 0:
			_emit("ModifierExpired", {"modifier_id": m["modifier_id"], "reason": "used"})
		else:
			keep.append(m)
	state.modifiers = keep


# =============================================================================
# Timeouts (safe defaults, GDD §3.8)
# =============================================================================

func _handle_timeout() -> void:
	_emit("DeadlineExpired", {"phase": state.phase, "seat": state.current_seat})
	match state.phase:
		GameState.AWAIT_ROLL:
			# Interpretation pending owner review: by default the server rolls
			# for an idle player (they still move, pay rent and collect Start);
			# with timeout_auto_roll=false the idle turn simply ends.
			if config.balance.get("timeout_auto_roll", true):
				_do_roll()
			else:
				_end_turn("timeout")
		GameState.AWAIT_BUY:
			var pid := property_at(state.player(state.current_seat)["position"])
			_emit("PropertyPassed", {"seat": state.current_seat, "property_id": pid, "timed_out": true})
			_open_auction(pid)
		GameState.AWAIT_CHOICE:
			_resolve_choice(state.choice["default_option"], true)
		GameState.STRATEGY:
			_end_turn("timeout")
		GameState.AUCTION:
			_close_auction()
		GameState.TRADE_PENDING:
			_finish_trade("expired")
		GameState.RESCUE:
			_force_settle()


# =============================================================================
# Ledger + event plumbing
# =============================================================================

## The only place cash moves. Never lets a balance go negative.
func _transfer(from: int, to: int, amount: int, reason: String) -> void:
	if amount == 0:
		return
	assert(amount > 0, "negative transfer")
	if from != BANK:
		assert(state.player(from)["cash"] >= amount, "transfer would make cash negative")
		state.player(from)["cash"] -= amount
	else:
		state.bank_net_issued += amount
	if to != BANK:
		state.player(to)["cash"] += amount
	else:
		state.bank_net_issued -= amount
	var tx_id := state.next_tx_id
	state.next_tx_id += 1
	_emit("CashChanged", {"tx_id": tx_id, "from": from, "to": to, "amount": amount, "reason": reason,
		"from_balance": state.player(from)["cash"] if from != BANK else null,
		"to_balance": state.player(to)["cash"] if to != BANK else null})


func _emit(type: String, data: Dictionary) -> void:
	state.seq += 1
	_pending.append({"seq": state.seq, "type": type, "data": data})


func _commit() -> Array:
	state.state_version += 1
	var out := _pending
	_pending = []
	for ev in out:
		ev["state_version"] = state.state_version
	if keep_event_log:
		event_log.append_array(out)
	return out


func _reject(code: String) -> Dictionary:
	return {"ok": false, "error": code, "events": []}


func _validate_shape(cmd: Dictionary) -> String:
	if cmd.get("protocol_version") != ErCommand.PROTOCOL_VERSION:
		return ErCommand.E_PROTOCOL_UNSUPPORTED
	if cmd.get("match_id") != state.match_id:
		return ErCommand.E_BAD_REQUEST
	if typeof(cmd.get("command_id")) != TYPE_STRING or str(cmd["command_id"]).is_empty():
		return ErCommand.E_BAD_REQUEST
	if typeof(cmd.get("player_id")) != TYPE_STRING or typeof(cmd.get("type")) != TYPE_STRING:
		return ErCommand.E_BAD_REQUEST
	if typeof(cmd.get("expected_state_version")) != TYPE_INT or typeof(cmd.get("payload")) != TYPE_DICTIONARY:
		return ErCommand.E_BAD_REQUEST
	return ""
