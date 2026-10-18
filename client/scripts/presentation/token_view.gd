## Player pawn: baked production model per seat (M2.3 kit).
class_name TokenView
extends Node3D

const HOP_TIME := 0.16
const HOP_HEIGHT := 0.28

var seat := 0
var _body: Node3D
## Seat-coloured ring on the ground (Phase 2, A3): from the high portrait
## camera a pawn is only ~13 px wide, the ring makes "whose pawn, where"
## readable and marks the active player.
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _pulse: Tween


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
	var torus := TorusMesh.new()
	torus.inner_radius = 0.118
	torus.outer_radius = 0.152
	torus.rings = 24
	torus.ring_segments = 4
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	_ring.mesh = torus
	_ring.scale = Vector3(1, 0.25, 1)
	_ring.position.y = 0.012
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = theme.player_color(seat)
	_ring.material_override = _ring_mat
	add_child(_ring)
	set_active(false)


## The active player's ring is opaque and slightly larger; with motion
## allowed it breathes gently. Others stay at 55% so they never compete.
func set_active(active: bool, animate := true) -> void:
	if _ring == null:
		return
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	_ring_mat.albedo_color.a = 1.0 if active else 0.55
	_ring.scale = Vector3(1.12, 0.25, 1.12) if active else Vector3(1, 0.25, 1)
	if active and animate:
		_pulse = create_tween().set_loops()
		_pulse.tween_property(_ring, "scale", Vector3(1.24, 0.25, 1.24), 0.7).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(_ring, "scale", Vector3(1.12, 0.25, 1.12), 0.7).set_trans(Tween.TRANS_SINE)


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
