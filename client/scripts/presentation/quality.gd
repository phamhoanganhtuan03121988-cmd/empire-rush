## Low / medium / high presets (shadows, MSAA, glow, render scale, and on Low
## no triplanar detail/normal maps).
class_name QualitySettings
extends RefCounted

const ORDER := ["low", "medium", "high"]


## Kit materials whose triplanar detail/normal maps the Low preset turns off
## (three texture fetches per map per pixel is the main extra fill cost of the
## M2.3 kit on slow GPUs). Vertex colours keep every surface's hue.
const DETAIL_MATERIALS := ["plaster", "concrete", "paving", "stone_wall", "asphalt", "grass", "roof_tile",
	"wood", "foliage", "marble"]

static var _detail_saved: Dictionary = {}


static func set_material_detail(full: bool) -> void:
	for n in DETAIL_MATERIALS:
		var path := "res://assets/materials/%s.tres" % n
		if not ResourceLoader.exists(path):
			continue
		var m := load(path) as StandardMaterial3D
		if m == null:
			continue
		if not _detail_saved.has(n):
			_detail_saved[n] = [m.albedo_texture, m.normal_texture, m.normal_enabled, m.uv1_triplanar]
		var d: Array = _detail_saved[n]
		m.albedo_texture = d[0] if full else null
		m.normal_texture = d[1] if full else null
		m.normal_enabled = d[2] if full else false
		m.uv1_triplanar = d[3] if full else false


static func apply(name: String, viewport: Viewport, sun: DirectionalLight3D, env: Environment) -> void:
	set_material_detail(name != "low")
	match name:
		"low":
			sun.shadow_enabled = false
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.scaling_3d_scale = 0.75
			env.glow_enabled = false
		"medium":
			sun.shadow_enabled = true
			sun.directional_shadow_max_distance = 30.0
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.scaling_3d_scale = 1.0
			env.glow_enabled = true
		_:
			sun.shadow_enabled = true
			sun.directional_shadow_max_distance = 40.0
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.scaling_3d_scale = 1.0
			env.glow_enabled = true


static func next(name: String) -> String:
	return ORDER[(ORDER.find(name) + 1) % ORDER.size()]
