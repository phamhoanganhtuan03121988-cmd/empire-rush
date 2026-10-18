## Compiles every script under res://scripts and res://tests and reports
## parse errors (GDScript only reports them when a script is loaded).
extends SceneTree


func _initialize() -> void:
	var files: Array[String] = []
	for root in ["res://scripts", "res://tests"]:
		_collect(root, files)
	var bad := 0
	for f in files:
		var s: GDScript = load(f)
		if s == null or not s.can_instantiate() and not f.ends_with("_runner.gd"):
			if s == null or s.reload() != OK:
				printerr("COMPILE FAIL: " + f)
				bad += 1
	print("CHECKED %d scripts, %d failed" % [files.size(), bad])
	quit(1 if bad > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
