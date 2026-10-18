## EMPIRE RUSH asset forge (M2.3): bakes the production kit into real project
## assets. Run through scripts/forge_assets.sh (two stages with an import in
## between, because materials can only reference imported textures):
##   --stage=textures  -> client/assets/textures/*.png (+ .import settings)
##   --stage=models    -> client/assets/materials/*.tres, client/assets/models/**.res
## Output is deterministic (fixed seeds). Every generated file is listed in
## docs/ASSET_REGISTER.csv (GEN-003..).
extends SceneTree

const TEX := "res://assets/textures/"
const MATS := "res://assets/materials/"
const MODELS := "res://assets/models/"

## name -> [albedo texture or "", normal texture or "", roughness, metallic, uv scale, extra]
const MATERIALS := {
	"plaster": ["plaster_albedo", "plaster_normal", 0.85, 0.0, 3.0, {}],
	"concrete": ["plaster_albedo", "plaster_normal", 0.8, 0.0, 5.0, {}],
	"paving": ["paving_albedo", "paving_normal", 0.82, 0.0, 2.0, {}],
	"stone_wall": ["stone_wall_albedo", "stone_wall_normal", 0.88, 0.0, 1.4, {}],
	"asphalt": ["asphalt_albedo", "asphalt_normal", 0.92, 0.0, 2.0, {}],
	"grass": ["grass_albedo", "", 0.95, 0.0, 1.2, {}],
	"roof_tile": ["roof_tile_albedo", "roof_tile_normal", 0.72, 0.0, 4.0, {}],
	"wood": ["wood_albedo", "wood_normal", 0.7, 0.0, 3.0, {}],
	"foliage": ["foliage_albedo", "foliage_normal", 0.9, 0.0, 5.0, {}],
	"marble": ["marble_albedo", "", 0.32, 0.0, 0.9, {}],
	"glass": ["", "", 0.06, 0.45, 1.0, {"specular": 0.8}],
	"metal": ["", "", 0.38, 0.6, 1.0, {}],
	"gold": ["", "", 0.3, 0.75, 1.0, {}],
	"fabric": ["", "", 0.95, 0.0, 1.0, {}],
	"paint": ["", "", 0.45, 0.0, 1.0, {}],
	"enamel": ["", "", 0.22, 0.1, 1.0, {"clearcoat": 0.6}],
}


func _initialize() -> void:
	var stage := "all"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			stage = a.trim_prefix("--stage=")
	if stage == "textures":
		_textures()
		_ui()
	elif stage == "models":
		_materials()
		_models()
	else:
		printerr("use --stage=textures or --stage=models")
		quit(2)
		return
	quit(0)


# --- textures ------------------------------------------------------------------------

func _save_png(img: Image, name: String, normal := false) -> void:
	var path := TEX + name + ".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEX))
	img.save_png(ProjectSettings.globalize_path(path))
	# Import settings: VRAM-compressed with mipmaps (ETC2/ASTC on phones),
	# normal maps flagged so they use the right compression.
	var imp := FileAccess.open(ProjectSettings.globalize_path(path + ".import"), FileAccess.WRITE)
	imp.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=2\ncompress/normal_map=%d\nmipmaps/generate=true\n' % (1 if normal else 2))
	imp.close()
	print("TEX ", path)


func _textures() -> void:
	var sets := {
		"paving": TexGen.paving(), "stone_wall": TexGen.stone_wall(), "asphalt": TexGen.asphalt(),
		"grass": TexGen.grass(), "roof_tile": TexGen.roof_tiles(), "plaster": TexGen.plaster(),
		"wood": TexGen.wood(), "foliage": TexGen.foliage(), "marble": TexGen.marble(),
	}
	for name in sets:
		var imgs: Array = sets[name]
		_save_png(imgs[0], name + "_albedo")
		if imgs.size() > 1:
			_save_png(imgs[1], name + "_normal", true)
	# The contact shadow is alpha-only and small: keep it lossless.
	var cs := TexGen.contact_shadow()
	cs.save_png(ProjectSettings.globalize_path(TEX + "contact_shadow.png"))
	print("TEX ", TEX + "contact_shadow.png")


# --- HUD skin ------------------------------------------------------------------------

func _ui() -> void:
	var dir := "res://assets/ui/skin/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var skins := UiGen.all()
	for name in skins:
		var path: String = dir + name + ".png"
		skins[name].save_png(ProjectSettings.globalize_path(path))
		# 2D UI: lossless, no mipmaps (drawn 1:1 or 9-sliced).
		var imp := FileAccess.open(ProjectSettings.globalize_path(path + ".import"), FileAccess.WRITE)
		imp.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=false\n')
		imp.close()
		print("UI ", path)


# --- materials -------------------------------------------------------------------------

