## Geometry helpers for baking the miniature-city kit (M2.3). Everything is
## added into a MeshMerger with material-asset keys, then saved as ArrayMesh
## resources. Units are metres; one board tile is 1.0 m.
class_name ModelKit
extends RefCounted

const MAT := "res://assets/materials/%s.tres"

var m := MeshMerger.new()
var rng := RandomNumberGenerator.new()


func _init(seed_value := 1) -> void:
	rng.seed = seed_value


static func mat(name: String) -> String:
	return MAT % name


# --- primitives -------------------------------------------------------------------

func box(size: Vector3, pos: Vector3, color: Color, material := "plaster", rot_y := 0.0) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	m.add_mesh(bm, Transform3D(Basis(Vector3.UP, rot_y), pos), color, mat(material))


## Box sitting on y0 (bottom at y0) - most building parts are placed this way.
func block(w: float, h: float, d: float, x: float, y0: float, z: float, color: Color, material := "plaster") -> void:
	box(Vector3(w, h, d), Vector3(x, y0 + h * 0.5, z), color, material)


func cylinder(r_top: float, r_bot: float, h: float, pos: Vector3, color: Color, material := "plaster", segments := 16) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segments
	cm.rings = 1
	m.add_mesh(cm, Transform3D(Basis(), pos), color, mat(material))


func sphere(r: float, pos: Vector3, color: Color, material := "foliage", segments := 12, squash := 1.0) -> void:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = segments
	sm.rings = maxi(4, segments / 2)
	m.add_mesh(sm, Transform3D(Basis().scaled(Vector3(1, squash, 1)), pos), color, mat(material))


## Gable roof: a prism along x (ridge along x) or z.
func gable(w: float, h: float, d: float, pos: Vector3, color: Color, along_z := false, material := "roof_tile") -> void:
	var pm := PrismMesh.new()
	pm.size = Vector3(w, h, d) if not along_z else Vector3(d, h, w)
	var basis := Basis() if not along_z else Basis(Vector3.UP, PI * 0.5)
	m.add_mesh(pm, Transform3D(basis, pos + Vector3(0, h * 0.5, 0)), color, mat(material))


## Four-sided hip / pyramid roof.
func pyramid(w: float, h: float, d: float, pos: Vector3, color: Color, material := "roof_tile") -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.7071
	cm.height = 1.0
	cm.radial_segments = 4
	cm.rings = 1
	# 4-sided cone rotated 45 degrees, then scaled to w x h x d.
	var b := Basis().scaled(Vector3(w, h, d)) * Basis(Vector3.UP, PI * 0.25)
	m.add_mesh(cm, Transform3D(b, pos + Vector3(0, h * 0.5, 0)), color, mat(material))


## Solid of revolution from a (radius, y) profile, bottom to top.
func lathe(profile: PackedVector2Array, pos: Vector3, color: Color, material: String, segments := 24) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		for s in segments:
			var t0 := TAU * s / segments
			var t1 := TAU * (s + 1) / segments
			var p00 := Vector3(cos(t0) * a.x, a.y, sin(t0) * a.x)
			var p01 := Vector3(cos(t1) * a.x, a.y, sin(t1) * a.x)
			var p10 := Vector3(cos(t0) * b.x, b.y, sin(t0) * b.x)
			var p11 := Vector3(cos(t1) * b.x, b.y, sin(t1) * b.x)
			# Godot front faces are clockwise as seen from outside.
			st.add_vertex(p00)
			st.add_vertex(p11)
			st.add_vertex(p10)
			st.add_vertex(p00)
			st.add_vertex(p01)
			st.add_vertex(p11)
	st.generate_normals()
	m.add_mesh(st.commit(), Transform3D(Basis(), pos), color, mat(material))


func torus(inner: float, outer: float, pos: Vector3, color: Color, material := "metal", rings := 24) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = rings
	tm.ring_segments = 6
	m.add_mesh(tm, Transform3D(Basis(), pos), color, mat(material))


