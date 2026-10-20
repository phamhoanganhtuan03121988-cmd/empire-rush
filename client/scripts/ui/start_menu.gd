## Front end (Phase 4 start menu, rebuilt in Phase 5 as a full entry flow):
##   title    - logo over the slowly turning diorama; CHƠI, HƯỚNG DẪN,
##              GIỚI THIỆU, CÀI ĐẶT;
##   intro    - four short pages on the goal and the turn (RulesGuide, from the
##              rules data), skippable; shown once before the first match;
##   setup    - players (2-4), character cards with the ability, the player's
##              colour and display name, and the line-up of the bots;
##   settings - SettingsPanel (graphics, reduced motion, volumes, mute);
##   how-to   - the full rules sheet (RulesGuide.how_to_text()).
## Choices live in MatchSetup / GameSettings, so back, skip and play-again
## never lose them. Pure presentation: rules come from GameConfig.
class_name StartMenu
extends Control

signal start_requested
signal tutorial_requested
signal settings_changed
signal resume_requested

const PRESET_LABELS := SettingsPanel.PRESET_LABELS
## Widest the how-to column and the cards get (logical px).
const READ_WIDTH := 760.0
const CARD_WIDTH := 700.0

var config: GameConfig
var theme_data: ThemeData
var guide: RulesGuide
var simulated_insets := Rect2()
var buttons := {}            # id -> Button (tests)
var page := ""
var how_to: PanelContainer
var how_to_label: Label
var settings: SettingsPanel
var _pages := {}             # name -> Control
var _cards := {}             # name -> PanelContainer (intro/setup/settings)
var _scroll: ScrollContainer # setup choices (tests)
var _card: PanelContainer    # setup card (tests)
var _content: VBoxContainer
var _bottom: HBoxContainer
var _relayouts := 2
var _ability: Label
var _lineup: HBoxContainer
var _name_edit: LineEdit
var _scrim: TextureRect
var _title_box: VBoxContainer
var _title_buttons: VBoxContainer
var _intro_index := 0
var _intro_parts := {}
var _settings_back_to := "title"
var _color_group: Array[Button] = []
var _persona_group: Array[Button] = []
var _persona_grid: GridContainer
var _persona_bio: Label
## Setup: two columns in landscape (players + character | identity + bots).
var _split: BoxContainer
var _cols: Array[VBoxContainer] = []


func setup(p_config: GameConfig, p_theme: ThemeData, first_page := "title") -> void:
	config = p_config
	theme_data = p_theme
	guide = RulesGuide.new(config)
	theme = UiTheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim = TextureRect.new()
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scrim.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_scrim)
	_build_title()
	_build_intro()
	_build_setup()
	_build_settings()
	_build_how_to()
	resized.connect(_layout)
	get_viewport().size_changed.connect(func(): _relayouts = 2; _layout())
	# Wrapped labels settle their height a few frames late: re-place the
	# title column when it does (or the buttons float above the bottom).
	_title_box.minimum_size_changed.connect(_layout.call_deferred)
	_title_buttons.minimum_size_changed.connect(_layout.call_deferred)
	show_page(first_page)


# --- navigation -----------------------------------------------------------------

func show_page(name: String) -> void:
	page = name
	for k in _pages:
		_pages[k].visible = k == name
	how_to.visible = false
	if name == "intro":
		_show_intro(0)
	if name == "setup":
		_refresh_setup()
	_relayouts = 2
	_layout.call_deferred()
	var p: Control = _pages[name]
	if not MatchSetup.reduced_motion:
		p.modulate.a = 0.0
		p.create_tween().tween_property(p, "modulate:a", 1.0, 0.22)


func _play_pressed() -> void:
	show_page("setup" if GameSettings.intro_seen else "intro")


func _finish_intro() -> void:
	GameSettings.intro_seen = true
	GameSettings.save_settings()
	show_page("setup")


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and visible):
		return
	if event.keycode == KEY_ESCAPE:
		if how_to.visible:
			how_to.visible = false
		elif page == "intro" or page == "setup":
			show_page("title")
		elif page == "settings":
			show_page(_settings_back_to)
		else:
			return
		AudioDirector.ui("ui_back")
		get_viewport().set_input_as_handled()


