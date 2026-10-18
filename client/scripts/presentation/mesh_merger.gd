## Merges many primitive meshes into one ArrayMesh, one surface per material
## group, using vertex colours instead of one material per object. This turns
## hundreds of MeshInstance3D draw calls into a handful (M2.1 rendering pass).
## Material keys:
##   "std|<roughness>|<metallic>"   StandardMaterial3D using vertex colour
##   "glow|<energy>|<roughness>|<metallic>"  emissive vertex-colour shader
##   "res://...tres"                 a material asset from client/assets/materials
##                                   (production kit, M2.3); vertex colour tints it
## UVs are carried through, so textured kit materials work after merging.
class_name MeshMerger
extends RefCounted

static var _materials: Dictionary = {}
static var _box_cache: Dictionary = {}

var _surfaces: Dictionary = {}  # key -> {v, n, uv, c, i}


static func material_for(key: String) -> Material:
	if _materials.has(key):
		return _materials[key]
	var m: Material
	if key.begins_with("res://"):
		m = load(key)
		_materials[key] = m
		return m
	var parts := key.split("|")
	if parts[0] == "glow":
		var sm := ShaderMaterial.new()
		sm.shader = load("res://scripts/presentation/vertex_glow.gdshader")
		sm.set_shader_parameter("energy", float(parts[1]))
		sm.set_shader_parameter("roughness_v", float(parts[2]))
		sm.set_shader_parameter("metallic_v", float(parts[3]))
		m = sm
	else:
		var st := StandardMaterial3D.new()
		st.vertex_color_use_as_albedo = true
		st.vertex_color_is_srgb = true
		st.roughness = float(parts[1])
		st.metallic = float(parts[2])
		m = st
	_materials[key] = m
	return m


static func std(roughness: float, metallic := 0.0) -> String:
	# Quantised so similar objects share a surface.
	return "std|%.1f|%.1f" % [snappedf(roughness, 0.1), snappedf(metallic, 0.1)]


static func glow(energy: float, roughness := 0.3, metallic := 0.0) -> String:
	return "glow|%.1f|%.1f|%.1f" % [energy, roughness, metallic]


static func box_mesh(size: Vector3) -> BoxMesh:
	var k := "%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	if not _box_cache.has(k):
		var b := BoxMesh.new()
		b.size = size
		_box_cache[k] = b
	return _box_cache[k]


func is_empty() -> bool:
	return _surfaces.is_empty()


func add_box(size: Vector3, pos: Vector3, color: Color, key: String) -> void:
	add_mesh(box_mesh(size), Transform3D(Basis(), pos), color, key)


func add_mesh(mesh: Mesh, xform: Transform3D, color: Color, key: String) -> void:
	_append(mesh.surface_get_arrays(0), xform, color, key, false)


## Adds every surface of a kit asset (an ArrayMesh whose surfaces carry
## material assets and baked vertex colours). `tint` multiplies the baked
## colours (e.g. the owner's colour on a white flag cloth).
func add_kit(mesh: Mesh, xform: Transform3D, tint := Color.WHITE) -> void:
	for si in mesh.get_surface_count():
		var mat := mesh.surface_get_material(si)
		var key: String = mat.resource_path if mat and mat.resource_path != "" else std(0.7)
		_append(mesh.surface_get_arrays(si), xform, tint, key, true)


func _append(arr: Array, xform: Transform3D, color: Color, key: String, multiply: bool) -> void:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uvs = arr[Mesh.ARRAY_TEX_UV]
	var cols = arr[Mesh.ARRAY_COLOR]
	var idx = arr[Mesh.ARRAY_INDEX]
	if not _surfaces.has(key):
		_surfaces[key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
	var s: Dictionary = _surfaces[key]
	var base: int = s["v"].size()
	var nb := xform.basis.inverse().transposed()
	var has_uv: bool = uvs != null and uvs.size() == verts.size()
	var has_c: bool = multiply and cols != null and cols.size() == verts.size()
	# "*_planar" materials are mapped by world X/Z (flat ground pieces), so
	# textures line up across merged pieces with a single fetch.
	var planar := key.contains("_planar")
	for k in verts.size():
		var wv := xform * verts[k]
		s["v"].append(wv)
		s["n"].append((nb * norms[k]).normalized())
		s["uv"].append(Vector2(wv.x, wv.z) if planar else (uvs[k] if has_uv else Vector2.ZERO))
		s["c"].append(cols[k] * color if has_c else color)
	if idx == null or idx.is_empty():
		for k in verts.size():
			s["i"].append(base + k)
	else:
		for k in idx:
			s["i"].append(base + k)


## Number of vertices added so far (asset budgets / tests).
func vertex_count() -> int:
	var n := 0
	for k in _surfaces:
		n += _surfaces[k]["v"].size()
	return n


func build() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var keys := _surfaces.keys()
	keys.sort()
	for key in keys:
		var s: Dictionary = _surfaces[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s["v"]
		arrays[Mesh.ARRAY_NORMAL] = s["n"]
		arrays[Mesh.ARRAY_TEX_UV] = s["uv"]
		arrays[Mesh.ARRAY_COLOR] = s["c"]
		arrays[Mesh.ARRAY_INDEX] = s["i"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material_for(key))
	return mesh


func instance(name := "Merged") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = build()
	return mi
