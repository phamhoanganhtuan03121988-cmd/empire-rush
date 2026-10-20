## Short one-shot effects for game moments (M2.3). Presentation only and
## always skippable: with reduced motion they are not spawned at all.
## Particles are CPUParticles3D (works on the Mobile renderer and on GLES
## fallbacks) with a small unshaded additive quad.
class_name Vfx
extends RefCounted

static var _spark_mat: StandardMaterial3D
static var _dust_mat: StandardMaterial3D


static func _mat(additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = load("res://assets/textures/contact_shadow.png") if not additive else null
	return m


static func _particles(parent: Node, pos: Vector3, mat: Material, amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	q.material = mat
	p.mesh = q
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.emitting = true
	# Free once finished (lifetime + margin), independent of game state.
	p.get_tree().create_timer(life + 0.3, false).timeout.connect(p.queue_free)
	return p


## Sparkle burst in a colour (purchase, auction win, upgrade).
static func burst(parent: Node, pos: Vector3, color: Color, amount := 24) -> void:
	if _spark_mat == null:
		_spark_mat = _mat(true)
	var p := _particles(parent, pos, _spark_mat, amount, 0.8)
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -3.5, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var g := Gradient.new()
	g.set_color(0, color.lightened(0.4))
	g.set_color(1, Color(color, 0.0))
	p.color_ramp = g


## Low dust ring (construction, bankruptcy).
static func dust(parent: Node, pos: Vector3, color := Color(0.85, 0.82, 0.76), amount := 18) -> void:
	if _dust_mat == null:
		_dust_mat = _mat(false)
	var p := _particles(parent, pos, _dust_mat, amount, 0.9)
	p.direction = Vector3(1, 0.2, 0)
	p.spread = 180.0
	p.flatness = 0.85
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, 0.15, 0)
	p.damping_min = 0.6
	p.damping_max = 1.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	var g := Gradient.new()
	g.set_color(0, Color(color, 0.55))
	g.set_color(1, Color(color, 0.0))
	p.color_ramp = g
