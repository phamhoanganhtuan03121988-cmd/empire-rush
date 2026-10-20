## Phase 5.1 dice screenshots: the human's roll in four beats (before the
## roll, dice in the air, result shown, pawn starts to move), for one or more
## seeds. Driven by a real ROLL command through the HUD button; beats follow
## the presenter's cues, so the same script captures old and new code.
## Usage (needs a renderer, e.g. xvfb + lavapipe):
##   godot --path client --resolution 1280x720 --script res://tests/capture/capture_dice.gd -- --out=DIR [--tag=land] [--seeds=3,7] [--players=4] [--notch]
extends SceneTree

var main: Node3D
var args := {}
var out := ""
var tag := ""
var _cues: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() == 2 else "1"
	out = args.get("out", "user://captures")
	tag = args.get("tag", "dice")
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	var path := "%s/%s_%s.png" % [out, tag, name]
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)


func _wait_cue(name: String, max_frames := 900) -> bool:
	for i in max_frames:
		if name in _cues:
			return true
		await process_frame
	return false


func _run() -> void:
	for s in str(args.get("seeds", "3")).split(","):
		await _one(int(s))
	quit()


func _one(seed_value: int) -> void:
	if main:
		main.queue_free()
		await _frames(3)
	_cues.clear()
	var a := {"players": args.get("players", "4"), "seed": str(seed_value), "quality": args.get("quality", "medium"),
		"still": "1", "telemetry": "user://test_telemetry/capture_dice.json"}
	if args.has("notch"):
		a["notch"] = "1"
	main = load("res://scenes/main.tscn").instantiate()
	main.args_override = a
	root.add_child(main)
	main.presenter.cue.connect(func(n: String, _d: Dictionary): _cues.append(n))
	await _frames(30)
	var roll: Button = null
	for i in 1200:
		await process_frame
		for act in main.hud.actions:
			if act["type"] == ErCommand.ROLL_DICE and not act["button"].disabled:
				roll = act["button"]
		if roll and main.presenter.is_idle():
			break
	await _frames(10)
	var s := "s%d" % seed_value
	await _shot(s + "_1_before")
	roll.pressed.emit()
	await _wait_cue("dice_roll")
	await create_timer(0.35).timeout
	await _shot(s + "_2_rolling")
	await _wait_cue("dice_land")
	await create_timer(0.3).timeout
	await _shot(s + "_3_result")
	print("DICE seed=%d shown=%d,%d" % [seed_value, main.dice.top_value(0), main.dice.top_value(1)])
	await _wait_cue("step")
	await create_timer(0.12).timeout
	await _shot(s + "_4_moving")
