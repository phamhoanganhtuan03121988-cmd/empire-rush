## MatchClock driven by frame time. Game time follows Engine.time_scale and the
## movie writer, so recorded videos and fast-forwarded tests stay consistent.
## Rules still only see now_ms(); this class just advances it.
class_name FrameClock
extends MatchClock


func tick(delta_seconds: float) -> void:
	advance(int(round(delta_seconds * 1000.0)))
