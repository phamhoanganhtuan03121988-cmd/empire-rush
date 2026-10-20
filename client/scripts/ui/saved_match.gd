## Web/PWA launch: the match in progress survives closing the page or app.
## Saved at the start of every turn and when the app goes to the background:
## the seed, seats and the engine's input log (MatchReplay record) plus the
## presentation identities (names, colours, portraits). Resuming replays the
## logged commands on a fresh engine, so the state is rebuilt by the rules
## themselves (and checked against the saved state hash); nothing is edited.
## Writes go to a temporary file first, then replace the save, so a crash or
## a killed tab never leaves a half-written save; a save that does not load
## or replay is discarded instead of blocking the game.
class_name SavedMatch
extends RefCounted

const FORMAT := 1
## Tests point this at a scratch file so they never touch a player's save.
static var path := "user://saved_match.json"
## Set by the title screen's TIẾP TỤC TRẬN; read once by main when the match starts.
static var pending: Dictionary = {}


static func exists() -> bool:
	return FileAccess.file_exists(path)


static func save(engine: GameEngine, identities: Array, human_seats: Array) -> bool:
	if engine == null or engine.is_ended():
		return false
	var rec := MatchReplay.record(engine)
	rec["save_format"] = FORMAT
	rec["identities"] = identities.duplicate(true)
	rec["human_seats"] = human_seats.duplicate()
	rec["round"] = engine.state.round
	rec["saved_unix"] = int(Time.get_unix_time_from_system())
	var tmp := path + ".tmp"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SavedMatch: cannot write %s (%d)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(rec))
	f.close()
	var d := DirAccess.open(path.get_base_dir())
	if d == null or d.rename(tmp.get_file(), path.get_file()) != OK:
		push_warning("SavedMatch: cannot replace %s" % path)
		return false
	return true


## The saved record, or {} when there is none or it is unreadable (then the
## broken file is removed so the title screen never offers a dead resume).
static func load_record() -> Dictionary:
	if not exists():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or int(parsed.get("save_format", 0)) != FORMAT or not parsed.has("input_log"):
		push_warning("SavedMatch: unreadable save discarded")
		clear()
		return {}
	return parsed


static func clear() -> void:
	if exists():
		DirAccess.remove_absolute(path)


## One line for the title screen: "Vòng 7 · 3 người · lưu lúc 21:05".
static func summary(rec: Dictionary) -> String:
	var when := ""
	if rec.has("saved_unix"):
		var t := Time.get_datetime_dict_from_unix_time(int(rec["saved_unix"]) + Time.get_time_zone_from_system().get("bias", 0) * 60)
		when = " · lưu lúc %02d:%02d %02d/%02d" % [t["hour"], t["minute"], t["day"], t["month"]]
	return "Vòng %d · %d người%s" % [int(rec.get("round", 1)), rec.get("seats", []).size(), when]
