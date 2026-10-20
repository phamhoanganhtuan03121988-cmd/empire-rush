## Catches runtime SCRIPT ERRORs (bad key, null access, type errors...) so a
## test that crashes half-way FAILS instead of passing with its remaining
## asserts silently skipped (Phase 3: found when a test died on a missing
## dictionary key and was still reported as PASS).
class_name ScriptErrorTrap
extends Logger

var errors: Array[String] = []
var _mutex := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
		error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	_mutex.lock()
	errors.append("runtime script error: %s %s (%s:%d %s)" % [code, rationale, file.get_file(), line, function])
	_mutex.unlock()


func take() -> Array[String]:
	_mutex.lock()
	var out := errors.duplicate()
	errors.clear()
	_mutex.unlock()
	return out
