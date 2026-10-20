## Offline authority for the vertical slice: owns the M1 GameEngine, drives
## its clock from frame time, applies timeouts and lets bot seats act.
## The UI talks to the match ONLY through submit(); everything the player sees
## comes from engine events. Swappable for a RemoteAuthority in M3.
class_name LocalMatch
extends Node

signal events_emitted(events: Array)
signal command_rejected(seat: int, type: String, error: String)

var config: GameConfig
var engine: GameEngine
var clock := FrameClock.new(0)
var human_seats: Array[int] = []
## Presentation gate: bots wait while this returns false so animations are
## visible. It never affects rules or timers (deadlines keep running).
var can_act: Callable = func(): return true
var bot_delay_range := Vector2(0.7, 1.5)
## Offline lifecycle (M2.2.1): while the app is in the background the match
## clock, bots and timeouts stop; see LifecycleGate and docs/RULES_M1.md §Offline lifecycle.
var lifecycle := LifecycleGate.new()
## Losing focus also pauses on phones. On desktop only a real OS suspend
## does, so alt-tabbing away from a window does not freeze the match.
var pause_on_focus_loss := OS.has_feature("mobile")

var _bots: Dictionary = {}
var _bot_wait := 0.0
var _rng := RandomNumberGenerator.new()  # bot pacing only
var _cmd_n := 0


func start(p_config: GameConfig, seats: Array, seed_value: int, p_human_seats: Array[int]) -> void:
	config = p_config
	human_seats = p_human_seats
	engine = GameEngine.create(config, clock, seats, seed_value, "local-%d" % seed_value)
	_rng.seed = seed_value
	var bot_rng := ErRng.new(seed_value * 7919 + 17)
	for i in seats.size():
		if not i in human_seats:
			_bots[i] = BotPlayer.new(i, seats[i]["player_id"], bot_rng, 0)
	# Events emitted by create() are in the engine log; replay them to listeners.
	events_emitted.emit.call_deferred(engine.event_log.duplicate())


## Web/PWA: rebuilds a saved match by replaying its logged commands on a
## fresh engine (SavedMatch). Returns false - and leaves the match unstarted -
## when the record does not replay to the saved state hash.
func resume(p_config: GameConfig, rec: Dictionary, p_human_seats: Array[int]) -> bool:
	var r := MatchReplay.replay(p_config, rec)
	if not r["ok"] or r["engine"].state.state_hash() != str(rec.get("state_hash", "")):
		push_warning("resume failed: %s" % r.get("error", "state hash differs"))
		return false
	config = p_config
	human_seats = p_human_seats
	engine = r["engine"]
	# Continue on the frame clock from the replayed match time.
	clock = FrameClock.new(engine.clock.now_ms())
	engine.clock = clock
	# Command ids continue after the logged ones (the engine ignores a
	# repeated id as a duplicate).
	for entry in engine.input_log:
		var id: String = str(entry.get("cmd", {}).get("command_id", ""))
		if id.begins_with("ui-"):
			_cmd_n = maxi(_cmd_n, int(id.trim_prefix("ui-")))
	var seed_value: int = int(rec["seed"])
	_rng.seed = seed_value
	var bot_rng := ErRng.new(seed_value * 7919 + 17)
	for i in engine.state.players.size():
		if not i in human_seats:
			_bots[i] = BotPlayer.new(i, engine.state.players[i]["player_id"], bot_rng, 0)
	return true


func is_human(seat: int) -> bool:
	return seat in human_seats


func player_id(seat: int) -> String:
	return engine.state.player(seat)["player_id"]


## The single entry point for player intent (UI buttons, autopilot).
func submit(seat: int, type: String, payload: Dictionary = {}) -> Dictionary:
	_cmd_n += 1
	var cmd := ErCommand.make(engine.state.match_id, player_id(seat), "ui-%d" % _cmd_n,
		engine.state.state_version, type, payload)
	var res := engine.submit(cmd)
	if res["ok"]:
		events_emitted.emit(res["events"])
	else:
		command_rejected.emit(seat, type, res["error"])
	return res


func _notification(what: int) -> void:
	lifecycle.on_notification(what, pause_on_focus_loss)


func is_suspended() -> bool:
	return lifecycle.is_paused()


func _process(delta: float) -> void:
	if engine == null:
		return
	delta = lifecycle.filter(delta, Engine.time_scale)
	if lifecycle.is_paused():
		return
	clock.tick(delta)
	var timed := engine.advance()
	if not timed.is_empty():
		events_emitted.emit(timed)
	if engine.is_ended() or not can_act.call():
		_bot_wait = 0.0
		return
	var actor := _bot_actor()
	if actor < 0:
		_bot_wait = 0.0
		return
	if _bot_wait <= 0.0:
		_bot_wait = _rng.randf_range(bot_delay_range.x, bot_delay_range.y)
		if engine.state.phase == GameState.AUCTION:
			_bot_wait *= 0.6
		return
	_bot_wait -= delta
	if _bot_wait > 0.0:
		return
	_bot_wait = 0.0
	var cmd: Dictionary = _bots[actor].decide(engine)
	if cmd.is_empty():
		return
	var res := engine.submit(cmd)
	if res["ok"]:
		events_emitted.emit(res["events"])


## Which bot seat should act now (-1 if none / a human is up).
func _bot_actor() -> int:
	var s := engine.state
	if s.phase == GameState.AUCTION:
		var n := s.players.size()
		for k in n:
			var seat := (s.current_seat + 1 + k) % n
			if _bots.has(seat) and not _bots[seat].decide(engine).is_empty():
				return seat
		return -1
	var actor := s.current_seat
	match s.phase:
		GameState.TRADE_PENDING: actor = s.trade["to"]
		GameState.RESCUE: actor = s.rescue["debtor"]
		GameState.AWAIT_CHOICE: actor = s.choice["seat"]
	return actor if _bots.has(actor) else -1


## Seat the UI must serve right now (-1 if no human decision is pending).
func human_actor() -> int:
	if engine == null or engine.is_ended():
		return -1
	var s := engine.state
	var actor := s.current_seat
	match s.phase:
		GameState.TRADE_PENDING: actor = s.trade["to"]
		GameState.RESCUE: actor = s.rescue["debtor"]
		GameState.AWAIT_CHOICE: actor = s.choice["seat"]
		GameState.AUCTION:
			for h in human_seats:
				if not s.player(h)["bankrupt"]:
					return h
			return -1
	return actor if is_human(actor) else -1


func seconds_left() -> float:
	if engine == null or engine.is_ended():
		return 0.0
	return maxf(0.0, (engine.current_deadline_ms() - clock.now_ms()) / 1000.0)
