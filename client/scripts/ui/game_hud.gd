## Touch HUD for the vertical slice. Reads engine state/queries for display and
## sends intent through LocalMatch.submit() only; it never changes rules state
## or computes money itself. Portrait-first; switches to a side layout in
## landscape. All interactive controls are >= UiTheme.MIN_TOUCH px tall.
class_name GameHud
extends Control

signal restart_requested
signal quality_cycle_requested
## Holding the quality button opens the device-validation panel (DevPanel).
signal dev_menu_requested
signal action_buttons_changed

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
var _cards_box: BoxContainer
var _cards: Array = []
var _round_label: Label
var _turn_label: Label
var _timer_bar: ProgressBar
var _quality_btn: Button
## Set by main only when the device tools exist (BuildFlavor). Otherwise a
## long press is just a press and cycles the preset.
var dev_menu_enabled := false
var _quality_down_ms := 0
var _quality_down := false
var _action_panel: PanelContainer
var _action_title: Label
var _action_body: Label
var _buttons: GridContainer
var _buttons_scroll: ScrollContainer
var _toasts: VBoxContainer
var _info: PanelContainer
var _info_label: Label
var _results: PanelContainer
var _results_label: Label
var _placeholder_tag: Label

const TOAST_MAX := 2
const TOAST_BAND := 104.0   # px reserved under the top panel for toasts (portrait)
const ACTION_BAND := 0.235  # fraction of height reserved for the action panel (portrait)
const LONG_PRESS_MS := 900

var _presented_turn := 0
var _presented_round := 1
var _sub_view := ""
var _last_key := ""
var _timer_total := 45.0
var _landscape := false


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
	_top.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.NAVY, Color(1, 1, 1, 0.1), 24, 0.82))
	add_child(_top)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_top.add_child(v)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	_round_label = _label(24, UiTheme.GOLD)
	_round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_round_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_round_label)
	_placeholder_tag = _label(18, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_RIGHT)
	_placeholder_tag.set_meta("decorative", true)
	_placeholder_tag.text = UiText.t("placeholder")
	_placeholder_tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_placeholder_tag)
	_quality_btn = Button.new()
	# 82 px ≈ 44 pt (Apple's minimum) for this secondary control.
	_quality_btn.custom_minimum_size = Vector2(UiTheme.MIN_TOUCH * 1.4, 82)
	_quality_btn.add_theme_font_size_override("font_size", 20)
	UiTheme.secondary(_quality_btn)
	_quality_btn.button_down.connect(func():
		_quality_down = true
		_quality_down_ms = Time.get_ticks_msec())
	_quality_btn.pressed.connect(_on_quality_pressed)
	row.add_child(_quality_btn)
	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 8)
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
	_timer_bar.add_theme_stylebox_override("background", bg)
	_timer_bar.add_theme_stylebox_override("fill", fg)
	v.add_child(_timer_bar)


func _build_card(seat: int) -> Dictionary:
	var p := match_ref.engine.state.player(seat)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
	_cards_box.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	panel.add_child(v)
	var name := _label(22, theme_data.player_color(seat).lightened(0.25))
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.text = theme_data.player_name(seat)
	v.add_child(name)
	var ch := _label(20, Color(1, 1, 1, 0.72))
	ch.autowrap_mode = TextServer.AUTOWRAP_OFF
	ch.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ch.text = theme_data.loc(p["character_id"], "short", theme_data.character_name(p["character_id"], config))
	v.add_child(ch)
	var cash := _label(30, UiTheme.TEXT)
	cash.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(cash)
	return {"panel": panel, "name": name, "cash": cash, "seat": seat}


func _build_action_panel() -> void:
	_action_panel = PanelContainer.new()
	add_child(_action_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_action_panel.add_child(v)
	_action_title = _label(29, UiTheme.GOLD)
	v.add_child(_action_title)
	_action_body = _label(24)
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
	add_child(_info)
	var v := VBoxContainer.new()
	_info.add_child(v)
	_info_label = _label(24)
	v.add_child(_info_label)
	var close := Button.new()
	close.text = UiText.t("back")
	close.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
	UiTheme.secondary(close)
	close.pressed.connect(func(): _info.visible = false)
	v.add_child(close)


func _build_results() -> void:
	_results = PanelContainer.new()
	_results.visible = false
	_results.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.NAVY, UiTheme.GOLD, 28, 0.96))
	add_child(_results)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_results.add_child(v)
	_results_label = _label(25)
	v.add_child(_results_label)
	var again := Button.new()
	again.text = UiText.t("play_again")
	again.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
	again.pressed.connect(func(): restart_requested.emit())
	v.add_child(again)


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
	# Widths go through custom_minimum_size: containers with autowrapping
	# labels otherwise collapse to their narrowest width.
	if _landscape:
		var top_w := s.size.x * 0.56
		_top.position = s.position + Vector2(m, m)
		_width(_top, top_w - m * 2)
		_action_panel.position = Vector2(s.position.x + s.size.x * 0.58, s.position.y + m)
		_width(_action_panel, s.size.x * 0.42 - m)
		_toasts.position = Vector2(s.position.x + s.size.x * 0.58, s.position.y + s.size.y * 0.62)
		_width(_toasts, s.size.x * 0.42 - m)
	else:
		_top.position = s.position + Vector2(m, m)
		_width(_top, s.size.x - m * 2)
		_width(_action_panel, s.size.x - m * 2)
		_width(_toasts, s.size.x - m * 2)
	_width(_info, minf(s.size.x - m * 4, 620))
	if _landscape:
		_width(_results, s.size.x * 0.42 - m)
	else:
		_width(_results, s.size.x - m * 2)
	_place_bottom.call_deferred()


