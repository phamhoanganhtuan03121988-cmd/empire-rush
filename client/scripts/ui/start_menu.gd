## Start screen (Phase 4, playtest readiness): number of players, the
## player's character, graphics preset, reduced motion and a short how-to-play
## generated from the rules data. Before Phase 4 the game started a 4-player
## match straight away and these choices needed command-line arguments.
class_name StartMenu
extends Control

signal start_requested

const PRESET_LABELS := {"low": "Thấp", "medium": "Vừa", "high": "Cao"}

var config: GameConfig
var theme_data: ThemeData
var simulated_insets := Rect2()
var buttons := {}            # id -> Button (tests)
var how_to: PanelContainer
var how_to_label: Label
var _scroll: ScrollContainer
var _card: PanelContainer
var _center: CenterContainer
var _content: VBoxContainer
var _bottom: HBoxContainer
var _relayouts := 2
## Widest the how-to column gets (logical px): ~70 characters a line.
const READ_WIDTH := 760.0
var _ability: Label


func setup(p_config: GameConfig, p_theme: ThemeData) -> void:
	config = p_config
	theme_data = p_theme
	theme = UiTheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.1, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	# Card = scrollable choices + a pinned START row, so START is always on
	# screen (landscape phones are only ~390 pt tall).
	_center = CenterContainer.new()
	add_child(_center)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiTheme.glass_panel(true))
	_center.add_child(_card)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	_card.add_child(outer)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(v)
	_content = v
	var title := _label("EMPIRE RUSH", 44, UiTheme.GOLD, "ExtraBold")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := _label("Bản thử nội bộ · chơi với máy", UiTheme.FS_BODY, UiTheme.TEXT_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	_section(v, "Số người chơi (bạn + máy)")
	_choice_row(v, "players", [[2, "2"], [3, "3"], [4, "4"]], MatchSetup.players, func(x): MatchSetup.players = x)
	_section(v, "Nhân vật của bạn")
	var chars: Array = []
	for c in MatchSetup.CHARACTER_CYCLE:
		chars.append([c, theme_data.loc(c, "short", c)])
	_choice_row(v, "character", chars, MatchSetup.character, func(x): MatchSetup.character = x; _update_ability())
	_ability = _label("", UiTheme.FS_BODY, UiTheme.TEXT)
	_ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_ability)
	_section(v, "Đồ họa")
	var q: Array = []
	for k in QualitySettings.ORDER:
		q.append([k, PRESET_LABELS[k]])
	_choice_row(v, "quality", q, MatchSetup.quality, func(x): MatchSetup.quality = x)
	var motion := Button.new()
	motion.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
	motion.toggle_mode = true
	motion.button_pressed = MatchSetup.reduced_motion
	UiTheme.neutral(motion)
	var set_motion_text := func(on: bool): motion.text = "Giảm chuyển động: " + ("BẬT" if on else "TẮT")
	set_motion_text.call(motion.button_pressed)
	motion.toggled.connect(func(on: bool): MatchSetup.reduced_motion = on; set_motion_text.call(on))
	buttons["reduced_motion"] = motion
	v.add_child(motion)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	outer.add_child(row)
	_bottom = row
	var help := _button("CÁCH CHƠI", "info")
	UiTheme.secondary(help)
	help.pressed.connect(func(): how_to.visible = true)
	buttons["how_to"] = help
	row.add_child(help)
	var start := _button("BẮT ĐẦU", "dice")
	start.pressed.connect(func(): start_requested.emit())
	buttons["start"] = start
	row.add_child(start)
	_build_how_to()
	_update_ability()
	resized.connect(_layout)
	get_viewport().size_changed.connect(func(): _relayouts = 2; _layout())
	_layout.call_deferred()


