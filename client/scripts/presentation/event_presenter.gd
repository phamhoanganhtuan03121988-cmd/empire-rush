## Turns engine events into animations, one at a time. The engine state is
## already final when events arrive; the presenter only catches the visuals up.
## It keeps a "presented" copy of balances/positions so the HUD never shows a
## number before its animation, and it never computes rules values itself:
## every number shown comes from an event payload.
class_name EventPresenter
extends Node

signal busy_changed(busy: bool)
signal toast(text: String, color: Color, icon: String)
signal cash_presented(seat: int, cash: int)
signal turn_presented(seat: int, round: int)
signal card_presented(card_id: String, seat: int)
signal match_ended_presented(data: Dictionary)

var board: BoardView
var dice: DiceView
var tokens: Array[TokenView] = []
var theme: ThemeData
var config: GameConfig
var match_ref: LocalMatch
var popup_parent: Node3D
## Multiplies every animation duration (tests use a small value).
var speed := 1.0
## Accessibility / slow devices: no particle effects, faster token moves.
var reduced_motion := false

var presented_cash: Dictionary = {}
var presented_pos: Dictionary = {}
var _auction_bidders: Dictionary = {}  # seats that bid in the open auction
var _queue: Array = []
var _running := false


func is_idle() -> bool:
	return not _running and _queue.is_empty()


func enqueue(events: Array) -> void:
	_queue.append_array(events)
	if not _running:
		_run()


func _run() -> void:
	_running = true
	busy_changed.emit(true)
	while not _queue.is_empty():
		var ev: Dictionary = _queue.pop_front()
		await _present(ev)
	_running = false
	busy_changed.emit(false)


func _wait(seconds: float) -> void:
	if seconds * speed > 0.0:
		await get_tree().create_timer(seconds * speed, false).timeout


func _name(seat: int) -> String:
	return theme.player_name(seat) if seat >= 0 else UiText.t("bank")


func _present(ev: Dictionary) -> void:
	var d: Dictionary = ev["data"]
	match ev["type"]:
		"MatchStarted":
			for s in d["seats"]:
				presented_cash[s["seat"]] = s["cash"]
				presented_pos[s["seat"]] = 0
				cash_presented.emit(s["seat"], s["cash"])
			_place_tokens()
		"TurnStarted":
			turn_presented.emit(d["seat"], d["round"])
			board.set_highlight(presented_pos.get(d["seat"], 0))
			dice.hide_dice()
		"DiceRolled":
			await dice.roll_to(d["d1"], d["d2"], Vector3(0, 0.06, 1.2), 0.9 * speed)
			toast.emit(UiText.t("rolled") % [_name(d["seat"]), d["d1"], d["d2"], d["d1"] + d["d2"]], theme.player_color(d["seat"]), "dice")
		"TokenMoved":
			await _move_token(d["seat"], d["from"], d["to"], d["via"])
		"CashChanged":
			for side in [["from", "from_balance", -1], ["to", "to_balance", 1]]:
				var seat: int = d[side[0]]
				if seat >= 0 and d[side[1]] != null:
					presented_cash[seat] = d[side[1]]
					cash_presented.emit(seat, d[side[1]])
					_popup(seat, d["amount"] * side[2])
		"PropertyBought":
			board.show_owner(d["property_id"], d["seat"])
			_fx_burst(d["property_id"], theme.player_color(d["seat"]))
			toast.emit(UiText.t("bought") % [_name(d["seat"]), _prop(d["property_id"]), d["price"]], theme.player_color(d["seat"]), "coin")
			await _wait(0.35)
		"PropertyPassed":
			toast.emit(UiText.t("passed") % [_name(d["seat"]), _prop(d["property_id"])], Color.WHITE, "skip")
		"AuctionOpened":
			_auction_bidders.clear()
			toast.emit(UiText.t("auction_open") % [_prop(d["property_id"]), d["min_bid"]], Color("#f2b134"), "gavel")
		"BidPlaced":
			_auction_bidders[d["seat"]] = true
			toast.emit(UiText.t("bid") % [_name(d["seat"]), d["amount"]], theme.player_color(d["seat"]), "gavel")
		"AuctionClosed":
			# Clear feedback for the human: won (gold burst) or outbid.
			for h in _auction_bidders:
				if match_ref.is_human(h) and d["winner"] != h:
					toast.emit(UiText.t("auction_lost_you") % _prop(d["property_id"]), Color("#ff8a80"), "close")
			if d["winner"] >= 0:
				board.show_owner(d["property_id"], d["winner"])
				_fx_burst(d["property_id"], Color("#ffd36b") if match_ref.is_human(d["winner"]) else theme.player_color(d["winner"]))
				toast.emit(UiText.t("auction_won") % [_name(d["winner"]), _prop(d["property_id"]), d["price"]], theme.player_color(d["winner"]), "gavel")
			else:
				toast.emit(UiText.t("auction_none") % _prop(d["property_id"]), Color.WHITE, "gavel")
			await _wait(0.3)
		"RentCharged":
			await _coin_flight(d["payer"], d["owner"])
			toast.emit(UiText.t("rent") % [_name(d["payer"]), d["amount"], _name(d["owner"])], Color("#ffb3b3"), "coin")
		"UpgradeBuilt":
			board.show_level(d["property_id"], d["level"], d["seat"])
			_fx_dust(d["property_id"])
			_fx_burst(d["property_id"], theme.player_color(d["seat"]))
			toast.emit(UiText.t("upgraded") % [_name(d["seat"]), _prop(d["property_id"]), d["level"], d["cost"]], theme.player_color(d["seat"]), "build")
			await _wait(0.55)
		"PropertyTransferred":
			board.show_owner(d["property_id"], d["to"])
			if d["to"] < 0:
				board.show_level(d["property_id"], 0, -1, false)
		"PropertyLiquidated":
			board.show_owner(d["property_id"], -1)
			board.show_level(d["property_id"], 0, -1, false)
			toast.emit(UiText.t("liquidated") % [_name(d["seat"]), _prop(d["property_id"]), d["value"]], Color("#ffb3b3"), "coin")
		"EventCardDrawn":
			card_presented.emit(d["card_id"], d["seat"])
			toast.emit(UiText.t("card") % [_name(d["seat"]), theme.loc(d["card_id"], "title", config.cards[d["card_id"]]["title"])], Color("#e05d5d"), "event")
			await _wait(0.6)
		"WealthTaxCharged":
			toast.emit(UiText.t("tax") % [_name(d["seat"]), d["amount"]], Color("#d4a017"), "tax")
		"RescueStarted":
			toast.emit(UiText.t("rescue") % [_name(d["debtor"]), d["amount"]], Color("#ff6b6b"), "warning")
		"PlayerBankrupt":
			toast.emit(UiText.t("bankrupt") % _name(d["seat"]), Color("#ff6b6b"), "bankrupt")
			if not reduced_motion and popup_parent:
				Vfx.dust(popup_parent, tokens[d["seat"]].position + Vector3(0, 0.1, 0), Color(0.35, 0.35, 0.38), 30)
			await tokens[d["seat"]].fade_out()
		"TradeProposed":
			toast.emit(UiText.t("trade_proposed") % [_name(d["from"]), _name(d["to"])], Color("#9ad0ff"), "handshake")
		"TradeResolved":
			toast.emit(UiText.t("trade_" + d["status"]), Color("#9ad0ff"), "handshake")
		"AbilityUsed":
			toast.emit(UiText.t("ability") % _name(d["seat"]), theme.player_color(d["seat"]), "bolt")
		"DeadlineExpired":
			if match_ref.is_human(d["seat"]) and d["phase"] != GameState.AUCTION:
				toast.emit(UiText.t("timeout"), Color("#ffcc66"), "clock")
		"MatchEnded":
			board.set_highlight(-1)
			await _wait(0.6)
			match_ended_presented.emit(d)


