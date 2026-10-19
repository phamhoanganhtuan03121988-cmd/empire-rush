## Choices made on the start menu (Phase 4). Static, so they survive the
## scene reload that starts a match ("play again" keeps them, "menu" clears
## `chosen`). Command-line / test args (--players=…) bypass the menu.
class_name MatchSetup
extends RefCounted

const CHARACTER_CYCLE := ["TYCOON", "INVESTOR", "NEGOTIATOR"]

static var chosen := false
static var players := 4
static var character := "TYCOON"
static var quality := "medium"
static var reduced_motion := false
## Phase 5 identity (presentation only): the human's colour (index into the
## four seat colours) and display name. Bots take the remaining colours.
const NAME_MAX := 14
static var color_index := 0
static var player_name := "Bạn"
## Phase 5.1 cosmetic persona (portrait + name + colour; no gameplay).
static var persona := "khoi"
## Phase 5: the next match is the guided tutorial (2 players, fixed seed).
static var tutorial := false


## Seat order: the human's character first, then the others in a fixed cycle.
static func seat_characters(n: int, human_character: String) -> Array:
	var order: Array = [human_character]
	for c in CHARACTER_CYCLE:
		if c != human_character:
			order.append(c)
	var out: Array = []
	for i in n:
		out.append(order[i % order.size()])
	return out


## Presentation identity for each seat: [{color, name, pawn, persona}].
## Seat 0 (the human) gets the chosen persona, colour and name; the bots take
## the other personas (data order) with their names, and the other colours in
## order. Without persona data the bots keep the base names. Never touches
## rules data.
static func identities(base: Array, n: int, personas: Array = []) -> Array:
	var colors: Array = []
	for p in base:
		colors.append(p["color"])
	var mine := clampi(color_index, 0, colors.size() - 1)
	var order: Array = [mine]
	for k in colors.size():
		if k != mine:
			order.append(k)
	var cast: Array = []  # persona per seat
	if not personas.is_empty():
		var ids: Array = personas.map(func(p): return p["id"])
		var mine_p: String = persona if persona in ids else ids[0]
		cast.append(mine_p)
		for id in ids:
			if id != mine_p:
				cast.append(id)
	var out: Array = []
	for i in n:
		var name: String = base[i % base.size()]["name"]
		var pid: String = str(base[i % base.size()].get("persona", ""))
		if not cast.is_empty():
			pid = cast[i % cast.size()]
			if i > 0:
				name = personas[personas.find_custom(func(p): return p["id"] == pid)]["name"]
		if i == 0:
			name = player_name.strip_edges() if player_name.strip_edges() != "" else base[0]["name"]
		var k: int = order[i % order.size()]
		# "pawn": the baked pawn model of that colour (shape + colour pair).
		out.append({"color": colors[k], "name": name, "pawn": k, "persona": pid})
	return out


## Choosing a persona also proposes its name, unless the player typed their own.
static func choose_persona(id: String, personas: Array) -> void:
	var names: Array = personas.map(func(p): return p["name"])
	if player_name.strip_edges() == "" or player_name == "Bạn" or player_name in names:
		var p: Array = personas.filter(func(x): return x["id"] == id)
		if not p.is_empty():
			player_name = p[0]["name"]
	var q: Array = personas.filter(func(x): return x["id"] == id)
	if not q.is_empty():
		color_index = int(q[0].get("pawn", color_index))
	persona = id
