## Two placeholder dice. roll_to(d1, d2) animates a tumble that always lands
## on the values decided by the rules engine (presentation never rolls).
class_name DiceView
extends Node3D

const PIPS := {
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
}
## Face value -> outward normal in die-local space (opposite faces sum to 7).
const FACE_NORMAL := {1: Vector3.UP, 6: Vector3.DOWN, 2: Vector3.BACK, 5: Vector3.FORWARD, 3: Vector3.RIGHT, 4: Vector3.LEFT}
const SIZE := 0.34

var _dice: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()  # tumble style only


func build(theme: ThemeData) -> void:
	_rng.randomize()
	for i in 2:
		var die := Node3D.new()
		# Cube + 21 pips merged into one mesh (was 22 draw calls per die).
		var mm := MeshMerger.new()
		mm.add_box(Vector3.ONE * SIZE, Vector3.ZERO, Color("#fbf8f1"), MeshMerger.std(0.4))
		var sm := SphereMesh.new()
		sm.radius = 0.032
		sm.height = 0.02
		sm.radial_segments = 8
		sm.rings = 3
		for v in PIPS:
			var n: Vector3 = FACE_NORMAL[v]
			var basis := _face_basis(n)
			for p in PIPS[v]:
				var pos: Vector3 = n * (SIZE * 0.5) + basis[0] * p.x * SIZE * 0.26 + basis[1] * p.y * SIZE * 0.26
				mm.add_mesh(sm, Transform3D(Basis(), pos), Color("#c0392b") if v == 1 else Color("#1d1d1f"), MeshMerger.std(0.5))
		die.add_child(mm.instance("Die"))
		die.visible = false
		add_child(die)
		_dice.append(die)


func _face_basis(n: Vector3) -> Array:
	var u := Vector3.RIGHT if absf(n.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK
	var a := n.cross(u).normalized()
	return [a, n.cross(a).normalized()]


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