func _layout() -> void:
	var vp := get_viewport_rect().size
	var safe := Rect2(Vector2.ZERO, vp)
	safe.position += simulated_insets.position
	safe.size -= simulated_insets.position + simulated_insets.size
	_center.position = safe.position
	_center.size = safe.size
	_card.custom_minimum_size.x = minf(safe.size.x - 28.0, 680.0)
	for l in _card.find_children("*", "Label", true, false):
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
			l.custom_minimum_size.x = _card.custom_minimum_size.x - 64.0
	# Choices scroll inside whatever height is left above the pinned row.
	var sb := _card.get_theme_stylebox("panel")
	var chrome := (sb.get_minimum_size().y if sb else 40.0) + 14.0 + _bottom.get_combined_minimum_size().y + 28.0
	_scroll.custom_minimum_size.y = minf(_content.get_combined_minimum_size().y, safe.size.y - chrome)
	# Wrapped labels report their real height only after a layout pass.
	if _relayouts > 0:
		_relayouts -= 1
		_layout.call_deferred()
	# A centred reading column: full width on phones in portrait, capped in
	# landscape so lines stay readable.
	var w := minf(safe.size.x - 28.0, READ_WIDTH)
	how_to.size = Vector2(w, safe.size.y - 28.0)
	how_to.position = safe.position + Vector2((safe.size.x - w) * 0.5, 14.0)
	how_to_label.custom_minimum_size.x = w - 60.0


func _section(v: VBoxContainer, text: String) -> void:
	v.add_child(_label(text, UiTheme.FS_LABEL, UiTheme.GOLD, "Bold"))


## A row of mutually exclusive buttons; the selected one uses the primary skin.
func _choice_row(v: VBoxContainer, id: String, options: Array, current: Variant, on_pick: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var group: Array[Button] = []
	for o in options:
		var b := _button(str(o[1]), "")
		b.set_meta("value", o[0])
		row.add_child(b)
		group.append(b)
		buttons["%s_%s" % [id, str(o[0])]] = b
	var paint := func(sel: Variant):
		for b in group:
			if b.get_meta("value") == sel:
				b.remove_theme_stylebox_override("normal")
				b.remove_theme_stylebox_override("hover")
				b.remove_theme_stylebox_override("pressed")
				b.remove_theme_color_override("font_color")
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
	return b


func _label(text: String, size: int, color: Color, weight := "Medium") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", UiTheme.font(weight))
	return l


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


## Short rules from the rules data (GDD wins if they ever disagree).
func how_to_text() -> String:
	var b: Dictionary = config.balance
	var rounds := []
	for n in [2, 3, 4]:
		rounds.append("%d người: %d vòng" % [n, config.max_rounds_for(n)])
	return "\n".join([
		"Mục tiêu: khi trận kết thúc, người có TÀI SẢN RÒNG cao nhất thắng (tiền mặt + giá trị bán lại đất và nhà).",
		"Mỗi người bắt đầu với %d RC. Qua ô Xuất phát nhận %d RC." % [b["starting_cash"], b["start_reward"]],
		"Lượt của bạn: bấm ĐỔ XÚC XẮC. Dừng ở đất chưa có chủ: MUA, hoặc BỎ QUA để cả bàn đấu giá.",
		"Dừng ở đất của người khác: trả tiền thuê tự động. Sở hữu đủ cả quận thì tiền thuê tăng và được nâng cấp nhà (tối đa cấp %d)." % b["max_level"],
		"Sau khi di chuyển, bạn có MỘT hành động chiến lược: nâng cấp, đề nghị giao dịch hoặc dùng kỹ năng nhân vật, rồi KẾT THÚC LƯỢT.",
		"Ô ! (Sự kiện thành phố): có sự kiện xảy ra ngay, có sự kiện cho bạn chọn. Ô ? (Cơ hội): chọn một trong các phương án. Ô %% là thuế tài sản (tối đa %d RC). Ô có tách cà phê là ô nghỉ." % b["wealth_tax"]["cap"],
		"Thiếu tiền: bán đất cho ngân hàng để trả nợ. Nếu vẫn không đủ thì PHÁ SẢN và rời trận.",
		"Mỗi lượt có %d giây; hết giờ trò chơi tự chọn phương án an toàn." % [int(b["turn_timer_ms"] / 1000)],
		"Trận kết thúc khi hết số vòng (%s), hết %d phút, hoặc chỉ còn một người chưa phá sản." % [", ".join(rounds), int(b["time_cap_ms"] / 60000)],
		"Mẹo: chạm vào một ô trên bàn cờ để xem giá, tiền thuê và chủ sở hữu.",
	])


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
	how_to_label = _label(how_to_text(), UiTheme.FS_BODY, UiTheme.TEXT)
	how_to_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sc.add_child(how_to_label)
	var close := _button("ĐÃ HIỂU", "check")
	close.pressed.connect(func(): how_to.visible = false)
	buttons["how_to_close"] = close
	v.add_child(close)
