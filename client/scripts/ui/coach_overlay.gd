## Phase 5.1 coach: explains the game in context, one thing at a time, on a
## real match. Replaces the Phase 5 wall-of-text tutorial.
##
## - Tips (RulesGuide.tips()): shown once each, the first time the situation
##   happens to the player (buy prompt, auction, rent paid, event card,
##   district complete, upgrade, rescue, trade...). Tips with `pause` pause
##   the match through the lifecycle gate (timer and bots wait) until the
##   player reads them or acts; the HUD stays usable. Seen tips persist
##   (GameSettings.tips_seen); tips can be switched off in Settings.
## - Guided tutorial (`guided`): a welcome card, then the same tips in play
##   order with the HUD button to press highlighted (roll, buy, end turn), a
##   "watch the bot" card, and a closing card. Every tip shows regardless of
##   what was seen before.
## - Next-action hint: when the player has a decision and does nothing for
##   idle_hint_s seconds, a short "Gợi ý: ..." line names the next step.
## Presentation only: it never sends a command or reads hidden state.
class_name CoachOverlay
extends Control

signal finished  # guided tutorial completed or skipped

var idle_hint_s := 10.0
const INFO_SECONDS := 8.0

var match_ref: LocalMatch
var hud: GameHud
var presenter: EventPresenter
var guide: RulesGuide
var guided := false
var buttons := {}
## Tip ids shown in this match, in order (tests / diagnostics).
var shown: Array[String] = []
## The card on screen: {id, pause, phase, info_left}.
var current := {}
var idle_hint: Label

var _tips: Dictionary
var _cards: Dictionary
var _queue: Array = []
var _card: PanelContainer
var _title: Label
var _body: Label
var _icon: TextureRect
var _seen_version := -1
var _idle := 0.0
var _idle_key := ""
var _paused := false
var _guided_stage := "welcome"  # welcome -> play -> watch -> done -> over
var _glow: Array = []


func setup(p_match: LocalMatch, p_hud: GameHud, p_presenter: EventPresenter, config: GameConfig, p_guided := false) -> void:
	match_ref = p_match
	hud = p_hud
	presenter = p_presenter
	guided = p_guided
	guide = RulesGuide.new(config)
	_tips = guide.tips()
	_cards = guide.guided_cards()
	theme = UiTheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	presenter.cue.connect(_on_cue)
	hud.action_buttons_changed.connect(_on_actions)
	get_viewport().size_changed.connect(_layout)
	if guided:
		_show_card("welcome", _cards["welcome"])


