## On-device measurement for M2.2 device validation. A phone build has no
## command line, so everything a tester needs is collected in-app and written
## to user://device_validation/ (visible in the iOS Files app, see
## export_presets.cfg). Values are MEASURED by the running build; nothing here
## is estimated. Limits (documented in docs/M2_2_DEVICE_VALIDATION_REPORT.md):
## - frame time is the engine frame delta (CPU+GPU pacing as seen by Godot);
## - input latency is "touch event dispatched -> next frame submitted", it
##   excludes the touch digitizer and display scan-out;
## - memory is Godot's static allocator (tracked in debug builds only; null in
##   release) plus reported video memory, not the process footprint the OS
##   uses for jetsam. Use Xcode's memory gauge for that.
class_name DeviceProbe
extends Node

const DIR := "user://device_validation"
const MARKER := DIR + "/session_open.json"
const SAVE_EVERY_S := 30.0
## Time ignored after a preset change or benchmark segment start (shader
## compiles and pipeline warm-up would otherwise dominate the percentiles).
const WARMUP_MS := 1500

var build_info: Dictionary = {}
var boot_ms := 0
var first_frame_ms := -1
var previous_session: Dictionary = {}
var report_path := ""
var preset := ""
var segments: Array = []
var input_latency_ms: Array = []
var peak_static_mb := 0.0
var peak_video_mb := 0.0

var _frames: PackedFloat32Array = PackedFloat32Array()
var _warm_until_ms := 0
var _segment_start_ms := 0
var _pending_input_us := -1
var _save_t := 0.0
var _started_unix := 0


func _init() -> void:
	boot_ms = Time.get_ticks_msec()
	_started_unix = int(Time.get_unix_time_from_system())
	build_info = load_build_info()
	previous_session = _read_json(MARKER)
	report_path = "%s/run_%d.json" % [DIR, _started_unix]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_write_marker("running")
	RenderingServer.frame_post_draw.connect(_on_frame_post_draw)


static func load_build_info() -> Dictionary:
	var info := _read_json("res://data/build_info.json")
	if info.is_empty():
		info = {"commit": "unknown", "built_at": "unknown"}
	info["version"] = ProjectSettings.get_setting("application/config/version", "")
	info["engine"] = Engine.get_version_info()["string"]
	info["debug_build"] = OS.is_debug_build()
	return info


func device_info() -> Dictionary:
	var screen := DisplayServer.screen_get_size()
	var win := DisplayServer.window_get_size()
	return {
		"os": OS.get_name(), "os_version": OS.get_version(), "model": OS.get_model_name(),
		"cpu": OS.get_processor_name(), "cpu_count": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"graphics_api": RenderingServer.get_video_adapter_api_version(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", ""),
		"display_server": DisplayServer.get_name(),
		"screen_px": [screen.x, screen.y],
		"screen_scale": DisplayServer.screen_get_scale(),
		"refresh_hz": DisplayServer.screen_get_refresh_rate(),
		"safe_area": str(DisplayServer.get_display_safe_area()),
		"viewport": str((Engine.get_main_loop() as SceneTree).root.get_visible_rect().size),
		"window_px": [win.x, win.y],
		"orientation": "portrait" if win.y >= win.x else "landscape",
		"system_memory": OS.get_memory_info(),
	}


## Starts a new frame-time segment (on preset change, benchmark step, ...).
func begin_segment(p_preset: String, tag := "") -> void:
	_close_segment()
	preset = p_preset
	_segment_start_ms = Time.get_ticks_msec()
	_warm_until_ms = _segment_start_ms + WARMUP_MS
	_frames = PackedFloat32Array()
	if tag != "":
		set_meta("segment_tag", tag)
	else:
		remove_meta("segment_tag")


func _process(delta: float) -> void:
	if Time.get_ticks_msec() >= _warm_until_ms:
		_frames.append(delta * 1000.0)
	_save_t += delta
	if _save_t >= SAVE_EVERY_S:
		_save_t = 0.0
		save()
	var static_mb := OS.get_static_memory_usage() / 1048576.0
	peak_static_mb = maxf(peak_static_mb, static_mb)


func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if pressed and _pending_input_us < 0:
		_pending_input_us = Time.get_ticks_usec()


func _on_frame_post_draw() -> void:
	if first_frame_ms < 0:
		first_frame_ms = Time.get_ticks_msec()
	if _pending_input_us >= 0:
		input_latency_ms.append((Time.get_ticks_usec() - _pending_input_us) / 1000.0)
		_pending_input_us = -1
	peak_video_mb = maxf(peak_video_mb,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0)


## Live numbers for the overlay.
func live() -> Dictionary:
	var s := frame_stats(_frames)
	s["fps_now"] = Engine.get_frames_per_second()
	s["draw_calls"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	s["static_mb"] = snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1) if OS.is_debug_build() else -1.0
	s["video_mb"] = snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, 0.1)
	s["preset"] = preset
	return s


