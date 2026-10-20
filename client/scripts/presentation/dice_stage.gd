## Phase 5.1 foreground dice presentation. The dice are real 3D models, but
## they are thrown in their OWN 3D world (SubViewport, own_world_3d): a small
## felt tray with its own camera and light, shown over the board while the
## board behind it dims a little. Nothing of the city (trees, towers) can be
## in front of or inside a die, the dice are large enough to read the pips,
## and the light is neutral (no green bounce from the grass).
##
## play() runs: dim in -> throw (bounces) -> result "5 + 6 = 11" -> short
## hold -> fade out. A tap, Space or Enter skips to the result and shortens
## the hold. Skipping or reduced motion only changes timing: the faces shown
## are always the engine's values, and nothing here touches the engine.
class_name DiceStage
extends Control

## Beat cues (audio / HUD): "dice_bounce" {index}, "dice_land", "dice_result".
signal beat(name: String, data: Dictionary)

const DIM := 0.42
## Seconds at speed 1: throw, result hold (human / bot), fades.
const THROW := 0.85
const HOLD_HUMAN := 0.8
const HOLD_BOT := 0.5
const FADE_IN := 0.14
const FADE_OUT := 0.18

var dice: DiceView
## Returns the free screen area for the board (HUD insets as fractions).
var region_provider: Callable
var quality := "medium"

var _dim: ColorRect
var _box: SubViewportContainer
var _vp: SubViewport
var _cam: Camera3D
var _light: DirectionalLight3D
var _result: Label
var _who: Label
var _card: PanelContainer
var _skip := false
var _short_hold := false
var _playing := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.01, 0.02, 0.05, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_box = SubViewportContainer.new()
	_box.stretch = true
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_box.add_child(_vp)
	_build_world()
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiTheme.NAVY, 0.92)
	sb.border_color = UiTheme.GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 8
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 14
	_card.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(col)
	_who = Label.new()
	_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_who.add_theme_font_override("font", UiTheme.font("Bold"))
	_who.add_theme_font_size_override("font_size", 26)
	col.add_child(_who)
	_result = Label.new()
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.add_theme_font_override("font", UiTheme.font("ExtraBold"))
	_result.add_theme_font_size_override("font_size", 64)
	_result.add_theme_color_override("font_color", UiTheme.GOLD)
	_result.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_result.add_theme_constant_override("shadow_offset_y", 4)
	col.add_child(_result)
	add_child(_card)
	_card.visible = false
	get_viewport().size_changed.connect(_layout)


func _build_world() -> void:
	var world := Node3D.new()
	_vp.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#f4efe6")
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	_light = DirectionalLight3D.new()
	_light.rotation_degrees = Vector3(-62, -35, 0)
	_light.light_energy = 1.15
	_light.light_color = Color("#fff6e8")
	_light.shadow_enabled = true
	_light.shadow_blur = 1.6
	world.add_child(_light)
	# The tray: night-blue felt in a walnut ring with a gold inlay (the board's
	# palette), so the dice read as part of the table, not a pasted sticker.
	var ring := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 1.12
	rm.bottom_radius = 1.16
	rm.height = 0.12
	rm.radial_segments = 64
	ring.mesh = rm
	ring.position = Vector3(0, -0.075, 0)
	ring.material_override = _mat(Color("#4a3426"), 0.55)
	world.add_child(ring)
	var inlay := MeshInstance3D.new()
	var im := CylinderMesh.new()
	im.top_radius = 1.05
	im.bottom_radius = 1.05
	im.height = 0.115
	im.radial_segments = 64
	inlay.mesh = im
	inlay.position = Vector3(0, -0.062, 0)
	inlay.material_override = _mat(UiTheme.GOLD, 0.3, 0.6)
	world.add_child(inlay)
	var felt := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 1.0
	fm.bottom_radius = 1.0
	fm.height = 0.12
	fm.radial_segments = 64
	felt.mesh = fm
	felt.position = Vector3(0, -0.055, 0)
	felt.material_override = _mat(Color("#13233b"), 1.0)
	world.add_child(felt)
	dice = DiceView.new()
	dice.build()
	dice.scale = Vector3.ONE * 1.25
	world.add_child(dice)
	dice.bounced.connect(func(i: int):
		beat.emit("dice_land" if i == DiceView.IMPACTS.size() - 1 else "dice_bounce", {"index": i}))
	_cam = Camera3D.new()
	_cam.fov = 30.0
	world.add_child(_cam)
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.look_at_from_position(Vector3(0, 3.3, 2.45), Vector3(0, -0.05, 0.12))


