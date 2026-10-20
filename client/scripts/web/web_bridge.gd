## Browser end-to-end test hook (web build only, and only when the page URL
## carries `e2e=1`). Exposes `window.erE2E` with two read-only functions so a
## browser test (tests_web/e2e_web.mjs) can TAP real on-screen buttons with
## real touch events and check the result:
##   erE2E.rect(id)  -> [x, y, w, h] of a visible button as fractions of the
##                      canvas (the test converts them to CSS pixels), or null
##   erE2E.state()   -> JSON text: page, phase, seat, cash, owners, card names
## Godot JS callbacks cannot return values, so each call leaves its answer in
## window.erE2EResult (the test reads it right after the call).
## Ids: "menu:<id>", "hud:<command>", "coach:<ok|off>", "pause:<id>",
## "hud:pause". It never sends commands itself: input goes through the browser.
class_name WebBridge
extends Node

var main: Node
var _callbacks: Array = []  # keep the JS callbacks alive


static func wanted() -> bool:
	if not OS.has_feature("web"):
		return false
	var q: Variant = JavaScriptBridge.eval("window.location.search", true)
	return q is String and (q as String).contains("e2e=1")


## Value of `name` in the page URL query, or "" (test mode only).
static func query_value(name: String) -> String:
	var q: Variant = JavaScriptBridge.eval("window.location.search", true)
	if not (q is String):
		return ""
	for part in (q as String).trim_prefix("?").split("&"):
		var kv := part.split("=", true, 1)
		if kv.size() == 2 and kv[0] == name:
			return kv[1]
	return ""


func _ready() -> void:
	var api: JavaScriptObject = JavaScriptBridge.create_object("Object")
	var win := JavaScriptBridge.get_interface("window")
	var rect_cb := JavaScriptBridge.create_callback(func(args: Array): win.erE2EResult = _rect_json(str(args[0])))
	var state_cb := JavaScriptBridge.create_callback(func(_args: Array): win.erE2EResult = JSON.stringify(_state()))
	_callbacks = [rect_cb, state_cb]
	api.rect = rect_cb
	api.state = state_cb
	JavaScriptBridge.get_interface("window").erE2E = api
	print("WEB_E2E bridge ready")


func _find(id: String) -> Control:
	var parts := id.split(":", true, 1)
	if parts.size() != 2:
		return null
	var key := parts[1]
	match parts[0]:
		"menu":
			if main.menu and main.menu.buttons.has(key):
				return main.menu.buttons[key]
		"pause":
			if main.pause_menu and main.pause_menu.buttons.has(key):
				return main.pause_menu.buttons[key]
		"coach":
			if main.coach and main.coach.buttons.has(key) and main.coach.current.size() > 0:
				return main.coach.buttons[key]
		"hud":
			if main.hud == null:
				return null
			if key == "pause":
				return main.hud.pause_button
			for a in main.hud.actions:
				if a["type"] == key and not a["button"].disabled:
					return a["button"]
	return null


func _rect_json(id: String) -> String:
	var c := _find(id)
	if c == null or not c.is_visible_in_tree():
		return "null"
	var vp := c.get_viewport_rect().size
	var r := c.get_global_rect()
	return JSON.stringify([r.position.x / vp.x, r.position.y / vp.y, r.size.x / vp.x, r.size.y / vp.y])


func _state() -> Dictionary:
	var out := {"page": main.menu.page if main.menu else "", "in_match": main.match_ref != null}
	if main.match_ref:
		var s: GameState = main.match_ref.engine.state
		out["phase"] = s.phase
		out["seat"] = s.current_seat
		out["round"] = s.round
		out["cash"] = s.players.map(func(p): return p["cash"])
		out["owned_by_human"] = s.properties_of(0)
		out["idle"] = main.presenter.is_idle()
		out["coach"] = main.coach.current.get("id", "") if main.coach else ""
		var cards: Array = []
		for c in main.hud._cards:
			var l: Label = c["name"]
			var font := l.get_theme_font("font")
			var fs := l.get_theme_font_size("font_size")
			var need := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			cards.append({"name": l.text, "fits": need <= l.size.x + 0.5, "width": l.size.x, "needed": need})
		out["cards"] = cards
	out["setup"] = {"persona": MatchSetup.persona, "name": MatchSetup.player_name, "players": MatchSetup.players}
	out["saved_match"] = SavedMatch.exists()
	out["saved_round"] = int(SavedMatch.load_record().get("round", 0)) if SavedMatch.exists() else 0
	out["saved_log"] = SavedMatch.load_record().get("input_log", []).size() if SavedMatch.exists() else 0
	out["resumed"] = main._resumed
	return out
