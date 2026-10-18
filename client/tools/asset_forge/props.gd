## Kit pieces for the board, streets and harbour, plus tokens and dice (M2.3).
## Every function returns a ModelKit; forge.gd saves each as an asset under
## client/assets/models/. Pieces are authored white/neutral where the board
## tints them at merge time (tile tops, frames, flags), and in final colours
## otherwise.
class_name Props
extends RefCounted

const STONE := Color("#d8cdb6")
const STONE_DARK := Color("#8f8370")
const METAL_DARK := Color("#3b4048")
const WOOD := Color("#8a5a3c")


## Unit cube in one material: scaled at runtime for strips, frames, roads.
static func unit_box(material: String, color := Color.WHITE) -> ModelKit:
	var k := ModelKit.new()
	k.box(Vector3.ONE, Vector3.ZERO, color, material)
	return k


## Tile body: stone curb with a recessed marble top (top tinted per tile).
static func tile_base() -> ModelKit:
	var k := ModelKit.new()
	k.box(Vector3(0.94, 0.09, 0.94), Vector3(0, 0.045, 0), STONE, "stone_wall")
	k.box(Vector3(0.95, 0.012, 0.95), Vector3(0, 0.006, 0), STONE_DARK, "stone_wall")
	return k


static func tile_top() -> ModelKit:
	var k := ModelKit.new()
	# Two stacked slabs = a small chamfer that catches light at phone size.
	k.box(Vector3(0.9, 0.02, 0.9), Vector3(0, 0.1, 0), Color.WHITE, "marble")
	k.box(Vector3(0.86, 0.012, 0.86), Vector3(0, 0.114, 0), Color.WHITE, "marble")
	return k


## Empty building lot: paved pad with a planted edge.
static func lot_plaza() -> ModelKit:
	var k := ModelKit.new()
	k.box(Vector3(0.6, 0.006, 0.6), Vector3(0, 0.003, 0), Color("#e4ddcf"), "paving")
	# Two small shrubs on the front corners (life on empty lots, no outline).
	for x in [-0.24, 0.24]:
		k.sphere(0.035, Vector3(x, 0.03, 0.24), Color("#4f8a3c"), "foliage", 8, 0.8)
	return k


static func streetlight() -> ModelKit:
	var k := ModelKit.new()
	k.cylinder(0.008, 0.011, 0.3, Vector3(0, 0.15, 0), METAL_DARK, "metal", 8)
	k.box(Vector3(0.06, 0.008, 0.008), Vector3(0.025, 0.3, 0), METAL_DARK, "metal")
	k.box(Vector3(0.04, 0.012, 0.024), Vector3(0.05, 0.293, 0), Color("#ffe3a3"), "window_glow")
	k.cylinder(0.016, 0.02, 0.012, Vector3(0, 0.006, 0), METAL_DARK, "metal", 8)
	return k


static func tree_round(variant: int) -> ModelKit:
	var k := ModelKit.new(30 + variant)
	k.contact_shadow(0.3, 0.3, Vector3(0, 0.003, 0), 0.7)
	k.tree_round(Vector3.ZERO, 1.0 + 0.15 * variant, [Color("#4f8a3c"), Color("#5f9a3e"), Color("#3f7a46")][variant % 3])
	return k


static func tree_cone() -> ModelKit:
	var k := ModelKit.new(40)
	k.contact_shadow(0.26, 0.26, Vector3(0, 0.003, 0), 0.7)
	k.tree_cone(Vector3.ZERO, 1.1)
	return k


static func palm() -> ModelKit:
	var k := ModelKit.new(41)
	k.contact_shadow(0.24, 0.24, Vector3(0, 0.003, 0), 0.6)
	k.palm(Vector3.ZERO, 1.1)
	return k


