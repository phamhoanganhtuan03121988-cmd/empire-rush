## Immutable, validated rules configuration (board, balance, cards, characters,
## opportunities). Built from plain dictionaries so the same data can be loaded
## from JSON files, from a server, or constructed inline by tests.
class_name GameConfig
extends RefCounted

const DEFAULT_DIR := "res://data/rules"
const SPACE_TYPES := ["START", "PROPERTY", "CITY_EVENT", "OPPORTUNITY", "REST", "SPECIAL"]

var board: Dictionary
var balance: Dictionary
var events: Dictionary
var characters: Dictionary
var opportunities: Dictionary

## Derived lookups.
var spaces: Array = []                 # index -> space dict
var property_ids: Array[String] = []   # board order
var property_index: Dictionary = {}    # property_id -> space index
var property_district: Dictionary = {} # property_id -> district_id
var district_props: Dictionary = {}    # district_id -> Array[String]
var district_tier: Dictionary = {}     # district_id -> int
var district_tags: Dictionary = {}     # district_id -> Array
var tiers: Dictionary = {}             # tier -> dict
var cards: Dictionary = {}             # card_id -> dict
var card_ids: Array[String] = []
var character_by_id: Dictionary = {}
var errors: Array[String] = []


static func load_from_dir(dir_path: String = DEFAULT_DIR) -> GameConfig:
	var parts := {}
	for name in ["board", "balance", "events", "characters", "opportunities"]:
		var path := dir_path.path_join(name + ".json")
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			push_error("GameConfig: cannot read " + path)
			return null
		parts[name] = JSON.parse_string(text)
	return from_dicts(parts["board"], parts["balance"], parts["events"], parts["characters"], parts["opportunities"])


## Returns a config even when invalid; callers must check is_valid().
static func from_dicts(p_board, p_balance, p_events, p_characters, p_opportunities) -> GameConfig:
	var cfg := GameConfig.new()
	cfg.board = normalize_numbers(p_board)
	cfg.balance = normalize_numbers(p_balance)
	cfg.events = normalize_numbers(p_events)
	cfg.characters = normalize_numbers(p_characters)
	cfg.opportunities = normalize_numbers(p_opportunities)
	cfg._index_and_validate()
	return cfg


## Returns a new validated config whose balance is this one's deep-merged with
## `patch` (dictionaries merge, everything else - including arrays such as
## `tiers` - is replaced). Used by balance experiments; never mutates self.
func with_balance(patch: Dictionary) -> GameConfig:
	var merged: Dictionary = balance.duplicate(true)
	_deep_merge(merged, normalize_numbers(patch))
	return GameConfig.from_dicts(board.duplicate(true), merged, events.duplicate(true),
		characters.duplicate(true), opportunities.duplicate(true))


static func _deep_merge(into: Dictionary, patch: Dictionary) -> void:
	for k in patch:
		if typeof(patch[k]) == TYPE_DICTIONARY and typeof(into.get(k)) == TYPE_DICTIONARY:
			_deep_merge(into[k], patch[k])
		else:
			into[k] = patch[k]


func is_valid() -> bool:
	return errors.is_empty()


