## Two dice (baked production model). roll_to(d1, d2) animates a throw that
## always lands on the values decided by the rules engine (presentation never
## rolls). Phase 5.1: the dice live in the DiceStage's own 3D world (no board
## object can cover them); the throw has weight (fall, two bounces, settle)
## and can be skipped: skip() jumps to the same final faces.
class_name DiceView
extends Node3D

## A bounce of the dice on the tray (sound sync): index 0, 1, 2 (last = settle).
signal bounced(index: int)

## Face value -> outward normal in die-local space (opposite faces sum to 7).
const FACE_NORMAL := {1: Vector3.UP, 6: Vector3.DOWN, 2: Vector3.BACK, 5: Vector3.FORWARD, 3: Vector3.RIGHT, 4: Vector3.LEFT}
const SIZE := 0.34
## Normalised times of the impacts on the tray (fall, bounce 1, bounce 2 = rest).
const IMPACTS := [0.4, 0.68, 0.86]

var _dice: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()  # tumble style only, never the values
var _anim := {}   # running throw: t, duration, per-die start/target/spin/basis
var _impacts_done := 0

signal _finished


func build(_theme: ThemeData = null) -> void:
	_rng.randomize()
	# Baked rounded die with recessed pips (assets/models/dice/die.res); its
	# faces follow FACE_NORMAL, which top_value() relies on.
	var mesh: Mesh = load("res://assets/models/dice/die.res")
	for i in 2:
		var die := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.name = "Die"
		mi.mesh = mesh
		die.add_child(mi)
		die.visible = false
		add_child(die)
		_dice.append(die)


## Rotation that brings face `value` to the top, with a small random yaw.
func _landing_basis(value: int) -> Basis:
	var n: Vector3 = FACE_NORMAL[value]
	var to_up := Quaternion(n, Vector3.UP) if n != Vector3.DOWN else Quaternion(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, _rng.randf_range(-0.35, 0.35)) * to_up)


func _target(i: int, center: Vector3) -> Vector3:
	return center + Vector3(-0.26 + i * 0.52, SIZE * 0.5, 0.06 * (i * 2 - 1))


## Throw both dice onto `center`; resolves when they rest on (d1, d2).
func roll_to(d1: int, d2: int, center: Vector3, duration := 0.85) -> void:
	_impacts_done = 0
	var dice := []
	for i in 2:
		var target := _target(i, center)
		dice.append({"start": target + Vector3(-1.1 + i * 0.25, 1.9, 1.2), "target": target,
			"spin": Vector3(_rng.randf_range(7, 11), _rng.randf_range(4, 9), _rng.randf_range(7, 11)) * (1 if i == 0 else -1),
			"basis": _landing_basis([d1, d2][i]), "delay": 0.05 * i})
		_dice[i].visible = true
	_anim = {"t": 0.0, "duration": maxf(duration, 0.001), "dice": dice}
	_apply(0.0)
	await _finished


## Jump to the final faces now (tap / key / reduced motion).
func skip() -> void:
	if not _anim.is_empty():
		_anim["t"] = _anim["duration"] * 2.0
		_anim["skipped"] = true


func is_rolling() -> bool:
	return not _anim.is_empty()


## Dice already resting on their values (reduced motion: no throw).
func place(d1: int, d2: int, center: Vector3) -> void:
	_anim = {}
	for i in 2:
		_dice[i].visible = true
		_dice[i].position = _target(i, center)
		_dice[i].basis = _landing_basis([d1, d2][i])


func _process(delta: float) -> void:
	if _anim.is_empty():
		return
	_anim["t"] += delta
	var k: float = _anim["t"] / _anim["duration"]
	_apply(k)
	while _impacts_done < IMPACTS.size() and k >= IMPACTS[_impacts_done]:
		# A skipped throw lands once (no burst of bounce sounds).
		if not _anim.get("skipped", false) or _impacts_done == IMPACTS.size() - 1:
			bounced.emit(_impacts_done)
		_impacts_done += 1
	if k >= 1.0 + 0.05:
		_anim = {}
		_finished.emit()


## Height of a thrown die over the tray at normalised time u (0..1):
## a fall, then two decaying bounces, then rest.
static func _height(u: float) -> float:
	var a: float = IMPACTS[0]
	var b: float = IMPACTS[1]
	var c: float = IMPACTS[2]
	if u < a:
		var f := u / a
		return 1.9 * (1.0 - f * f)
	if u < b:
		var f := (u - a) / (b - a)
		return 0.42 * 4.0 * f * (1.0 - f)
	if u < c:
		var f := (u - b) / (c - b)
		return 0.12 * 4.0 * f * (1.0 - f)
	return 0.0


func _apply(k: float) -> void:
	for i in 2:
		var d: Dictionary = _anim["dice"][i]
		var u := clampf((k - d["delay"]) / (1.0 - d["delay"]), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - u, 2.2)
		var flat: Vector3 = d["start"].lerp(d["target"], e)
		var die := _dice[i]
		die.position = Vector3(flat.x, d["target"].y + _height(u), flat.z)
		var left := pow(1.0 - u, 1.6)
		die.basis = Basis.from_euler(d["spin"] * left) * d["basis"]


func hide_dice() -> void:
	for d in _dice:
		d.visible = false


## Value whose face currently points up (used by tests to prove the visual
## result matches the rules result).
func top_value(i: int) -> int:
	var best := 1
	var best_dot := -2.0
	for v in FACE_NORMAL:
		var n: Vector3 = FACE_NORMAL[v]
		var d: float = (_dice[i].basis * n).dot(Vector3.UP)
		if d > best_dot:
			best_dot = d
			best = v
	return best