static func _mat(c: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func set_quality(name: String) -> void:
	quality = name
	_vp.msaa_3d = {"low": Viewport.MSAA_DISABLED, "medium": Viewport.MSAA_2X, "high": Viewport.MSAA_4X}.get(name, Viewport.MSAA_2X)
	_light.shadow_enabled = name != "low"


func _region() -> Rect2:
	var vp := get_viewport_rect().size
	var ins: Dictionary = region_provider.call() if region_provider.is_valid() else {}
	var r := Rect2(vp.x * ins.get("left", 0.0), vp.y * ins.get("top", 0.0), 0, 0)
	r.size = Vector2(vp.x * (1.0 - ins.get("left", 0.0) - ins.get("right", 0.0)), vp.y * (1.0 - ins.get("top", 0.0) - ins.get("bottom", 0.0)))
	return r


## The tray covers the middle of the board area (dice ~1/7 of its width each), the
## result card sits just under it.
func _layout() -> void:
	# Hidden at _ready, so anchors never sized it: fill the screen by hand
	# (the dim and the tap-to-skip area need the full rect).
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_dim.position = Vector2.ZERO
	_dim.size = size
	var r := _region()
	# Mobile pass: 76% of the board area (was 92%): the dice stay big and
	# readable but no longer cover the whole board on a phone.
	var w := minf(minf(r.size.x * 0.76, (r.size.y - 120.0) * 1.1), 620.0)
	w = maxf(w, 280.0)
	var h := w / 1.35
	_box.size = Vector2(w, h)
	_box.position = Vector2(r.get_center().x - w * 0.5, r.position.y + maxf(0.0, (r.size.y - h - 110.0) * 0.5))
	_card.reset_size()
	_card.position = Vector2(r.get_center().x - _card.size.x * 0.5, _box.position.y + h - 26.0)


## Present one roll; returns when the stage has faded out.
func play(d1: int, d2: int, who: String, color: Color, human: bool, speed := 1.0, reduced := false) -> void:
	_playing = true
	_skip = false
	_short_hold = false
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_card.visible = false
	_who.text = who
	_who.add_theme_color_override("font_color", color.lightened(0.25))
	_result.text = ""
	_layout()
	var tw := create_tween()
	tw.tween_property(_dim, "color:a", DIM, FADE_IN * speed if not reduced else 0.0)
	_box.modulate.a = 1.0
	if reduced:
		dice.place(d1, d2, Vector3.ZERO)
		beat.emit("dice_land", {"index": DiceView.IMPACTS.size() - 1})
	else:
		await dice.roll_to(d1, d2, Vector3.ZERO, THROW * speed)
	_result.text = "%d + %d = %d" % [d1, d2, d1 + d2]
	_card.visible = true
	_layout()
	_card.pivot_offset = _card.size * 0.5
	if not reduced and speed > 0.2:
		_card.scale = Vector2.ONE * 0.7
		create_tween().tween_property(_card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	beat.emit("dice_result", {"d1": d1, "d2": d2})
	var hold := (HOLD_HUMAN if human else HOLD_BOT) * speed
	if _short_hold:
		hold = minf(hold, 0.35 * speed)
	var t := 0.0
	while t < hold and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()
	var out := create_tween().set_parallel()
	var fade := FADE_OUT * speed if not reduced else 0.06 * speed
	out.tween_property(_dim, "color:a", 0.0, fade)
	out.tween_property(_box, "modulate:a", 0.0, fade)
	out.tween_property(_card, "modulate:a", 0.0, fade)
	await out.finished
	_card.modulate.a = 1.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playing = false


func is_playing() -> bool:
	return _playing


## Skip: the dice land on their (engine) faces now and the hold is cut short.
func skip() -> void:
	if not _playing:
		return
	if dice.is_rolling():
		_short_hold = true
		dice.skip()
	else:
		_skip = true


func _gui_input(event: InputEvent) -> void:
	if _playing and (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		skip()
		accept_event()


func _input(event: InputEvent) -> void:
	if _playing and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		skip()
		get_viewport().set_input_as_handled()