static func frame_stats(frames: PackedFloat32Array) -> Dictionary:
	var n := frames.size()
	if n == 0:
		return {"frames": 0}
	var sorted := frames.duplicate()
	sorted.sort()
	var total := 0.0
	var over33 := 0
	var over16 := 0
	for v in sorted:
		total += v
		if v > 33.4:
			over33 += 1
		if v > 16.7:
			over16 += 1
	return {
		"frames": n,
		"mean_fps": snappedf(1000.0 * n / total, 0.1),
		"p50_ms": snappedf(_pct(sorted, 0.50), 0.01),
		"p95_ms": snappedf(_pct(sorted, 0.95), 0.01),
		"p99_ms": snappedf(_pct(sorted, 0.99), 0.01),
		"max_ms": snappedf(sorted[n - 1], 0.01),
		"pct_over_33ms": snappedf(100.0 * over33 / n, 0.01),
		"pct_over_16_7ms": snappedf(100.0 * over16 / n, 0.01),
	}


static func _pct(sorted: PackedFloat32Array, q: float) -> float:
	return sorted[clampi(int(ceil(q * sorted.size())) - 1, 0, sorted.size() - 1)]


func _close_segment() -> void:
	if preset == "" or _frames.is_empty():
		return
	var seg := frame_stats(_frames)
	seg["preset"] = preset
	seg["tag"] = get_meta("segment_tag", "")
	seg["seconds"] = snappedf((Time.get_ticks_msec() - _segment_start_ms) / 1000.0, 0.1)
	seg["draw_calls_at_end"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	segments.append(seg)
	_frames = PackedFloat32Array()


func report(include_open_segment := true) -> Dictionary:
	var segs := segments.duplicate(true)
	if include_open_segment and not _frames.is_empty():
		var open := frame_stats(_frames)
		open["preset"] = preset
		open["tag"] = get_meta("segment_tag", "")
		open["open"] = true
		segs.append(open)
	var lat := PackedFloat32Array(input_latency_ms)
	return {
		"schema": 1,
		"build": build_info,
		"device": device_info(),
		"started_unix": _started_unix,
		"load": {"engine_to_scene_ready_ms": boot_ms, "engine_to_first_frame_ms": first_frame_ms},
		"previous_session": previous_session,
		"frame_segments": segs,
		"input_latency_ms": frame_stats(lat) if lat.size() > 0 else {"frames": 0},
		"input_latency_samples": lat.size(),
		"memory_peak": {
			# Godot only tracks its static allocator in debug builds.
			"static_mb": snappedf(peak_static_mb, 0.1) if OS.is_debug_build() else null,
			"static_peak_reported_mb": snappedf(OS.get_static_memory_peak_usage() / 1048576.0, 0.1) if OS.is_debug_build() else null,
			"video_mb": snappedf(peak_video_mb, 0.1)},
	}


func save() -> void:
	var f := FileAccess.open(report_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report(), "  "))


## Clean end of a session (quit). A marker still saying "running" at the next
## launch means the app died in the foreground: a crash or a watchdog kill.
## "background" means iOS may have reclaimed a suspended app (not a crash).
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			save()
			_write_marker("background")
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_write_marker("running")
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_PREDELETE:
			if report_path != "":
				save()
				DirAccess.remove_absolute(MARKER)


func _write_marker(state: String) -> void:
	var f := FileAccess.open(MARKER, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"state": state, "started_unix": _started_unix,
			"report": report_path, "commit": build_info.get("commit", ""),
			"updated_ms": Time.get_ticks_msec()}))


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
