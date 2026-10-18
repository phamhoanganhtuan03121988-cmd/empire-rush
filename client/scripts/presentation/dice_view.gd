## Two dice (baked production model). roll_to(d1, d2) animates a tumble that always lands
## on the values decided by the rules engine (presentation never rolls).
class_name DiceView
extends Node3D

## Face value -> outward normal in die-local space (opposite faces sum to 7).
const FACE_NORMAL := {1: Vector3.UP, 6: Vector3.DOWN, 2: Vector3.BACK, 5: Vector3.FORWARD, 3: Vector3.RIGHT, 4: Vector3.LEFT}
const SIZE := 0.34

var _dice: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()  # tumble style only


func build(theme: ThemeData) -> void:
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


## Rotation that brings face `value` to the top, with a random yaw.
func _landing_basis(value: int) -> Basis:
	var n: Vector3 = FACE_NORMAL[value]
	var to_up := Quaternion(n, Vector3.UP) if n != Vector3.DOWN else Quaternion(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, _rng.randf_range(-0.6, 0.6)) * to_up)


func roll_to(d1: int, d2: int, center: Vector3, duration := 0.9) -> void:
	var vals := [d1, d2]
	var tweens: Array = []
	for i in 2:
		var die := _dice[i]
		die.visible = true
		var target := center + Vector3(-0.28 + i * 0.56, SIZE * 0.5, 0.1 * (i * 2 - 1))
		var start := target + Vector3(_rng.randf_range(-0.8, 0.8), 1.6, 1.2)
		die.position = start
		var spin := Vector3(_rng.randf_range(6, 12), _rng.randf_range(6, 12), _rng.randf_range(6, 12))
		var final_basis := _landing_basis(vals[i])
		var t := create_tween()
		t.tween_method(func(k: float):
			var e := 1.0 - pow(1.0 - k, 3.0)
			die.position = start.lerp(target, e) + Vector3(0, absf(sin(e * PI * 2.0)) * (1.0 - e) * 0.6, 0)
			var spin_basis := Basis.from_euler(spin * (1.0 - e))
			die.basis = spin_basis * final_basis, 0.0, 1.0, duration)
		tweens.append(t)
	await tweens[1].finished


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
