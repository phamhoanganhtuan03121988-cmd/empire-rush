## Architecture guard: presentation/UI code must not mutate rules state or
## bypass LocalMatch.submit(). Scans the source so a regression fails CI.
extends TestCase

const DIRS := ["res://scripts/ui", "res://scripts/presentation"]
var _assign := RegEx.create_from_string("\\bstate\\.[A-Za-z_\\[\\]\"0-9.()]*\\s*(=|\\+=|-=)[^=]")
var _engine_submit := RegEx.create_from_string("engine\\.submit\\(|\\._(transfer|resolve_landing|commit|charge|end_turn)\\(")


func _files() -> Array[String]:
	var out: Array[String] = []
	for d in DIRS:
		var dir := DirAccess.open(d)
		for f in dir.get_files():
			if f.ends_with(".gd"):
				out.append(d.path_join(f))
	return out


func test_ui_and_presentation_never_write_rules_state() -> void:
	for path in _files():
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line := lines[i].strip_edges()
			if line.begins_with("#"):
				continue
			if _assign.search(line) != null:
				errors.append("%s:%d writes rules state: %s" % [path, i + 1, line])


func test_only_local_match_submits_to_the_engine() -> void:
	for path in _files():
		if path.ends_with("local_match.gd"):
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			if _engine_submit.search(lines[i]) != null:
				errors.append("%s:%d bypasses LocalMatch.submit(): %s" % [path, i + 1, lines[i].strip_edges()])
	assert_true(_files().size() >= 10, "scanned the presentation/UI scripts")
