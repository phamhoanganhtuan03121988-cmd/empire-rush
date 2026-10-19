## Phase 5 settings, shared by the title flow and the in-game pause menu:
## graphics preset, reduced motion, music and effects volume, mute. Every
## change is saved (GameSettings) and announced with `changed`, so main can
## apply it live (preset, presenter motion, audio buses).
class_name SettingsPanel
extends VBoxContainer

signal changed

const PRESET_LABELS := {"low": "Thấp", "medium": "Vừa", "high": "Cao"}

var buttons := {}   # id -> Button (tests): quality_*, reduced_motion, mute
var sliders := {}   # "music" / "sfx" -> HSlider


func build() -> void:
	add_theme_constant_override("separation", 14)
	_section("Đồ họa")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var group: Array[Button] = []
	for k in QualitySettings.ORDER:
		var b := _button(PRESET_LABELS[k])
		b.set_meta("value", k)
		row.add_child(b)
		group.append(b)
		buttons["quality_" + k] = b
		b.pressed.connect(func():
			MatchSetup.quality = k
			_paint(group, k)
			_save())
	_paint(group, MatchSetup.quality)
	add_child(_hint("Máy yếu hoặc pin yếu: chọn Thấp."))
	var motion := _toggle("Giảm chuyển động", MatchSetup.reduced_motion, func(on: bool):
		MatchSetup.reduced_motion = on
		_save())
	buttons["reduced_motion"] = motion
	_section("Âm thanh")
	sliders["music"] = _slider("Nhạc nền", GameSettings.music_volume, func(v: float):
		GameSettings.music_volume = v
		_save())
	sliders["sfx"] = _slider("Hiệu ứng", GameSettings.sfx_volume, func(v: float):
		GameSettings.sfx_volume = v
		_save())
	buttons["mute"] = _toggle("Tắt âm thanh", GameSettings.muted, func(on: bool):
		GameSettings.muted = on
		_save())
	# Phase 5.1: contextual tips for new players (CoachOverlay).
	_section("Hướng dẫn")
	buttons["tips"] = _toggle("Gợi ý cho người mới", GameSettings.tips_enabled, func(on: bool):
		GameSettings.tips_enabled = on
		_save())
	var again := _button("Hiện lại tất cả gợi ý")
	again.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.neutral(again)
	again.pressed.connect(func():
		GameSettings.tips_seen.clear()
		GameSettings.tips_enabled = true
		buttons["tips"].button_pressed = true
		again.text = "Đã bật lại: gợi ý sẽ hiện khi tình huống xảy ra"
		_save())
	buttons["tips_reset"] = again
	add_child(again)


func _save() -> void:
	GameSettings.save_settings()
	changed.emit()


func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiTheme.FS_LABEL)
	l.add_theme_color_override("font_color", UiTheme.GOLD)
	l.add_theme_font_override("font", UiTheme.font("Bold"))
	add_child(l)


func _hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiTheme.FS_CAPTION)
	l.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AudioDirector.wire(b)
	return b


func _paint(group: Array[Button], sel: Variant) -> void:
	for b in group:
		if b.get_meta("value") == sel:
			for st in ["normal", "hover", "pressed"]:
				b.remove_theme_stylebox_override(st)
			b.remove_theme_color_override("font_color")
			b.set_meta("selected", true)
		else:
			UiTheme.neutral(b)
			b.set_meta("selected", false)


func _toggle(text: String, on: bool, cb: Callable) -> Button:
	var b := _button("")
	b.toggle_mode = true
	b.button_pressed = on
	UiTheme.neutral(b)
	var paint := func(v: bool):
		b.text = "%s: %s" % [text, "BẬT" if v else "TẮT"]
		if v:
			for st in ["normal", "hover", "pressed"]:
				b.remove_theme_stylebox_override(st)
			for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
				b.add_theme_color_override(c, UiTheme.INK)
		else:
			UiTheme.neutral(b)
	paint.call(on)
	b.toggled.connect(func(v: bool):
		paint.call(v)
		cb.call(v))
	add_child(b)
	return b


func _slider(text: String, value: float, cb: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 150
	l.add_theme_font_size_override("font_size", UiTheme.FS_BODY)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.value = roundf(value * 100.0)
	s.custom_minimum_size = Vector2(0, 64)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(s)
	row.add_child(s)
	var pct := Label.new()
	pct.custom_minimum_size.x = 76
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.add_theme_font_size_override("font_size", UiTheme.FS_BODY)
	pct.add_theme_font_override("font", UiTheme.font("Bold"))
	pct.text = "%d%%" % int(s.value)
	row.add_child(pct)
	s.value_changed.connect(func(v: float):
		pct.text = "%d%%" % int(v)
		cb.call(v / 100.0))
	s.drag_ended.connect(func(_c): AudioDirector.ui("ui_click"))
	return s


## Thick track, gold fill and a large round grabber (touch and mouse).
static func _style_slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.14)
	track.set_corner_radius_all(8)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.GOLD
	fill.set_corner_radius_all(8)
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var g := Image.create(36, 36, false, Image.FORMAT_RGBA8)
	for y in 36:
		for x in 36:
			var d := Vector2(x - 17.5, y - 17.5).length()
			var c := UiTheme.TEXT if d < 15.5 else (UiTheme.GOLD_DARK if d < 17.5 else Color(0, 0, 0, 0))
			g.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(g)
	s.add_theme_icon_override("grabber", tex)
	s.add_theme_icon_override("grabber_highlight", tex)
