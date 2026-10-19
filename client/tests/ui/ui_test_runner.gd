## Runs res://tests/ui/test_*.gd. Tests are coroutines (they await frames),
## so this runner awaits each one. Exit code 0 only if all pass.
extends SceneTree

var _failures: Array[String] = []
var _passed := 0
var _discovered := 0
var _trap := ScriptErrorTrap.new()


func _initialize() -> void:
	OS.add_logger(_trap)
	_run.call_deferred()


func _run() -> void:
	var player_files := _player_telemetry()
	var dir := DirAccess.open("res://tests/ui")
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append("res://tests/ui/" + f)
	files.sort()
	for path in files:
		var script: GDScript = load(path)
		# A file that does not compile must fail the run, not vanish from it
		# (Phase 4: a parse error silently skipped a whole test file).
		if script == null or not script.can_instantiate():
			_failures.append("%s: failed to load / compile" % path)
			continue
		var names: Array[String] = []
		for m in script.get_script_method_list():
			if String(m["name"]).begins_with("test_"):
				names.append(m["name"])
		if names.is_empty():
			_failures.append("%s: no test_ methods" % path)
		_discovered += names.size()
		for name in names:
			var suite: UiTestCase = script.new()
			suite.tree = self
			_trap.take()
			await suite.call(name)
			await suite.stop_game()
			suite.errors.append_array(_trap.take())
			if suite.errors.is_empty():
				_passed += 1
				print("PASS: %s::%s" % [path.get_file(), name])
			else:
				for e in suite.errors:
					_failures.append("%s::%s - %s" % [path.get_file(), name, e])
	# Regression (Phase 4): test matches wrote 45 non-replayable records into
	# the folder testers collect. They must go to user://test_telemetry.
	var leaked := _player_telemetry().filter(func(f: String) -> bool: return not f in player_files)
	if not leaked.is_empty():
		_failures.append("UI tests wrote into user://telemetry: %s" % [leaked])
	print("UI DISCOVERED: %d files, %d tests, 0 files skipped" % [files.size(), _discovered])
	print("UI RESULT: %d passed, %d failed" % [_passed, _failures.size()])
	for f in _failures:
		printerr("FAIL: " + f)
	quit(0 if _failures.is_empty() and _passed > 0 else 1)


func _player_telemetry() -> Array:
	var d := DirAccess.open("user://telemetry")
	return Array(d.get_files()) if d != null else []
