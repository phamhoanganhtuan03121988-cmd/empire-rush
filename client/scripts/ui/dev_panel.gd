## Device-validation tools for testers on a phone (no command line there):
## a live numbers overlay and an automatic benchmark that plays the match with
## the HUD autopilot and records low / medium / high frame times in turn.
## Opened by holding the graphics-quality button for about one second.
## Presentation only: it never touches the rules engine.
class_name DevPanel
extends Control

signal bench_finished(report_path: String)

const BENCH_ORDER := ["low", "medium", "high"]

var probe: DeviceProbe
## Callables provided by main: set_quality(name), start_autopilot(), current_quality() -> String.
var set_quality: Callable
var start_autopilot: Callable
var current_quality: Callable
var bench_seconds := 60.0

var overlay: Label
var _panel: PanelContainer
var _status: Label
var _overlay_btn: Button
var _bench_btn: Button
var _bench_step := -1
var _bench_end_ms := 0
var _bench_restore := ""
var _overlay_t := 0.0


func setup(p_probe: DeviceProbe) -> void:
	probe = p_probe
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay = Label.new()
	overlay.set_meta("decorative", true)
	overlay.add_theme_font_size_override("font_size", 20)
	overlay.add_theme_color_override("font_color", Color("#7CFC9A"))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_content_margin_all(6)
	overlay.add_theme_stylebox_override("normal", bg)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	add_child(overlay)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(560, 0)
	_panel.add_child(v)
	var title := Label.new()
	title.text = UiText.t("dev_title")
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	v.add_child(title)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 22)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(540, 0)
	v.add_child(_status)
	_overlay_btn = _button(v, "", toggle_overlay)
	_bench_btn = _button(v, UiText.t("dev_bench") % int(bench_seconds), start_bench)
	_button(v, UiText.t("dev_save"), _save_now)
	var close := _button(v, UiText.t("dev_close"), func(): _panel.visible = false)
	UiTheme.secondary(close)
	_refresh_texts()


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func is_open() -> bool:
	return _panel.visible


func open() -> void:
	_refresh_texts()
	_panel.visible = true
	_panel.reset_size()
	_panel.position = (get_viewport_rect().size - _panel.size) / 2.0


func toggle_overlay() -> void:
	overlay.visible = not overlay.visible
	_refresh_texts()


func start_bench() -> void:
	if _bench_step >= 0:
		return
	_bench_restore = current_quality.call()
	start_autopilot.call()
	_panel.visible = false
	overlay.visible = true
	_bench_step = 0
	_begin_step()


func is_benchmarking() -> bool:
	return _bench_step >= 0


func _begin_step() -> void:
	var name: String = BENCH_ORDER[_bench_step]
	set_quality.call(name)
	probe.begin_segment(name, "bench")
	# Wall clock, not summed frame deltas: slow frames must not stretch a step.
	_bench_end_ms = Time.get_ticks_msec() + int(bench_seconds * 1000.0)


func _process(delta: float) -> void:
	if _bench_step >= 0:
		if Time.get_ticks_msec() >= _bench_end_ms:
			_bench_step += 1
			if _bench_step < BENCH_ORDER.size():
				_begin_step()
			else:
				_bench_step = -1
				set_quality.call(_bench_restore)
				probe.save()
				_status.text = UiText.t("dev_bench_done") + "\n" + probe.report_path
				_panel.visible = true
				bench_finished.emit(probe.report_path)
	if overlay.visible:
		_overlay_t -= delta
		if _overlay_t <= 0.0:
			_overlay_t = 0.25
			_update_overlay()


func _update_overlay() -> void:
	var s := probe.live()
	var lines := PackedStringArray()
	lines.append("%s · %.0f FPS · %d draw" % [s.get("preset", ""), s["fps_now"], s["draw_calls"]])
	if s.get("frames", 0) > 0:
		lines.append("p50 %.1f · p95 %.1f · p99 %.1f ms" % [s["p50_ms"], s["p95_ms"], s["p99_ms"]])
		lines.append(">33ms %.1f%% · max %.0f ms" % [s["pct_over_33ms"], s["max_ms"]])
	lines.append("RAM %.0f MB · VRAM %.0f MB" % [s["static_mb"], s["video_mb"]])
	if _bench_step >= 0:
		lines.append(UiText.t("dev_bench_running") % [BENCH_ORDER[_bench_step], ceili((_bench_end_ms - Time.get_ticks_msec()) / 1000.0)])
	overlay.text = "\n".join(lines)
	var safe := get_viewport().get_visible_rect()
	var hud := get_parent() as GameHud
	if hud:
		safe = hud.safe_rect()
	overlay.position = safe.position + Vector2(8, safe.size.y * 0.42)


func _save_now() -> void:
	probe.save()
	_status.text = UiText.t("dev_saved") % probe.report_path


func _refresh_texts() -> void:
	if probe == null:
		return
	_overlay_btn.text = UiText.t("dev_overlay_off") if overlay.visible else UiText.t("dev_overlay_on")
	var lines := PackedStringArray()
	var b := probe.build_info
	lines.append("Build %s · %s · %s" % [b.get("version", ""), b.get("commit", ""), "debug" if b.get("debug_build", false) else "release"])
	var d := probe.device_info()
	lines.append("%s %s · %s" % [d["model"], d["os_version"], d["gpu"]])
	lines.append("Tải: %d ms tới khung hình đầu" % probe.first_frame_ms)
	if probe.previous_session.get("state", "") == "running":
		lines.append(UiText.t("dev_prev_unclean") % "crash / bị hệ thống dừng khi đang mở")
	_status.text = "\n".join(lines)
