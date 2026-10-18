## Player pawn: baked production model per seat (M2.3 kit).
class_name TokenView
extends Node3D

const HOP_TIME := 0.16
const HOP_HEIGHT := 0.28

var seat := 0
var _body: Node3D


func build(p_seat: int, theme: ThemeData) -> void:
	seat = p_seat
	_body = Node3D.new()
	add_child(_body)
	# Baked pawn (assets/models/tokens): turned base + a head shape unique to
	# the seat (crown, top hat, rook, gem) in the seat colour.
	var mi := MeshInstance3D.new()
	mi.name = "Pawn"
	mi.mesh = load("res://assets/models/tokens/pawn_%d.res" % (seat % 4))
	_body.add_child(mi)


## Hops tile by tile through `points` (world positions). Awaitable.
func hop_along(points: Array, step_time := HOP_TIME) -> void:
	for p in points:
		var start := position
		var t := create_tween()
		t.tween_method(func(k: float):
			position = start.lerp(p, k) + Vector3(0, sin(k * PI) * HOP_HEIGHT, 0), 0.0, 1.0, step_time)
		await t.finished
	var squash := create_tween()
	squash.tween_property(_body, "scale", Vector3(1.15, 0.85, 1.15), 0.06)
	squash.tween_property(_body, "scale", Vector3.ONE, 0.1)
	await squash.finished


func fade_out() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
	await t.finished
	visible = false