## Godot's JSON parser returns every number as float. Money must be int, so
## integral floats become int and any fractional number is rejected upstream.
static func normalize_numbers(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			if value == floorf(value):
				return int(value)
			return value
		TYPE_DICTIONARY:
			var out := {}
			for k in value:
				out[k] = normalize_numbers(value[k])
			return out
		TYPE_ARRAY:
			var arr := []
			for v in value:
				arr.append(normalize_numbers(v))
			return arr
	return value


func _err(msg: String) -> void:
	errors.append(msg)


func _index_and_validate() -> void:
	if typeof(board) != TYPE_DICTIONARY or typeof(balance) != TYPE_DICTIONARY:
		_err("board/balance missing")
		return
	for t in balance.get("tiers", []):
		tiers[t["tier"]] = t
		for key in ["price", "base_rent", "upgrade_cost", "liquidation_value"]:
			if typeof(t.get(key)) != TYPE_INT or t[key] < 0:
				_err("tier %s: %s must be a non-negative int" % [t.get("tier"), key])
	for key in ["starting_cash", "start_reward", "max_rounds", "time_cap_ms", "turn_timer_ms",
			"trade_timer_ms", "rescue_timer_ms", "upgrade_refund_pct", "max_level"]:
		if typeof(balance.get(key)) != TYPE_INT:
			_err("balance.%s must be int" % key)
	for key in ["level0_incomplete", "level0_district_complete", "level1", "level2", "level3"]:
		if typeof(balance.get("rent_multiplier_pct", {}).get(key)) != TYPE_INT:
			_err("rent_multiplier_pct.%s must be int" % key)
	_check_ints(balance, "balance")

	for d in board.get("districts", []):
		district_props[d["district_id"]] = [] as Array[String]
		district_tier[d["district_id"]] = d["tier"]
		district_tags[d["district_id"]] = d.get("tags", [])
		if not tiers.has(d["tier"]):
			_err("district %s references unknown tier %s" % [d["district_id"], d["tier"]])

	var counts := {}
	var seen_ids := {}
	spaces = board.get("spaces", [])
	for i in spaces.size():
		var s: Dictionary = spaces[i]
		if s.get("index") != i:
			_err("space %d has index %s" % [i, s.get("index")])
		if seen_ids.has(s.get("space_id")):
			_err("duplicate space_id " + str(s.get("space_id")))
		seen_ids[s.get("space_id")] = true
		var st: String = s.get("space_type", "")
		if not st in SPACE_TYPES:
			_err("space %d unknown type %s" % [i, st])
		counts[st] = counts.get(st, 0) + 1
		if st == "PROPERTY":
			var pid: String = s.get("property_id", "")
			var did: String = s.get("district_id", "")
			if pid.is_empty() or property_index.has(pid):
				_err("space %d bad/duplicate property_id" % i)
			if not district_props.has(did):
				_err("space %d unknown district %s" % [i, did])
				continue
			property_ids.append(pid)
			property_index[pid] = i
			property_district[pid] = did
			district_props[did].append(pid)
	if spaces.size() != 28:
		_err("board must have 28 spaces, has %d" % spaces.size())
	var expected := {"PROPERTY": 21, "START": 1, "CITY_EVENT": 2, "OPPORTUNITY": 2, "REST": 1, "SPECIAL": 1}
	for k in expected:
		if counts.get(k, 0) != expected[k]:
			_err("board must have %d %s spaces, has %d" % [expected[k], k, counts.get(k, 0)])
	if spaces.size() > 0 and spaces[0].get("space_type") != "START":
		_err("space 0 must be START")
	if district_props.size() != 7:
		_err("board must have 7 districts")
	for did in district_props:
		if district_props[did].size() != 3:
			_err("district %s must have 3 properties" % did)

	for c in events.get("cards", []):
		if c.has("options"):
			_validate_default_option(c, "card " + c["card_id"])
		cards[c["card_id"]] = c
		card_ids.append(c["card_id"])
		_validate_effect_list(c.get("effects", []), "card " + c["card_id"])
		for o in c.get("options", []):
			_validate_option(o, "card " + c["card_id"])
	if card_ids.size() != 12:
		_err("need 12 event cards, have %d" % card_ids.size())
	var cats := {}
	for c in events.get("cards", []):
		cats[c["category"]] = cats.get(c["category"], 0) + 1
	if cats.get("positive", 0) != 4 or cats.get("negative", 0) != 4 or cats.get("choice", 0) != 4:
		_err("event cards must be 4 positive / 4 negative / 4 choice: %s" % str(cats))

	for ch in characters.get("characters", []):
		character_by_id[ch["character_id"]] = ch
		_validate_effect_list(ch["ability"].get("effects", []), "character " + ch["character_id"])
		for e in ch["ability"].get("effects", []):
			if e.get("type") in PAYMENT_EFFECTS:
				_err("character %s: abilities must not charge the player" % ch["character_id"])
	if character_by_id.size() != 3:
		_err("need 3 characters, have %d" % character_by_id.size())

	var entries: Array = opportunities.get("entries", [])
	if entries.size() != 4:
		_err("opportunity table needs 4 entries, has %d" % entries.size())
	for e in entries:
		_validate_default_option(e, "opportunity " + str(e.get("entry_id")))
		if e.get("options", []).size() != 2:
			_err("opportunity %s needs exactly 2 options" % e.get("entry_id"))
		for o in e.get("options", []):
			_validate_option(o, "opportunity " + str(e.get("entry_id")))


func _validate_option(o: Dictionary, where: String) -> void:
	if typeof(o.get("cost")) != TYPE_INT or o["cost"] < 0:
		_err(where + ": option cost must be non-negative int")
	_validate_effect_list(o.get("effects", []), where)


const EFFECT_TYPES := ["cash", "advance_to_start", "pay_per_level", "pay_per_property_at_level",
	"rent_modifier", "upgrade_discount_next", "rent_discount_next", "rent_cap",
	"delayed_payout", "per_property_cash"]


## Effects that can charge the player (and therefore open Rescue).
const PAYMENT_EFFECTS := ["pay_per_level", "pay_per_property_at_level"]


func _validate_effect_list(effects: Array, where: String) -> void:
	for i in effects.size():
		var e: Dictionary = effects[i]
		if not e.get("type") in EFFECT_TYPES:
			_err("%s: unknown effect type %s" % [where, e.get("type")])
		var pays: bool = e.get("type") in PAYMENT_EFFECTS or (e.get("type") == "cash" and e.get("amount", 0) < 0)
		if pays and i != effects.size() - 1:
			_err("%s: a payment effect must be the last effect" % where)
	_check_ints(effects, where)


## Timeouts pick the default option, so it must never cost money.
func _validate_default_option(def: Dictionary, where: String) -> void:
	var opts: Array = def.get("options", [])
	var idx = def.get("default_option", 0)
	if typeof(idx) != TYPE_INT or idx < 0 or idx >= opts.size():
		_err(where + ": default_option out of range")
	elif opts[idx].get("cost", 0) != 0:
		_err(where + ": default option must cost 0")


## Any non-integral number in rules data is an error (money is integer RC).
func _check_ints(value: Variant, where: String) -> void:
	match typeof(value):
		TYPE_FLOAT:
			_err("%s: non-integer number %s" % [where, value])
		TYPE_DICTIONARY:
			for k in value:
				_check_ints(value[k], where + "." + str(k))
		TYPE_ARRAY:
			for v in value:
				_check_ints(v, where)


# --- convenience accessors used by the rules ---------------------------------

func tier_of(property_id: String) -> Dictionary:
	return tiers[district_tier[property_district[property_id]]]


func board_size() -> int:
	return spaces.size()


func space_type(index: int) -> String:
	return spaces[index]["space_type"]


func opportunity_entries() -> Array:
	return opportunities["entries"]
