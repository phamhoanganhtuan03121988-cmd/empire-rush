## Loads presentation-only theme data (colours/labels) and builds shared
## materials. Kept separate from GameConfig so rules never depend on visuals.
class_name ThemeData
extends RefCounted

var districts: Dictionary
var special: Dictionary
var players: Array
## Phase 5.1 cosmetic personas (data/presentation/personas.json): name,
## portrait, signature colour, bio. Never read by the rules engine.
var personas: Array = []
var _portraits: Dictionary = {}
var character_icons: Dictionary = {}
var strings: Dictionary = {}
var _mats: Dictionary = {}


static func load_default() -> ThemeData:
	var t := ThemeData.new()
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/board_theme.json"))
	t.districts = d["districts"]
	t.special = d["special_tiles"]
	t.players = d["players"]
	t.character_icons = d.get("character_icons", {})
	var pd = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/personas.json"))
	if typeof(pd) == TYPE_DICTIONARY:
		t.personas = pd.get("personas", [])
	var vi = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/strings_vi.json"))
	if typeof(vi) == TYPE_DICTIONARY:
		t.strings = vi
	return t


## Localised display text for rules content (cards, opportunities, characters).
## Falls back to the DRAFT English text in the rules data.
func loc(id: String, field: String, fallback: String) -> String:
	return strings.get("content", {}).get(id, {}).get(field, fallback)


func character_name(character_id: String, config: GameConfig) -> String:
	return loc(character_id, "name", config.character_by_id[character_id]["name"])


## SVG icon name (assets/ui/icons) used as the character's emblem.
func character_icon(character_id: String) -> String:
	return character_icons.get(character_id, "user")


func district_color(did: String) -> Color:
	return Color(districts[did]["color"])


func player_color(seat: int) -> Color:
	return Color(players[seat % players.size()]["color"])


func persona(id: String) -> Dictionary:
	for p in personas:
		if p["id"] == id:
			return p
	return {}


## Portrait texture of a persona (cached; SVG imported by Godot).
func portrait(id: String) -> Texture2D:
	if not _portraits.has(id):
		var path := "res://assets/ui/portraits/%s.svg" % id
		_portraits[id] = load(path) if ResourceLoader.exists(path) else null
	return _portraits[id]


func player_portrait(seat: int) -> Texture2D:
	return portrait(str(players[seat % players.size()].get("persona", "")))


func player_name(seat: int) -> String:
	return players[seat % players.size()]["name"]


## Cached StandardMaterial3D per (colour, roughness, metallic, emission).
func mat(color: Color, roughness := 0.75, metallic := 0.0, emission := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(), roughness, metallic, emission]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m


func property_name(pid: String, config: GameConfig) -> String:
	return loc(pid, "name", config.spaces[config.property_index[pid]]["presentation"]["label"])
