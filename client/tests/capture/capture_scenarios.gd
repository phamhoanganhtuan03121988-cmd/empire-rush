## Deterministic screenshot + metrics capture for layout/readability work.
## Builds fixed game situations (white-box engine setup + presentation-only
## board calls), waits for animations, then saves PNGs and prints metrics.
## Works on the M2 code base too, so before/after images are comparable.
## Usage (needs a renderer, e.g. xvfb + lavapipe):
##   godot --path client --resolution 786x1704 --script res://tests/capture/capture_scenarios.gd -- --out=DIR [--notch]
extends SceneTree

var main: Node3D
var out := ""
var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() == 2 else "1"
	out = args.get("out", "user://captures")
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle() -> void:
	for i in 900:
		await process_frame
		if main.presenter.is_idle() and i > 3:
			break
	await _frames(20)


func _shot(name: String) -> void:
	await _frames(3)
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	var rs := RenderingServer
	var m := _board_metrics()
	print("CAPTURE %s draw_calls=%d objects=%d primitives=%d board_area_pct=%.1f min_tile_px=%.1f board_w_pct=%.1f board_h_pct=%.1f" % [name,
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		m["area"], m["min_tile"], m["w"], m["h"]])


## Projected board size: bbox of the 28-tile ring and the smallest projected
## tile edge (proxy for how readable a tile is on the phone).
func _board_metrics() -> Dictionary:
	var cam: Camera3D = main.camera
	var vp := root.get_viewport().get_visible_rect().size
	var bb := Rect2()
	var first := true
	var min_edge := 1e9
	for i in 28:
		var c: Vector3 = BoardLayout.position_of(i)
		var h := 0.5 * (BoardLayout.TILE - BoardLayout.GAP)
		var pts: Array[Vector2] = []
		for d in [Vector3(-h, 0.12, -h), Vector3(h, 0.12, -h), Vector3(h, 0.12, h), Vector3(-h, 0.12, h)]:
			var p := cam.unproject_position(c + d)
			pts.append(p)
			if first:
				bb = Rect2(p, Vector2.ZERO)
				first = false
			else:
				bb = bb.expand(p)
		for k in 4:
			min_edge = minf(min_edge, pts[k].distance_to(pts[(k + 1) % 4]))
	var scale := root.get_window().size.x / vp.x  # report in window pixels
	return {"area": 100.0 * bb.size.x * bb.size.y / (vp.x * vp.y), "min_tile": min_edge * scale,
		"w": 100.0 * bb.size.x / vp.x, "h": 100.0 * bb.size.y / vp.y}


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	var a := {"players": "4", "seed": "7", "quality": args.get("quality", "high")}
	if args.has("notch"):
		a["notch"] = "1"
	for k in ["cam_yaw", "cam_pitch", "cam_half", "cam_tall"]:
		if args.has(k):
			a[k] = args[k]
	main.args_override = a
	root.add_child(main)
	await _frames(5)
	main.presenter.speed = 0.05
	main.match_ref.bot_delay_range = Vector2(999, 999)  # freeze bots: static scenes
	await _settle()
	var e: GameEngine = main.match_ref.engine
	# Mid-game board: ownership and buildings spread over all four sides.
	var layout := {"P_D1_1": [1, 1], "P_D1_2": [1, 2], "P_D1_3": [1, 1], "P_D2_1": [2, 0], "P_D3_1": [3, 0],
		"P_D3_2": [3, 0], "P_D5_1": [2, 3], "P_D5_2": [2, 3], "P_D5_3": [2, 2], "P_D6_2": [1, 0],
		"P_D7_1": [3, 3], "P_D7_2": [3, 2], "P_D7_3": [3, 3], "P_D4_3": [0, 0]}
	for pid in layout:
		e.state.owner[pid] = layout[pid][0]
		e.state.level[pid] = layout[pid][1]
		main.board.show_owner(pid, layout[pid][0])
		main.board.show_level(pid, layout[pid][1], layout[pid][0], false)
	# Human lands on an unowned property -> buy prompt.
	e.state.current_seat = 0
	e.state.phase = GameState.AWAIT_ROLL
	e.state.player(0)["position"] = 13
	main.presenter.presented_pos[0] = 13
	main.presenter.tokens[0].position = main.board.tile_position(13) + Vector3(-0.16, 0, -0.16)
	e._resolve_landing(0)
	main.match_ref.events_emitted.emit(e._commit())
	await _settle()
	main.hud.show_toast("Minh trả 605 RC tiền thuê cho Lan", Color("#ffb3b3"))
	main.hud.show_toast("Lan nâng Vịnh Cọ lên cấp 3 (60 RC)", Color("#27ae60"))
	await _shot("01_buy_prompt")
	if args.has("only_first"):
		quit()
		return
	# Pass -> auction panel.
	for act in main.hud.actions:
		if act["type"] == ErCommand.PASS_PROPERTY:
			act["button"].pressed.emit()
	await _settle()
	await _shot("02_auction")
	# Close the auction, then strategy with the upgrade list open.
	main.match_ref.clock.set_now(e.current_deadline_ms())
	main.match_ref.events_emitted.emit(e.advance())
	await _settle()
	for pid in ["P_D1_1", "P_D1_2", "P_D1_3"]:
		e.state.owner[pid] = 0
		main.board.show_owner(pid, 0)
	e.state.phase = GameState.STRATEGY
	e.state.strategy_used = false
	e.state.turn_deadline_ms = main.match_ref.clock.now_ms() + 45000
	main.match_ref.events_emitted.emit(e._commit())
	await _settle()
	for act in main.hud.actions:
		if act["button"].has_meta("opens"):
			act["button"].pressed.emit()
	await _frames(10)
	await _shot("03_upgrade_menu")
	# Results screen.
	e._end_match("round_cap")
	main.match_ref.events_emitted.emit(e._commit())
	await _settle()
	await _frames(40)
	await _shot("04_results")
	quit()