# --- title ----------------------------------------------------------------------

func _build_title() -> void:
	var p := Control.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	_pages["title"] = p
	_title_box = VBoxContainer.new()
	_title_box.add_theme_constant_override("separation", 6)
	p.add_child(_title_box)
	var kicker := _label("TRÒ CHƠI BÀN CỜ CHIẾN THUẬT", 24, UiTheme.TEXT_MUTED, "Bold")
	_title_box.add_child(kicker)
	var logo := _label("EMPIRE\nRUSH", 112, UiTheme.GOLD, "ExtraBold")
	logo.add_theme_constant_override("line_spacing", -24)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	logo.add_theme_constant_override("shadow_offset_x", 0)
	logo.add_theme_constant_override("shadow_offset_y", 6)
	logo.add_theme_constant_override("shadow_outline_size", 10)
	_title_box.add_child(logo)
	var rule := ColorRect.new()
	rule.color = UiTheme.GOLD
	rule.custom_minimum_size = Vector2(96, 4)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_title_box.add_child(rule)
	var tag := _label("Mua đất · Gom quận · Xây nhà · Thu tiền thuê", 28, UiTheme.TEXT, "Medium")
	_title_box.add_child(tag)
	_title_buttons = VBoxContainer.new()
	_title_buttons.add_theme_constant_override("separation", 14)
	p.add_child(_title_buttons)
	# Web/PWA: a saved match comes first (closing the app never loses it).
	var saved := SavedMatch.load_record()
	if not saved.is_empty():
		var res := _button("TIẾP TỤC TRẬN", "arrow_up")
		res.custom_minimum_size.y = 120
		res.add_theme_font_size_override("font_size", 38)
		res.add_theme_font_override("font", UiTheme.font("ExtraBold"))
		res.pressed.connect(func():
			SavedMatch.pending = SavedMatch.load_record()
			if SavedMatch.pending.is_empty():
				show_page("title")
				return
			resume_requested.emit())
		buttons["title_resume"] = res
		UiTheme.center_text(res)
		_title_buttons.add_child(res)
		var info := _label(SavedMatch.summary(saved), 22, UiTheme.TEXT_MUTED, "Medium")
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title_buttons.add_child(info)
	var play := _button("CHƠI" if saved.is_empty() else "TRẬN MỚI", "dice")
	play.custom_minimum_size.y = 120 if saved.is_empty() else 96
	if not saved.is_empty():
		UiTheme.secondary(play)
	play.add_theme_font_size_override("font_size", 40)
	play.add_theme_font_override("font", UiTheme.font("ExtraBold"))
	play.add_theme_constant_override("icon_max_width", 52)
	play.pressed.connect(_play_pressed)
	buttons["title_play"] = play
	UiTheme.center_text(play)
	_title_buttons.add_child(play)
	var tut := _button("HƯỚNG DẪN TỪNG BƯỚC", "star")
	UiTheme.secondary(tut)
	tut.pressed.connect(func(): tutorial_requested.emit())
	buttons["title_tutorial"] = tut
	UiTheme.center_text(tut)
	_title_buttons.add_child(tut)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_title_buttons.add_child(row)
	var intro := _button("GIỚI THIỆU", "info")
	UiTheme.neutral(intro)
	intro.pressed.connect(func(): show_page("intro"))
	buttons["title_intro"] = intro
	row.add_child(intro)
	var sets := _button("CÀI ĐẶT", "gear")
	UiTheme.neutral(sets)
	sets.pressed.connect(func(): _settings_back_to = "title"; show_page("settings"))
	buttons["title_settings"] = sets
	row.add_child(sets)
	var stamp := ("Phiên bản %s" if BuildFlavor.name() == "public-release" else "Bản thử nội bộ · %s") % _build_stamp()
	var foot := _label(stamp, 20, Color(1, 1, 1, 0.45), "Medium")
	foot.name = "Footer"
	_title_buttons.add_child(foot)


