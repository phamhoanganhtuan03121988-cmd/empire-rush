## Renders the baked production kit as contact sheets (needs a renderer:
## xvfb + lavapipe). Used to review assets and for docs/media.
##   godot --path client --resolution 1600x1000 --script res://tests/capture/asset_sheet.gd -- --out=DIR [--sheet=buildings|props]
extends SceneTree

var out := ""
var sheet := "buildings"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		if a.begins_with("--sheet="):
			sheet = a.trim_prefix("--sheet=")
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _env(world: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#20283a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b8c6dc")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#ffe2b8")
	sun.light_energy = 1.4
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.shadow_enabled = true
	world.add_child(sun)


func _place(world: Node3D, mesh_path: String, pos: Vector3, label: String) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = load(mesh_path)
	mi.position = pos
	world.add_child(mi)
	var l := Label3D.new()
	l.text = label
	l.font_size = 48
	l.pixel_size = 0.003
	l.position = pos + Vector3(0, 0.02, 0.42)
	l.rotation_degrees = Vector3(-60, 0, 0)
	l.modulate = Color(1, 1, 1, 0.9)
	world.add_child(l)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	_env(world)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#3a4252")
	floor.material_override = fm
	world.add_child(floor)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	if sheet == "buildings":
		var ds := ["D1", "D2", "D3", "D4", "D5", "D6", "D7"]
		for i in ds.size():
			for lv in [1, 2, 3]:
				_place(world, "res://assets/models/buildings/%s_l%d.res" % [ds[i].to_lower(), lv],
					Vector3((i - 3) * 0.95, 0, (2 - lv) * 1.15), "%s L%d" % [ds[i], lv])
		cam.position = Vector3(0, 4.6, 5.0)
		cam.look_at(Vector3(0, 0.3, -0.2))
		cam.fov = 48
	else:
		var items := ["tile_base", "tile_top", "lot_plaza", "streetlight", "tree_round_0", "tree_round_1",
			"tree_cone", "palm", "bench", "planter", "bollard", "boat_red", "yacht", "pier", "fountain",
			"bg_block_0", "bg_block_1", "bg_block_2", "bg_block_3", "landmark", "flag_pole", "flag_cloth"]
		for i in items.size():
			var x := (i % 8 - 3.5) * 1.1
			var z := (i / 8 - 1) * 1.3
			_place(world, "res://assets/models/kit/%s.res" % items[i], Vector3(x, 0, z), items[i])
		for s in 4:
			_place(world, "res://assets/models/tokens/pawn_%d.res" % s, Vector3(-3.0 + s * 0.45, 0, 2.2), "pawn %d" % s)
		_place(world, "res://assets/models/dice/die.res", Vector3(-0.8, 0.17, 2.2), "die")
		cam.position = Vector3(0, 5.2, 6.4)
		cam.look_at(Vector3(0, 0.2, 0.3))
		cam.fov = 55
	for i in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/asset_sheet_%s.png" % [out, sheet])
	print("SHEET ", out, "/asset_sheet_", sheet, ".png")
	quit()
