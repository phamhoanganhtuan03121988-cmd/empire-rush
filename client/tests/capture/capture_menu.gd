## Phase 4 regression screenshots: start menu (default and with choices made),
## how-to-play sheet, and the first in-match money toast (start reward),
## driven through the real menu buttons and a real ROLL command.
## Usage (needs a renderer, e.g. xvfb + lavapipe):
##   godot --path client --resolution 786x1704 --script res://tests/capture/capture_menu.gd -- --out=DIR --tag=portrait [--notch]
extends SceneTree

var main: Node3D
var out := ""
var tag := ""
var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() == 2 else "1"
	out = args.get("out", "user://captures")
	tag = args.get("tag", "shot")
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	var path := "%s/%s_%s.png" % [out, tag, name]
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)


func _run() -> void:
	MatchSetup.chosen = false
	var a := {"menu": "1", "quality": "medium", "telemetry": "user://test_telemetry/capture_menu.json"}
	if args.has("notch"):
		a["notch"] = "1"
	main = load("res://scenes/main.tscn").instantiate()
	main.args_override = a
	root.add_child(main)
	await _frames(30)
	await _shot("01_menu_default")
	var m: StartMenu = main.menu
	m.buttons["players_2"].pressed.emit()
	m.buttons["character_INVESTOR"].pressed.emit()
	m.buttons["quality_low"].pressed.emit()
	m.buttons["reduced_motion"].button_pressed = true
	await _frames(10)
	await _shot("02_menu_choices")
	m.buttons["how_to"].pressed.emit()
	await _frames(10)
	await _shot("03_how_to")
	m.buttons["how_to_close"].pressed.emit()
	await _frames(5)
	m.buttons["start"].pressed.emit()
	await _frames(30)
	# Real command path: the human stands two tiles before START and rolls,
	# so any roll passes START and the start-reward toast explains the cash.
	var e: GameEngine = main.match_ref.engine
	e.state.player(0)["position"] = e.config.board_size() - 2
	for i in 300:
		await process_frame
		if main.presenter.is_idle() and e.state.current_seat == 0 and e.state.phase == GameState.AWAIT_ROLL:
			break
	main.match_ref.submit(0, ErCommand.ROLL_DICE)
	for i in 240:
		await process_frame
		if main.hud._toasts.get_child_count() > 0:
			break
	await _frames(8)
	print("TOASTS ", main.hud._toasts.get_children().map(func(c): return c.text if c is Label else str(c.find_children("*", "Label", true, false).map(func(l): return l.text))))
	await _shot("04_start_reward_toast")
	quit(0)
