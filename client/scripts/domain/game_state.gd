## Authoritative match state: plain data only, no rules. Everything a snapshot,
## a replay or a hash needs lives here (including the RNG state).
class_name GameState
extends RefCounted

const BANK := -1

# Phases
const AWAIT_ROLL := "AwaitRoll"
const AWAIT_BUY := "AwaitBuyDecision"
const AUCTION := "Auction"
const AWAIT_CHOICE := "AwaitChoice"
const STRATEGY := "StrategyAction"
const TRADE_PENDING := "TradePending"
const RESCUE := "Rescue"
const ENDED := "Ended"

var match_id := ""
var seed_value := 0
var state_version := 0
var seq := 0
var phase := AWAIT_ROLL
var round := 1
var turn_number := 1
var current_seat := 0
var match_start_ms := 0
var turn_deadline_ms := 0
var paused_turn_remaining_ms := -1
var strategy_used := false

## [{seat, player_id, character_id, cash, position, bankrupt, bankrupt_turn,
##   ability_uses_left, ability_ready_round}]
var players: Array = []
var owner: Dictionary = {}   # property_id -> seat or BANK
var level: Dictionary = {}   # property_id -> 0..3

var auction: Dictionary = {}
var trade: Dictionary = {}
var choice: Dictionary = {}
var rescue: Dictionary = {}
var last_roll: Array = []

## [{modifier_id, kind, seat, pct, cap, tag, uses, expires_turn}]
var modifiers: Array = []
## [{payout_id, seat, reward, chance_pct}] resolved at the start of `seat`'s next turn.
var pending_payouts: Array = []
var event_deck: Array = []

var next_tx_id := 1
var next_aux_id := 1
## Money created by the bank minus money returned to it (conservation check).
var bank_net_issued := 0

var end_reason := ""
var results: Array = []

## "seat|command_id" -> result dictionary (accepted commands only).
var processed: Dictionary = {}

var rng := ErRng.new()


func player(seat: int) -> Dictionary:
	return players[seat]


func active_seats() -> Array[int]:
	var out: Array[int] = []
	for p in players:
		if not p["bankrupt"]:
			out.append(p["seat"])
	return out


func seat_of_player_id(player_id: String) -> int:
	for p in players:
		if p["player_id"] == player_id:
			return p["seat"]
	return -2


func properties_of(seat: int) -> Array[String]:
	var out: Array[String] = []
	for pid in owner:
		if owner[pid] == seat:
			out.append(pid)
	out.sort()
	return out


func alloc_id(prefix: String) -> String:
	var id := "%s%d" % [prefix, next_aux_id]
	next_aux_id += 1
	return id


## Canonical, order-stable dictionary of the full state (snapshot + hashing).
## `processed` is excluded: it is a dedupe cache, not game state.
func to_dict() -> Dictionary:
	return {
		"match_id": match_id, "seed": seed_value, "state_version": state_version, "seq": seq,
		"phase": phase, "round": round, "turn_number": turn_number, "current_seat": current_seat,
		"match_start_ms": match_start_ms, "turn_deadline_ms": turn_deadline_ms,
		"paused_turn_remaining_ms": paused_turn_remaining_ms, "strategy_used": strategy_used,
		"players": players, "owner": owner, "level": level,
		"auction": auction, "trade": trade, "choice": choice, "rescue": rescue, "last_roll": last_roll,
		"modifiers": modifiers, "pending_payouts": pending_payouts, "event_deck": event_deck,
		"next_tx_id": next_tx_id, "next_aux_id": next_aux_id, "bank_net_issued": bank_net_issued,
		"end_reason": end_reason, "results": results, "rng": rng.get_state(),
	}


func state_hash() -> String:
	return JSON.stringify(to_dict(), "", true).sha256_text()
