## Touch HUD for the vertical slice. Reads engine state/queries for display and
## sends intent through LocalMatch.submit() only; it never changes rules state
## or computes money itself. Portrait-first; switches to a side layout in
## landscape. All interactive controls are >= UiTheme.MIN_TOUCH px tall.
class_name GameHud
extends Control

signal restart_requested
signal menu_requested
signal quality_cycle_requested
## Holding the quality button opens the device-validation panel (DevPanel).
signal dev_menu_requested
signal action_buttons_changed
## Phase 5: the menu button (pause menu: resume, guide, settings, main menu).
signal pause_requested

var match_ref: LocalMatch
var presenter: EventPresenter
var theme_data: ThemeData
var config: GameConfig
## Extra safe-area insets in design pixels (used to emulate the iPhone notch
## on desktop / in screenshots). Added to the OS-reported safe area.
var simulated_insets := Rect2(0, 0, 0, 0)

## Current action buttons: [{button, type, payload}] (used by autopilot/tests).
var actions: Array = []

var _top: PanelContainer
var _cards_box: GridContainer
var _cards: Array = []
var _round_label: Label
var _turn_label: Label
var _timer_bar: ProgressBar
var _timer_fill: StyleBoxFlat
var _quality_btn: Button
var pause_button: Button
## Set by main only when the device tools exist (BuildFlavor). Otherwise a
## long press is just a press and cycles the preset.
var dev_menu_enabled := false
var _quality_down_ms := 0
var _quality_down := false
var _action_panel: PanelContainer
var _action_title: Label
var _action_icon: TextureRect
var _action_body: Label
var _buttons: GridContainer
var _buttons_scroll: ScrollContainer
var _toasts: VBoxContainer
var _info: PanelContainer
var _info_label: Label
var _results: PanelContainer
var _results_label: Label
var _results_rows: GridContainer
var _placeholder_tag: Label

const TOAST_MAX := 2
const TOAST_BAND := 104.0   # px reserved under the top panel for toasts (portrait)
const ACTION_BAND := 0.235  # fraction of height reserved for the action panel (portrait)
## Landscape: the board gets the full height on the left; player bar, toasts
## and the action panel share the right column (Phase 2, A4).
const LANDSCAPE_SPLIT := 0.62
## Phase 5 hero roll button: the main action of every turn.
const HERO_HEIGHT := 132
const HERO_FONT := 38
const LONG_PRESS_MS := 900

var _presented_turn := 0
var _presented_round := 1
var _sub_view := ""
var _last_key := ""
var _timer_total := 45.0
var _landscape := false
var _refits_left := 0
var results_menu_button: Button
## Set when the human sends RollDice; shows the rolling state until the dice
## have landed and the move is presented.
var _rolling := false
var _hero_tween: Tween
## Phase 5: last dice shown (d1, d2), for the rolling hero button.
var _last_dice := []


func setup(p_match: LocalMatch, p_presenter: EventPresenter, p_theme: ThemeData, p_config: GameConfig) -> void:
	match_ref = p_match
	presenter = p_presenter
	theme_data = p_theme
	config = p_config
	theme = UiTheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_action_panel()
	_build_toasts()
	_build_info()
	_build_results()
	presenter.cash_presented.connect(_on_cash)
	presenter.turn_presented.connect(_on_turn)
	presenter.toast.connect(show_toast)
	presenter.match_ended_presented.connect(_on_match_ended)
	presenter.busy_changed.connect(func(_b): _last_key = "")
	presenter.cue.connect(_on_cue)
	get_viewport().size_changed.connect(_layout)
	_layout()


# --- construction -------------------------------------------------------------