static func bench() -> ModelKit:
	var k := ModelKit.new()
	k.box(Vector3(0.12, 0.008, 0.035), Vector3(0, 0.03, 0), WOOD, "wood")
	k.box(Vector3(0.12, 0.03, 0.006), Vector3(0, 0.05, -0.016), WOOD, "wood")
	for x in [-0.05, 0.05]:
		k.box(Vector3(0.006, 0.03, 0.03), Vector3(x, 0.015, 0), METAL_DARK, "metal")
	return k


static func planter() -> ModelKit:
	var k := ModelKit.new(7)
	k.box(Vector3(0.12, 0.04, 0.12), Vector3(0, 0.02, 0), STONE, "concrete")
	k.sphere(0.055, Vector3(0, 0.06, 0), Color("#4f8a3c"), "foliage", 8, 0.7)
	k.flowers(Vector3(0, 0.05, 0), 6, 0.04, [Color("#f6c1d1"), Color("#ffe08a"), Color("#ffffff")])
	return k


static func bollard() -> ModelKit:
	var k := ModelKit.new()
	k.cylinder(0.014, 0.018, 0.05, Vector3(0, 0.025, 0), METAL_DARK, "metal", 8)
	k.sphere(0.015, Vector3(0, 0.05, 0), METAL_DARK, "metal", 8)
	return k


## Small motor boat, bow towards +x.
static func boat_small(hull: Color) -> ModelKit:
	var k := ModelKit.new()
	k.box(Vector3(0.32, 0.06, 0.13), Vector3(0, 0.03, 0), hull, "paint")
	k.gable(0.13, 0.06, 0.1, Vector3(0.21, 0.0, 0), hull, true, "paint")
	k.box(Vector3(0.34, 0.012, 0.14), Vector3(0.0, 0.066, 0), Color("#f4efe6"), "wood")
	k.box(Vector3(0.1, 0.05, 0.09), Vector3(-0.03, 0.1, 0), Color("#f8f8f8"), "plaster")
	k.box(Vector3(0.006, 0.03, 0.08), Vector3(0.022, 0.105, 0), Color("#4d7ca6"), "glass")
	return k


static func yacht() -> ModelKit:
	var k := ModelKit.new()
	k.box(Vector3(0.6, 0.08, 0.2), Vector3(0, 0.04, 0), Color("#fbfaf6"), "paint")
	k.gable(0.2, 0.08, 0.14, Vector3(0.37, 0.0, 0), Color("#fbfaf6"), true, "paint")
	k.box(Vector3(0.6, 0.012, 0.21), Vector3(0, 0.03, 0), Color("#1d3b5a"), "paint")
	k.box(Vector3(0.62, 0.012, 0.21), Vector3(0.02, 0.086, 0), Color("#c8a27a"), "wood")
	k.box(Vector3(0.3, 0.06, 0.15), Vector3(-0.06, 0.12, 0), Color("#fbfaf6"), "plaster")
	k.box(Vector3(0.3, 0.03, 0.152), Vector3(-0.06, 0.125, 0), Color("#29475f"), "glass")
	k.box(Vector3(0.16, 0.04, 0.12), Vector3(-0.08, 0.17, 0), Color("#fbfaf6"), "plaster")
	k.box(Vector3(0.16, 0.02, 0.122), Vector3(-0.08, 0.172, 0), Color("#29475f"), "glass")
	return k


static func pier() -> ModelKit:
	var k := ModelKit.new()
	k.box(Vector3(0.9, 0.025, 0.22), Vector3(0, 0.0, 0), Color("#a77b55"), "wood")
	for x in [-0.4, -0.13, 0.13, 0.4]:
		for z in [-0.1, 0.1]:
			k.cylinder(0.014, 0.014, 0.2, Vector3(x, -0.09, z), Color("#6b4a32"), "wood", 6)
	return k


