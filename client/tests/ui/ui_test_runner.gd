## Runs res://tests/ui/test_*.gd. Tests are coroutines (they await frames),
## so this runner awaits each one. Exit code 0 only if all pass.
extends SceneTree

var _failures: Array[String] = []
var _passed := 0
var _trap := ScriptErrorTrap.new()


func _initialize() -> void:
	OS.add_logger(_trap)
	_run.call_deferred()


func _run() -> void:
	var dir := DirAccess.open("res://tests/ui")
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append("res://tests/ui/" + f)
	files.sort()
	for path in files:
		var script: GDScript = load(path)
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
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
	print("UI RESULT: %d passed, %d failed" % [_passed, _failures.size()])
	for f in _failures:
		printerr("FAIL: " + f)
	quit(0 if _failures.is_empty() and _passed > 0 else 1)
