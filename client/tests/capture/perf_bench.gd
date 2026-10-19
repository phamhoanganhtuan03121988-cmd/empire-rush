## Fixed-scene performance benchmark with cost attribution (Phase 2, A1).
## Same scene as capture_scenarios.gd (4 players, seed 7, mid-game board,
## buy prompt), same camera, bots frozen, so runs are comparable across
## commits. For each preset it measures a baseline and "ablations" (one part
## removed at a time) to attribute frame cost to shadows, HUD, buildings,
## static board, water, triplanar detail and glow.
## Frame time is wall-clock between frames (Godot clamps `delta` at 133 ms,
## which hides slow frames). Render CPU/GPU time comes from the viewport's
## measured render time. Needs a renderer (xvfb + lavapipe or a GPU).
##   godot --path client --resolution 786x1704 --script res://tests/capture/perf_bench.gd -- --out=FILE.json [--frames=90] [--presets=low,medium,high] [--ablate=1]
extends SceneTree

var main: Node3D
var args := {}
var results: Array = []
var _times: PackedFloat64Array = PackedFloat64Array()
var _cpu: PackedFloat64Array = PackedFloat64Array()
var _gpu: PackedFloat64Array = PackedFloat64Array()


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() == 2 else "1"
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


var load_ms := {}


func _setup() -> void:
	# Load time: scene load + instantiate, then until the board is built and
	# the first frames are drawn (presentation only; engine start included).
	var t_load := Time.get_ticks_usec()
	var packed: PackedScene = load("res://scenes/main.tscn")
	main = packed.instantiate()
	load_ms["scene_load_instantiate"] = snappedf((Time.get_ticks_usec() - t_load) / 1000.0, 0.1)
	main.args_override = {"players": "4", "seed": "7", "quality": "medium", "notch": "1"}
	root.add_child(main)
	await _frames(1)
	load_ms["to_first_frame"] = snappedf((Time.get_ticks_usec() - t_load) / 1000.0, 0.1)
	await _frames(4)
	main.presenter.speed = 0.05
	main.match_ref.bot_delay_range = Vector2(999, 999)
	for i in 600:
		await process_frame
		if main.presenter.is_idle() and i > 3:
			break
	var e: GameEngine = main.match_ref.engine
	var layout := {"P_D1_1": [1, 1], "P_D1_2": [1, 2], "P_D1_3": [1, 1], "P_D2_1": [2, 0], "P_D3_1": [3, 0],
		"P_D3_2": [3, 0], "P_D5_1": [2, 3], "P_D5_2": [2, 3], "P_D5_3": [2, 2], "P_D6_2": [1, 0],
		"P_D7_1": [3, 3], "P_D7_2": [3, 2], "P_D7_3": [3, 3], "P_D4_3": [0, 0]}
	for pid in layout:
		e.state.owner[pid] = layout[pid][0]
		e.state.level[pid] = layout[pid][1]
		main.board.show_owner(pid, layout[pid][0])
		main.board.show_level(pid, layout[pid][1], layout[pid][0], false)
	e.state.current_seat = 0
	e.state.phase = GameState.AWAIT_ROLL
	e.state.player(0)["position"] = 13
	main.presenter.presented_pos[0] = 13
	main.presenter.tokens[0].position = main.board.tile_position(13) + Vector3(-0.16, 0, -0.16)
	e._resolve_landing(0)
	main.match_ref.events_emitted.emit(e._commit())
	# Freeze the turn clock so nothing changes during measurement.
	main.match_ref.lifecycle.pause("bench")
	await _frames(30)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)


func _set_ablation(name: String, on: bool) -> void:
	match name:
		"no_shadows":
			main.sun.shadow_enabled = not on if main.quality != "low" else false
		"no_hud":
			main.hud.visible = not on
		"no_buildings":
			for n in main.board.find_children("Building", "MeshInstance3D", true, false):
				n.visible = not on
		"no_static":
			main.board.get_node("StaticBoard").visible = not on
			if main.board.has_node("StaticProps"):
				main.board.get_node("StaticProps").visible = not on
		"no_water":
			main.board.get_node("Table").visible = not on
		"no_detail_tex":
			QualitySettings.set_material_detail(not on if main.quality != "low" else false)
		"no_glow":
			main.env.glow_enabled = not on if main.quality != "low" else false


func _measure(preset: String, ablation: String) -> void:
	var n := int(args.get("frames", "90"))
	await _frames(20)
	_times.clear()
	_cpu.clear()
	_gpu.clear()
	var vp := root.get_viewport_rid()
	var last := Time.get_ticks_usec()
	var proc := 0.0
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		_times.append((now - last) / 1000.0)
		last = now
		_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
		_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var v := root.get_viewport()
	var row := {
		"preset": preset, "ablation": ablation, "frames": n,
		"frame_ms": _stats(_times), "render_cpu_ms": _stats(_cpu), "render_gpu_ms": _stats(_gpu),
		"process_ms_mean": snappedf(proc / n, 0.01),
		"draw_calls_total": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"draw_calls_3d": v.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"draw_calls_shadow": v.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"primitives_total": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"primitives_3d": v.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"primitives_shadow": v.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"static_mem_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1),
		"video_mem_mb": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"texture_mem_mb": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0, 0.1),
		"buffer_mem_mb": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0, 0.1),
	}
	results.append(row)
	print("PERF %s/%s frame p50=%.1f p95=%.1f p99=%.1f | render cpu %.1f gpu %.1f | dc %d (3d %d, shadow %d) prim3d %d shadowprim %d" % [
		preset, ablation, row["frame_ms"]["p50"], row["frame_ms"]["p95"], row["frame_ms"]["p99"],
		row["render_cpu_ms"]["p50"], row["render_gpu_ms"]["p50"], row["draw_calls_total"], row["draw_calls_3d"],
		row["draw_calls_shadow"], row["primitives_3d"], row["primitives_shadow"]])


static func _stats(a: PackedFloat64Array) -> Dictionary:
	if a.is_empty():
		return {}
	var s := a.duplicate()
	s.sort()
	var total := 0.0
	for x in s:
		total += x
	var q := func(p: float) -> float: return s[clampi(int(ceil(p * s.size())) - 1, 0, s.size() - 1)]
	return {"mean": snappedf(total / s.size(), 0.01), "p50": snappedf(q.call(0.5), 0.01),
		"p95": snappedf(q.call(0.95), 0.01), "p99": snappedf(q.call(0.99), 0.01), "max": snappedf(s[s.size() - 1], 0.01)}


func _run() -> void:
	await _setup()
	print("LOAD ", JSON.stringify(load_ms))
	var presets := str(args.get("presets", "low,medium,high")).split(",")
	var ablations := ["no_shadows", "no_hud", "no_buildings", "no_static", "no_water", "no_detail_tex", "no_glow"]
	for p in presets:
		main.set_quality(p)
		await _measure(p, "base")
		if args.has("ablate"):
			for a in ablations:
				_set_ablation(a, true)
				await _measure(p, a)
				_set_ablation(a, false)
			main.set_quality(p)
	var meta := {"load_ms": load_ms, "engine": Engine.get_version_info()["string"], "adapter": RenderingServer.get_video_adapter_name(),
		"api": RenderingServer.get_video_adapter_api_version(), "viewport": str(root.get_viewport().get_visible_rect().size),
		"window": str(DisplayServer.window_get_size()), "args": args}
	if args.has("out"):
		var f := FileAccess.open(args["out"], FileAccess.WRITE)
		f.store_string(JSON.stringify({"meta": meta, "results": results}, "  "))
		f.close()
	quit()
