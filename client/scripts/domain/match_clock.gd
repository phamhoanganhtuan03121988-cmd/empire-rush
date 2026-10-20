## Injectable match clock. Rules read time only through this object so
## simulations and tests control time exactly; the live server will subclass
## it with a wall-clock implementation.
class_name MatchClock
extends RefCounted

var _now_ms := 0


func _init(start_ms: int = 0) -> void:
	_now_ms = start_ms


func now_ms() -> int:
	return _now_ms


func advance(ms: int) -> void:
	assert(ms >= 0)
	_now_ms += ms


func set_now(ms: int) -> void:
	assert(ms >= _now_ms, "clock cannot go backwards")
	_now_ms = ms
