## Shared helpers for rules tests. White-box helpers (land/give/etc.) set up
## positions directly so each test controls the exact situation; everything
## under test still goes through GameEngine.submit()/advance().
class_name ErFixture
extends RefCounted

static var _config: GameConfig

var engine: GameEngine
var clock: MatchClock
var _n := 0


static func config() -> GameConfig:
	if _config == null:
		_config = GameConfig.load_from_dir()
	return _config


static func make(n_players: int = 2, seed_value: int = 1, characters: Array = []) -> ErFixture:
	var f := ErFixture.new()
	f.clock = MatchClock.new(1_000_000)
	var seats: Array = []
	var default_chars := ["TYCOON", "INVESTOR", "NEGOTIATOR", "TYCOON"]
	for i in n_players:
		seats.append({"player_id": "p%d" % i, "character_id": characters[i] if i < characters.size() else default_chars[i]})
	f.engine = GameEngine.create(config(), f.clock, seats, seed_value, "test")
	return f


var state: GameState:
	get: return engine.state


func cmd(seat: int, type: String, payload: Dictionary = {}, command_id: String = "") -> Dictionary:
	_n += 1
	var id := command_id if command_id != "" else "c%d" % _n
	return engine.submit(ErCommand.make("test", "p%d" % seat, id, state.state_version, type, payload))


func cash(seat: int) -> int:
	return state.player(seat)["cash"]


func set_cash(seat: int, amount: int) -> void:
	# Keep the money-conservation counter consistent with direct edits.
	state.bank_net_issued += amount - state.player(seat)["cash"]
	state.player(seat)["cash"] = amount


func give(seat: int, pids: Array, lvl: int = 0) -> void:
	for pid in pids:
		state.owner[pid] = seat
		state.level[pid] = lvl


func district(did: String) -> Array:
	return config().district_props[did]


## Puts `seat` on `index` as the current player and resolves that tile.
func land(seat: int, index: int) -> Array:
	state.current_seat = seat
	state.phase = GameState.AWAIT_ROLL
	state.player(seat)["position"] = index
	engine._resolve_landing(seat)
	return engine._commit()


## Makes `seat` the current player in StrategyAction.
func to_strategy(seat: int) -> void:
	state.current_seat = seat
	state.phase = GameState.STRATEGY
	state.strategy_used = false
	engine._commit()


func types(events: Array) -> Array:
	return events.map(func(e): return e["type"])


func expire() -> Array:
	clock.set_now(maxi(clock.now_ms(), engine.current_deadline_ms()))
	return engine.advance()


func invariants() -> Array[String]:
	return Invariants.check(engine)