static func fountain() -> ModelKit:
	var k := ModelKit.new()
	var basin := PackedVector2Array([Vector2(0.3, 0), Vector2(0.3, 0.05), Vector2(0.27, 0.05), Vector2(0.27, 0.035), Vector2(0.0, 0.035)])
	k.lathe(basin, Vector3.ZERO, STONE, "stone_wall", 28)
	k.cylinder(0.265, 0.265, 0.008, Vector3(0, 0.03, 0), Color("#5fb6c9"), "glass", 28)
	k.cylinder(0.04, 0.05, 0.12, Vector3(0, 0.06, 0), STONE, "stone_wall", 12)
	k.cylinder(0.1, 0.06, 0.02, Vector3(0, 0.13, 0), STONE, "stone_wall", 16)
	k.cylinder(0.012, 0.03, 0.08, Vector3(0, 0.17, 0), Color("#d9f3ff"), "window_glow", 10)
	return k


## Central landmark: stepped stone tower with a gold crown (decorative).
static func landmark() -> ModelKit:
	var k := ModelKit.new(5)
	k.contact_shadow(1.0, 1.0, Vector3(0, 0.003, 0), 0.8)
	k.block(0.9, 0.08, 0.9, 0, 0, 0, STONE, "stone_wall")
	k.block(0.7, 0.5, 0.7, 0, 0.08, 0, Color("#f0ebe0"))
	k.windows(0.7, 0.7, 0, 0, 0.1, 0.56, 3, 5, 5, Color("#36505f"), 0.45, Color("#f5f1e8"))
	var y := 0.58
	var w := 0.56
	for t in 3:
		var h := 0.38 - t * 0.06
		k.band(w, w, 0, 0, y - 0.01, 0.02, Color("#d8a63a"), 0.015, "gold")
		k.block(w, h, w, 0, y, 0, Color("#f3efe6"))
		k.windows(w, w, 0, 0, y + 0.02, y + h - 0.02, 3, 4, 4, Color("#36505f"), 0.5, Color("#f5f1e8"))
		y += h
		w -= 0.1
	k.band(w + 0.1, w + 0.1, 0, 0, y - 0.01, 0.02, Color("#d8a63a"), 0.015, "gold")
	var crown := PackedVector2Array([Vector2(0.18, 0), Vector2(0.2, 0.08), Vector2(0.12, 0.2), Vector2(0.0, 0.42)])
	k.lathe(crown, Vector3(0, y, 0), Color("#e2b448"), "gold", 16)
	k.sphere(0.04, Vector3(0, y + 0.45, 0), Color("#fff1c2"), "window_glow", 10)
	k.bake_ground_ao(0.12, 0.7)
	return k


## Background blocks for the city centre (not gameplay lots).
static func bg_block(variant: int) -> ModelKit:
	var k := ModelKit.new(100 + variant)
	var palettes := [Color("#efe5d1"), Color("#dfe7ec"), Color("#f2dccb"), Color("#e6e1d6")]
	var c: Color = palettes[variant % palettes.size()]
	match variant:
		0:
			k.contact_shadow(0.62, 0.62)
			k.block(0.5, 0.42, 0.5, 0, 0, 0, c)
			k.windows(0.5, 0.5, 0, 0, 0.03, 0.4, 4, 4, 4, Color("#36505f"), 0.3, Color("#f5f1e8"))
			k.block(0.52, 0.02, 0.52, 0, 0.42, 0, Color("#9aa3ab"), "concrete")
			k.block(0.12, 0.05, 0.1, 0.12, 0.44, -0.1, Color("#c9ced2"), "metal")
		1:
			k.contact_shadow(0.62, 0.62)
			k.block(0.46, 0.75, 0.46, 0, 0, 0, Color("#6f97bb"), "glass")
			k.windows(0.46, 0.46, 0, 0, 0.03, 0.73, 7, 4, 4, Color("#2c4860"), 0.3, Color("#eef3f5"), 0.75)
			k.block(0.48, 0.03, 0.48, 0, 0.75, 0, Color("#e9eef2"), "metal")
		2:
			k.contact_shadow(0.62, 0.62)
			k.block(0.5, 0.3, 0.44, 0, 0, 0, c)
			k.windows(0.5, 0.44, 0, 0, 0.03, 0.28, 2, 4, 3, Color("#36505f"), 0.35, Color("#f5f1e8"))
			k.gable(0.54, 0.14, 0.48, Vector3(0, 0.3, 0), Color("#b65a36"), true)
		_:
			k.contact_shadow(0.62, 0.62)
			k.block(0.36, 1.0, 0.36, 0, 0, 0, c)
			k.windows(0.36, 0.36, 0, 0, 0.04, 0.98, 9, 3, 3, Color("#36505f"), 0.3, Color("#f5f1e8"))
			k.band(0.36, 0.36, 0, 0, 0.98, 0.03, Color("#d8a63a"), 0.015, "gold")
			k.block(0.2, 0.12, 0.2, 0, 1.01, 0, c)
	k.bake_ground_ao(0.12, 0.7)
	return k


