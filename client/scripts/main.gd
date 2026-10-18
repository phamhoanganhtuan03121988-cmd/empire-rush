## Vertical-slice entry point: one offline match (human seat 0 vs bots).
## Wires rules (LocalMatch -> GameEngine), presentation (BoardView, tokens,
## dice, EventPresenter) and UI (GameHud). Command-line user args (after --):
##   --players=N --seed=S --quality=low|medium|high --notch (emulate iPhone
##   safe area) --autoplay (HUD autopilot plays seat 0) --timescale=X
##   --telemetry=PATH --shots=DIR --shot-every=SECONDS --quit-on-end
##   --stats=FRAMES (print render statistics once after N frames)
##   --perf (show the device-validation overlay) --bench=SECONDS (run the
##   low/medium/high benchmark at start, SECONDS per preset) --bench-quit
##   --devpanel (open the device panel at start)
##   --reduced-motion (no particle effects, faster token moves)
extends Node3D

const CHARACTERS := ["TYCOON", "INVESTOR", "NEGOTIATOR", "TYCOON"]

var args := {}
## Tests set this before adding the scene to the tree (replaces CLI args).
var args_override: Dictionary = {}
var config: GameConfig
var theme_data: ThemeData
var board: BoardView
var dice: DiceView
var match_ref: LocalMatch
var presenter: EventPresenter
var hud: GameHud
var camera: CameraRig
var sun: DirectionalLight3D
var env: Environment
var telemetry: SessionTelemetry
var autopilot: HudAutopilot
var probe: DeviceProbe
var dev_panel: DevPanel
var quality := "medium"
var _shot_t := 0.0
var _shot_n := 0


func _ready() -> void:
	if args_override.is_empty():
		for a in OS.get_cmdline_user_args():
			var kv := a.trim_prefix("--").split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() == 2 else "1"
	else:
		args = args_override
	if args.has("timescale"):
		Engine.time_scale = float(args["timescale"])
	config = GameConfig.load_from_dir()
	theme_data = ThemeData.load_default()
	_build_world()
	var n := clampi(int(args.get("players", "4")), 2, 4)
	var seed_value := int(args["seed"]) if args.has("seed") else int(Time.get_unix_time_from_system()) % 1000000
	var seats: Array = []
	for i in n:
		seats.append({"player_id": "p%d" % i, "character_id": CHARACTERS[i]})
	match_ref = LocalMatch.new()
	match_ref.name = "LocalMatch"
	add_child(match_ref)
	var tokens: Array[TokenView] = []
	for i in n:
		var t := TokenView.new()
		t.build(i, theme_data)
		add_child(t)
		tokens.append(t)
	presenter = EventPresenter.new()
	presenter.name = "Presenter"
	presenter.board = board
	presenter.dice = dice
	presenter.tokens = tokens
	presenter.theme = theme_data
	presenter.config = config
	presenter.match_ref = match_ref
	presenter.popup_parent = self
	presenter.reduced_motion = args.has("reduced-motion")
	add_child(presenter)
	match_ref.can_act = presenter.is_idle
	match_ref.events_emitted.connect(presenter.enqueue)
	match_ref.events_emitted.connect(_on_events)
	match_ref.start(config, seats, seed_value, [0] as Array[int])
	telemetry = SessionTelemetry.new()
	telemetry.source = "autopilot" if args.has("autoplay") else "human"
	add_child(telemetry)
	presenter.busy_changed.connect(telemetry.on_presentation)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = GameHud.new()
	if args.has("notch"):
		# iPhone 14 Pro portrait safe area: 59 pt top, 34 pt bottom (x1.83 px/pt).
		hud.simulated_insets = Rect2(0, 108, 0, 62)
	layer.add_child(hud)
	hud.setup(match_ref, presenter, theme_data, config)
	hud.restart_requested.connect(func(): get_tree().reload_current_scene())
	hud.quality_cycle_requested.connect(func(): set_quality(QualitySettings.next(quality)))
	_setup_device_probe()
	presenter.match_ended_presented.connect(_on_match_ended)
	set_quality(args.get("quality", "medium"))
	get_viewport().size_changed.connect(_reframe)
	_reframe.call_deferred()
	if args.has("autoplay"):
		start_autopilot()
	if dev_panel and args.has("perf"):
		dev_panel.toggle_overlay()
	if dev_panel and args.has("devpanel"):
		dev_panel.open.call_deferred()
	if dev_panel and args.has("bench"):
		dev_panel.bench_seconds = float(args["bench"])
		dev_panel.start_bench.call_deferred()


func start_autopilot() -> void:
	if autopilot:
		return
	autopilot = HudAutopilot.new()
	add_child(autopilot)
	autopilot.setup(hud, match_ref, 0, match_ref.engine.state.seed_value + 1)