func _width(c: Control, w: float) -> void:
	c.custom_minimum_size.x = w
	c.size = Vector2(w, 0)
	# Autowrapping labels compute their minimum height from their current
	# width; give them the final width up front or panels grow to full height.
	for l in c.find_children("*", "Label", true, false):
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
			l.custom_minimum_size.x = w - 40.0
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
		_action_panel.reset_size()
		_results.reset_size()
		_results.position = _action_panel.position
	_info.reset_size()
	_info.position = s.get_center() - _info.size * 0.5


## Fraction of the viewport height covered by HUD at top/bottom (portrait),
## or width fraction on the right (landscape). Used by the camera rig.
func board_insets() -> Dictionary:
	var vp := get_viewport_rect().size
	if _landscape:
		var s0 := safe_rect()
		return {"top": (_top.position.y + _top.size.y) / vp.y, "bottom": (vp.y - s0.end.y) / vp.y, "right": 1.0 - (_action_panel.position.x / vp.x) + 0.01, "left": 0.0}
	# Reserve a fixed band for the action panel so the board does not jump
	# every time the panel height changes.
	var s := safe_rect()
	return {"top": (_top.position.y + _top.size.y + TOAST_BAND) / vp.y, "bottom": (vp.y - s.end.y) / vp.y + ACTION_BAND, "left": 0.0, "right": 0.0}


# --- live updates ---------------------------------------------------------------

func _on_cash(seat: int, cash: int) -> void:
	if seat < _cards.size():
		_cards[seat]["cash"].text = "%d RC" % cash


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
		var border: Color = theme_data.player_color(seat) if active else Color(1, 1, 1, 0.08)
		c["panel"].add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.NAVY_SOFT if active else UiTheme.NAVY, border, 16, 0.95))
		c["panel"].modulate = Color(1, 1, 1, 0.45) if bankrupt else Color.WHITE
	var cap := config.max_rounds_for(s.players.size())
	_round_label.text = UiText.t("round") % [_presented_round, cap]
	var who := theme_data.player_name(_presented_turn)
	_turn_label.text = UiText.t("your_turn") if match_ref.is_human(_presented_turn) else UiText.t("turn_of") % who


func show_toast(text: String, color := Color.WHITE) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiTheme.panel(Color(0.05, 0.07, 0.12), color.darkened(0.2), 14, 0.78))
	var l := _label(22, color.lightened(0.35))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.text = text
	p.add_child(l)
	_toasts.add_child(p)
	while _toasts.get_child_count() > TOAST_MAX:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var t := p.create_tween()
	t.tween_interval(3.2)
	t.tween_property(p, "modulate:a", 0.0, 0.5)
	t.tween_callback(p.queue_free)


func _process(_delta: float) -> void:
	if match_ref == null or match_ref.engine == null:
		return
	var left := match_ref.seconds_left()
	_timer_bar.value = 100.0 * left / maxf(_timer_total, 0.001)
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
	var rows: Array[String] = [UiText.t("results") + " · " + UiText.t("end_reason_" + d["reason"])]
	var human_won := false
	for r in d["results"]:
		rows.append(UiText.t("result_row") % [r["rank"], theme_data.player_name(r["seat"]), r["net_worth"], UiText.t("bankrupt_tag") if r["bankrupt"] else ""])
		if r["rank"] == 1 and match_ref.is_human(r["seat"]):
			human_won = true
	rows.insert(1, UiText.t("you_won") if human_won else UiText.t("you_lost"))
	_results_label.text = "\n".join(rows)
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