func _label(size: int, color := UiTheme.TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _build_top() -> void:
	_top = PanelContainer.new()
	_top.add_theme_stylebox_override("panel", UiTheme.glass_panel())
	add_child(_top)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_top.add_child(v)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	row.add_child(_icon_rect("clock", 30, UiTheme.GOLD))
	_round_label = _label(UiTheme.FS_LABEL, UiTheme.GOLD)
	_round_label.add_theme_font_override("font", UiTheme.font("ExtraBold"))
	_round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_round_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_round_label)
	_placeholder_tag = _label(18, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_RIGHT)
	_placeholder_tag.set_meta("decorative", true)
	_placeholder_tag.text = UiText.t("placeholder")
	_placeholder_tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Phase 5: the build tag moved to the title screen (it crowded this row).
	_placeholder_tag.visible = false
	row.add_child(_placeholder_tag)
	_quality_btn = Button.new()
	# 82 px ≈ 44 pt (Apple's minimum) for this secondary control.
	_quality_btn.custom_minimum_size = Vector2(UiTheme.MIN_TOUCH * 1.4, 82)
	_quality_btn.add_theme_font_size_override("font_size", 20)
	_quality_btn.icon = UiTheme.icon("gear")
	_quality_btn.add_theme_constant_override("icon_max_width", 26)
	UiTheme.neutral(_quality_btn)
	_quality_btn.button_down.connect(func():
		_quality_down = true
		_quality_down_ms = Time.get_ticks_msec())
	_quality_btn.pressed.connect(_on_quality_pressed)
	AudioDirector.wire(_quality_btn)
	row.add_child(_quality_btn)
	pause_button = Button.new()
	pause_button.custom_minimum_size = Vector2(82, 82)
	pause_button.icon = UiTheme.icon("menu")
	pause_button.add_theme_constant_override("icon_max_width", 34)
	pause_button.tooltip_text = "Menu (Esc)"
	UiTheme.neutral(pause_button)
	pause_button.pressed.connect(func(): pause_requested.emit())
	AudioDirector.wire(pause_button)
	row.add_child(pause_button)
	# Phase 5: a grid, so landscape shows the players 2 x 2 in a narrower column.
	_cards_box = GridContainer.new()
	_cards_box.columns = match_ref.engine.state.players.size()
	_cards_box.add_theme_constant_override("h_separation", 6)
	_cards_box.add_theme_constant_override("v_separation", 6)
	v.add_child(_cards_box)
	for seat in match_ref.engine.state.players.size():
		_cards.append(_build_card(seat))
	# The active player is shown by the highlighted card; the action panel
	# title says whose turn it is, so no separate turn line (saves height).
	_turn_label = _label(20)
	_turn_label.visible = false
	v.add_child(_turn_label)
	_timer_bar = ProgressBar.new()
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 8)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(5)
	var fg := StyleBoxFlat.new()
	fg.bg_color = UiTheme.GOLD
	fg.set_corner_radius_all(5)
	_timer_fill = fg
	_timer_bar.add_theme_stylebox_override("background", bg)
	_timer_bar.add_theme_stylebox_override("fill", fg)
	v.add_child(_timer_bar)


func _build_card(seat: int) -> Dictionary:
	var p := match_ref.engine.state.player(seat)
	var pc := theme_data.player_color(seat)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
	_cards_box.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	panel.add_child(v)
	# Avatar badge (character emblem on the seat colour) + name.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	# Phase 5.1: the persona portrait (cosmetic); the role stays on the line below.
	var avatar: PanelContainer
	var face := theme_data.player_portrait(seat)
	if face:
		avatar = PortraitBadge.make(face, pc, 46)
	else:
		avatar = PanelContainer.new()
		avatar.add_theme_stylebox_override("panel", UiTheme.badge(pc.darkened(0.15), pc.lightened(0.45)))
		avatar.custom_minimum_size = Vector2(34, 34)
		avatar.add_child(_icon_rect(theme_data.character_icon(p["character_id"]), 24, Color.WHITE))
	head.add_child(avatar)
	var name := _label(22, pc.lightened(0.35))
	name.add_theme_font_override("font", UiTheme.font("Bold"))
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.text = theme_data.player_name(seat)
	head.add_child(name)
	var ch := _label(20, UiTheme.TEXT_MUTED)
	ch.autowrap_mode = TextServer.AUTOWRAP_OFF
	ch.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ch.text = theme_data.loc(p["character_id"], "short", theme_data.character_name(p["character_id"], config))
	ch.tooltip_text = UiText.t("worth_tip")
	ch.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(ch)
	var money := HBoxContainer.new()
	money.add_theme_constant_override("separation", 4)
	v.add_child(money)
	money.add_child(_icon_rect("coin", 22, UiTheme.GOLD))
	var cash := _label(26, UiTheme.TEXT)
	cash.add_theme_font_override("font", UiTheme.font("ExtraBold"))
	cash.autowrap_mode = TextServer.AUTOWRAP_OFF
	cash.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cash.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money.add_child(cash)
	return {"panel": panel, "name": name, "cash": cash, "seat": seat, "avatar": avatar, "role": ch, "role_text": ch.text}


func _icon_rect(name: String, size: int, tint: Color) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UiTheme.icon(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.modulate = tint
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _build_action_panel() -> void:
	_action_panel = PanelContainer.new()
	add_child(_action_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_action_panel.add_child(v)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	v.add_child(title_row)
	_action_icon = _icon_rect("user", 34, UiTheme.GOLD)
	title_row.add_child(_action_icon)
	_action_title = _label(UiTheme.FS_TITLE, UiTheme.GOLD)
	_action_title.add_theme_font_override("font", UiTheme.font("ExtraBold"))
	_action_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_action_title)
	_action_body = _label(UiTheme.FS_BODY, UiTheme.TEXT_MUTED.lightened(0.2))
	v.add_child(_action_body)
	# Grid: binary choices and long lists use two columns so the panel stays
	# within the band the camera reserves for it.
	_buttons = GridContainer.new()
	_buttons.columns = 1
	_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons.add_theme_constant_override("h_separation", 10)
	_buttons.add_theme_constant_override("v_separation", 10)
	# Long lists (upgrades, liquidation) scroll by touch instead of growing
	# the panel over the board.
	_buttons_scroll = ScrollContainer.new()
	_buttons_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_buttons_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons_scroll.add_child(_buttons)
	v.add_child(_buttons_scroll)


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 6)
	add_child(_toasts)


