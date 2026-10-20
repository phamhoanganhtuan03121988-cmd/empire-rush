## M2.3 production kit guards: every asset the game loads exists, uses the
## shared material library, stays inside its triangle budget, and reads
## correctly (upgrade levels grow, districts differ, dice faces match rules).
extends TestCase

const DISTRICTS := ["D1", "D2", "D3", "D4", "D5", "D6", "D7"]
const BUILDING_TRI_BUDGET := 8000
const KIT_PIECES := ["tile_base", "tile_top", "lot_plaza", "streetlight", "tree_round_0", "tree_round_1", "tree_round_2",
	"tree_cone", "palm", "bench", "planter", "bollard", "boat_red", "boat_blue", "yacht", "pier", "fountain",
	"landmark", "bg_block_0", "bg_block_1", "bg_block_2", "bg_block_3", "flag_pole", "flag_cloth",
	"unit_marble", "unit_paving", "unit_asphalt", "unit_grass", "unit_stone_wall", "unit_metal", "unit_gold",
	"unit_paint", "unit_plaster", "unit_window_glow", "unit_foliage", "unit_wood"]


func _tris(m: Mesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		var idx = m.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		n += (idx.size() if idx != null and not idx.is_empty() else m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX].size()) / 3
	return n


func _materials_ok(m: Mesh, what: String) -> void:
	for s in m.get_surface_count():
		var mat := m.surface_get_material(s)
		assert_true(mat != null and mat.resource_path.begins_with("res://assets/materials/"),
			"%s surface %d uses a library material (%s)" % [what, s, mat.resource_path if mat else "none"])


func test_every_building_level_exists_and_is_in_budget() -> void:
	for d in DISTRICTS:
		for lv in [1, 2, 3]:
			var path := "res://assets/models/buildings/%s_l%d.res" % [d.to_lower(), lv]
			assert_true(ResourceLoader.exists(path), path)
			var m: Mesh = load(path)
			assert_true(m != null and m.get_surface_count() > 0, "%s loads" % path)
			assert_true(_tris(m) <= BUILDING_TRI_BUDGET, "%s: %d tris <= %d" % [path, _tris(m), BUILDING_TRI_BUDGET])
			_materials_ok(m, path)
			var aabb := m.get_aabb()
			# Fits the lot (0.56 m footprint) and the camera framing (1.3 m).
			assert_true(aabb.size.x <= 0.6 and aabb.size.z <= 0.6, "%s footprint %s" % [path, aabb.size])
			assert_true(aabb.end.y <= 1.32, "%s height %.2f" % [path, aabb.end.y])


func test_upgrade_levels_grow_and_districts_differ() -> void:
	var l3_heights := {}
	for d in DISTRICTS:
		var h: Array = []
		for lv in [1, 2, 3]:
			h.append(load("res://assets/models/buildings/%s_l%d.res" % [d.to_lower(), lv]).get_aabb().end.y)
		assert_true(h[0] < h[1] and h[1] < h[2], "%s levels grow in height %s" % [d, str(h)])
		assert_true(h[2] - h[0] >= 0.35, "%s L3 clearly taller than L1" % d)
		l3_heights[snappedf(h[2], 0.01)] = true
	# Phase 3: every level sits in the art-direction height band (L1 0.3-0.45,
	# L2 0.6-0.8, L3 1.0-1.3 m, +-0.03 m) and steps up clearly, so the
	# upgrade reads at phone size (D4 L2/L3 were 0.59/0.61 m before).
	var bands := [[0.27, 0.48], [0.57, 0.83], [0.97, 1.33]]
	for d in ["D1", "D2", "D3", "D4", "D5", "D6", "D7"]:
		var hs: Array = []
		for lv in 3:
			var m: Mesh = load("res://assets/models/buildings/%s_l%d.res" % [d.to_lower(), lv + 1])
			hs.append(m.get_aabb().end.y)
			assert_true(hs[lv] >= bands[lv][0] and hs[lv] <= bands[lv][1], "%s L%d height %.2f in %s" % [d, lv + 1, hs[lv], str(bands[lv])])
		assert_true(hs[1] - hs[0] >= 0.2 and hs[2] - hs[1] >= 0.3, "%s level steps %.2f / %.2f" % [d, hs[1] - hs[0], hs[2] - hs[1]])
	# Distinct silhouettes: the L3 landmarks do not share one height.
	assert_true(l3_heights.size() >= 6, "L3 buildings differ (%d distinct heights)" % l3_heights.size())


func test_kit_pieces_tokens_and_dice_exist() -> void:
	for k in KIT_PIECES:
		var path := "res://assets/models/kit/%s.res" % k
		assert_true(ResourceLoader.exists(path), path)
		_materials_ok(load(path), path)
	for s in 4:
		var p := "res://assets/models/tokens/pawn_%d.res" % s
		assert_true(ResourceLoader.exists(p), p)
	# Pawns differ by shape, not only colour.
	var heights := {}
	for s in 4:
		heights[snappedf(load("res://assets/models/tokens/pawn_%d.res" % s).get_aabb().end.y, 0.005)] = true
	assert_eq(heights.size(), 4, "four distinct pawn silhouettes")


## The baked die must show the face DiceView.top_value() reports, or the
## dice would contradict the rules engine.
func test_die_faces_match_rules_mapping() -> void:
	var m: Mesh = load("res://assets/models/dice/die.res")
	var arr := m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var per_face := {}
	var red_up := 0
	for i in v.size():
		var col := c[i]
		var is_red := col.r > 0.5 and col.g < 0.4
		var is_dark := col.r < 0.2 and col.g < 0.2
		if not (is_red or is_dark):
			continue
		var best := 0
		var best_dot := -9.0
		for val in DiceView.FACE_NORMAL:
			var d: float = v[i].dot(DiceView.FACE_NORMAL[val])
			if d > best_dot:
				best_dot = d
				best = val
		per_face[best] = per_face.get(best, 0) + 1
		if is_red and best == 1:
			red_up += 1
	assert_true(red_up > 0, "the red pip is on face 1 (up)")
	var unit: float = per_face.get(1, 0)
	for val in [2, 3, 4, 5, 6]:
		assert_eq(per_face.get(val, 0), int(unit) * val, "face %d has %d pips" % [val, val])


func test_font_and_icons() -> void:
	var f: Font = UiTheme.font("Bold")
	assert_true(f != null, "Be Vietnam Pro loads")
	for ch in ["Đ", "ệ", "ữ", "ạ", "ố", "Ả"]:
		assert_true(f.has_char(ch.unicode_at(0)), "font has %s" % ch)
	for icon in GameHud.ACTION_ICONS.values():
		assert_true(ResourceLoader.exists(UiTheme.ICON_DIR % icon), "icon %s" % icon)
	var theme := ThemeData.load_default()
	for st in theme.special:
		var name: String = theme.special[st].get("icon", "")
		assert_true(name != "" and ResourceLoader.exists(UiTheme.ICON_DIR % name), "special tile %s icon" % st)
	for cid in theme.character_icons:
		assert_true(ResourceLoader.exists(UiTheme.ICON_DIR % theme.character_icons[cid]), "character %s emblem" % cid)
	for kind in BoardView.MARKERS:
		assert_true(ResourceLoader.exists(UiTheme.ICON_DIR % BoardView.MARKERS[kind][0]), "marker %s icon" % kind)
