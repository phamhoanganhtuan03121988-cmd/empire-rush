## Offline-mode app lifecycle gate (M2.2.1). Decides how much of a frame's
## delta may reach the offline match clock:
## - while the app is backgrounded / suspended (any pause reason held), none;
## - on the first frame after the last reason is released, at most the real
##   time that has passed since the release, because the OS may deliver that
##   frame with the whole suspension folded into its delta (and the resume
##   notification and that frame can come in either order);
## - otherwise the full delta (an app that stays in the foreground is
##   unaffected).
## Rules never see this class: it only filters what LocalMatch feeds into the
## injected MatchClock, so the domain's deadlines simply do not move while the
## app is away. Online play (M3) does NOT use it: server timers keep running.
class_name LifecycleGate
extends RefCounted

## Monotonic real-time source in microseconds. Tests inject a fake.
var wall_us: Callable = Time.get_ticks_usec
## Number of times the gate went from running to paused (diagnostics/tests).
var pause_count := 0
## Seconds of frame delta withheld from the clock so far (diagnostics/tests).
var withheld_s := 0.0

var _reasons: Dictionary = {}
var _resumed_at_us := -1


## Feed Node._notification() here. Losing focus pauses only when asked to
## (phones: Control Center, call banner, app switcher); a real OS suspend
## (NOTIFICATION_APPLICATION_PAUSED, mobile only) always pauses.
func on_notification(what: int, pause_on_focus_loss: bool) -> void:
	match what:
		Node.NOTIFICATION_APPLICATION_PAUSED:
			pause("suspended")
		Node.NOTIFICATION_APPLICATION_RESUMED:
			resume("suspended")
		Node.NOTIFICATION_APPLICATION_FOCUS_OUT:
			if pause_on_focus_loss:
				pause("focus")
		Node.NOTIFICATION_APPLICATION_FOCUS_IN:
			resume("focus")


func pause(reason: String) -> void:
	if _reasons.is_empty():
		pause_count += 1
	_reasons[reason] = true
	_resumed_at_us = -1


func resume(reason: String) -> void:
	if not _reasons.has(reason):
		return
	_reasons.erase(reason)
	if _reasons.is_empty():
		_resumed_at_us = wall_us.call()


func is_paused() -> bool:
	return not _reasons.is_empty()


## Returns the part of `delta` (seconds, already time-scaled) that counts as
## foreground game time. `time_scale` converts real seconds to game seconds.
func filter(delta: float, time_scale: float = 1.0) -> float:
	if is_paused():
		withheld_s += delta
		return 0.0
	if _resumed_at_us >= 0:
		var real_s := maxf(0.0, (wall_us.call() - _resumed_at_us) / 1000000.0)
		_resumed_at_us = -1
		var credited := minf(delta, real_s * time_scale)
		withheld_s += delta - credited
		return credited
	return delta