func _build_info() -> void:
	_info = PanelContainer.new()
	_info.visible = false
	_info.add_theme_stylebox_override("panel", UiTheme.glass_panel(true))
	add_child(_info)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_info.add_child(v)
	_info_label = _label(24)
	v.add_child(_info_label)
	var close := Button.new()
	close.text = UiText.t("back")
	close.icon = UiTheme.icon("close")
	close.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
	UiTheme.neutral(close)
	close.pressed.connect(func(): _info.visible = false)
	v.add_child(close)


func _build_results() -> void:
	_results = PanelContainer.new()
	_results.visible = false
	_results.add_theme_stylebox_override("panel", UiTheme.glass_panel(true))
	add_child(_results)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_results.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(_icon_rect("trophy", 36, UiTheme.GOLD))
	_results_label = _label(UiTheme.FS_LABEL, UiTheme.GOLD)
	_results_label.add_theme_font_override("font", UiTheme.font("ExtraBold"))
	_results_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_results_label)
	# Ranking in a 2-column grid in portrait so the sheet stays inside the
	# band reserved under the board.
	_results_rows = GridContainer.new()
	_results_rows.columns = 2
	_results_rows.add_theme_constant_override("h_separation", 14)
	_results_rows.add_theme_constant_override("v_separation", 6)
	v.add_child(_results_rows)
	var again := Button.new()
	again.text = UiText.t("play_again")
	again.icon = UiTheme.icon("dice")
	again.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
	again.pressed.connect(func(): restart_requested.emit())
	# Phase 4: back to the start menu (players, character, preset).
	var to_menu := Button.new()
	to_menu.text = "MENU"
	to_menu.icon = UiTheme.icon("gear")
	to_menu.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
	UiTheme.secondary(to_menu)
	to_menu.pressed.connect(func(): menu_requested.emit())
	results_menu_button = to_menu
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	to_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(again)
	row.add_child(to_menu)
	v.add_child(row)


# --- layout ---------------------------------------------------------------------

func safe_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var r := Rect2(Vector2.ZERO, vp)
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x > 0 and win.y > 0 and safe.size.x > 0 and DisplayServer.get_name() != "headless":
		var k := vp / Vector2(win)
		var win_pos := DisplayServer.window_get_position()
		var local := Rect2(Vector2(safe.position - win_pos) * k, Vector2(safe.size) * k)
		r = r.intersection(local) if r.intersects(local) else r
	r.position += simulated_insets.position
	r.size -= simulated_insets.position + simulated_insets.size
	return r


func _layout() -> void:
	var vp := get_viewport_rect().size
	_landscape = vp.x > vp.y
	var s := safe_rect()
	var m := 14.0
	var n_cards := _cards.size()
	_cards_box.columns = 2 if _landscape and n_cards > 2 else maxi(n_cards, 1)
	# Wrapped text re-measures at the new width over the next frames; place
	# the panels again then (Phase 5: the action panel ended 33 px off screen
	# after a portrait -> landscape switch).
	_refits_left = 2
	# Widths go through custom_minimum_size: containers with autowrapping
	# labels otherwise collapse to their narrowest width.
	if _landscape:
		# Right column: its share of the width, but never narrower than the
		# HUD content needs (560 px) nor wider than half the screen.
		var cw := column_width()
		var cx := s.end.x - cw - m
		_top.position = Vector2(cx, s.position.y + m)
		_width(_top, cw)
		_action_panel.position = Vector2(cx, s.position.y + m)
		_width(_action_panel, cw)
		_toasts.position = Vector2(cx, s.position.y + m)
		_width(_toasts, cw)
	else:
		_top.position = s.position + Vector2(m, m)
		_width(_top, s.size.x - m * 2)
		_width(_action_panel, s.size.x - m * 2)
		_width(_toasts, s.size.x - m * 2)
	_width(_info, minf(s.size.x - m * 4, 620))
	if _landscape:
		_width(_results, column_width())
	else:
		_width(_results, s.size.x - m * 2)
	_place_bottom.call_deferred()


## Landscape HUD column width (px, design canvas).
func column_width() -> float:
	var s := safe_rect()
	return clampf(s.size.x * (1.0 - LANDSCAPE_SPLIT) - 14.0, minf(560.0, s.size.x * 0.5), s.size.x * 0.5)


func _width(c: Control, w: float) -> void:
	c.custom_minimum_size.x = w
	c.size = Vector2(w, 0)
	# Autowrapping labels compute their minimum height from their current
	# width; give them the final width up front or panels grow to full height.
	var pad := 44.0  # panel content margins (20 + 20) + slack
	for l in c.find_children("*", "Label", true, false):
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
			var avail := w - pad
			# Labels sharing a row with icons/badges get what the row leaves.
			var row := l.get_parent() as HBoxContainer
			if row:
				var others := 0.0
				var n := 0
				for sib in row.get_children():
					if sib != l and sib is Control and sib.visible:
						others += sib.get_combined_minimum_size().x
						n += 1
				avail -= others + n * row.get_theme_constant("separation")
			l.custom_minimum_size.x = maxf(avail, 40.0)
	c.reset_size()