func _build() -> void:
	_card = PanelContainer.new()
	var st := UiTheme.panel(UiTheme.NAVY, UiTheme.GOLD, 20, 0.97)
	st.set_border_width_all(3)
	st.shadow_size = 18
	st.shadow_color = Color(0, 0, 0, 0.5)
	_card.add_theme_stylebox_override("panel", st)
	_card.visible = false
	add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(40, 40)
	_icon.modulate = UiTheme.GOLD
	head.add_child(_icon)
	_title = _label(28, UiTheme.GOLD, "ExtraBold")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_body = _label(UiTheme.FS_BODY, UiTheme.TEXT, "Medium")
	v.add_child(_body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var off := _button("BỎ HƯỚNG DẪN" if guided else "TẮT GỢI Ý", "skip")
	UiTheme.neutral(off)
	off.pressed.connect(_switch_off)
	buttons["off"] = off
	row.add_child(off)
	var ok := _button("ĐÃ HIỂU", "check")
	ok.pressed.connect(_dismiss)
	buttons["ok"] = ok
	row.add_child(ok)
	idle_hint = _label(UiTheme.FS_BODY, UiTheme.AMBER, "Bold")
	idle_hint.visible = false
	idle_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hs := UiTheme.panel(Color(0.04, 0.06, 0.1), UiTheme.AMBER, 16, 0.92)
	var hint_box := PanelContainer.new()
	hint_box.add_theme_stylebox_override("panel", hs)
	hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_box.add_child(idle_hint)
	hint_box.visible = false
	hint_box.name = "HintBox"
	add_child(hint_box)


# --- triggers -------------------------------------------------------------------

func _human_turn() -> bool:
	return match_ref.human_actor() >= 0


## Phase-based tips, evaluated when the HUD rebuilds its buttons (the human
## has a decision and the presentation has caught up).
func _on_actions() -> void:
	var e := match_ref.engine
	var s := e.state
	if e.is_ended():
		_clear()
		return
	if not current.is_empty() and current.get("phase", "") != "" and current["phase"] != s.phase:
		_dismiss()  # the player acted: that tip is done
	var seat := match_ref.human_actor()
	if guided and _guided_stage == "play" and not match_ref.is_human(s.current_seat):
		_guided_stage = "watch"  # the player's first turn is over
	if seat < 0 or not presenter.is_idle():
		if guided and _guided_stage == "watch" and current.is_empty() and not "watch" in shown:
			shown.append("watch")
			_show_card("watch", _cards["watch"])
		return
	if guided and _guided_stage == "watch" and s.current_seat == seat and s.phase == GameState.AWAIT_ROLL:
		_guided_stage = "done"
		if current.get("id", "") == "watch":
			_dismiss()
		_show_card("done", _cards["done"])
		return
	match s.phase:
		GameState.AWAIT_ROLL:
			_want("roll", s.phase)
		GameState.AWAIT_BUY:
			_want("buy", s.phase)
		GameState.AUCTION:
			_want("auction", s.phase)
		GameState.AWAIT_CHOICE:
			_want("choice", s.phase)
		GameState.TRADE_PENDING:
			_want("trade", s.phase)
		GameState.RESCUE:
			_want("rescue", s.phase)
		GameState.STRATEGY:
			var can_up := false
			for pid in s.properties_of(seat):
				if e.can_upgrade(seat, pid) == "":
					can_up = true
			if can_up:
				_want("upgrade", s.phase)
			elif e.ability_available(seat):
				_want("ability", s.phase)
			else:
				_want("strategy", s.phase)
	_point()


## Event-based tips (presenter cues: shown when the beat is on screen).
func _on_cue(name: String, data: Dictionary) -> void:
	var me := match_ref.is_human(int(data.get("seat", -1)))
	match name:
		"cash_loss":
			if me and data.get("reason", "") == "rent":
				_want("rent_paid", "")
			elif me and data.get("reason", "") == "wealth_tax":
				_want("tax", "")
		"cash_gain":
			if me and data.get("reason", "") == "rent":
				_want("rent_got", "")
			elif me and data.get("reason", "") == "start_reward":
				_want("start", "")
		"card":
			if me:
				_want("event", "")
		"buy":
			if me and _completes_district(int(data["seat"]), str(data.get("property_id", ""))):
				_want("district", "")
		"bankrupt":
			if not me:
				_want("bankrupt", "")


func _completes_district(seat: int, pid: String) -> bool:
	if pid == "" or not match_ref.engine.config.property_index.has(pid):
		return false
	var cfg := match_ref.engine.config
	var did: String = cfg.spaces[cfg.property_index[pid]]["district_id"]
	for p in cfg.district_props[did]:
		if match_ref.engine.state.owner.get(p, GameState.BANK) != seat:
			return false
	return true


func _want(id: String, phase: String) -> void:
	if not _tips.has(id) or id in shown or current.get("id", "") == id:
		return
	if not guided and (not GameSettings.tips_enabled or id in GameSettings.tips_seen):
		return
	if guided and _guided_stage == "welcome":
		return
	for q in _queue:
		if q["id"] == id:
			return
	var t: Dictionary = _tips[id].duplicate()
	t["id"] = id
	t["phase"] = phase
	if guided and phase != "":
		t["pause"] = true  # the tutorial waits for the reader on every decision
	if current.is_empty():
		_show_card(id, t)
	elif t["pause"] and not current["pause"] and current["id"] != "welcome":
		# A decision is waiting: it goes first, the information tip waits.
		var info: Dictionary = _tips.get(current["id"], {}).duplicate()
		if not info.is_empty():
			info["id"] = current["id"]
			info["phase"] = ""
			shown.erase(current["id"])  # shown again after the decision
		current = {}
		_show_card(id, t)
		if not info.is_empty():
			_queue.push_front(info)
	else:
		_queue.append(t)


# --- card -----------------------------------------------------------------------

func _show_card(id: String, t: Dictionary) -> void:
	current = {"id": id, "pause": bool(t.get("pause", false)), "phase": t.get("phase", ""), "info_left": INFO_SECONDS}
	if id in _tips:
		shown.append(id)
		if not guided and not id in GameSettings.tips_seen:
			GameSettings.tips_seen.append(id)
			GameSettings.save_settings()
	_icon.texture = UiTheme.icon(t["icon"])
	_title.text = t["title"]
	_body.text = t["body"]
	buttons["ok"].text = {"welcome": "BẮT ĐẦU", "done": "CHƠI TIẾP"}.get(id, "ĐÃ HIỂU")
	buttons["off"].visible = id != "done"
	_card.visible = true
	_set_pause(current["pause"])
	if not MatchSetup.reduced_motion:
		_card.modulate.a = 0.0
		_card.create_tween().tween_property(_card, "modulate:a", 1.0, 0.2)
	AudioDirector.ui("ui_confirm")
	_hide_hint()
	_relayout()
	_point()


func _dismiss() -> void:
	if current.is_empty():
		return
	var id: String = current["id"]
	current = {}
	_card.visible = false
	_set_pause(false)
	_unpoint()
	if guided:
		if id == "welcome":
			_guided_stage = "play"
			_on_actions()
		elif id == "done":
			_guided_stage = "over"
			guided = false
			finished.emit()
	if not _queue.is_empty():
		var t: Dictionary = _queue.pop_front()
		_show_card(t["id"], t)


func _switch_off() -> void:
	if guided:
		guided = false
		_guided_stage = "over"
		finished.emit()
	GameSettings.tips_enabled = false
	GameSettings.save_settings()
	_clear()


func _clear() -> void:
	_queue.clear()
	current = {}
	_card.visible = false
	_set_pause(false)
	_unpoint()
	_hide_hint()


func _set_pause(on: bool) -> void:
	if on == _paused or match_ref == null:
		return
	_paused = on
	if on:
		match_ref.lifecycle.pause("coach")
	else:
		match_ref.lifecycle.resume("coach")


## Guided tutorial: light up the HUD button the current step teaches.
func _point() -> void:
	_unpoint()
	if not guided or current.is_empty():
		return
	var types: Array = {"roll": [ErCommand.ROLL_DICE], "buy": [ErCommand.BUY_PROPERTY, ErCommand.PASS_PROPERTY],
		"strategy": [ErCommand.END_TURN], "auction": [ErCommand.PLACE_BID]}.get(current["id"], [])
	for a in hud.actions:
		if a["type"] in types and not a["button"].disabled:
			var b: Button = a["button"]
			var tw := b.create_tween().set_loops()
			tw.tween_property(b, "modulate", Color(1.25, 1.2, 0.9), 0.45)
			tw.tween_property(b, "modulate", Color.WHITE, 0.45)
			_glow.append([b, tw])


func _unpoint() -> void:
	for g in _glow:
		if is_instance_valid(g[1]):
			g[1].kill()
		if is_instance_valid(g[0]):
			g[0].modulate = Color.WHITE
	_glow.clear()


func is_pointing() -> bool:
	return not _glow.is_empty()


# --- idle hint and info timeout -------------------------------------------------

func _process(delta: float) -> void:
	if match_ref == null:
		return
	var s := match_ref.engine.state
	if not current.is_empty() and not current["pause"]:
		current["info_left"] -= delta
		if current["info_left"] <= 0.0 and current["id"] != "watch":
			_dismiss()
	var seat := match_ref.human_actor()
	var key := "%s|%d" % [s.phase, s.state_version]
	if seat < 0 or not presenter.is_idle() or not current.is_empty() or match_ref.engine.is_ended():
		_idle = 0.0
		_idle_key = key
		_hide_hint()
		return
	if key != _idle_key:
		_idle_key = key
		_idle = 0.0
		_hide_hint()
	_idle += delta
	if _idle >= idle_hint_s and not idle_hint.visible:
		var text := guide.next_hint(s.phase)
		if text != "":
			idle_hint.text = text
			idle_hint.visible = true
			idle_hint.get_parent().visible = true
			_layout()


func _hide_hint() -> void:
	if idle_hint and idle_hint.visible:
		idle_hint.visible = false
		idle_hint.get_parent().visible = false


# --- layout ---------------------------------------------------------------------

## Wrapped labels report their real height a frame or two late: lay out
## again then, or the card keeps a too-tall first guess (empty band).
func _relayout() -> void:
	_layout.call_deferred()
	for i in 2:
		await get_tree().process_frame
		if is_inside_tree():
			_card.size = Vector2.ZERO
			_layout()

func _layout() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport_rect().size
	var landscape := vp.x > vp.y
	var w := minf(vp.x * (0.5 if landscape else 1.0) - 40.0, 680.0)
	_card.custom_minimum_size.x = w
	_body.custom_minimum_size.x = w - 44.0
	_title.custom_minimum_size.x = w - 100.0
	_card.reset_size()
	if landscape:
		# Over the top of the board area (left of the HUD column).
		var board_w: float = hud._top.position.x
		_card.position = Vector2((board_w - _card.size.x) * 0.5, 20.0)
	else:
		# Under the player bar, above the board.
		_card.position = Vector2((vp.x - _card.size.x) * 0.5, hud._top.position.y + hud._top.size.y + 12.0)
	var hb: Control = idle_hint.get_parent()
	idle_hint.custom_minimum_size.x = minf(w, 620.0) - 32.0
	hb.reset_size()
	var panel: Control = hud._action_panel
	hb.position = Vector2(panel.position.x + (panel.size.x - hb.size.x) * 0.5, panel.position.y - hb.size.y - 10.0)


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
