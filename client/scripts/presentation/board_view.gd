## 3D miniature-city board built procedurally from GameConfig + ThemeData.
## Placeholder art (primitives + flat PBR materials) until production assets
## exist; scale, lighting and colour rules follow docs/M2_VERTICAL_SLICE_REPORT.md.
## Pure presentation: it is told what to show, it never reads rules state.
class_name BoardView
extends Node3D

signal tile_tapped(index: int)

const TILE_H := 0.12
const BOARD_H := 0.35

var config: GameConfig
var theme: ThemeData
var _tiles: Array[Node3D] = []
var _lots: Dictionary = {}        # property_id -> Node3D (building anchor)
var _owner_marks: Dictionary = {} # property_id -> MeshInstance3D
var _levels: Dictionary = {}      # property_id -> int shown
var _highlight: MeshInstance3D
var _rng := RandomNumberGenerator.new()  # decoration only, never rules


func build(p_config: GameConfig, p_theme: ThemeData) -> void:
	config = p_config
	theme = p_theme
	_rng.seed = 2026
	_build_water()
	_build_base()
	_build_center_city()
	for i in config.board_size():
		_build_tile(i)
	_highlight = MeshInstance3D.new()
	var hm := TorusMesh.new()
	hm.inner_radius = 0.38
	hm.outer_radius = 0.46
	_highlight.mesh = hm
	_highlight.material_override = theme.mat(Color(1.0, 0.85, 0.35), 0.3, 0.0, 2.5)
	_highlight.visible = false
	add_child(_highlight)


# --- environment ---------------------------------------------------------------

func _build_water() -> void:
	var w := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	pm.subdivide_width = 1
	pm.subdivide_depth = 1
	w.mesh = pm
	w.position.y = -BOARD_H - 0.05
	var sh := ShaderMaterial.new()
	sh.shader = load("res://scripts/presentation/water.gdshader")
	w.material_override = sh
	add_child(w)


func _build_base() -> void:
	# Stone quay slab under the ring of tiles, with a darker skirt.
	var slab := _box(Vector3(8.7, BOARD_H, 8.7), Color("#d9cdb4"), 0.85)
	slab.position.y = -BOARD_H * 0.5
	add_child(slab)
	var skirt := _box(Vector3(9.0, 0.12, 9.0), Color("#8a7b66"), 0.9)
	skirt.position.y = -BOARD_H + 0.02
	add_child(skirt)
	# Inner park lawn.
	var lawn := _box(Vector3(5.9, 0.06, 5.9), Color("#7fb069"), 0.95)
	lawn.position.y = 0.0
	add_child(lawn)


func _build_center_city() -> void:
	# Decorative skyline: a central landmark tower plus a ring of blocks,
	# roads and trees. Purely visual.
	var city := Node3D.new()
	city.name = "CenterCity"
	add_child(city)
	var road_mat := theme.mat(Color("#5b5f66"), 0.95)
	for axis in [Vector3(5.2, 0.02, 0.45), Vector3(0.45, 0.02, 5.2)]:
		var road := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = axis
		road.mesh = bm
		road.material_override = road_mat
		road.position.y = 0.04
		city.add_child(road)
	# Landmark tower (gold crown) in the middle.
	var tower := _box(Vector3(0.7, 2.2, 0.7), Color("#e9e4d8"), 0.4, 0.1)
	tower.position = Vector3(0, 1.13, 0)
	city.add_child(tower)
	var crown := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.42
	cm.height = 0.6
	crown.mesh = cm
	crown.material_override = theme.mat(Color("#f4c542"), 0.25, 0.8, 0.6)
	crown.position = Vector3(0, 2.53, 0)
	city.add_child(crown)
	# Blocks in four quadrants.
	var palette := [Color("#f1e3c6"), Color("#cfd8dc"), Color("#f6d5c3"), Color("#d7ccc8"), Color("#bfd7ea")]
	for qx in [-1, 1]:
		for qz in [-1, 1]:
			for k in 4:
				var h := _rng.randf_range(0.4, 1.4)
				var b := _box(Vector3(0.55, h, 0.55), palette[_rng.randi() % palette.size()], 0.6)
				var off := Vector3(0.75 + (k % 2) * 0.85, 0, 0.75 + (k / 2) * 0.85)
				b.position = Vector3(qx * off.x, h * 0.5 + 0.03, qz * off.z)
				city.add_child(b)
				var roof := _box(Vector3(0.6, 0.06, 0.6), Color("#7a8a99"), 0.7)
				roof.position = b.position + Vector3(0, h * 0.5 + 0.03, 0)
				city.add_child(roof)
	for i in 14:
		var ang := TAU * i / 14.0
		_tree(city, Vector3(cos(ang) * 2.55, 0.03, sin(ang) * 2.55))