func _place_bottom() -> void:
	var s := safe_rect()
	var m := 14.0
	_fit_button_scroll(s)
	if not _landscape:
		_top.reset_size()
		_toasts.position = Vector2(s.position.x + m, _top.position.y + _top.size.y + 8)
		_action_panel.size.y = 0
		_action_panel.reset_size()
		_action_panel.position = Vector2(s.position.x + m, s.end.y - _action_panel.size.y - m)
		# Results replace the action panel as a bottom sheet so the final
		# board stays visible.
		_results.reset_size()
		_results.position = Vector2(s.position.x + m, s.end.y - _results.size.y - m)
	else:
		# Right column: player bar on top, toasts under it, action panel and
		# results anchored to the bottom.
		_top.reset_size()
		_toasts.position = Vector2(_top.position.x, _top.position.y + _top.size.y + 8)
		_action_panel.size.y = 0
		_action_panel.reset_size()
		_action_panel.position = Vector2(_top.position.x, s.end.y - _action_panel.size.y - m)
		_results.reset_size()
		_results.position = Vector2(_top.position.x, s.end.y - _results.size.y - m)
	_info.reset_size()
	_info.position = s.get_center() - _info.size * 0.5


## Fraction of the viewport height covered by HUD at top/bottom (portrait),
## or width fraction on the right (landscape). Used by the camera rig.
func board_insets() -> Dictionary:
	var vp := get_viewport_rect().size
	if _landscape:
		var s0 := safe_rect()
		return {"top": s0.position.y / vp.y, "bottom": (vp.y - s0.end.y) / vp.y, "right": 1.0 - (_top.position.x / vp.x) + 0.01, "left": s0.position.x / vp.x}
	# Reserve a fixed band for the action panel so the board does not jump
	# every time the panel height changes.
	var s := safe_rect()
	return {"top": (_top.position.y + _top.size.y + TOAST_BAND) / vp.y, "bottom": (vp.y - s.end.y) / vp.y + ACTION_BAND, "left": 0.0, "right": 0.0}


# --- live updates ---------------------------------------------------------------

func _on_cash(seat: int, cash: int) -> void:
	if seat < _cards.size():
		_cards[seat]["cash"].text = "%d RC" % cash
	_refresh_worth()


## Phase 5.1: the winner is decided on NET WORTH (cash + resale value of
## land and houses), so every card shows it next to the role. Presented cash
## + the engine's resale values (read-only).
func _refresh_worth() -> void:
	if presenter == null or match_ref == null:
		return
	var e := match_ref.engine
	for c in _cards:
		var seat: int = c["seat"]
		var worth := 0
		if not e.state.player(seat)["bankrupt"]:
			worth = int(presenter.presented_cash.get(seat, e.state.player(seat)["cash"]))
			for pid in e.state.properties_of(seat):
				worth += e.liquidation_value(pid)
		c["role"].text = UiText.t("role_worth") % [worth, c["role_text"]]


func _on_turn(seat: int, round: int) -> void:
	_presented_turn = seat
	_presented_round = round
	_refresh_cards()


func _refresh_cards() -> void:
	var s := match_ref.engine.state
	for c in _cards:
		var seat: int = c["seat"]
		var active: bool = seat == _presented_turn
		var bankrupt: bool = s.player(seat)["bankrupt"]
		var pc: Color = theme_data.player_color(seat)
		var style := UiTheme.panel(UiTheme.NAVY_SOFT if active else Color("#0f1626"), pc if active else Color(1, 1, 1, 0.08), 16, 0.95)
		style.content_margin_left = 10
		style.content_margin_right = 8
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		if active:
			# Active player: coloured border plus a soft glow in their colour.
			style.set_border_width_all(3)
			style.shadow_color = Color(pc, 0.45)
			style.shadow_size = 10
		c["panel"].add_theme_stylebox_override("panel", style)
		c["panel"].modulate = Color(1, 1, 1, 0.45) if bankrupt else Color.WHITE
	var cap := config.max_rounds_for(s.players.size())
	_round_label.text = UiText.t("round") % [_presented_round, cap]
	var who := theme_data.player_name(_presented_turn)
	_turn_label.text = UiText.t("your_turn") if match_ref.is_human(_presented_turn) else UiText.t("turn_of") % who


func show_toast(text: String, color := Color.WHITE, icon := "info") -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := UiTheme.panel(Color("#0c1220"), Color(1, 1, 1, 0.08), 14, 0.86)
	st.border_width_left = 6
	st.border_color = color
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	st.content_margin_left = 14
	p.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	row.add_child(_icon_rect(icon if icon != "" else "info", 26, color.lightened(0.25)))
	var l := _label(22, Color(1, 1, 1, 0.95))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.text = text
	row.add_child(l)
	_toasts.add_child(p)
	while _toasts.get_child_count() > TOAST_MAX:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	# Slide in from the left, hold, fade.
	p.modulate.a = 0.0
	var t := p.create_tween()
	t.tween_property(p, "modulate:a", 1.0, 0.15)
	t.tween_interval(3.0)
	t.tween_property(p, "modulate:a", 0.0, 0.5)
	t.tween_callback(p.queue_free)