func _materials() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATS))
	for name in MATERIALS:
		var d: Array = MATERIALS[name]
		var m := StandardMaterial3D.new()
		m.resource_name = name
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = d[2]
		m.metallic = d[3]
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if d[0] != "" or d[1] != "":
			# World-space triplanar mapping: constant texel density on every
			# kit piece without hand-made UVs, and textures line up across
			# merged pieces.
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE * float(d[4])
			m.uv1_triplanar_sharpness = 4.0
		if d[0] != "":
			m.albedo_texture = load(TEX + d[0] + ".png")
		if d[1] != "":
			m.normal_enabled = true
			m.normal_texture = load(TEX + d[1] + ".png")
			m.normal_scale = 0.8
		var extra: Dictionary = d[5]
		if extra.has("specular"):
			m.metallic_specular = extra["specular"]
		if extra.has("clearcoat"):
			m.clearcoat_enabled = true
			m.clearcoat = extra["clearcoat"]
			m.clearcoat_roughness = 0.2
		_save(m, MATS + name + ".tres")
	var glow := ShaderMaterial.new()
	glow.resource_name = "window_glow"
	glow.shader = load("res://scripts/presentation/vertex_glow.gdshader")
	glow.set_shader_parameter("energy", 0.85)
	glow.set_shader_parameter("roughness_v", 0.3)
	glow.set_shader_parameter("metallic_v", 0.0)
	_save(glow, MATS + "window_glow.tres")
	var cs := StandardMaterial3D.new()
	cs.resource_name = "contact_shadow"
	cs.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cs.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cs.vertex_color_use_as_albedo = true
	cs.albedo_color = Color(1, 1, 1, 1)
	cs.albedo_texture = load(TEX + "contact_shadow.png")
	cs.render_priority = -1
	_save(cs, MATS + "contact_shadow.tres")


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		printerr("SAVE FAILED ", path, " ", err)
	res.take_over_path(path)
	print("RES ", path)


# --- models ------------------------------------------------------------------------------

func _save_model(k: ModelKit, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var mesh := k.build()
	mesh.resource_name = path.get_file().get_basename()
	var err := ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		printerr("SAVE FAILED ", path, " ", err)
	print("MODEL %s tris=%d surfaces=%d" % [path, k.triangle_count(), mesh.get_surface_count()])


func _models() -> void:
	# Load the just-saved materials from disk so meshes reference them by path.
	MeshMerger._materials.clear()
	var theme: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/board_theme.json"))
	var districts: Dictionary = theme["districts"]
	var seed_value := 1000
	for did in Buildings.TABLE:
		for lv in [1, 2, 3]:
			seed_value += 1
			var k := Buildings.build(did, lv, Color(districts[did]["color"]), seed_value)
			_save_model(k, MODELS + "buildings/%s_l%d.res" % [did.to_lower(), lv])
	var kit := MODELS + "kit/"
	for mat_name in ["marble", "paving", "asphalt", "grass", "stone_wall", "metal", "gold", "paint", "plaster", "window_glow", "foliage", "wood"]:
		_save_model(Props.unit_box(mat_name), kit + "unit_%s.res" % mat_name)
	_save_model(Props.tile_base(), kit + "tile_base.res")
	_save_model(Props.tile_top(), kit + "tile_top.res")
	_save_model(Props.lot_plaza(), kit + "lot_plaza.res")
	_save_model(Props.streetlight(), kit + "streetlight.res")
	for v in 3:
		_save_model(Props.tree_round(v), kit + "tree_round_%d.res" % v)
	_save_model(Props.tree_cone(), kit + "tree_cone.res")
	_save_model(Props.palm(), kit + "palm.res")
	_save_model(Props.bench(), kit + "bench.res")
	_save_model(Props.planter(), kit + "planter.res")
	_save_model(Props.bollard(), kit + "bollard.res")
	_save_model(Props.boat_small(Color("#c0392b")), kit + "boat_red.res")
	_save_model(Props.boat_small(Color("#2a6f97")), kit + "boat_blue.res")
	_save_model(Props.yacht(), kit + "yacht.res")
	_save_model(Props.pier(), kit + "pier.res")
	_save_model(Props.fountain(), kit + "fountain.res")
	_save_model(Props.landmark(), kit + "landmark.res")
	for v in 4:
		_save_model(Props.bg_block(v), kit + "bg_block_%d.res" % v)
	_save_model(Props.flag_pole(), kit + "flag_pole.res")
	_save_model(Props.flag_cloth(), kit + "flag_cloth.res")
	var players: Array = theme["players"]
	for seat in players.size():
		_save_model(Props.pawn(seat, Color(players[seat]["color"])), MODELS + "tokens/pawn_%d.res" % seat)
	_save_model(Props.die(0.34), MODELS + "dice/die.res")