func _build_stamp() -> String:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/build_info.json")) if FileAccess.file_exists("res://data/build_info.json") else null
	return str(d.get("commit", "dev")) if d is Dictionary else "dev"


# --- intro ----------------------------------------------------------------------

func _build_intro() -> void:
	var v := _page_card("intro")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	v.add_child(head)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiTheme.badge(UiTheme.NAVY_SOFT, UiTheme.GOLD))
	badge.custom_minimum_size = Vector2(112, 112)
	var icon := _icon("trophy", 72, UiTheme.GOLD)
	badge.add_child(icon)
	head.add_child(badge)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(tv)
	var step := _label("", 22, UiTheme.TEXT_MUTED, "Bold")
	tv.add_child(step)
	var title := _label("", 40, UiTheme.GOLD, "ExtraBold")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(title)
	var body := _label("", 28, UiTheme.TEXT, "Medium")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_constant_override("line_spacing", 6)
	v.add_child(body)
	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 10)
	v.add_child(dots)
	for i in guide.intro_pages().size():
		var d := Panel.new()
		d.custom_minimum_size = Vector2(14, 14)
		dots.add_child(d)
	_intro_parts = {"icon": icon, "step": step, "title": title, "body": body, "dots": dots, "box": v}
	var row := _bottom_row("intro")
	var skip := _button("BỎ QUA", "skip")
	UiTheme.neutral(skip)
	skip.pressed.connect(_finish_intro)
	buttons["intro_skip"] = skip
	row.add_child(skip)
	var back := _button("QUAY LẠI", "close")
	UiTheme.secondary(back)
	back.pressed.connect(func():
		if _intro_index == 0:
			show_page("title")
		else:
			_show_intro(_intro_index - 1))
	buttons["intro_back"] = back
	row.add_child(back)
	var next := _button("TIẾP", "check")
	next.pressed.connect(func():
		if _intro_index >= guide.intro_pages().size() - 1:
			_finish_intro()
		else:
			_show_intro(_intro_index + 1))
	buttons["intro_next"] = next
	row.add_child(next)


func _show_intro(i: int) -> void:
	var pages := guide.intro_pages()
	_intro_index = clampi(i, 0, pages.size() - 1)
	var pg: Dictionary = pages[_intro_index]
	_intro_parts["icon"].texture = UiTheme.icon(pg["icon"])
	_intro_parts["step"].text = "%d / %d" % [_intro_index + 1, pages.size()]
	_intro_parts["title"].text = pg["title"]
	_intro_parts["body"].text = pg["body"]
	var k := 0
	for d in _intro_parts["dots"].get_children():
		var st := StyleBoxFlat.new()
		st.bg_color = UiTheme.GOLD if k == _intro_index else Color(1, 1, 1, 0.25)
		st.set_corner_radius_all(7)
		d.add_theme_stylebox_override("panel", st)
		k += 1
	var last := _intro_index == pages.size() - 1
	buttons["intro_next"].text = "BẮT ĐẦU" if last else "TIẾP"
	buttons["intro_back"].text = "MENU" if _intro_index == 0 else "QUAY LẠI"
	UiTheme.refit_button(buttons["intro_next"])
	UiTheme.refit_button(buttons["intro_back"])
	var box: Control = _intro_parts["box"]
	if not MatchSetup.reduced_motion and is_inside_tree():
		box.modulate.a = 0.0
		box.create_tween().tween_property(box, "modulate:a", 1.0, 0.25)
	_relayouts = 2
	_layout.call_deferred()


# --- setup ----------------------------------------------------------------------

