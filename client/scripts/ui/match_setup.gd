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