func _tree(parent: Node3D, pos: Vector3) -> void:
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.03
	tm.bottom_radius = 0.04
	tm.height = 0.18
	trunk.mesh = tm
	trunk.material_override = theme.mat(Color("#6d4c41"), 0.9)
	trunk.position = pos + Vector3(0, 0.09, 0)
	parent.add_child(trunk)
	var crown := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.3
	crown.mesh = sm
	crown.material_override = theme.mat(Color("#4e8f3a").lerp(Color("#7cb342"), _rng.randf()), 0.9)
	crown.position = pos + Vector3(0, 0.3, 0)
	parent.add_child(crown)


# --- tiles -----------------------------------------------------------------------

func _build_tile(i: int) -> void:
	var root := Node3D.new()
	root.name = "Tile%02d" % i
	root.position = BoardLayout.position_of(i)
	add_child(root)
	_tiles.append(root)
	var sp: Dictionary = config.spaces[i]
	var st: String = sp["space_type"]
	var size := Vector3(BoardLayout.TILE - BoardLayout.GAP, TILE_H, BoardLayout.TILE - BoardLayout.GAP)
	var base_color := Color("#f7f1e3")
	var accent: Color
	if st == "PROPERTY":
		accent = theme.district_color(sp["district_id"])
	else:
		accent = Color(theme.special[st]["color"])
		base_color = accent.lerp(Color.WHITE, 0.55)
	var tile := _box(size, base_color, 0.7)
	tile.position.y = TILE_H * 0.5
	root.add_child(tile)
	# Pick body for tap-to-inspect.
	var body := StaticBody3D.new()
	body.set_meta("tile_index", i)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, 0.6, size.z)
	shape.shape = bs
	shape.position.y = 0.3
	body.add_child(shape)
	root.add_child(body)
	var inward := BoardLayout.inward(i)
	if st == "PROPERTY":
		# District colour band on the inner edge (classic board read).
		var band := _box(Vector3(size.x, 0.03, size.z * 0.28), accent, 0.5)
		var flat_in := Vector3(signf(inward.x) if absf(inward.x) > 0.5 else 0.0, 0, signf(inward.z) if absf(inward.z) > 0.5 else 0.0)
		if absf(flat_in.x) > 0.0:
			band.mesh.size = Vector3(size.x * 0.28, 0.03, size.z)
		band.position = Vector3(flat_in.x * size.x * 0.36, TILE_H + 0.015, flat_in.z * size.z * 0.36)
		root.add_child(band)
		var lot := Node3D.new()
		lot.position = Vector3(-flat_in.x * 0.1, TILE_H, -flat_in.z * 0.1)
		root.add_child(lot)
		_lots[sp["property_id"]] = lot
		_levels[sp["property_id"]] = -1
	else:
		var label := Label3D.new()
		label.text = theme.special[st]["label"]
		label.font_size = 64
		label.pixel_size = 0.0032
		label.outline_size = 10
		label.modulate = Color.WHITE
		label.outline_modulate = accent.darkened(0.45)
		label.rotation_degrees = Vector3(-90, 45, 0)
		label.position.y = TILE_H + 0.02
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(label)


# --- dynamic state ----------------------------------------------------------------

func tile_position(index: int) -> Vector3:
	return BoardLayout.position_of(index) + Vector3(0, TILE_H, 0)


