## Phase 4/5 regression screenshots of the entry flow and the first turn:
## title, intro pages, setup (players, character, colour, line-up), settings,
## how-to sheet, then the match: roll ready (hero button), rolling, the money
## toast, the guided tutorial card and the pause menu. Driven through the real
## buttons and a real ROLL command.
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


func _boot(extra: Dictionary) -> void:
	if main:
		main.queue_free()
		await _frames(3)
	var a := {"menu": "1", "quality": "medium", "still": "1", "telemetry": "user://test_telemetry/capture_menu.json"}
	if args.has("notch"):
		a["notch"] = "1"
	a.merge(extra, true)
	main = load("res://scenes/main.tscn").instantiate()
	main.args_override = a
	root.add_child(main)
	await _frames(30)


func _run() -> void:
	MatchSetup.chosen = false
	MatchSetup.tutorial = false
	GameSettings.intro_seen = false
	MatchSetup.players = 4
	await _boot({})
	await _shot("01_title")
	var m: StartMenu = main.menu
	m.buttons["title_play"].pressed.emit()
	await _frames(12)
	await _shot("02_intro_1")
	m.buttons["intro_next"].pressed.emit()
	m.buttons["intro_next"].pressed.emit()
	await _frames(12)
	await _shot("03_intro_3")
	m.buttons["intro_skip"].pressed.emit()
	await _frames(12)
	m.buttons["players_3"].pressed.emit()
	m.buttons["character_INVESTOR"].pressed.emit()
	m.buttons["color_2"].pressed.emit()
	await _frames(12)
	await _shot("04_setup")
	m.buttons["how_to"].pressed.emit()
	await _frames(10)
	await _shot("05_how_to")
	m.buttons["how_to_close"].pressed.emit()
	m.buttons["setup_back"].pressed.emit()
	await _frames(5)
	m.buttons["title_settings"].pressed.emit()
	await _frames(12)
	await _shot("06_settings")
	m.buttons["settings_back"].pressed.emit()
	await _frames(5)
	m.buttons["title_play"].pressed.emit()
	await _frames(5)
	m.buttons["start"].pressed.emit()
	await _frames(40)
	# Real command path: the human stands two tiles before START and rolls,
	# so any roll passes START and the start-reward toast explains the cash.
	var e: GameEngine = main.match_ref.engine
	e.state.player(0)["position"] = e.config.board_size() - 2
	for i in 300:
		await process_frame
		if main.presenter.is_idle() and e.state.current_seat == 0 and e.state.phase == GameState.AWAIT_ROLL:
			break
	await _frames(20)
	await _shot("07_roll_ready")
	for act in main.hud.actions:
		if act["type"] == ErCommand.ROLL_DICE:
			act["button"].pressed.emit()
	await _frames(4)
	await _shot("08_rolling")
	for i in 400:
		await process_frame
		if main.hud._toasts.get_child_count() > 1:
			break
	await _frames(8)
	await _shot("09_money_toast")
	main.open_pause()
	await _frames(10)
	await _shot("10_pause")
	main.pause_menu.buttons["guide"].pressed.emit()
	await _frames(10)
	await _shot("11_pause_guide")
	main.close_pause()
	# Guided tutorial on a fresh match.
	MatchSetup.chosen = false
	await _boot({})
	main.menu.buttons["title_tutorial"].pressed.emit()
	await _frames(40)
	await _shot("12_tutorial_step1")
	quit(0)
