## Plays the human seat THROUGH THE HUD: asks a BotPlayer what to do, then
## presses the matching on-screen button (or the closest one). Used for the
## automated UI tests, video capture and timing sessions; it never calls the
## engine directly.
class_name HudAutopilot
extends Node

var hud: GameHud
var match_ref: LocalMatch
var think_seconds := Vector2(0.8, 1.6)
var presses := 0
var _bot: BotPlayer
var _wait := -1.0
var _rng := RandomNumberGenerator.new()


func setup(p_hud: GameHud, p_match: LocalMatch, seat: int, seed_value: int) -> void:
	hud = p_hud
	match_ref = p_match
	_rng.seed = seed_value
	_bot = BotPlayer.new(seat, match_ref.player_id(seat), ErRng.new(seed_value), 0)


func _process(delta: float) -> void:
	if hud.actions.is_empty():
		_wait = -1.0
		return
	if _wait < 0.0:
		_wait = _rng.randf_range(think_seconds.x, think_seconds.y)
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = -1.0
	var b := choose_button()
	if b:
		presses += 1
		b.pressed.emit()


func choose_button() -> Button:
	var want: Dictionary = _bot.decide(match_ref.engine)
	var enabled := hud.actions.filter(func(a): return not a["button"].disabled)
	if enabled.is_empty():
		return null
	if want.is_empty():
		return null  # e.g. auction: bot would not bid -> let the timer run
	if want["type"] == ErCommand.UPGRADE:
		# Open the upgrade sub-menu first if needed.
		for a in enabled:
			if a["button"].has_meta("opens"):
				return a["button"]
	for a in enabled:
		if a["type"] == want["type"] and (a["payload"] == want["payload"] or want["type"] in [ErCommand.PLACE_BID, ErCommand.LIQUIDATE, ErCommand.UPGRADE]):
			return a["button"]
	for a in enabled:
		if a["type"] == want["type"]:
			return a["button"]
	# Fall back to the safe "end/decline" style action.
	for a in enabled:
		if a["type"] in [ErCommand.END_TURN, ErCommand.PASS_PROPERTY]:
			return a["button"]
	return enabled[0]["button"]
