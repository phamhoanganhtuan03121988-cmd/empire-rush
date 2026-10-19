## Phase 5: game audio. Two buses under Master - "Music" and "SFX" - with
## their own volume and one mute switch (GameSettings). Sounds are the
## project's own synthesised assets (scripts/audio/gen_audio.py, CC0).
## Effects are triggered by EventPresenter.cue (the moment a beat is SHOWN),
## UI clicks/hovers by the HUD and menus. Overlap control: a pool of players,
## a minimum gap per sound and a cap on simultaneous copies, so a burst of
## events never stacks into noise.
class_name AudioDirector
extends Node

const SFX_DIR := "res://assets/audio/sfx/%s.wav"
const MUSIC := "res://assets/audio/music/theme_loop.ogg"
const POOL := 8
## Per sound: [volume dB, min gap s, max simultaneous].
const SPEC := {
	"ui_hover": [-16.0, 0.05, 1], "ui_click": [-6.0, 0.04, 2], "ui_confirm": [-4.0, 0.1, 1], "ui_back": [-6.0, 0.1, 1],
	"dice_roll": [-3.0, 0.3, 1], "dice_land": [-2.0, 0.1, 1], "step": [-10.0, 0.06, 2],
	"buy": [-3.0, 0.2, 1], "upgrade": [-2.0, 0.2, 1], "cash_gain": [-8.0, 0.15, 1], "cash_loss": [-8.0, 0.15, 1],
	"card": [-4.0, 0.2, 1], "choice": [-6.0, 0.3, 1], "auction": [-3.0, 0.3, 1], "bid": [-6.0, 0.1, 2],
	"rescue": [-4.0, 0.5, 1], "bankrupt": [-3.0, 0.5, 1], "your_turn": [-8.0, 0.5, 1], "win": [-2.0, 1.0, 1], "lose": [-3.0, 1.0, 1],
}
## Presenter cue -> sound.
const CUE_SOUND := {
	"dice_roll": "dice_roll", "dice_land": "dice_land", "step": "step", "buy": "buy", "upgrade": "upgrade",
	"cash_gain": "cash_gain", "cash_loss": "cash_loss", "card": "card", "choice": "choice", "auction": "auction",
	"bid": "bid", "rescue": "rescue", "bankrupt": "bankrupt", "your_turn": "your_turn", "win": "win", "lose": "lose",
}

## The live director (menus and HUD reach it without a node path).
static var instance: AudioDirector

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _streams: Dictionary = {}
var _last_play: Dictionary = {}   # sound -> msec
var _next := 0
## Every sound actually started, newest last (tests / diagnostics).
var played: Array[String] = []


static func ensure_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")


func _ready() -> void:
	instance = self
	ensure_buses()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	var m: AudioStream = load(MUSIC)
	if m is AudioStreamOggVorbis:
		(m as AudioStreamOggVorbis).loop = true
	_music.stream = m
	_music.volume_db = -8.0
	add_child(_music)
	apply_settings()


func _exit_tree() -> void:
	if instance == self:
		instance = null


## Volumes and mute from GameSettings onto the buses. Mute silences both
## buses at the bus level (nothing reaches the output), not just the players.
func apply_settings() -> void:
	_set_bus("Music", GameSettings.music_volume, GameSettings.muted)
	_set_bus("SFX", GameSettings.sfx_volume, GameSettings.muted)


static func _set_bus(name: String, linear: float, muted: bool) -> void:
	var i := AudioServer.get_bus_index(name)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, muted or linear <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))


func play_music() -> void:
	if _music.stream and not _music.playing:
		_music.play()


func play(name: String, pitch_jitter := 0.0) -> bool:
	if not SPEC.has(name):
		return false
	var spec: Array = SPEC[name]
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(name, -100000)) < int(spec[1] * 1000.0):
		return false
	var live := 0
	for p in _players:
		if p.playing and p.get_meta("sound", "") == name:
			live += 1
	if live >= int(spec[2]):
		return false
	if not _streams.has(name):
		_streams[name] = load(SFX_DIR % name)
	# Round-robin over the pool; a busy player is cut only when all are busy.
	var p: AudioStreamPlayer = null
	for k in POOL:
		var cand := _players[(_next + k) % POOL]
		if not cand.playing:
			p = cand
			_next = (_next + k + 1) % POOL
			break
	if p == null:
		p = _players[_next]
		_next = (_next + 1) % POOL
	p.stream = _streams[name]
	p.volume_db = spec[0]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.set_meta("sound", name)
	p.play()
	_last_play[name] = now
	played.append(name)
	if played.size() > 200:
		played = played.slice(100)
	return true


func on_cue(cue_name: String, _data: Dictionary) -> void:
	if CUE_SOUND.has(cue_name):
		play(CUE_SOUND[cue_name], 0.06 if cue_name == "step" else 0.0)


## UI sounds from anywhere (menus, HUD). Safe when no director exists.
static func ui(name: String) -> void:
	if instance:
		instance.play(name)


## Wires a button: click on press, a soft tick on hover (desktop).
static func wire(b: BaseButton, sound := "ui_click") -> void:
	b.pressed.connect(func(): ui(sound))
	b.mouse_entered.connect(func():
		if not b.disabled:
			ui("ui_hover"))
