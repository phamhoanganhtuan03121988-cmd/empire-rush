## Phase 5 in-game pause menu: TIẾP TỤC, HƯỚNG DẪN (every tutorial step from
## RulesGuide, to re-read at any time), CÀI ĐẶT (SettingsPanel) and VỀ MÀN
## HÌNH CHÍNH. While it is open the match is paused through the lifecycle
## gate (turn timer, match cap and bots stop), like a backgrounded phone app.
class_name PauseMenu
extends Control

signal resume_requested
signal main_menu_requested
signal settings_changed

var guide: RulesGuide
var buttons := {}
var settings: SettingsPanel
var simulated_insets := Rect2()
var _card: PanelContainer
var _pages := {}
var page := "main"


func setup(config: GameConfig) -> void:
	guide = RulesGuide.new(config)
	theme = UiTheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.7)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiTheme.glass_panel(true))
	add_child(_card)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	_card.add_child(outer)
	# Main page.
	var m := VBoxContainer.new()
	m.add_theme_constant_override("separation", 14)
	outer.add_child(m)
	_pages["main"] = m
	m.add_child(_title("TẠM DỪNG"))
	m.add_child(_note("Đồng hồ lượt và máy đang dừng chờ bạn."))
	for spec in [["resume", "TIẾP TỤC", "dice", ""], ["guide", "HƯỚNG DẪN", "info", "secondary"],
			["settings", "CÀI ĐẶT", "gear", "neutral"], ["main_menu", "VỀ MÀN HÌNH CHÍNH", "flag", "danger"]]:
		var b := _button(spec[1], spec[2])
		match spec[3]:
			"secondary": UiTheme.secondary(b)
			"neutral": UiTheme.neutral(b)
			"danger": UiTheme.danger(b)
		buttons[spec[0]] = b
		m.add_child(b)
	buttons["resume"].pressed.connect(func(): resume_requested.emit())
	buttons["guide"].pressed.connect(func(): _show("guide"))
	buttons["settings"].pressed.connect(func(): _show("settings"))
	buttons["main_menu"].pressed.connect(func(): main_menu_requested.emit())
	# Guide page: every tutorial step, scrollable.
	var g := VBoxContainer.new()
	g.add_theme_constant_override("separation", 12)
	outer.add_child(g)
	_pages["guide"] = g
	g.add_child(_title("HƯỚNG DẪN"))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.set_meta("guide_scroll", true)
	g.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for st in guide.tutorial_steps():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var ic := TextureRect.new()
		ic.texture = UiTheme.icon(st["icon"])
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(44, 44)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ic.modulate = UiTheme.GOLD
		row.add_child(ic)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tv)
		var t := _note(st["title"])
		t.add_theme_color_override("font_color", UiTheme.GOLD)
		t.add_theme_font_override("font", UiTheme.font("Bold"))
		tv.add_child(t)
		tv.add_child(_note(st["body"]))
		list.add_child(row)
	var gb := _button("QUAY LẠI", "close")
	UiTheme.secondary(gb)
	gb.pressed.connect(func(): _show("main"))
	buttons["guide_back"] = gb
	g.add_child(gb)
	# Settings page.
	var s := VBoxContainer.new()
	s.add_theme_constant_override("separation", 12)
	outer.add_child(s)
	_pages["settings"] = s
	s.add_child(_title("CÀI ĐẶT"))
	settings = SettingsPanel.new()
	settings.build()
	settings.changed.connect(func(): settings_changed.emit())
	s.add_child(settings)
	var sb := _button("XONG", "check")
	sb.pressed.connect(func(): _show("main"))
	buttons["settings_back"] = sb
	s.add_child(sb)
	_show("main")
	get_viewport().size_changed.connect(_layout)


func _show(name: String) -> void:
	page = name
	for k in _pages:
		_pages[k].visible = k == name
	_layout.call_deferred()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and visible:
		if page == "main":
			resume_requested.emit()
		else:
			_show("main")
		get_viewport().set_input_as_handled()


func _layout() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport_rect().size
	var safe := Rect2(simulated_insets.position, vp - simulated_insets.position - simulated_insets.size)
	var w := minf(safe.size.x - 28.0, 700.0)
	_card.custom_minimum_size.x = w
	for l in _card.find_children("*", "Label", true, false):
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
			l.custom_minimum_size.x = w - (124.0 if l.get_parent().get_parent() is HBoxContainer else 64.0)
	for sc in _card.find_children("*", "ScrollContainer", true, false):
		if sc.has_meta("guide_scroll"):
			sc.custom_minimum_size.y = minf(sc.get_child(0).get_combined_minimum_size().y, safe.size.y - 280.0)
	_card.reset_size()
	_card.position = safe.position + (safe.size - _card.size) * 0.5


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", UiTheme.GOLD)
	l.add_theme_font_override("font", UiTheme.font("ExtraBold"))
	return l


func _note(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiTheme.FS_BODY)
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
