## Player pawn (placeholder: base disc + body + head in the player colour).
class_name TokenView
extends Node3D

const HOP_TIME := 0.16
const HOP_HEIGHT := 0.28

var seat := 0
var _body: Node3D


func build(p_seat: int, theme: ThemeData) -> void:
	seat = p_seat
	var c := theme.player_color(seat)
	_body = Node3D.new()
	add_child(_body)
	# Base + body + head merged into one mesh (one draw call per pawn).
	var mm := MeshMerger.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.13
	bm.bottom_radius = 0.15
	bm.height = 0.05
	bm.radial_segments = 20
	bm.rings = 1
	mm.add_mesh(bm, Transform3D(Basis(), Vector3(0, 0.025, 0)), c.darkened(0.25), MeshMerger.std(0.4, 0.4))
	var cm := CapsuleMesh.new()
	cm.radius = 0.08
	cm.height = 0.3
	cm.radial_segments = 16
	cm.rings = 4
	mm.add_mesh(cm, Transform3D(Basis(), Vector3(0, 0.2, 0)), c, MeshMerger.std(0.4, 0.4))
	var sm := SphereMesh.new()
	sm.radius = 0.075
	sm.height = 0.15
	sm.radial_segments = 16
	sm.rings = 8
	mm.add_mesh(sm, Transform3D(Basis(), Vector3(0, 0.41, 0)), Color("#ffe0bd"), MeshMerger.std(0.6))
	_body.add_child(mm.instance("Pawn"))


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