func _process(_delta: float) -> void:
	if match_ref == null or match_ref.engine == null:
		return
	var left := match_ref.seconds_left()
	_timer_bar.value = 100.0 * left / maxf(_timer_total, 0.001)
	_timer_fill.bg_color = UiTheme.RED if left < 10.0 and match_ref.human_actor() >= 0 else UiTheme.GOLD
	var s := match_ref.engine.state
	var key := "%d|%s|%s|%s" % [s.state_version, presenter.is_idle(), _sub_view, s.phase]
	if key != _last_key:
		_last_key = key
		_timer_total = maxf(left, 1.0)
		_rebuild_actions()


func open_tile_info(index: int) -> void:
	var sp: Dictionary = config.spaces[index]
	var lines: Array[String] = []
	if sp["space_type"] == "PROPERTY":
		var pid: String = sp["property_id"]
		var t := config.tier_of(pid)
		var o: int = match_ref.engine.state.owner[pid]
		var lad := match_ref.engine.rent_ladder(pid)
		lines.append("%s — %s" % [_prop_name(pid), theme_data.districts[sp["district_id"]]["label"]])
		lines.append(UiText.t("price_rent") % [t["price"], lad[0]])
		lines.append(UiText.t("rent_table") % lad)
		lines.append("Chủ: %s · Cấp %d" % [UiText.t("bank") if o < 0 else theme_data.player_name(o), match_ref.engine.state.level[pid]])
	else:
		lines.append(theme_data.special[sp["space_type"]]["label"].replace("\n", " "))
	_info_label.text = "\n".join(lines)
	_info.visible = true
	_place_bottom.call_deferred()


