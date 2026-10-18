## Records real (game-clock) timings of a session: per-turn duration split
## into presentation (animation) time and decision time, per seat type.
## Written as JSON so playtests produce comparable measurements.
## Distinguish clearly: these are MEASURED values from a running build.
class_name SessionTelemetry
extends Node

var source := "unknown"  # "human", "autopilot" ...
var turns: Array = []
var _turn: Dictionary = {}
var _presenting_since := -1.0
var _t := 0.0
var _start_wall := 0
var _frames := 0
var _max_delta := 0.0


func _ready() -> void:
	_start_wall = Time.get_ticks_msec()


func _process(delta: float) -> void:
	_t += delta
	_frames += 1
	_max_delta = maxf(_max_delta, delta)


func now() -> float:
	return _t


func on_turn_started(seat: int, round: int, human: bool) -> void:
	_close_turn()
	_turn = {"seat": seat, "round": round, "human": human, "start": _t, "presentation_s": 0.0}


func on_presentation(busy: bool) -> void:
	if busy and _presenting_since < 0.0:
		_presenting_since = _t
	elif not busy and _presenting_since >= 0.0:
		if not _turn.is_empty():
			_turn["presentation_s"] += _t - _presenting_since
		_presenting_since = -1.0


func _close_turn() -> void:
	if _turn.is_empty():
		return
	_turn["duration_s"] = _t - _turn["start"]
	_turn["decision_and_wait_s"] = _turn["duration_s"] - _turn["presentation_s"]
	turns.append(_turn)
	_turn = {}


func summary(match_end_reason: String, n_players: int) -> Dictionary:
	_close_turn()
	var by := {"human": [], "bot": []}
	var pres: Array = []
	for t in turns:
		by["human" if t["human"] else "bot"].append(t["duration_s"])
		pres.append(t["presentation_s"])
	return {
		"source": source, "players": n_players, "end_reason": match_end_reason,
		"session_game_seconds": snappedf(_t, 0.1),
		"session_wall_seconds": snappedf((Time.get_ticks_msec() - _start_wall) / 1000.0, 0.1),
		"engine_time_scale": Engine.time_scale,
		# Measurement resolution: animations shorter than one frame of game
		# time are stretched, so a valid timing run needs a small frame delta.
		"frames": _frames, "mean_frame_game_s": snappedf(_t / maxi(1, _frames), 0.0001),
		"max_frame_game_s": snappedf(_max_delta, 0.0001),
		"turns": turns.size(),
		"mean_turn_s": {"human": _mean(by["human"]), "bot": _mean(by["bot"])},
		"mean_presentation_s_per_turn": _mean(pres),
		"turn_log": turns,
	}


func save(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


static func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return snappedf(s / a.size(), 0.01)
