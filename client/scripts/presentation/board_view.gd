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
	# All static board geometry goes into ONE merged mesh (a few surfaces)
	# instead of ~120 separate MeshInstance3D nodes (M2.1 rendering pass).
	var st := MeshMerger.new()
	_build_base(st)
	_build_center_city(st)
	for i in config.board_size():
		_build_tile(i, st)
	add_child(st.instance("StaticBoard"))
	_highlight = MeshInstance3D.new()
	var hm := TorusMesh.new()
	hm.inner_radius = 0.38
	hm.outer_radius = 0.46
	hm.rings = 32
	hm.ring_segments = 8
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


func _build_base(st: MeshMerger) -> void:
	# Stone quay slab under the ring of tiles, with a darker skirt.
	st.add_box(Vector3(8.7, BOARD_H, 8.7), Vector3(0, -BOARD_H * 0.5, 0), Color("#d9cdb4"), MeshMerger.std(0.85))
	st.add_box(Vector3(9.0, 0.12, 9.0), Vector3(0, -BOARD_H + 0.02, 0), Color("#8a7b66"), MeshMerger.std(0.9))
	# Inner park lawn.
	st.add_box(Vector3(5.9, 0.06, 5.9), Vector3.ZERO, Color("#7fb069"), MeshMerger.std(0.95))


func _build_center_city(st: MeshMerger) -> void:
	# Decorative skyline: a central landmark tower plus a ring of blocks,
	# roads and trees. Purely visual.
	for axis in [Vector3(5.2, 0.02, 0.45), Vector3(0.45, 0.02, 5.2)]:
		st.add_box(axis, Vector3(0, 0.04, 0), Color("#5b5f66"), MeshMerger.std(0.95))
	# Landmark tower (gold crown) in the middle.
	st.add_box(Vector3(0.7, 2.2, 0.7), Vector3(0, 1.13, 0), Color("#e9e4d8"), MeshMerger.std(0.4, 0.1))
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.42
	cm.height = 0.6
	cm.radial_segments = 24
	cm.rings = 1
	st.add_mesh(cm, Transform3D(Basis(), Vector3(0, 2.53, 0)), Color("#f4c542"), MeshMerger.glow(0.6, 0.25, 0.8))
	# Blocks in four quadrants.
	var palette := [Color("#f1e3c6"), Color("#cfd8dc"), Color("#f6d5c3"), Color("#d7ccc8"), Color("#bfd7ea")]
	for qx in [-1, 1]:
		for qz in [-1, 1]:
			for k in 4:
				var h := _rng.randf_range(0.4, 1.4)
				var col: Color = palette[_rng.randi() % palette.size()]
				var off := Vector3(0.75 + (k % 2) * 0.85, 0, 0.75 + (k / 2) * 0.85)
				var pos := Vector3(qx * off.x, h * 0.5 + 0.03, qz * off.z)
				st.add_box(Vector3(0.55, h, 0.55), pos, col, MeshMerger.std(0.6))
				st.add_box(Vector3(0.6, 0.06, 0.6), pos + Vector3(0, h * 0.5 + 0.03, 0), Color("#7a8a99"), MeshMerger.std(0.7))
	var tm := CylinderMesh.new()
	tm.top_radius = 0.03
	tm.bottom_radius = 0.04
	tm.height = 0.18
	tm.radial_segments = 6
	tm.rings = 1
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.3
	sm.radial_segments = 10
	sm.rings = 5
	for i in 14:
		var ang := TAU * i / 14.0
		var pos := Vector3(cos(ang) * 2.55, 0.03, sin(ang) * 2.55)
		st.add_mesh(tm, Transform3D(Basis(), pos + Vector3(0, 0.09, 0)), Color("#6d4c41"), MeshMerger.std(0.9))
		st.add_mesh(sm, Transform3D(Basis(), pos + Vector3(0, 0.3, 0)), Color("#4e8f3a").lerp(Color("#7cb342"), _rng.randf()), MeshMerger.std(0.9))


# --- tiles -----------------------------------------------------------------------