func show_owner(pid: String, seat: int) -> void:
	if _owner_marks.has(pid):
		_owner_marks[pid].queue_free()
		_owner_marks.erase(pid)
	if seat < 0:
		return
	var flag := Node3D.new()
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.012
	pm.bottom_radius = 0.012
	pm.height = 0.36
	pole.mesh = pm
	pole.material_override = theme.mat(Color("#eeeeee"), 0.4, 0.6)
	pole.position = Vector3(0.3, 0.18, 0.3)
	flag.add_child(pole)
	var cloth := _box(Vector3(0.16, 0.1, 0.01), theme.player_color(seat), 0.6)
	cloth.position = Vector3(0.38, 0.31, 0.3)
	flag.add_child(cloth)
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.40
	rm.outer_radius = 0.44
	ring.mesh = rm
	ring.material_override = theme.mat(theme.player_color(seat), 0.4, 0.0, 0.6)
	ring.position.y = 0.005
	flag.add_child(ring)
	_lots[pid].add_child(flag)
	_owner_marks[pid] = flag
	flag.scale = Vector3.ONE * 0.01
	create_tween().tween_property(flag, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Shows building level 0..3 for a property (0 = empty lot).
func show_level(pid: String, level: int, seat: int, animate := true) -> void:
	if _levels.get(pid, -1) == level:
		return
	_levels[pid] = level
	var lot: Node3D = _lots[pid]
	var old := lot.get_node_or_null("Building")
	if old:
		old.queue_free()
	if level <= 0:
		return
	var b := Node3D.new()
	b.name = "Building"
	lot.add_child(b)
	var accent: Color = theme.player_color(seat) if seat >= 0 else Color.WHITE
	match level:
		1: _house(b, accent)
		2: _apartment(b, accent)
		_: _tower(b, accent)
	if animate:
		b.scale = Vector3(1, 0.01, 1)
		create_tween().tween_property(b, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _house(b: Node3D, accent: Color) -> void:
	var body := _box(Vector3(0.36, 0.24, 0.32), Color("#f5ebe0"), 0.7)
	body.position.y = 0.12
	b.add_child(body)
	var roof := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.42, 0.18, 0.36)
	roof.mesh = pm
	roof.material_override = theme.mat(accent.darkened(0.15), 0.6)
	roof.position.y = 0.33
	b.add_child(roof)
	_windows(b, Vector3(0.36, 0.24, 0.32), 0.12, 1)


func _apartment(b: Node3D, accent: Color) -> void:
	var body := _box(Vector3(0.4, 0.6, 0.38), Color("#e8e2d4"), 0.55)
	body.position.y = 0.3
	b.add_child(body)
	var roof := _box(Vector3(0.44, 0.05, 0.42), accent, 0.5)
	roof.position.y = 0.625
	b.add_child(roof)
	_windows(b, Vector3(0.4, 0.6, 0.38), 0.3, 3)


func _tower(b: Node3D, accent: Color) -> void:
	var body := _box(Vector3(0.38, 1.0, 0.38), Color("#cfe3f0"), 0.2, 0.3)
	body.position.y = 0.5
	b.add_child(body)
	var top := _box(Vector3(0.28, 0.2, 0.28), Color("#e9edf2"), 0.3, 0.3)
	top.position.y = 1.1
	b.add_child(top)
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.06
	cm.height = 0.3
	cap.mesh = cm
	cap.material_override = theme.mat(Color("#f4c542"), 0.25, 0.9, 1.2)
	cap.position.y = 1.35
	b.add_child(cap)
	var band := _box(Vector3(0.4, 0.04, 0.4), accent, 0.4, 0.0, 0.8)
	band.position.y = 0.98
	b.add_child(band)
	_windows(b, Vector3(0.38, 1.0, 0.38), 0.5, 5)


## Warm emissive window strips on the camera-facing sides.
func _windows(b: Node3D, size: Vector3, center_y: float, rows: int) -> void:
	var glow := theme.mat(Color("#ffd27a"), 0.3, 0.0, 1.6)
	for r in rows:
		var y := center_y - size.y * 0.35 + (size.y * 0.7) * (r + 0.5) / rows
		for face in [Vector3(0, 0, 1), Vector3(1, 0, 0)]:
			var w := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(size.x * 0.7, size.y * 0.35 / rows, 0.01) if face.z > 0 else Vector3(0.01, size.y * 0.35 / rows, size.z * 0.7)
			w.mesh = bm
			w.material_override = glow
			w.position = Vector3(face.x * (size.x * 0.5 + 0.006), y, face.z * (size.z * 0.5 + 0.006))
			b.add_child(w)


func set_highlight(index: int) -> void:
	if index < 0:
		_highlight.visible = false
		return
	_highlight.visible = true
	_highlight.position = tile_position(index) + Vector3(0, 0.02, 0)


func pick(camera: Camera3D, screen_pos: Vector2) -> int:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 100.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not hit["collider"].has_meta("tile_index"):
		return -1
	return hit["collider"].get_meta("tile_index")


func _box(size: Vector3, color: Color, roughness := 0.75, metallic := 0.0, emission := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = theme.mat(color, roughness, metallic, emission)
	return m