func _build_setup() -> void:
	var root := _page_card("setup", true)
	_card = _cards["setup"]
	root.add_child(_label("THIẾT LẬP TRẬN", 40, UiTheme.GOLD, "ExtraBold"))
	_split = BoxContainer.new()
	_split.add_theme_constant_override("separation", 28)
	root.add_child(_split)
	for i in 2:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 14)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_split.add_child(col)
		_cols.append(col)
	var v := _cols[0]
	# Phase 5.1: a real character choice (portrait, name, colour, bio). The
	# persona is cosmetic; the ROLE below is the approved rules character.
	_section(v, "Chọn nhân vật")
	_persona_grid = GridContainer.new()
	_persona_grid.columns = 4
	_persona_grid.add_theme_constant_override("h_separation", 10)
	_persona_grid.add_theme_constant_override("v_separation", 10)
	v.add_child(_persona_grid)
	for p in theme_data.personas:
		var pid: String = p["id"]
		var b := Button.new()
		b.text = p["name"]
		b.icon = theme_data.portrait(pid)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = Vector2(0, 150)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_constant_override("icon_max_width", 104)
		b.add_theme_constant_override("h_separation", 2)
		for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(k, Color.WHITE)
		b.set_meta("value", pid)
		b.tooltip_text = p["bio"]
		AudioDirector.wire(b)
		b.pressed.connect(func():
			MatchSetup.choose_persona(pid, theme_data.personas)
			_name_edit.text = MatchSetup.player_name
			_refresh_setup())
		buttons["persona_%s" % pid] = b
		_persona_group.append(b)
		_persona_grid.add_child(b)
	_persona_bio = _label("", UiTheme.FS_BODY, UiTheme.TEXT, "Medium")
	_persona_bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_persona_bio)
	_section(v, "Số người chơi (bạn + máy)")
	_choice_row(v, "players", [[2, "2"], [3, "3"], [4, "4"]], MatchSetup.players, func(x):
		MatchSetup.players = x
		_refresh_setup())
	# Who plays: one portrait per seat (you first, then the bots' personas).
	_section(v, "Đội hình trận")
	_lineup = HBoxContainer.new()
	_lineup.add_theme_constant_override("separation", 10)
	v.add_child(_lineup)
	v = _cols[1]
	_section(v, "Tên và màu quân của bạn")
	_name_edit = LineEdit.new()
	_name_edit.max_length = MatchSetup.NAME_MAX
	_name_edit.placeholder_text = "Tên hiển thị (ví dụ: Bạn)"
	_name_edit.text = MatchSetup.player_name
	_name_edit.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
	_name_edit.add_theme_font_size_override("font_size", 28)
	_name_edit.add_theme_stylebox_override("normal", UiTheme.panel(Color("#0c1220"), Color(1, 1, 1, 0.18), 16, 0.95))
	_name_edit.add_theme_stylebox_override("focus", UiTheme.panel(Color("#0c1220"), UiTheme.GOLD, 16, 0.95))
	_name_edit.text_changed.connect(func(t: String):
		MatchSetup.player_name = t
		_refresh_lineup())
	v.add_child(_name_edit)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 10)
	v.add_child(crow)
	for i in theme_data.players.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("value", i)
		b.tooltip_text = "Màu quân %d" % (i + 1)
		AudioDirector.wire(b)
		b.pressed.connect(func():
			MatchSetup.color_index = i
			_refresh_setup())
		buttons["color_%d" % i] = b
		_color_group.append(b)
		crow.add_child(b)
	_section(v, "Vai trò trong trận (kỹ năng)")
	var chars: Array = []
	for c in MatchSetup.CHARACTER_CYCLE:
		chars.append([c, theme_data.loc(c, "short", c), theme_data.character_icon(c)])
	_choice_row(v, "character", chars, MatchSetup.character, func(x):
		MatchSetup.character = x
		_update_ability()
		_refresh_setup())
	_ability = _label("", UiTheme.FS_BODY, UiTheme.TEXT, "Medium")
	_ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_ability)
	var note := _label("Nhân vật chỉ là ngoại hình. Vai trò quyết định kỹ năng trong trận.", 20, UiTheme.TEXT_MUTED, "Medium")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	var row := _bottom_row("setup")
	_bottom = row
	var back := _button("MENU", "close")
	UiTheme.neutral(back)
	back.pressed.connect(func(): show_page("title"))
	buttons["setup_back"] = back
	row.add_child(back)
	var help := _button("CÁCH CHƠI", "info")
	UiTheme.secondary(help)
	help.pressed.connect(func(): how_to.visible = true; _layout.call_deferred())
	buttons["how_to"] = help
	row.add_child(help)
	var start := _button("BẮT ĐẦU", "dice")
	start.add_theme_font_override("font", UiTheme.font("ExtraBold"))
	start.pressed.connect(func():
		GameSettings.save_settings()
		AudioDirector.ui("ui_confirm")
		start_requested.emit())
	buttons["start"] = start
	row.add_child(start)
	_update_ability()