func _fx_burst(pid: String, color: Color) -> void:
	if reduced_motion or popup_parent == null or speed < 0.2:
		return
	Vfx.burst(popup_parent, board.tile_position(config.property_index[pid]) + Vector3(0, 0.25, 0), color)


func _fx_dust(pid: String) -> void:
	if reduced_motion or popup_parent == null or speed < 0.2:
		return
	Vfx.dust(popup_parent, board.tile_position(config.property_index[pid]) + Vector3(0, 0.03, 0))


func _prop(pid: String) -> String:
	return theme.property_name(pid, config)


func _token_offset(seat: int) -> Vector3:
	var offs := [Vector3(-0.16, 0, -0.16), Vector3(0.16, 0, -0.16), Vector3(-0.16, 0, 0.16), Vector3(0.16, 0, 0.16)]
	return offs[seat % 4]


func _place_tokens() -> void:
	for t in tokens:
		t.position = board.tile_position(0) + _token_offset(t.seat)


func _move_token(seat: int, from: int, to: int, via: String) -> void:
	var n := config.board_size()
	var steps := (to - from + n) % n
	if steps == 0 and via == "card":
		steps = n
	var points: Array = []
	for k in range(1, steps + 1):
		points.append(board.tile_position((from + k) % n) + _token_offset(seat))
	board.set_highlight(-1)
	var hop := TokenView.HOP_TIME * speed * (0.6 if via == "card" else 1.0) * (0.5 if reduced_motion else 1.0)
	await tokens[seat].hop_along(points, hop)
	presented_pos[seat] = to
	board.set_highlight(to)


func _popup(seat: int, amount: int) -> void:
	if popup_parent == null or seat < 0 or seat >= tokens.size():
		return
	var l := Label3D.new()
	l.text = ("+%d" % amount) if amount > 0 else ("%d" % amount)
	l.font_size = 72
	l.pixel_size = 0.004
	l.outline_size = 14
	l.modulate = Color("#7CFC9A") if amount > 0 else Color("#ff6b6b")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = tokens[seat].position + Vector3(0, 0.75, 0)
	popup_parent.add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "position:y", l.position.y + 0.6, 1.1 * maxf(speed, 0.05))
	t.parallel().tween_property(l, "modulate:a", 0.0, 1.1 * maxf(speed, 0.05)).set_delay(0.4 * speed)
	t.tween_callback(l.queue_free)


func _coin_flight(from_seat: int, to_seat: int) -> void:
	if popup_parent == null:
		return
	var coin := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.09
	cm.height = 0.025
	cm.radial_segments = 16
	cm.rings = 1
	coin.mesh = cm
	coin.material_override = theme.mat(Color("#f4c542"), 0.25, 0.9, 0.5)
	popup_parent.add_child(coin)
	var a := tokens[from_seat].position + Vector3(0, 0.5, 0)
	var b := tokens[to_seat].position + Vector3(0, 0.5, 0)
	var t := coin.create_tween()
	t.tween_method(func(k: float):
		coin.position = a.lerp(b, k) + Vector3(0, sin(k * PI) * 1.0, 0)
		coin.rotation.x = k * TAU * 2.0, 0.0, 1.0, 0.55 * speed)
	await t.finished
	coin.queue_free()