## The probe lives on the root so it survives "play again" scene reloads and
## keeps measuring one app session. Automated tests (args_override) only get
## it when they ask for it, so test runs do not write device reports.
func _setup_device_probe() -> void:
	# Public release builds never get the tools (BuildFlavor).
	if not BuildFlavor.device_tools_enabled():
		return
	if not args_override.is_empty() and not args.has("probe"):
		return
	probe = get_tree().root.get_node_or_null("DeviceProbe") as DeviceProbe
	if probe == null:
		probe = DeviceProbe.new()
		probe.name = "DeviceProbe"
		get_tree().root.add_child.call_deferred(probe)
	dev_panel = DevPanel.new()
	dev_panel.set_quality = set_quality
	dev_panel.start_autopilot = start_autopilot
	dev_panel.current_quality = func() -> String: return quality
	hud.add_child(dev_panel)
	dev_panel.setup(probe)
	hud.dev_menu_enabled = true
	hud.dev_menu_requested.connect(dev_panel.open)
	dev_panel.bench_finished.connect(func(path: String):
		print("BENCH_REPORT ", ProjectSettings.globalize_path(path))
		if args.has("bench-quit"):
			get_tree().quit())


func _build_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#5b8fd6")
	sm.sky_horizon_color = Color("#f6c98b")
	sm.ground_horizon_color = Color("#f6c98b")
	sm.ground_bottom_color = Color("#2a4a6b")
	sm.sun_angle_max = 30.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color("#ffe2b8")
	sun.light_energy = 1.45
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#9cc3ff")
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-30, 150, 0)
	add_child(fill)
	camera = CameraRig.new()
	if args.has("cam_yaw"):
		camera.configure(float(args["cam_yaw"]), float(args.get("cam_pitch", "50")),
			float(args.get("cam_half", "4.6")), float(args.get("cam_tall", "1.6")))
	add_child(camera)
	camera.current = true
	board = BoardView.new()
	board.name = "Board"
	add_child(board)
	board.build(config, theme_data)
	dice = DiceView.new()
	add_child(dice)
	dice.build(theme_data)


func set_quality(name: String) -> void:
	quality = name
	QualitySettings.apply(name, get_viewport(), sun, env)
	board.set_water_lite(name == "low")
	hud.set_quality_label(name)
	if probe and not (dev_panel and dev_panel.is_benchmarking()):
		probe.begin_segment(name)


func _reframe() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	camera.frame(hud.board_insets())


func _on_events(events: Array) -> void:
	for ev in events:
		if ev["type"] == "TurnStarted":
			telemetry.on_turn_started(ev["data"]["seat"], ev["data"]["round"], match_ref.is_human(ev["data"]["seat"]))


func _unhandled_input(event: InputEvent) -> void:
	var pos := Vector2(-1, -1)
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	if pos.x >= 0:
		var idx := board.pick(camera, pos)
		if idx >= 0:
			hud.open_tile_info(idx)


func _on_match_ended(d: Dictionary) -> void:
	var summary := telemetry.summary(d["reason"], match_ref.engine.state.players.size())
	summary["seed"] = match_ref.engine.state.seed_value
	summary["rounds"] = match_ref.engine.state.round
	summary["engine_duration_s"] = d["duration_ms"] / 1000.0
	# Public release builds write no telemetry files (BuildFlavor).
	if BuildFlavor.device_tools_enabled():
		# Exact replay record for bug reports (tools/replay_match.gd).
		summary["replay"] = MatchReplay.record(match_ref.engine)
		var path: String = args.get("telemetry", "user://telemetry/session_%d.json" % Time.get_unix_time_from_system())
		telemetry.save(path, summary)
		print("TELEMETRY ", path, " turns=", summary["turns"], " game_s=", summary["session_game_seconds"])
	if args.has("quit-on-end"):
		await get_tree().create_timer(1.0).timeout
		_capture("final")
		get_tree().quit()


var _stats_t := 0.0
var _stats_done := false


func _process(delta: float) -> void:
	if args.has("stats") and not _stats_done:
		_stats_t += 1.0
		if _stats_t > float(args["stats"]):
			_stats_done = true
			var rs := RenderingServer
			print("RENDER_STATS draw_calls=%d objects=%d primitives=%d video_mem_mb=%.1f fps=%.1f adapter=%s resolution=%s" % [
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
				Engine.get_frames_per_second(), rs.get_video_adapter_name(), str(get_viewport().get_visible_rect().size)])
			get_tree().quit()
	if args.has("shots"):
		_shot_t += delta
		if _shot_t >= float(args.get("shot-every", "5")):
			_shot_t = 0.0
			_capture("%03d" % _shot_n)
			_shot_n += 1


func _capture(tag: String) -> void:
	if not args.has("shots"):
		return
	DirAccess.make_dir_recursive_absolute(args["shots"])
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/shot_%s.png" % [args["shots"], tag])
