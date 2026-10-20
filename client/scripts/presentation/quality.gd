## Low / medium / high presets (shadows, MSAA, glow, render scale, and on Low
## no triplanar detail/normal maps).
class_name QualitySettings
extends RefCounted

const ORDER := ["low", "medium", "high"]


## Kit materials whose triplanar detail/normal maps the Low preset turns off
## (three texture fetches per map per pixel is the main extra fill cost of the
## M2.3 kit on slow GPUs). Vertex colours keep every surface's hue.
const DETAIL_MATERIALS := ["plaster", "concrete", "paving", "stone_wall", "asphalt", "grass", "roof_tile",
	"wood", "foliage", "marble", "paving_planar", "asphalt_planar", "grass_planar", "marble_planar"]

static var _detail_saved: Dictionary = {}
## Runtime copies of library materials without triplanar (MeshMerger bakes
## the projection into UVs for static meshes, Phase 3): name -> [material].
static var _variants: Dictionary = {}
static var _detail_on := true
static var _aniso := false


static func register_variant(name: String, m: StandardMaterial3D) -> void:
	if not _variants.has(name):
		_variants[name] = []
	_variants[name].append(m)
	m.set_meta("detail_textures", [m.albedo_texture, m.normal_texture, m.normal_enabled])
	_apply_variant(m)


static func _apply_variant(m: StandardMaterial3D) -> void:
	var d: Array = m.get_meta("detail_textures")
	m.albedo_texture = d[0] if _detail_on else null
	m.normal_texture = d[1] if _detail_on else null
	m.normal_enabled = d[2] if _detail_on else false
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if _aniso \
		else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


static func _apply_variants() -> void:
	for n in _variants:
		for m in _variants[n]:
			_apply_variant(m)


## Texture filtering per preset: anisotropic only on High (it multiplies
## texture fetches; trilinear is enough at phone pixel density).
static func set_material_filter(aniso: bool) -> void:
	_aniso = aniso
	_apply_variants()
	for n in DETAIL_MATERIALS:
		var path := "res://assets/materials/%s.tres" % n
		if ResourceLoader.exists(path):
			var m := load(path) as StandardMaterial3D
			if m:
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if aniso \
					else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


static func set_material_detail(full: bool) -> void:
	_detail_on = full
	_apply_variants()
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
		# (planar variants never use triplanar: d[3] is false for them)


## Directional shadow map size, explicit per preset (Phase 3). Godot's default
## is 4096 on desktop but 2048 on iOS/Android (`size.mobile`), so desktop
## benchmarks used to measure a heavier shadow pass than phones run.
const SHADOW_ATLAS := {"medium": 2048, "high": 2048}


static func apply(name: String, viewport: Viewport, sun: DirectionalLight3D, env: Environment) -> void:
	if SHADOW_ATLAS.has(name):
		RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS[name], true)
	set_material_detail(name != "low")
	set_material_filter(name == "high")
	match name:
		"low":
			sun.shadow_enabled = false
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.scaling_3d_scale = 0.75
			env.glow_enabled = false
		"medium":
			sun.shadow_enabled = true
			# One orthographic shadow map: the board is small, so PSSM splits
			# only re-render the same casters (Phase 2 profiling).
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			sun.directional_shadow_max_distance = 30.0
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.scaling_3d_scale = 1.0
			env.glow_enabled = true
		_:
			sun.shadow_enabled = true
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 40.0
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.scaling_3d_scale = 1.0
			env.glow_enabled = true


static func next(name: String) -> String:
	return ORDER[(ORDER.find(name) + 1) % ORDER.size()]
