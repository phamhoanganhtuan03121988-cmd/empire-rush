## Player pawn: baked production model per seat (M2.3 kit).
class_name TokenView
extends Node3D

const HOP_TIME := 0.16
const HOP_HEIGHT := 0.28
## Phase 5: pawns read from the overview camera (they were ~13 px wide).
const PAWN_SCALE := 1.35

var seat := 0
var _body: Node3D
## Seat-coloured ring on the ground (Phase 2, A3): from the high portrait
## camera a pawn is only ~13 px wide, the ring makes "whose pawn, where"
## readable and marks the active player.
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _pulse: Tween
## Phase 5.1: the persona portrait floating over the pawn (billboard, drawn
## over the city so a tower never hides who is who). Cosmetic only.
var medallion: Sprite3D


func build(p_seat: int, theme: ThemeData) -> void:
	seat = p_seat
	_body = Node3D.new()
	add_child(_body)
	# Baked pawn (assets/models/tokens): turned base + a head shape unique to
	# the seat (crown, top hat, rook, gem) in the seat colour.
	var mi := MeshInstance3D.new()
	mi.name = "Pawn"
	# The baked pawn of the seat's COLOUR (Phase 5 colour choice; default = seat).
	var pawn: int = int(theme.players[seat % theme.players.size()].get("pawn", seat % 4))
	mi.mesh = load("res://assets/models/tokens/pawn_%d.res" % (pawn % 4))
	_body.add_child(mi)
	_body.scale = Vector3.ONE * PAWN_SCALE
	var torus := TorusMesh.new()
	torus.inner_radius = 0.13
	torus.outer_radius = 0.19
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
	var face := theme.player_portrait(seat)
	if face:
		medallion = Sprite3D.new()
		medallion.name = "Medallion"
		medallion.texture = face
		medallion.pixel_size = 0.30 / face.get_width()
		medallion.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		medallion.shaded = false
		medallion.no_depth_test = true
		medallion.render_priority = 4
		medallion.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		medallion.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		medallion.position = Vector3(0, 1.08, 0)
		medallion.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(medallion)
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
	if medallion:
		medallion.modulate.a = 1.0 if active else 0.8
		medallion.scale = Vector3.ONE * (1.3 if active else 1.0)
	_ring.scale = Vector3(1.12, 0.25, 1.12) if active else Vector3(1, 0.25, 1)
	if active and animate:
		_pulse = create_tween().set_loops()
		_pulse.tween_property(_ring, "scale", Vector3(1.24, 0.25, 1.24), 0.7).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(_ring, "scale", Vector3(1.12, 0.25, 1.12), 0.7).set_trans(Tween.TRANS_SINE)


## Hops tile by tile through `points` (world positions). Awaitable.
## `on_hop` (optional) is called each time the pawn lands on a tile (step sound).
func hop_along(points: Array, step_time := HOP_TIME, on_hop := Callable()) -> void:
	for p in points:
		var start := position
		var t := create_tween()
		t.tween_method(func(k: float):
			position = start.lerp(p, k) + Vector3(0, sin(k * PI) * HOP_HEIGHT, 0), 0.0, 1.0, step_time)
		await t.finished
		if on_hop.is_valid():
			on_hop.call()
	var squash := create_tween()
	squash.tween_property(_body, "scale", Vector3(1.15, 0.85, 1.15) * PAWN_SCALE, 0.06)
	squash.tween_property(_body, "scale", Vector3.ONE * PAWN_SCALE, 0.1)
	await squash.finished


func fade_out() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
	await t.finished
	visible = false
