## Phase 5: player settings that survive a restart (ConfigFile in user://):
## graphics preset, reduced motion, music / effects volume, mute, whether the
## intro was seen, and the last setup choices. Presentation only - nothing
## here reaches the rules engine, and no file is telemetry (Public builds
## write this file too, like any game's options).
class_name GameSettings
extends RefCounted

## Tests point this at a scratch file so they never touch a player's settings.
static var path := "user://settings.cfg"

static var music_volume := 0.6
static var sfx_volume := 0.8
static var muted := false
static var intro_seen := false
static var loaded := false



static func load_settings() -> void:
	var cf := ConfigFile.new()
	loaded = true
	if cf.load(path) != OK:
		return
	# Graphics preset and reduced motion live in MatchSetup (used by main).
	var q := str(cf.get_value("video", "quality", MatchSetup.quality))
	MatchSetup.quality = q if q in QualitySettings.ORDER else "medium"
	MatchSetup.reduced_motion = bool(cf.get_value("video", "reduced_motion", MatchSetup.reduced_motion))
	music_volume = clampf(float(cf.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cf.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	muted = bool(cf.get_value("audio", "muted", muted))
	intro_seen = bool(cf.get_value("flow", "intro_seen", intro_seen))
	MatchSetup.players = clampi(int(cf.get_value("setup", "players", MatchSetup.players)), 2, 4)
	var ch := str(cf.get_value("setup", "character", MatchSetup.character))
	if ch in MatchSetup.CHARACTER_CYCLE:
		MatchSetup.character = ch
	MatchSetup.color_index = clampi(int(cf.get_value("setup", "color", MatchSetup.color_index)), 0, 3)
	MatchSetup.player_name = str(cf.get_value("setup", "name", MatchSetup.player_name)).left(MatchSetup.NAME_MAX)
	MatchSetup.persona = str(cf.get_value("setup", "persona", MatchSetup.persona))


static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("video", "quality", MatchSetup.quality)
	cf.set_value("video", "reduced_motion", MatchSetup.reduced_motion)
	cf.set_value("audio", "music", music_volume)
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("audio", "muted", muted)
	cf.set_value("flow", "intro_seen", intro_seen)
	cf.set_value("setup", "players", MatchSetup.players)
	cf.set_value("setup", "character", MatchSetup.character)
	cf.set_value("setup", "color", MatchSetup.color_index)
	cf.set_value("setup", "name", MatchSetup.player_name)
	cf.set_value("setup", "persona", MatchSetup.persona)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	cf.save(path)