func _refresh_setup() -> void:
	if _color_group.is_empty():
		return
	for b in _persona_group:
		var sel: bool = b.get_meta("value") == MatchSetup.persona
		var pc := Color(theme_data.persona(b.get_meta("value")).get("color", "#334"))
		var st := UiTheme.panel(pc.darkened(0.55) if sel else Color("#0c1220"), UiTheme.GOLD if sel else Color(1, 1, 1, 0.14), 18, 0.95)
		st.set_border_width_all(5 if sel else 2)
		st.set_content_margin_all(6)
		var hov := st.duplicate()
		hov.bg_color = pc.darkened(0.35)
		for k in ["normal", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, st)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_color_override("font_color", UiTheme.GOLD if sel else UiTheme.TEXT)
		b.add_theme_color_override("font_hover_color", UiTheme.GOLD if sel else UiTheme.TEXT)
		b.set_meta("selected", sel)
	var me := theme_data.persona(MatchSetup.persona)
	if _persona_bio and not me.is_empty():
		_persona_bio.text = "%s: %s" % [me["name"], me["bio"]]
	for b in _color_group:
		var i: int = b.get_meta("value")
		var c := Color(theme_data.players[i]["color"])
		var sel := i == MatchSetup.color_index
		var st := UiTheme.panel(c, UiTheme.GOLD if sel else Color(1, 1, 1, 0.3), 18, 1.0)
		st.set_border_width_all(6 if sel else 2)
		var hov := st.duplicate()
		hov.bg_color = c.lightened(0.15)
		for k in ["normal", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, st)
		b.add_theme_stylebox_override("hover", hov)
		b.icon = UiTheme.icon("check") if sel else null
		b.add_theme_color_override("icon_normal_color", Color.WHITE)
		b.add_theme_color_override("icon_hover_color", Color.WHITE)
		b.set_meta("selected", sel)
	_refresh_lineup()


func _refresh_lineup() -> void:
	if _lineup == null:
		return
	for c in _lineup.get_children():
		_lineup.remove_child(c)
		c.queue_free()
	var ids := MatchSetup.identities(theme_data.players, MatchSetup.players, theme_data.personas)
	var chars := MatchSetup.seat_characters(MatchSetup.players, MatchSetup.character)
	for seat in ids.size():
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size.x = 0
		var pc := Color(ids[seat]["color"])
		var av := PortraitBadge.make(theme_data.portrait(ids[seat]["persona"]), pc, 60)
		av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(av)
		for line in [[ids[seat]["name"], 20, UiTheme.GOLD if seat == 0 else pc.lightened(0.45), "Bold"],
				["%s · %s" % [theme_data.loc(chars[seat], "short", chars[seat]), "bạn" if seat == 0 else "máy"], 17, UiTheme.TEXT_MUTED, "Medium"]]:
			var l := _label(str(line[0]), line[1], line[2], line[3])
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.custom_minimum_size.x = 0
			cell.add_child(l)
			UiTheme.fit_name(l, line[1], 14)
		cell.set_meta("seat", seat)
		_lineup.add_child(cell)
	_relayouts = 2
	_layout.call_deferred()


func _update_ability() -> void:
	_ability.text = ability_text(MatchSetup.character)
	# The text height changes with the character: measure again, or the
	# scroll keeps its old height and clips the rows below (Phase 4 bug).
	_relayouts = 2
	_layout.call_deferred()