func _add_button(text: String, type: String, payload := {}, style := "", enabled := true, local_action := Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.disabled = not enabled
	match style:
		"secondary": UiTheme.secondary(b)
		"danger": UiTheme.danger(b)
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
	var max_panel := (vp.y * ACTION_BAND - 14.0) if not _landscape else (s.size.y - 28.0)
	_action_body.visible = _action_body.text != ""
	# Everything in the panel except the scroll area, measured, not guessed.
	var fixed := _action_panel.get_combined_minimum_size().y - _buttons_scroll.get_combined_minimum_size().y + 4.0
	var want := _buttons.get_combined_minimum_size().y
	_buttons_scroll.custom_minimum_size.y = clampf(want, 0.0, maxf(UiTheme.MIN_TOUCH, max_panel - fixed))
	_buttons_scroll.scroll_vertical = 0


## 2 buttons side by side, 3 in a row, longer lists in two columns.
func _apply_columns() -> void:
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
	match_ref.submit(seat, type, payload)


func _rebuild_actions() -> void:
	_clear_buttons()
	var e := match_ref.engine
	var s := e.state
	if e.is_ended():
		_action_panel.visible = false
		action_buttons_changed.emit()
		return
	_action_panel.visible = true
	var seat := match_ref.human_actor()
	_action_body.text = ""
	if seat < 0 or not presenter.is_idle():
		var actor := s.current_seat
		_action_title.text = UiText.t("turn_of") % theme_data.player_name(actor) if not match_ref.is_human(actor) else UiText.t("your_turn")
		if seat < 0 and presenter.is_idle():
			_action_body.text = UiText.t("waiting") % theme_data.player_name(actor)
		_place_bottom.call_deferred()
		action_buttons_changed.emit()
		return
	var cash: int = s.player(seat)["cash"]
	match s.phase:
		GameState.AWAIT_ROLL:
			_action_title.text = UiText.t("your_turn")
			_add_button(UiText.t("roll"), ErCommand.ROLL_DICE)
		GameState.AWAIT_BUY:
			var pid := e.property_at(s.player(seat)["position"])
			var price: int = config.tier_of(pid)["price"]
			var sp: Dictionary = config.spaces[s.player(seat)["position"]]
			var lad := e.rent_ladder(pid)
			_action_title.text = "%s · %s" % [_prop_name(pid), theme_data.districts[sp["district_id"]]["label"]]
			_action_body.text = (UiText.t("price_rent") % [price, lad[0]]) + "\n" + (UiText.t("rent_table") % lad)
			if price > cash:
				_action_body.text += "\n" + UiText.t("cant_afford") % price
			_add_button(UiText.t("buy") % price, ErCommand.BUY_PROPERTY, {"property_id": pid}, "", price <= cash)
			_add_button(UiText.t("pass"), ErCommand.PASS_PROPERTY, {"property_id": pid}, "secondary")
		GameState.AUCTION:
			var a := s.auction
			var need := e.min_next_bid()
			_action_title.text = UiText.t("auction_title") % _prop_name(a["property_id"])
			var leader: String = "—" if a["high_seat"] < 0 else theme_data.player_name(a["high_seat"])
			_action_body.text = UiText.t("auction_state") % [a["high_bid"], leader, need]
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
			_action_title.text = theme_data.loc(c["ref_id"], "title", def["title"])
			_action_body.text = theme_data.loc(c["ref_id"], "text", def.get("text", ""))
			for o in c["options"]:
				var olabel: String = theme_data.loc(c["ref_id"] + "." + o["option_id"], "label", o["label"])
				var label: String = olabel if o["cost"] == 0 else UiText.t("choice_cost") % [olabel, o["cost"]]
				_add_button(label, ErCommand.CHOOSE_OPTION, {"choice_id": c["choice_id"], "option_id": o["option_id"]}, "", o["cost"] <= cash)
		GameState.STRATEGY:
			_build_strategy(seat)
		GameState.TRADE_PENDING:
			var t := s.trade
			_action_title.text = UiText.t("trade_title") % theme_data.player_name(t["from"])
			_action_body.text = UiText.t("trade_terms") % [_side_text(t["give"]), _side_text(t["take"])]
			_add_button(UiText.t("accept"), ErCommand.RESPOND_TRADE, {"trade_id": t["trade_id"], "accept": true})
			_add_button(UiText.t("reject"), ErCommand.RESPOND_TRADE, {"trade_id": t["trade_id"], "accept": false}, "danger")
		GameState.RESCUE:
			var r := s.rescue
			_action_title.text = UiText.t("rescue_title") % r["amount"]
			_action_body.text = UiText.t("rescue_body") % cash
			for pid in s.properties_of(seat):
				_add_button(UiText.t("liquidate_item") % [_prop_name(pid), e.liquidation_value(pid)], ErCommand.LIQUIDATE, {"property_ids": [pid]}, "secondary")
			_add_button(UiText.t("declare"), ErCommand.DECLARE_BANKRUPTCY, {}, "danger")
	_apply_columns()
	_place_bottom.call_deferred()
	action_buttons_changed.emit()


func _build_strategy(seat: int) -> void:
	var e := match_ref.engine
	var s := e.state
	_action_title.text = UiText.t("strategy_title")
	var upgradable: Array = []
	for pid in s.properties_of(seat):
		if e.can_upgrade(seat, pid) == "":
			upgradable.append(pid)
	if _sub_view == "upgrade":
		for pid in upgradable:
			_add_button(UiText.t("upgrade_item") % [_prop_name(pid), s.level[pid] + 1, e.upgrade_quote(seat, pid)["amount"]], ErCommand.UPGRADE, {"property_id": pid})
		_add_button(UiText.t("back"), "", {}, "secondary", true, func(): _sub_view = "")
		return
	if upgradable.is_empty():
		_action_body.text = UiText.t("no_upgrades")
	var up := _add_button(UiText.t("upgrade"), "", {}, "", not upgradable.is_empty(), func(): _sub_view = "upgrade")
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
