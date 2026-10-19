## Base class for UI flow tests: boots the real main scene, drives it only
## through on-screen HUD buttons, and checks the result against the engine.
class_name UiTestCase
extends TestCase

var tree: SceneTree
var main: Node3D


func start_game(players := 2, seed_value := 1, extra := {}) -> void:
	var args := {"players": str(players), "seed": str(seed_value), "quality": "low", "telemetry": scratch_telemetry_path()}
	args.merge(extra, true)
	main = load("res://scenes/main.tscn").instantiate()
	main.args_override = args
	tree.root.add_child(main)
	main.presenter.speed = 0.05
	main.match_ref.bot_delay_range = Vector2(0.02, 0.05)
	await frames(3)


## Tests edit engine state directly (forced ends, placed tokens), so their
## replay records cannot be rebuilt from the input log. They must never land
## in user://telemetry, which testers collect and share (Phase 4).
static func scratch_telemetry_path() -> String:
	return "user://test_telemetry/ui_%d.json" % Time.get_ticks_usec()


func stop_game() -> void:
	if main:
		main.queue_free()
		main = null
	await frames(2)


func frames(n: int) -> void:
	for i in n:
		await tree.process_frame


## Waits until the presenter is idle and the HUD has rebuilt its buttons.
func settle(max_frames := 600) -> bool:
	for i in max_frames:
		await tree.process_frame
		if main.presenter.is_idle() and i > 2:
			await frames(2)
			return true
	return false


## Waits until the HUD offers a button of `type` (or times out).
func wait_for_action(type: String, max_frames := 900) -> bool:
	for i in max_frames:
		await tree.process_frame
		if find_action(type) != null:
			return true
	return false


func find_action(type: String) -> Button:
	for a in main.hud.actions:
		if a["type"] == type and not a["button"].disabled:
			return a["button"]
	return null


func press(type: String) -> bool:
	var b := find_action(type)
	if b == null:
		errors.append("no enabled HUD button for %s (have %s)" % [type, str(main.hud.actions.map(func(x): return x["type"]))])
		return false
	b.pressed.emit()
	await frames(2)
	return true


func engine() -> GameEngine:
	return main.match_ref.engine


## Puts the human on `index` at the start of their turn and resolves it,
## feeding the resulting events to the presenter like a real move would.
func land_human(index: int) -> void:
	var e := engine()
	e.state.current_seat = 0
	e.state.phase = GameState.AWAIT_ROLL
	e.state.player(0)["position"] = index
	e._resolve_landing(0)
	main.match_ref.events_emitted.emit(e._commit())
	await settle()


func give(seat: int, pids: Array, lvl := 0) -> void:
	for pid in pids:
		engine().state.owner[pid] = seat
		engine().state.level[pid] = lvl