## Owner flag pieces: the pole stays white metal, the cloth is tinted.
static func flag_pole() -> ModelKit:
	var k := ModelKit.new()
	k.cylinder(0.007, 0.008, 0.34, Vector3(0, 0.17, 0), Color("#eeeeee"), "metal", 6)
	k.sphere(0.013, Vector3(0, 0.345, 0), Color("#e2b448"), "gold", 8)
	k.cylinder(0.022, 0.026, 0.012, Vector3(0, 0.006, 0), Color("#d0d0d0"), "metal", 8)
	return k


static func flag_cloth() -> ModelKit:
	var k := ModelKit.new()
	# Slight wave: three panels at small angles.
	for i in 3:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.055, 0.1, 0.006)
		var x := 0.03 + i * 0.052
		k.m.add_mesh(bm, Transform3D(Basis(Vector3.UP, [0.15, -0.15, 0.12][i]), Vector3(x, 0.28, 0.004 * (i - 1))), Color.WHITE, ModelKit.mat("fabric"))
	return k


# --- tokens and dice -------------------------------------------------------------------

## Player pawns: shared turned base, distinct heads so seats differ by shape
## as well as colour (crown, top hat, rook, gem).
static func pawn(seat: int, color: Color) -> ModelKit:
	var k := ModelKit.new(200 + seat)
	var gold := Color("#e2b448")
	var base := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.135, 0.02), Vector2(0.12, 0.04), Vector2(0.0, 0.04)])
	k.lathe(base, Vector3.ZERO, gold, "gold", 28)
	var body := PackedVector2Array([Vector2(0.1, 0.04), Vector2(0.085, 0.07), Vector2(0.06, 0.12), Vector2(0.045, 0.22),
		Vector2(0.05, 0.26), Vector2(0.075, 0.275), Vector2(0.05, 0.29), Vector2(0.0, 0.29)])
	k.lathe(body, Vector3.ZERO, color, "enamel", 24)
	var top := Vector3(0, 0.29, 0)
	match seat % 4:
		0:
			k.sphere(0.06, top + Vector3(0, 0.05, 0), color, "enamel", 16)
			k.cylinder(0.06, 0.05, 0.03, top + Vector3(0, 0.1, 0), gold, "gold", 16)
			for i in 6:
				var a := TAU * i / 6.0
				k.box(Vector3(0.018, 0.04, 0.018), top + Vector3(cos(a) * 0.05, 0.13, sin(a) * 0.05), gold, "gold")
		1:
			k.sphere(0.06, top + Vector3(0, 0.05, 0), color, "enamel", 16)
			k.cylinder(0.085, 0.085, 0.01, top + Vector3(0, 0.09, 0), Color("#24262b"), "enamel", 20)
			k.cylinder(0.05, 0.05, 0.08, top + Vector3(0, 0.135, 0), Color("#24262b"), "enamel", 20)
			k.cylinder(0.051, 0.051, 0.015, top + Vector3(0, 0.105, 0), gold, "gold", 20)
		2:
			k.cylinder(0.07, 0.065, 0.1, top + Vector3(0, 0.05, 0), color, "enamel", 20)
			for i in 6:
				var a := TAU * i / 6.0
				k.box(Vector3(0.03, 0.035, 0.03), top + Vector3(cos(a) * 0.055, 0.115, sin(a) * 0.055), color, "enamel")
			k.cylinder(0.072, 0.072, 0.012, top + Vector3(0, 0.03, 0), gold, "gold", 20)
		_:
			k.sphere(0.04, top + Vector3(0, 0.03, 0), gold, "gold", 12)
			# Gem: octahedron-like double cone.
			k.cylinder(0.0, 0.07, 0.07, top + Vector3(0, 0.1, 0), color.lightened(0.15), "enamel", 6)
			k.cylinder(0.07, 0.0, 0.05, top + Vector3(0, 0.16, 0), color.lightened(0.3), "enamel", 6)
	return k


