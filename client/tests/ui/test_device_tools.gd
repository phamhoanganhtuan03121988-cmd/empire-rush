## M2.2 device tools: a short press on the graphics button still cycles the
## preset, a long press opens the device panel, and the automatic benchmark
## records one frame-time segment per preset and restores the preset.
extends UiTestCase


func _cleanup_probe() -> void:
	var p: Node = tree.root.get_node_or_null("DeviceProbe")
	if p:
		var report: String = p.report_path
		p.free()
		if report != "":
			DirAccess.remove_absolute(report)
		DirAccess.remove_absolute(DeviceProbe.MARKER)


func test_short_and_long_press_on_quality_button() -> void:
	await start_game(2, 3, {"probe": "1"})
	var hud: GameHud = main.hud
	var btn: Button = hud._quality_btn
	assert_eq(main.quality, "low", "start preset")
	btn.button_down.emit()
	btn.pressed.emit()
	await frames(2)
	assert_eq(main.quality, "medium", "short press cycles the preset")
	assert_false(main.dev_panel.is_open(), "short press does not open the panel")
	btn.button_down.emit()
	hud._quality_down_ms -= GameHud.LONG_PRESS_MS + 50  # held long enough
	btn.pressed.emit()
	await frames(2)
	assert_eq(main.quality, "medium", "long press does not change the preset")
	assert_true(main.dev_panel.is_open(), "long press opens the device panel")
	for b in main.dev_panel.find_children("*", "Button", true, false):
		var bt: Button = b
		if bt.is_visible_in_tree():
			assert_true(bt.size.y >= UiTheme.MIN_TOUCH, "panel button '%s' is a touch target" % bt.text)
	await stop_game()
	_cleanup_probe()


func test_benchmark_records_every_preset() -> void:
	await start_game(2, 5, {"probe": "1"})
	await frames(2)
	var panel: DevPanel = main.dev_panel
	panel.bench_seconds = 2.5  # > DeviceProbe.WARMUP_MS so every step keeps frames
	var probe: DeviceProbe = main.probe
	var before: int = probe.segments.size()
	panel.start_bench()
	assert_true(main.autopilot != null, "benchmark plays through the HUD autopilot")
	for i in 2000:
		await tree.process_frame
		if not panel.is_benchmarking():
			break
	assert_false(panel.is_benchmarking(), "benchmark finished")
	assert_eq(main.quality, "low", "preset restored after the benchmark")
	var tags: Array = []
	for s in probe.segments.slice(before):
		if s["tag"] == "bench":
			tags.append(s["preset"])
	assert_eq(tags, ["low", "medium", "high"], "one bench segment per preset")
	var rep := probe.report()
	assert_true(rep.has("device") and rep.has("build") and rep.has("load"), "report sections")
	assert_true(FileAccess.file_exists(probe.report_path), "report saved to user://")
	await stop_game()
	_cleanup_probe()


func test_touch_records_input_latency() -> void:
	await start_game(2, 7, {"probe": "1"})
	await frames(3)
	var probe: DeviceProbe = main.probe
	var before: int = probe.input_latency_ms.size()
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = Vector2(360, 700)
	tree.root.push_input(ev)
	await frames(3)
	assert_true(probe._pending_input_us >= 0 or probe.input_latency_ms.size() > before, "touch reached the probe")
	if DisplayServer.get_name() == "headless":
		# The headless renderer never draws, so frame_post_draw is not emitted;
		# stand in for the first drawn frame after the touch.
		probe._on_frame_post_draw()
	assert_eq(probe.input_latency_ms.size(), before + 1, "one latency sample per touch")
	if probe.input_latency_ms.size() > before:
		var ms: float = probe.input_latency_ms[before]
		assert_true(ms >= 0.0 and ms < 5000.0, "plausible latency %.2f ms" % ms)
	await stop_game()
	_cleanup_probe()
