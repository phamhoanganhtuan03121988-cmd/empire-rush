## State invariants checked after every accepted command / timeout step in
## tests and simulations. Returns a list of violations (empty == healthy).
class_name Invariants
extends RefCounted


static func check(engine: GameEngine) -> Array[String]:
	var out: Array[String] = []
	var s := engine.state
	var cfg := engine.config
	var cash_sum := 0
	for p in s.players:
		if typeof(p["cash"]) != TYPE_INT:
			out.append("seat %d cash is not int" % p["seat"])
		if p["cash"] < 0:
			out.append("seat %d negative cash %d" % [p["seat"], p["cash"]])
		if p["bankrupt"] and (p["cash"] != 0 or not s.properties_of(p["seat"]).is_empty()):
			out.append("bankrupt seat %d still holds assets" % p["seat"])
		cash_sum += p["cash"]
	if cash_sum != s.bank_net_issued:
		out.append("money not conserved: players hold %d, bank issued %d" % [cash_sum, s.bank_net_issued])
	if s.owner.size() != cfg.property_ids.size():
		out.append("ownership table size %d" % s.owner.size())
	for pid in s.owner:
		var o: int = s.owner[pid]
		var lv: int = s.level[pid]
		if o != GameState.BANK and (o < 0 or o >= s.players.size() or s.players[o]["bankrupt"]):
			out.append("%s owned by invalid/bankrupt seat %d" % [pid, o])
		if lv < 0 or lv > cfg.balance["max_level"]:
			out.append("%s level %d out of range" % [pid, lv])
		if lv > 0 and o == GameState.BANK:
			out.append("%s has buildings but no owner" % pid)
	if s.phase != GameState.ENDED and s.players[s.current_seat]["bankrupt"]:
		out.append("current seat %d is bankrupt" % s.current_seat)
	if s.round > cfg.balance["max_rounds"]:
		out.append("round %d beyond cap" % s.round)
	var expect := {
		"auction": s.phase == GameState.AUCTION,
		"trade": s.phase == GameState.TRADE_PENDING,
		"choice": s.phase == GameState.AWAIT_CHOICE,
	}
	if (not s.auction.is_empty()) != expect["auction"]:
		out.append("auction data/phase mismatch in %s" % s.phase)
	if (not s.trade.is_empty()) != expect["trade"]:
		out.append("trade data/phase mismatch in %s" % s.phase)
	if (not s.choice.is_empty()) != expect["choice"]:
		out.append("choice data/phase mismatch in %s" % s.phase)
	var in_rescue: bool = s.phase == GameState.RESCUE or (s.phase == GameState.TRADE_PENDING and s.trade.get("return_phase") == GameState.RESCUE)
	if (not s.rescue.is_empty()) != in_rescue:
		out.append("rescue data/phase mismatch in %s" % s.phase)
	for m in s.modifiers:
		if m["uses"] == 0:
			out.append("spent modifier %s still active" % m["modifier_id"])
	if s.phase == GameState.ENDED and s.results.is_empty():
		out.append("ended without results")
	return out


## Checks an event batch: contiguous seq numbers and strictly increasing tx ids.
static func check_events(events: Array, last_seq: int, last_tx: int) -> Dictionary:
	var errs: Array[String] = []
	var seq := last_seq
	var tx := last_tx
	for ev in events:
		if ev["seq"] != seq + 1:
			errs.append("event seq gap: %d after %d" % [ev["seq"], seq])
		seq = ev["seq"]
		if ev["type"] == "CashChanged":
			if ev["data"]["tx_id"] != tx + 1:
				errs.append("tx id %d after %d" % [ev["data"]["tx_id"], tx])
			tx = ev["data"]["tx_id"]
	return {"errors": errs, "seq": seq, "tx": tx}
