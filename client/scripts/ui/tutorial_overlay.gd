## Phase 5 guided tutorial, played on a REAL match (2 players, fixed seed).
## A coach card walks through RulesGuide.tutorial_steps() in order. A step
## with `wait` completes when that presenter cue happens for the human
## (step 1 waits for the player's own roll); the buy step also completes when
## the player buys or opens an auction. Other steps continue with TIẾP. While
## the card is up the match is paused through the lifecycle gate (timer and
## bots wait for the reader); the human can still act with the HUD.
class_name TutorialOverlay
extends Control

signal finished

var steps: Array = []
var index := 0
var buttons := {}
var match_ref: LocalMatch
var hud: GameHud
var _card: PanelContainer
var _step: Label
var _title: Label
var _body: Label
var _hint: Label
var _icon: TextureRect
var _waiting := false


func setup(p_match: LocalMatch, p_hud: GameHud, presenter: EventPresenter, config: GameConfig) -> void:
	match_ref = p_match
	hud = p_hud
	steps = RulesGuide.new(config).tutorial_steps()
	theme = UiTheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PanelContainer.new()
	var st := UiTheme.panel(UiTheme.NAVY, UiTheme.GOLD, 20, 0.97)
	st.set_border_width_all(3)
	st.shadow_size = 18
	st.shadow_color = Color(0, 0, 0, 0.5)
	_card.add_theme_stylebox_override("panel", st)
	add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(44, 44)
	_icon.modulate = UiTheme.GOLD
	head.add_child(_icon)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	head.add_child(tv)
	_step = _label(20, UiTheme.TEXT_MUTED, "Bold")
	tv.add_child(_step)
	_title = _label(30, UiTheme.GOLD, "ExtraBold")
	tv.add_child(_title)
	_body = _label(UiTheme.FS_BODY, UiTheme.TEXT, "Medium")
	v.add_child(_body)
	_hint = _label(UiTheme.FS_CAPTION, UiTheme.AMBER, "Bold")
	v.add_child(_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var skip := _button("BỎ HƯỚNG DẪN", "skip")
	UiTheme.neutral(skip)
	skip.pressed.connect(close)
	buttons["skip"] = skip
	row.add_child(skip)
	var next := _button("TIẾP", "check")
	next.pressed.connect(func(): show_step(index + 1))
	buttons["next"] = next
	row.add_child(next)
	presenter.cue.connect(_on_cue)
	get_viewport().size_changed.connect(_layout)
	match_ref.lifecycle.pause("tutorial")
	show_step(0)


func show_step(i: int) -> void:
	if i >= steps.size():
		close()
		return
	index = i
	var s: Dictionary = steps[i]
	_icon.texture = UiTheme.icon(s["icon"])
	_step.text = "HƯỚNG DẪN · BƯỚC %d/%d" % [i + 1, steps.size()]
	_title.text = s["title"]
	_body.text = s["body"]
	_waiting = s["wait"] != ""
	_hint.visible = _waiting
	_hint.text = "Hãy bấm ĐỔ XÚC XẮC ở bảng hành động." if s["wait"] == "dice_land" else ""
	buttons["next"].disabled = _waiting
	buttons["next"].text = "BẮT ĐẦU CHƠI" if i == steps.size() - 1 else "TIẾP"
	if not MatchSetup.reduced_motion:
		_card.modulate.a = 0.0
		_card.create_tween().tween_property(_card, "modulate:a", 1.0, 0.25)
	AudioDirector.ui("ui_confirm" if i > 0 else "your_turn")
	_layout.call_deferred()


func _on_cue(name: String, data: Dictionary) -> void:
	if not visible or index >= steps.size():
		return
	var mine: bool = match_ref.is_human(int(data.get("seat", -1)))
	var wait: String = steps[index]["wait"]
	if wait != "" and name == wait and mine:
		_waiting = false
		show_step(index + 1)
	elif index == 2 and mine and (name == "buy" or name == "auction"):
		show_step(index + 1)


func close() -> void:
	if not visible:
		return
	visible = false
	match_ref.lifecycle.resume("tutorial")
	finished.emit()


func _layout() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport_rect().size
	var landscape := vp.x > vp.y
	var w := minf(vp.x * (0.5 if landscape else 1.0) - 40.0, 680.0)
	_card.custom_minimum_size.x = w
	for l in [_body, _hint]:
		l.custom_minimum_size.x = w - 44.0
	_title.custom_minimum_size.x = w - 100.0
	_card.reset_size()
	if landscape:
		# Over the top of the board area (left of the HUD column).
		var board_w: float = hud._top.position.x if hud else vp.x * GameHud.LANDSCAPE_SPLIT
		_card.position = Vector2((board_w - _card.size.x) * 0.5, 20.0)
	else:
		# Under the player bar, above the board.
		var top := hud._top.position.y + hud._top.size.y + 12.0 if hud else 200.0
		_card.position = Vector2((vp.x - _card.size.x) * 0.5, top)


func _label(size: int, color: Color, weight: String) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", UiTheme.font(weight))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String, icon: String) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = UiTheme.icon(icon)
	b.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AudioDirector.wire(b)
	return b
