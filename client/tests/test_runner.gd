## Headless test runner. Discovers res://tests/**/test_*.gd, runs every
## method whose name starts with "test_", and exits with code 0 only when
## every test passes. No third-party test framework is used so the runner has
## no licensing or version coupling.
##
## Usage (from repo root): scripts/run_tests.sh
## Optional user arg `--only=<text>` runs just the files whose path contains it.
extends SceneTree

const TEST_ROOTS := ["res://tests/unit", "res://tests/integration"]

var _failures: Array[String] = []
var _passed := 0
var _discovered := 0
var _trap := ScriptErrorTrap.new()


func _initialize() -> void:
	OS.add_logger(_trap)
	var files: Array[String] = []
	for root in TEST_ROOTS:
		_collect(root, files)
	files.sort()
	var found := files.size()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			files = files.filter(func(p: String) -> bool: return p.contains(a.trim_prefix("--only=")))
	for path in files:
		_run_file(path)
	# Counts, not just "0 failed": a file that vanished or stopped compiling
	# shows up here. Skipped = files left out by --only.
	print("DISCOVERED: %d files, %d tests, %d files skipped" % [files.size(), _discovered, found - files.size()])
	print("RESULT: %d passed, %d failed" % [_passed, _failures.size()])
	for failure in _failures:
		printerr("FAIL: " + failure)
	quit(0 if _failures.is_empty() and _passed > 0 else 1)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			out.append(dir_path.path_join(file))


func _run_file(path: String) -> void:
	var script: GDScript = load(path)
	if script == null or not script.can_instantiate():
		_failures.append("%s: failed to load" % path)
		return
	var names: Array[String] = []
	for method in script.get_script_method_list():
		if String(method["name"]).begins_with("test_"):
			names.append(method["name"])
	if names.is_empty():
		_failures.append("%s: no test_ methods" % path)
	_discovered += names.size()
	for name in names:
		var suite: TestCase = script.new()
		_trap.take()
		suite.call(name)
		suite.errors.append_array(_trap.take())
		if suite.errors.is_empty():
			_passed += 1
			print("PASS: %s::%s" % [path.get_file(), name])
		else:
			for err in suite.errors:
				_failures.append("%s::%s - %s" % [path.get_file(), name, err])