func _build_tile(i: int, st: MeshMerger) -> void:
	var root := Node3D.new()
	root.name = "Tile%02d" % i
	root.position = BoardLayout.position_of(i)
	add_child(root)
	_tiles.append(root)
	var sp: Dictionary = config.spaces[i]
	var stype: String = sp["space_type"]
	var size := Vector3(BoardLayout.TILE - BoardLayout.GAP, TILE_H, BoardLayout.TILE - BoardLayout.GAP)
	var base_color := Color("#f7f1e3")
	var accent: Color
	if stype == "PROPERTY":
		accent = theme.district_color(sp["district_id"])
	else:
		accent = Color(theme.special[stype]["color"])
		base_color = accent.lerp(Color.WHITE, 0.55)
	st.add_box(size, root.position + Vector3(0, TILE_H * 0.5, 0), base_color, MeshMerger.std(0.7))
	# Pick body for tap-to-inspect (no rendering cost).
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
	if stype == "PROPERTY":
		# District colour band on the inner edge (classic board read).
		var flat_in := Vector3(signf(inward.x) if absf(inward.x) > 0.5 else 0.0, 0, signf(inward.z) if absf(inward.z) > 0.5 else 0.0)
		var band_size := Vector3(size.x, 0.03, size.z * 0.28) if absf(flat_in.x) == 0.0 else Vector3(size.x * 0.28, 0.03, size.z)
		st.add_box(band_size, root.position + Vector3(flat_in.x * size.x * 0.36, TILE_H + 0.015, flat_in.z * size.z * 0.36), accent, MeshMerger.std(0.5))
		var lot := Node3D.new()
		lot.position = Vector3(-flat_in.x * 0.1, TILE_H, -flat_in.z * 0.1)
		root.add_child(lot)
		_lots[sp["property_id"]] = lot
		_levels[sp["property_id"]] = -1
	else:
		var label := Label3D.new()
		var glyph: String = theme.special[stype].get("glyph", theme.special[stype]["label"])
		label.text = glyph
		label.font_size = 64
		# Single glyphs are drawn large so they stay legible on a phone.
		label.pixel_size = 0.0105 if glyph.length() == 1 else 0.0042
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
	var c := theme.player_color(seat)
	var lot: Node3D = _lots[pid]
	var mm := MeshMerger.new()
	# Owner tint over the whole tile top (readable at phone size), then ring,
	# pole and flag - one merged mesh per owned lot.
	var span := BoardLayout.TILE - BoardLayout.GAP - 0.06
	mm.add_box(Vector3(span, 0.012, span), Vector3(-lot.position.x, 0.004, -lot.position.z), c.lerp(Color.WHITE, 0.45), MeshMerger.std(0.7))
	var pm := CylinderMesh.new()
	pm.top_radius = 0.012
	pm.bottom_radius = 0.012
	pm.height = 0.36
	pm.radial_segments = 6
	pm.rings = 1
	mm.add_mesh(pm, Transform3D(Basis(), Vector3(0.3, 0.18, 0.3)), Color("#eeeeee"), MeshMerger.std(0.4, 0.6))
	mm.add_box(Vector3(0.16, 0.1, 0.01), Vector3(0.38, 0.31, 0.3), c, MeshMerger.std(0.6))
	var rm := TorusMesh.new()
	rm.inner_radius = 0.40
	rm.outer_radius = 0.44
	rm.rings = 24
	rm.ring_segments = 6
	mm.add_mesh(rm, Transform3D(Basis(), Vector3(0, 0.012, 0)), c, MeshMerger.glow(0.6, 0.4))
	var flag := mm.instance("Owner")
	lot.add_child(flag)
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
		# Detach now: a queued node would keep the name and the new building
		# would be auto-renamed, so the next upgrade could not find it.
		lot.remove_child(old)
		old.queue_free()
	if level <= 0:
		return
	var accent: Color = theme.player_color(seat) if seat >= 0 else Color.WHITE
	var mm := MeshMerger.new()
	match level:
		1: _house(mm, accent)
		2: _apartment(mm, accent)
		_: _tower(mm, accent)
	var b := mm.instance("Building")
	lot.add_child(b)
	if animate:
		b.scale = Vector3(1, 0.01, 1)
		create_tween().tween_property(b, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _house(mm: MeshMerger, accent: Color) -> void:
	mm.add_box(Vector3(0.36, 0.24, 0.32), Vector3(0, 0.12, 0), Color("#f5ebe0"), MeshMerger.std(0.7))
	var pm := PrismMesh.new()
	pm.size = Vector3(0.42, 0.18, 0.36)
	mm.add_mesh(pm, Transform3D(Basis(), Vector3(0, 0.33, 0)), accent.darkened(0.15), MeshMerger.std(0.6))
	_windows(mm, Vector3(0.36, 0.24, 0.32), 0.12, 1)


func _apartment(mm: MeshMerger, accent: Color) -> void:
	mm.add_box(Vector3(0.4, 0.6, 0.38), Vector3(0, 0.3, 0), Color("#e8e2d4"), MeshMerger.std(0.6))
	mm.add_box(Vector3(0.44, 0.05, 0.42), Vector3(0, 0.625, 0), accent, MeshMerger.std(0.5))
	_windows(mm, Vector3(0.4, 0.6, 0.38), 0.3, 3)


func _tower(mm: MeshMerger, accent: Color) -> void:
	mm.add_box(Vector3(0.38, 1.0, 0.38), Vector3(0, 0.5, 0), Color("#cfe3f0"), MeshMerger.std(0.3, 0.3))
	mm.add_box(Vector3(0.28, 0.2, 0.28), Vector3(0, 1.1, 0), Color("#e9edf2"), MeshMerger.std(0.3, 0.3))
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.06
	cm.height = 0.3
	cm.radial_segments = 8
	cm.rings = 1
	mm.add_mesh(cm, Transform3D(Basis(), Vector3(0, 1.35, 0)), Color("#f4c542"), MeshMerger.glow(1.2, 0.25, 0.9))
	mm.add_box(Vector3(0.4, 0.04, 0.4), Vector3(0, 0.98, 0), accent, MeshMerger.glow(0.8, 0.4))
	_windows(mm, Vector3(0.38, 1.0, 0.38), 0.5, 5)


## Warm emissive window strips on the camera-facing sides.
func _windows(mm: MeshMerger, size: Vector3, center_y: float, rows: int) -> void:
	for r in rows:
		var y := center_y - size.y * 0.35 + (size.y * 0.7) * (r + 0.5) / rows
		mm.add_box(Vector3(size.x * 0.7, size.y * 0.35 / rows, 0.01), Vector3(0, y, size.z * 0.5 + 0.006), Color("#ffd27a"), MeshMerger.glow(1.6))
		mm.add_box(Vector3(0.01, size.y * 0.35 / rows, size.z * 0.7), Vector3(size.x * 0.5 + 0.006, y, 0), Color("#ffd27a"), MeshMerger.glow(1.6))


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