## Vietnamese ability summary built from the rules data (numbers never typed
## twice, so the text follows any balance change).
func ability_text(character_id: String) -> String:
	var a: Dictionary = config.character_by_id[character_id]["ability"]
	match a["ability_id"]:
		"BUILDER_DISCOUNT":
			return "Xây rẻ: mỗi lần nâng cấp giảm %d%% chi phí. Luôn có hiệu lực." % a["upgrade_discount_pct"]
		"DIVIDEND_CALL":
			var e: Dictionary = a["effects"][0]
			return "Gọi cổ tức: nhận %d RC cho mỗi ô đang sở hữu (tối đa %d RC). %d lần mỗi trận, chờ %d vòng giữa hai lần; dùng thay cho hành động chiến lược của lượt." % [
				e["amount"], e["max_total"], a["uses_per_match"], a["cooldown_rounds"]]
		"CONTRACT_CLAUSE":
			var e: Dictionary = a["effects"][0]
			return "Điều khoản hợp đồng: lần trả tiền thuê kế tiếp trong %d vòng chỉ mất %d%%. %d lần mỗi trận, chờ %d vòng; dùng thay cho hành động chiến lược." % [
				e["duration_rounds"], 100 - int(e["pct"]), a["uses_per_match"], a["cooldown_rounds"]]
	return str(config.character_by_id[character_id].get("description", ""))


## The full rules sheet (RulesGuide, generated from the rules data).
func how_to_text() -> String:
	return guide.how_to_text()


# --- settings -------------------------------------------------------------------

func _build_settings() -> void:
	var v := _page_card("settings", true)
	v.add_child(_label("CÀI ĐẶT", 40, UiTheme.GOLD, "ExtraBold"))
	settings = SettingsPanel.new()
	settings.build()
	settings.changed.connect(func(): settings_changed.emit())
	v.add_child(settings)
	for k in settings.buttons:
		buttons[k] = settings.buttons[k]
	var row := _bottom_row("settings")
	var back := _button("XONG", "check")
	back.pressed.connect(func(): show_page(_settings_back_to))
	buttons["settings_back"] = back
	row.add_child(back)


# --- how-to sheet ---------------------------------------------------------------

func _build_how_to() -> void:
	how_to = PanelContainer.new()
	how_to.add_theme_stylebox_override("panel", UiTheme.glass_panel(true))
	how_to.visible = false
	add_child(how_to)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	how_to.add_child(v)
	v.add_child(_label("Cách chơi", UiTheme.FS_TITLE, UiTheme.GOLD, "ExtraBold"))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	how_to_label = _label(how_to_text(), UiTheme.FS_BODY, UiTheme.TEXT, "Medium")
	how_to_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sc.add_child(how_to_label)
	var close := _button("ĐÃ HIỂU", "check")
	close.pressed.connect(func(): how_to.visible = false)
	buttons["how_to_close"] = close
	v.add_child(close)


# --- building blocks ------------------------------------------------------------

## A centred card page. `scroll`: the content scrolls above a pinned button row.
func _page_card(name: String, scroll := false) -> VBoxContainer:
	var p := Control.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	_pages[name] = p
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.glass_panel(true))
	p.add_child(card)
	_cards[name] = card
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	card.add_child(outer)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if scroll:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		outer.add_child(sc)
		sc.add_child(v)
		card.set_meta("scroll", sc)
		card.set_meta("content", v)
		if name == "setup":
			_scroll = sc
			_content = v
	else:
		outer.add_child(v)
	return v