## Thin dark-shadow quad (contact shadow / ambient occlusion under objects).
func contact_shadow(w: float, d: float, pos := Vector3(0, 0.004, 0), strength := 1.0) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, d)
	m.add_mesh(pm, Transform3D(Basis(), pos), Color(1, 1, 1, strength), mat("contact_shadow"))


# --- architectural details ----------------------------------------------------------

## Windows on the four faces of a w x d block between y0 and y1.
## lit: share of windows glowing warm (deterministic per kit seed).
func windows(w: float, d: float, cx: float, cz: float, y0: float, y1: float, floors: int, cols_w: int, cols_d: int,
		glass := Color("#3b5568"), lit := 0.35, frame := Color("#f2efe8"), tall := 0.55) -> void:
	var fh := (y1 - y0) / floors
	var faces := [
		[Vector3(0, 0, 1), w, cols_w, Vector3(cx, 0, cz + d * 0.5)],
		[Vector3(0, 0, -1), w, cols_w, Vector3(cx, 0, cz - d * 0.5)],
		[Vector3(1, 0, 0), d, cols_d, Vector3(cx + w * 0.5, 0, cz)],
		[Vector3(-1, 0, 0), d, cols_d, Vector3(cx - w * 0.5, 0, cz)],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var span: float = f[1]
		var cols: int = f[2]
		var c0: Vector3 = f[3]
		if cols <= 0:
			continue
		var along := Vector3(n.z, 0, -n.x).abs()
		var cw := span / cols
		for fl in floors:
			var yc := y0 + fh * (fl + 0.5)
			for c in cols:
				var off := -span * 0.5 + cw * (c + 0.5)
				var p: Vector3 = c0 + along * off + Vector3(0, yc, 0) + n * 0.004
				var ww := cw * 0.58
				var wh := fh * tall
				# Pane, sill top and sill front are single quads (6 triangles
				# per window instead of 24 with boxes: Phase 2 profiling showed
				# windows dominate the kit's triangle count).
				var facing := Basis.looking_at(-n, Vector3.UP)
				var is_lit := rng.randf() < lit
				quad(Vector2(ww, wh), p, facing, Color("#ffd58a") if is_lit else glass, "window_glow" if is_lit else "glass")
				var sill_y := p.y - wh * 0.5 - 0.002
				var sill_c := c0 + along * off + n * 0.01
				quad(Vector2(ww * 1.15, 0.016), Vector3(sill_c.x, sill_y, sill_c.z), facing * Basis(Vector3.RIGHT, -PI * 0.5), frame, "concrete")
				quad(Vector2(ww * 1.15, 0.006), Vector3(sill_c.x, sill_y - 0.003, sill_c.z) + n * 0.008, facing, frame.darkened(0.15), "concrete")


## Single quad (2 triangles); `basis` maps the quad's +Z normal into place.
func quad(size: Vector2, pos: Vector3, basis: Basis, color: Color, material: String) -> void:
	var qm := QuadMesh.new()
	qm.size = size
	m.add_mesh(qm, Transform3D(basis, pos), color, mat(material))


## Horizontal band (cornice / floor slab edge) around a block.
func band(w: float, d: float, cx: float, cz: float, y: float, h: float, color: Color, out := 0.02, material := "concrete") -> void:
	box(Vector3(w + out * 2.0, h, d + out * 2.0), Vector3(cx, y + h * 0.5, cz), color, material)


## Striped shop awning on one face.
func awning(width: float, pos: Vector3, normal: Vector3, c1: Color, c2: Color, stripes := 5) -> void:
	var along := Vector3(normal.z, 0, -normal.x).abs()
	var sw := width / stripes
	for i in stripes:
		var p := pos + along * (-width * 0.5 + sw * (i + 0.5)) + normal * 0.045
		var sz := Vector3(sw, 0.012, 0.09) if absf(normal.z) > 0.5 else Vector3(0.09, 0.012, sw)
		var rot := Basis(along, -0.35 if normal.z > 0 or normal.x < 0 else 0.35)
		var bm := BoxMesh.new()
		bm.size = sz
		m.add_mesh(bm, Transform3D(rot, p), c1 if i % 2 == 0 else c2, mat("fabric"))


func tree_round(pos: Vector3, scale := 1.0, leaf := Color("#4f8a3c")) -> void:
	cylinder(0.018 * scale, 0.026 * scale, 0.16 * scale, pos + Vector3(0, 0.08 * scale, 0), Color("#6b4a32"), "wood", 6)
	sphere(0.12 * scale, pos + Vector3(0, 0.24 * scale, 0), leaf, "foliage", 8, 0.9)
	sphere(0.085 * scale, pos + Vector3(0.05 * scale, 0.32 * scale, 0.03 * scale), leaf.lightened(0.12), "foliage", 7, 0.9)
	sphere(0.07 * scale, pos + Vector3(-0.06 * scale, 0.29 * scale, -0.04 * scale), leaf.darkened(0.08), "foliage", 6, 0.9)


func tree_cone(pos: Vector3, scale := 1.0, leaf := Color("#2f6b45")) -> void:
	cylinder(0.016 * scale, 0.022 * scale, 0.1 * scale, pos + Vector3(0, 0.05 * scale, 0), Color("#5d4030"), "wood", 6)
	cylinder(0.0, 0.11 * scale, 0.2 * scale, pos + Vector3(0, 0.18 * scale, 0), leaf, "foliage", 10)
	cylinder(0.0, 0.085 * scale, 0.16 * scale, pos + Vector3(0, 0.28 * scale, 0), leaf.lightened(0.08), "foliage", 10)


func palm(pos: Vector3, scale := 1.0) -> void:
	var trunk := PackedVector2Array([Vector2(0.022, 0), Vector2(0.018, 0.15), Vector2(0.014, 0.32)])
	lathe(_scaled(trunk, scale), pos, Color("#8a6a4a"), "wood", 7)
	var top := pos + Vector3(0, 0.32 * scale, 0)
	for i in 7:
		var a := TAU * i / 7.0
		var dir := Vector3(cos(a), 0, sin(a))
		var leaf := BoxMesh.new()
		leaf.size = Vector3(0.16 * scale, 0.006, 0.045 * scale)
		var b := Basis(Vector3.UP, -a) * Basis(Vector3.BACK, -0.45)
		m.add_mesh(leaf, Transform3D(b, top + dir * 0.07 * scale + Vector3(0, -0.02 * scale, 0)), Color("#3f8f4a"), mat("foliage"))
	sphere(0.025 * scale, top, Color("#5a4632"), "wood", 6)


func hedge(w: float, d: float, pos: Vector3, leaf := Color("#4a7d3a")) -> void:
	box(Vector3(w, 0.06, d), pos + Vector3(0, 0.03, 0), leaf, "foliage")


func flowers(pos: Vector3, count: int, spread: float, colors: Array) -> void:
	for i in count:
		var p := pos + Vector3(rng.randf_range(-spread, spread), 0.015, rng.randf_range(-spread, spread))
		sphere(0.014, p, colors[i % colors.size()], "foliage", 6)


func _scaled(p: PackedVector2Array, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in p:
		out.append(v * s)
	return out


# --- post process ----------------------------------------------------------------

## Cheap baked ambient occlusion: darkens vertices near the ground so blocks
## sit on the board instead of floating (the Mobile renderer has no SSAO).
func bake_ground_ao(height := 0.12, floor_tone := 0.68) -> void:
	for key in m._surfaces:
		if str(key).ends_with("window_glow.tres") or str(key).ends_with("contact_shadow.tres"):
			continue
		var s: Dictionary = m._surfaces[key]
		var v: PackedVector3Array = s["v"]
		var c: PackedColorArray = s["c"]
		for i in v.size():
			var k := lerpf(floor_tone, 1.0, smoothstep(0.0, height, v[i].y))
			c[i] = Color(c[i].r * k, c[i].g * k, c[i].b * k, c[i].a)
		s["c"] = c


func build() -> ArrayMesh:
	return m.build()


func triangle_count() -> int:
	var n := 0
	for k in m._surfaces:
		n += m._surfaces[k]["i"].size() / 3
	return n