func _on_match_ended(d: Dictionary) -> void:
	var human_won := false
	for r in d["results"]:
		if r["rank"] == 1 and match_ref.is_human(r["seat"]):
			human_won = true
	_results_label.text = (UiText.t("you_won") if human_won else UiText.t("you_lost")) + " · " + UiText.t("end_reason_" + d["reason"])
	_results_rows.columns = 1 if _landscape or d["results"].size() <= 2 else 2
	for c in _results_rows.get_children():
		c.queue_free()
	var medals := [Color("#f5c542"), Color("#c9d2dc"), Color("#d08a4e"), Color("#5c6680")]
	for r in d["results"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var badge := PanelContainer.new()
		var rank: int = r["rank"]
		badge.add_theme_stylebox_override("panel", UiTheme.badge(medals[clampi(rank - 1, 0, 3)], Color(1, 1, 1, 0.6)))
		badge.custom_minimum_size = Vector2(36, 36)
		var num := _label(22, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
		num.add_theme_font_override("font", UiTheme.font("ExtraBold"))
		num.autowrap_mode = TextServer.AUTOWRAP_OFF
		num.text = str(rank)
		badge.add_child(num)
		row.add_child(badge)
		var name := _label(22, theme_data.player_color(r["seat"]).lightened(0.35))
		name.add_theme_font_override("font", UiTheme.font("Bold"))
		name.autowrap_mode = TextServer.AUTOWRAP_OFF
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.custom_minimum_size.x = 60
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.text = theme_data.player_name(r["seat"]) + (UiText.t("bankrupt_tag") if r["bankrupt"] else "")
		row.add_child(name)
		row.add_child(_icon_rect("coin", 22, UiTheme.GOLD))
		var nw := _label(22, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		nw.add_theme_font_override("font", UiTheme.font("ExtraBold"))
		nw.autowrap_mode = TextServer.AUTOWRAP_OFF
		nw.text = "%d RC" % r["net_worth"]
		row.add_child(nw)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_results_rows.add_child(row)
	_results.visible = true
	_action_panel.visible = false
	_place_bottom.call_deferred()


func _on_quality_pressed() -> void:
	var held := Time.get_ticks_msec() - _quality_down_ms if _quality_down else 0
	_quality_down = false
	if dev_menu_enabled and held >= LONG_PRESS_MS:
		dev_menu_requested.emit()
	else:
		quality_cycle_requested.emit()


func set_quality_label(name: String) -> void:
	_quality_btn.text = UiText.t("quality") % UiText.t("quality_" + name)


# --- action panel ---------------------------------------------------------------

func _clear_buttons() -> void:
	for c in _buttons.get_children():
		_buttons.remove_child(c)
		c.queue_free()
	actions = []


## Default icon per command type (art direction: every action has an icon).
const ACTION_ICONS := {
	"RollDice": "dice", "BuyProperty": "coin", "PassProperty": "gavel", "PlaceBid": "gavel",
	"ChooseOption": "star", "Upgrade": "build", "UseAbility": "bolt", "EndTurn": "flag",
	"Liquidate": "coin", "DeclareBankruptcy": "bankrupt",
}


func _add_button(text: String, type: String, payload := {}, style := "", enabled := true, local_action := Callable(), icon := "") -> Button:
	var b := Button.new()
	b.text = text
	var icon_name: String = icon if icon != "" else ACTION_ICONS.get(type, "")
	if type == ErCommand.RESPOND_TRADE:
		icon_name = "check" if payload.get("accept", false) else "close"
	if icon_name != "":
		b.icon = UiTheme.icon(icon_name)
	b.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.disabled = not enabled
	match style:
		"secondary": UiTheme.secondary(b)
		"danger": UiTheme.danger(b)
	AudioDirector.wire(b, "ui_click")
	if local_action.is_valid():
		b.pressed.connect(local_action)
	else:
		b.pressed.connect(func(): _send(type, payload))
	_buttons.add_child(b)
	actions.append({"button": b, "type": type, "payload": payload})
	return b


## Caps the button area so the action panel never exceeds its reserved band
## (portrait: ACTION_BAND of the height; landscape: the right column).
func _fit_button_scroll(s: Rect2) -> void:
	var vp := get_viewport_rect().size
	var max_panel := (vp.y * ACTION_BAND - 14.0) if not _landscape else (s.end.y - (_top.position.y + _top.size.y) - TOAST_BAND - 28.0)
	_action_body.visible = _action_body.text != ""
	# Everything in the panel except the scroll area, measured, not guessed.
	# Measured from the parts, not from container minimum sizes: those are
	# only refreshed on the next layout pass and were stale here (Phase 3).
	var n := _buttons.get_child_count()
	var tops := row_tops()
	var want: float = tops.back() if not tops.is_empty() else 0.0
	var hint := UiText.t("more_below") % n
	# Start from the body without the hint: an earlier pass (before layout)
	# may have added it although the list fits now.
	if _action_body.text.ends_with(hint):
		_action_body.text = _action_body.text.trim_suffix(hint).trim_suffix("\n")
		_action_body.visible = _action_body.text != ""
	var cap := maxf(UiTheme.MIN_TOUCH, max_panel - _panel_fixed_height())
	if want > cap:
		# Overflow: say so (a cut-off row alone did not read as scrollable;
		# Phase 3 UI review), then measure again with the hint line.
		_action_body.text = (_action_body.text + "\n" if _action_body.text != "" else "") + hint
		_action_body.visible = true
		cap = maxf(UiTheme.MIN_TOUCH, max_panel - _panel_fixed_height())
	if want > cap and n > 0:
		# Show whole rows only, so no label is cut in half.
		var best: float = tops[0]  # never less than one whole row
		for top in tops:
			if top > cap:
				break
			best = top
		cap = best
	_buttons_scroll.custom_minimum_size.y = clampf(want, 0.0, cap)
	_buttons_scroll.scroll_vertical = 0
	# Wrapping buttons only know their height once they have a width (after
	# the next layout pass): measure again then, a bounded number of times.
	if _refits_left > 0 and not get_tree().process_frame.is_connected(_place_bottom):
		_refits_left -= 1
		get_tree().process_frame.connect(_place_bottom, CONNECT_ONE_SHOT)


## Height of the action panel without its button list: margins, title,
## body and the separations between them.
func _panel_fixed_height() -> float:
	var v := _buttons_scroll.get_parent() as VBoxContainer
	var sb := _action_panel.get_theme_stylebox("panel")
	var h := sb.get_margin(SIDE_TOP) + sb.get_margin(SIDE_BOTTOM) if sb else 0.0
	var shown := 0
	for c in v.get_children():
		if c is Control and c.visible:
			shown += 1
			if c != _buttons_scroll:
				h += c.get_combined_minimum_size().y
	return h + maxi(0, shown - 1) * v.get_theme_constant("separation") + 4.0


## Bottom edge of each button row (a grid row is as tall as its tallest
## button), so a scroll area can end exactly after a row.
func row_tops() -> Array:
	var cols := maxi(1, _buttons.columns)
	var sep := float(_buttons.get_theme_constant("v_separation"))
	var out: Array = []
	var y := 0.0
	var kids := _buttons.get_children()
	for r in ceili(float(kids.size()) / cols):
		var h := 0.0
		for c in cols:
			var i := r * cols + c
			if i < kids.size():
				h = maxf(h, kids[i].get_combined_minimum_size().y)
		y += h
		out.append(y)
		y += sep
	return out


## 2 buttons side by side, 3 in a row, longer lists in two columns.
func _apply_columns() -> void:
	_refits_left = 2
	var n := _buttons.get_child_count()
	_buttons.columns = 1 if n <= 1 else (n if n <= 3 else 2)
	var fs := 30 if _buttons.columns == 1 else (26 if _buttons.columns == 2 else 22)
	for b in _buttons.get_children():
		b.add_theme_font_size_override("font_size", fs)


func _send(type: String, payload: Dictionary) -> void:
	var seat := match_ref.human_actor()
	if seat < 0:
		return
	_sub_view = ""
	if type == ErCommand.ROLL_DICE:
		_rolling = true
		_last_dice = []
	# Phase 4: one tap = one command. Disable the whole button set at once so
	# a double tap (or a second button hit while the panel is rebuilt) cannot
	# send another command; the engine would reject it, but silently.
	for b in _buttons.get_children():
		if b is Button:
			b.disabled = true
	match_ref.submit(seat, type, payload)


func _set_title(text: String, icon: String, tint := UiTheme.GOLD) -> void:
	_action_title.text = text
	_action_icon.texture = UiTheme.icon(icon)
	_action_icon.modulate = tint


## Board state markers: the property under auction, and (on the human's
## strategy step) every property they can upgrade. Read-only engine queries.
func _sync_board_markers(seat: int) -> void:
	var board: BoardView = presenter.board if presenter else null
	if board == null:
		return
	var e := match_ref.engine
	var s := e.state
	board.clear_tile_markers("auction")
	board.clear_tile_markers("upgrade")
	if e.is_ended():
		return
	if s.phase == GameState.AUCTION:
		board.set_tile_marker(config.property_index[s.auction["property_id"]], "auction", true)
	elif s.phase == GameState.STRATEGY and seat >= 0 and presenter.is_idle():
		for pid in s.properties_of(seat):
			if e.can_upgrade(seat, pid) == "":
				board.set_tile_marker(config.property_index[pid], "upgrade", true)


func _rebuild_actions() -> void:
	_clear_buttons()
	var e := match_ref.engine
	var s := e.state
	_sync_board_markers(match_ref.human_actor())
	if e.is_ended():
		_action_panel.visible = false
		action_buttons_changed.emit()
		return
	_action_panel.visible = true
	var seat := match_ref.human_actor()
	_action_body.text = ""
	if _rolling and match_ref.is_human(s.current_seat) and not presenter.is_idle():
		# Rolling: keep the hero button in place, disabled, with live feedback
		# (no layout jump and no second roll while the dice are in the air).
		_set_title(UiText.t("your_turn"), "dice")
		var label := UiText.t("rolling") if _last_dice.is_empty() else UiText.t("rolled_hero") % [_last_dice[0], _last_dice[1], _last_dice[0] + _last_dice[1]]
		_hero(_add_button(label, ErCommand.ROLL_DICE, {}, "", false))
		_apply_columns()
		_hero(_buttons.get_child(0))
		_place_bottom.call_deferred()
		action_buttons_changed.emit()
		return
	if presenter.is_idle():
		_rolling = false
	if seat < 0 or not presenter.is_idle():
		var actor := s.current_seat
		_set_title(UiText.t("turn_of") % theme_data.player_name(actor) if not match_ref.is_human(actor) else UiText.t("your_turn"),
			"user", theme_data.player_color(actor).lightened(0.3))
		if seat < 0 and presenter.is_idle():
			_action_body.text = UiText.t("waiting") % theme_data.player_name(actor)
		_place_bottom.call_deferred()
		action_buttons_changed.emit()
		return
	var cash: int = s.player(seat)["cash"]
	match s.phase:
		GameState.AWAIT_ROLL:
			_set_title(UiText.t("your_turn"), "dice")
			_action_body.text = UiText.t("roll_hint")
			_hero(_add_button(UiText.t("roll"), ErCommand.ROLL_DICE))
		GameState.AWAIT_BUY:
			var pid := e.property_at(s.player(seat)["position"])
			var price: int = config.tier_of(pid)["price"]
			var sp: Dictionary = config.spaces[s.player(seat)["position"]]
			var lad := e.rent_ladder(pid)
			_set_title("%s · %s" % [_prop_name(pid), theme_data.districts[sp["district_id"]]["label"]], "tag", theme_data.district_color(sp["district_id"]).lightened(0.35))
			_action_body.text = (UiText.t("price_rent") % [price, lad[0]]) + "\n" + (UiText.t("rent_table") % lad)
			if price > cash:
				_action_body.text += "\n" + UiText.t("cant_afford") % price
			_add_button(UiText.t("buy") % price, ErCommand.BUY_PROPERTY, {"property_id": pid}, "", price <= cash)
			_add_button(UiText.t("pass"), ErCommand.PASS_PROPERTY, {"property_id": pid}, "secondary")
		GameState.AUCTION:
			var a := s.auction
			var need := e.min_next_bid()
			_set_title(UiText.t("auction_title") % _prop_name(a["property_id"]), "gavel", UiTheme.AMBER)
			if a["high_seat"] < 0:
				_action_body.text = UiText.t("auction_no_bid") % need
			else:
				_action_body.text = UiText.t("auction_state") % [a["high_bid"], theme_data.player_name(a["high_seat"]), need]
			if a["high_seat"] == seat:
				_action_body.text += "\n" + UiText.t("you_lead")
			else:
				_add_button(UiText.t("bid_btn") % need, ErCommand.PLACE_BID, {"auction_id": a["auction_id"], "amount": need}, "", need <= cash)
				var big := need + 40
				if big <= cash:
					_add_button(UiText.t("bid_btn") % big, ErCommand.PLACE_BID, {"auction_id": a["auction_id"], "amount": big}, "secondary")
		GameState.AWAIT_CHOICE:
			var c := s.choice
			var def: Dictionary = config.cards[c["ref_id"]] if c["source"] == "event" else _opp(c["ref_id"])
			_set_title(theme_data.loc(c["ref_id"], "title", def["title"]), "event" if c["source"] == "event" else "opportunity")
			_action_body.text = theme_data.loc(c["ref_id"], "text", def.get("text", ""))
			for o in c["options"]:
				var olabel: String = theme_data.loc(c["ref_id"] + "." + o["option_id"], "label", o["label"])
				var label: String = olabel if o["cost"] == 0 else UiText.t("choice_cost") % [olabel, o["cost"]]
				_add_button(label, ErCommand.CHOOSE_OPTION, {"choice_id": c["choice_id"], "option_id": o["option_id"]}, "", o["cost"] <= cash)
		GameState.STRATEGY:
			_build_strategy(seat)
		GameState.TRADE_PENDING:
			var t := s.trade
			_set_title(UiText.t("trade_title") % theme_data.player_name(t["from"]), "handshake")
			_action_body.text = UiText.t("trade_terms") % [_side_text(t["give"]), _side_text(t["take"])]
			_add_button(UiText.t("accept"), ErCommand.RESPOND_TRADE, {"trade_id": t["trade_id"], "accept": true})
			_add_button(UiText.t("reject"), ErCommand.RESPOND_TRADE, {"trade_id": t["trade_id"], "accept": false}, "danger")
		GameState.RESCUE:
			var r := s.rescue
			_set_title(UiText.t("rescue_title") % r["amount"], "warning", UiTheme.RED.lightened(0.2))
			_action_body.text = UiText.t("rescue_body") % cash
			for pid in s.properties_of(seat):
				_add_button(UiText.t("liquidate_item") % [_prop_name(pid), e.liquidation_value(pid)], ErCommand.LIQUIDATE, {"property_ids": [pid]}, "secondary")
			_add_button(UiText.t("declare"), ErCommand.DECLARE_BANKRUPTCY, {}, "danger")
	_apply_columns()
	if s.phase == GameState.AWAIT_ROLL and _buttons.get_child_count() == 1:
		_hero(_buttons.get_child(0))
	_place_bottom.call_deferred()
	action_buttons_changed.emit()


## Phase 5: the roll button is the hero of the HUD: tall, large type, big dice
## icon, a gentle breathing glow while it waits (off with reduced motion).
## States: normal / hover (brighter) / pressed (lip removed) / disabled.
func _hero(b: Button) -> void:
	b.custom_minimum_size.y = HERO_HEIGHT
	b.add_theme_font_size_override("font_size", HERO_FONT)
	b.add_theme_font_override("font", UiTheme.font("ExtraBold"))
	b.add_theme_constant_override("icon_max_width", 64)
	b.add_theme_stylebox_override("hover", UiTheme.hover_skin("btn_primary"))
	b.set_meta("hero", true)
	if _hero_tween:
		_hero_tween.kill()
		_hero_tween = null
	if b.disabled:
		b.add_theme_color_override("font_disabled_color", UiTheme.TEXT)
		b.add_theme_color_override("icon_disabled_color", UiTheme.GOLD)
		return
	if presenter and not presenter.reduced_motion:
		_hero_tween = b.create_tween().set_loops()
		_hero_tween.tween_property(b, "self_modulate", Color(1.12, 1.08, 0.98), 0.9).set_trans(Tween.TRANS_SINE)
		_hero_tween.tween_property(b, "self_modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE)


func _on_cue(name: String, data: Dictionary) -> void:
	match name:
		"dice_roll":
			_last_dice = []
		"dice_land":
			_last_dice = [data["d1"], data["d2"]]
			if _rolling:
				_last_key = ""  # refresh the hero label with the result


## Windows/desktop: Space or Enter rolls when the roll button is offered.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		pause_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		for a in actions:
			if a["type"] == ErCommand.ROLL_DICE and not a["button"].disabled:
				a["button"].pressed.emit()
				get_viewport().set_input_as_handled()
				return


func _build_strategy(seat: int) -> void:
	var e := match_ref.engine
	var s := e.state
	_set_title(UiText.t("strategy_title"), "build")
	var upgradable: Array = []
	for pid in s.properties_of(seat):
		if e.can_upgrade(seat, pid) == "":
			upgradable.append(pid)
	if _sub_view == "upgrade":
		for pid in upgradable:
			_add_button(UiText.t("upgrade_item") % [_prop_name(pid), s.level[pid] + 1, e.upgrade_quote(seat, pid)["amount"]], ErCommand.UPGRADE, {"property_id": pid})
		_add_button(UiText.t("back"), "", {}, "secondary", true, func(): _sub_view = "", "close")
		return
	if upgradable.is_empty():
		_action_body.text = UiText.t("no_upgrades")
	var up := _add_button(UiText.t("upgrade"), "", {}, "", not upgradable.is_empty(), func(): _sub_view = "upgrade", "build")
	up.set_meta("opens", "upgrade")
	if e.ability_available(seat):
		var ab: Dictionary = config.character_by_id[s.player(seat)["character_id"]]["ability"]
		_add_button(UiText.t("use_ability"), ErCommand.USE_ABILITY, {"ability_id": ab["ability_id"]}, "secondary")
	_add_button(UiText.t("end_turn"), ErCommand.END_TURN, {}, "secondary")


func _side_text(side: Dictionary) -> String:
	var parts: Array[String] = []
	if side["cash"] > 0:
		parts.append("%d RC" % side["cash"])
	for pid in side["property_ids"]:
		parts.append(_prop_name(pid))
	return "—" if parts.is_empty() else ", ".join(parts)


func _prop_name(pid: String) -> String:
	return theme_data.property_name(pid, config)


func _opp(entry_id: String) -> Dictionary:
	for e in config.opportunity_entries():
		if e["entry_id"] == entry_id:
			return e
	return {}