func _bottom_row(name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	(_cards[name].get_child(0) as VBoxContainer).add_child(row)
	_cards[name].set_meta("bottom", row)
	return row


func _section(v: VBoxContainer, text: String) -> void:
	v.add_child(_label(text, UiTheme.FS_LABEL, UiTheme.GOLD, "Bold"))


## A row of mutually exclusive buttons; the selected one uses the primary skin.
## Options: [value, text] or [value, text, icon].
func _choice_row(v: VBoxContainer, id: String, options: Array, current: Variant, on_pick: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var group: Array[Button] = []
	for o in options:
		var b := _button(str(o[1]), o[2] if o.size() > 2 else "")
		b.set_meta("value", o[0])
		b.custom_minimum_size.x = 0
		row.add_child(b)
		group.append(b)
		buttons["%s_%s" % [id, str(o[0])]] = b
	var paint := func(sel: Variant):
		for b in group:
			if b.get_meta("value") == sel:
				for st in ["normal", "hover", "pressed"]:
					b.remove_theme_stylebox_override(st)
				for c in ["font_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
					b.remove_theme_color_override(c)
				b.set_meta("selected", true)
			else:
				UiTheme.neutral(b)
				b.set_meta("selected", false)
	for b in group:
		b.pressed.connect(func(): on_pick.call(b.get_meta("value")); paint.call(b.get_meta("value")))
	paint.call(current)


func _button(text: String, icon_name: String) -> Button:
	var b := Button.new()
	b.text = text
	if icon_name != "":
		b.icon = UiTheme.icon(icon_name)
	b.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Rows of 3 buttons on a phone: one line, the text shrinks to fit
	# (UiTheme.fit_button), it never wraps or widens the card.
	UiTheme.fit_button.call_deferred(b)
	AudioDirector.wire(b)
	return b


func _label(text: String, size: int, color: Color, weight := "Medium") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", UiTheme.font(weight))
	return l


func _icon(name: String, size: int, tint: Color) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UiTheme.icon(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.modulate = tint
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


# --- layout ---------------------------------------------------------------------

## Portrait title: the free band between the logo block and the buttons, as
## fractions of the screen height {top, bottom} for the camera framing.
func title_board_band() -> Dictionary:
	var h := get_viewport_rect().size.y
	var top := (_title_box.position.y + _title_box.get_combined_minimum_size().y * _title_box.scale.y + 20.0) / h
	var bottom := 1.0 - (_title_buttons.position.y - 20.0) / h
	return {"top": clampf(top, 0.0, 0.6), "bottom": clampf(bottom, 0.0, 0.6)}


func safe_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var safe := Rect2(Vector2.ZERO, vp)
	safe.position += simulated_insets.position
	safe.size -= simulated_insets.position + simulated_insets.size
	return safe


func _layout() -> void:
	var vp := get_viewport_rect().size
	var safe := safe_rect()
	var landscape := vp.x > vp.y
	_scrim.texture = _scrim_texture(landscape, page == "title")
	# Title: logo + buttons over the diorama. Landscape: a left column;
	# portrait: logo at the top, buttons at the bottom, the board in between.
	var col_w := minf(safe.size.x - 56.0, 620.0)
	if landscape:
		col_w = minf(safe.size.x * 0.42, 620.0)
	_title_box.custom_minimum_size.x = col_w
	_title_buttons.custom_minimum_size.x = col_w
	_title_box.reset_size()
	_title_buttons.reset_size()
	if landscape:
		var x := safe.position.x + maxf(40.0, safe.size.x * 0.06)
		var total := _title_box.get_combined_minimum_size().y + 48.0 + _title_buttons.get_combined_minimum_size().y
		# Short windows: scale the whole column down to fit (input follows).
		var k := minf(1.0, (safe.size.y - 48.0) / total)
		_title_box.scale = Vector2.ONE * k
		_title_buttons.scale = Vector2.ONE * k
		var y := safe.position.y + maxf(24.0, (safe.size.y - total * k) * 0.5)
		_title_box.position = Vector2(x, y)
		_title_buttons.position = Vector2(x, y + (_title_box.get_combined_minimum_size().y + 48.0) * k)
	else:
		var x := safe.position.x + (safe.size.x - col_w) * 0.5
		_title_box.scale = Vector2.ONE
		_title_buttons.scale = Vector2.ONE
		_title_box.position = Vector2(x, safe.position.y + 48.0)
		_title_buttons.position = Vector2(x, safe.end.y - _title_buttons.get_combined_minimum_size().y - 40.0)
	# Cards: centred in the safe area; content scrolls above a pinned row.
	# Landscape setup: two columns side by side in a wider card.
	var two_cols := landscape and safe.size.x >= 1100.0
	if _split:
		_split.vertical = not two_cols
	# Landscape: a shorter persona grid so the line-up stays on screen.
	if _persona_grid:
		_persona_grid.columns = 8 if two_cols else 4
	for b in _persona_group:
		b.custom_minimum_size.y = 118 if two_cols else 150
		b.add_theme_constant_override("icon_max_width", 66 if two_cols else 104)
		b.add_theme_font_size_override("font_size", 16 if two_cols else 19)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		var full: String = theme_data.persona(b.get_meta("value")).get("name", "")
		b.text = full.split(" ")[-1] if two_cols else full
	for name in _cards:
		var card: PanelContainer = _cards[name]
		var w := minf(safe.size.x - 28.0, 1280.0 if (two_cols and name == "setup") else CARD_WIDTH)
		var text_w := (w - 64.0 - 28.0) * 0.5 if (two_cols and name == "setup") else w - 64.0
		card.custom_minimum_size.x = w
		for l in card.find_children("*", "Label", true, false):
			if l.has_meta("fit_max"):
				continue  # name labels size themselves (UiTheme.fit_name)
			if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
				l.custom_minimum_size.x = maxf(_avail_width(l, card, text_w), 80.0)
		if card.has_meta("scroll"):
			var sc: ScrollContainer = card.get_meta("scroll")
			var content: Control = card.get_meta("content")
			var sb := card.get_theme_stylebox("panel")
			var bottom: Control = card.get_meta("bottom") if card.has_meta("bottom") else null
			var chrome := (sb.get_minimum_size().y if sb else 40.0) + 14.0 + (bottom.get_combined_minimum_size().y if bottom else 0.0) + 28.0
			sc.custom_minimum_size.y = minf(content.get_combined_minimum_size().y, safe.size.y - chrome)
		card.reset_size()
		card.position = safe.position + (safe.size - card.size) * 0.5
	# Wrapped labels report their real height only after a layout pass.
	if _relayouts > 0:
		_relayouts -= 1
		_layout.call_deferred()
	# A centred reading column: full width on phones in portrait, capped in
	# landscape so lines stay readable.
	var hw := minf(safe.size.x - 28.0, READ_WIDTH)
	how_to.size = Vector2(hw, safe.size.y - 28.0)
	how_to.position = safe.position + Vector2((safe.size.x - hw) * 0.5, 14.0)
	how_to_label.custom_minimum_size.x = hw - 60.0


## Width left for a wrapping label: the column width minus whatever sits
## beside it in any horizontal row on the way up to the card (a badge next to
## a title block, an avatar next to a name). Phase 5 bug: only the direct
## parent was checked, so the intro title grew the card past the screen.
func _avail_width(l: Control, card: Control, text_w: float) -> float:
	var avail := text_w
	var node: Node = l
	while node.get_parent() != null and node.get_parent() != card:
		var par := node.get_parent()
		if par is HBoxContainer:
			for sib in par.get_children():
				if sib != node and sib is Control and sib.visible:
					avail -= sib.get_combined_minimum_size().x + par.get_theme_constant("separation")
		node = par
	return avail


## Title: a gradient that darkens the side holding the text (the diorama
## stays visible); other pages: an even dim behind the card.
func _scrim_texture(landscape: bool, title: bool) -> GradientTexture2D:
	var g := Gradient.new()
	var tex := GradientTexture2D.new()
	if title:
		g.set_color(0, Color(0.02, 0.03, 0.06, 0.88))
		g.set_color(1, Color(0.02, 0.03, 0.06, 0.0))
		g.add_point(0.45, Color(0.02, 0.03, 0.06, 0.55))
		tex.fill_from = Vector2(0, 0) if landscape else Vector2(0, 1)
		tex.fill_to = Vector2(0.75, 0) if landscape else Vector2(0, 0.35)
	else:
		g.set_color(0, Color(0.02, 0.03, 0.06, 0.62))
		g.set_color(1, Color(0.02, 0.03, 0.06, 0.62))
	tex.gradient = g
	tex.width = 64
	tex.height = 64
	return tex