## Rounded die (spherified cube) with recessed pips. Faces follow DiceView:
## 1 up, 6 down, 2 +z, 5 -z, 3 +x, 4 -x.
static func die(size: float) -> ModelKit:
	var k := ModelKit.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := size * 0.5
	var r := size * 0.18
	var n := 10
	var faces := [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	for f in faces:
		var fn: Vector3 = f
		var u := Vector3.RIGHT if absf(fn.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK
		var a := fn.cross(u).normalized()
		var b := fn.cross(a).normalized()
		var grid := []
		for i in n + 1:
			var row := []
			for j in n + 1:
				var p: Vector3 = fn * h + a * h * (2.0 * i / n - 1.0) + b * h * (2.0 * j / n - 1.0)
				var inner := p.clamp(Vector3.ONE * -(h - r), Vector3.ONE * (h - r))
				var dir := (p - inner).normalized()
				row.append([inner + dir * r, dir])
			grid.append(row)
		for i in n:
			for j in n:
				var q := [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
				for t in [[0, 1, 2], [0, 2, 3]]:
					for idx in t:
						st.set_normal(q[idx][1])
						st.add_vertex(q[idx][0])
	var mesh := st.commit()
	# Winding depends on the face basis; make every triangle face outwards.
	k.m.add_mesh(_outward(mesh), Transform3D(), Color("#fbf7ee"), ModelKit.mat("enamel"))
	var pips := {1: [Vector2(0, 0)], 2: [Vector2(-1, -1), Vector2(1, 1)], 3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
		4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
		5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
		6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]}
	var normals := {1: Vector3.UP, 6: Vector3.DOWN, 2: Vector3.BACK, 5: Vector3.FORWARD, 3: Vector3.RIGHT, 4: Vector3.LEFT}
	for v in pips:
		var fn: Vector3 = normals[v]
		var u := Vector3.RIGHT if absf(fn.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK
		var a := fn.cross(u).normalized()
		var b := fn.cross(a).normalized()
		for p in pips[v]:
			var pos: Vector3 = fn * (h - 0.004) + a * p.x * size * 0.26 + b * p.y * size * 0.26
			var cm := CylinderMesh.new()
			cm.top_radius = size * 0.085 if v == 1 else size * 0.075
			cm.bottom_radius = cm.top_radius
			cm.height = 0.01
			cm.radial_segments = 14
			cm.rings = 1
			var basis := Basis(Quaternion(Vector3.UP, fn)) if fn != Vector3.DOWN else Basis(Vector3.RIGHT, PI)
			k.m.add_mesh(cm, Transform3D(basis, pos), Color("#c0392b") if v == 1 else Color("#1d1f24"), ModelKit.mat("enamel"))
	return k


static func _outward(mesh: ArrayMesh) -> ArrayMesh:
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for i in range(0, v.size(), 3):
		var fnorm := (v[i + 1] - v[i]).cross(v[i + 2] - v[i])
		# Godot front faces are clockwise: the cross product points inwards.
		if fnorm.dot(nrm[i]) > 0.0:
			var t := v[i + 1]
			v[i + 1] = v[i + 2]
			v[i + 2] = t
			var tn := nrm[i + 1]
			nrm[i + 1] = nrm[i + 2]
			nrm[i + 2] = tn
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nrm
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out
