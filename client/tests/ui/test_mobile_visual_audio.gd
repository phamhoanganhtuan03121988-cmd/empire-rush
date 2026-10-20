## Mobile visual + audio pass (iPhone feedback): price plates centred on every
## property tile and inside it, owner badges, net worth / cash on narrow
## player cards, tile info with the rent due now, and the audio buses that
## the web build needs (they were silent: buses added at run time are not
## mirrored to the browser's audio graph).
extends UiTestCase


func test_price_plates_are_centred_inside_every_tile() -> void:
	await start_game(2, 4)
	var board: BoardView = main.board
	var cam: Camera3D = main.camera
	var checked := 0
	var sides := {}
	for i in board.config.board_size():
		var sp: Dictionary = board.config.spaces[i]
		if sp["space_type"] != "PROPERTY":
			continue
		var pid: String = sp["property_id"]
		var holder: Node3D = board._price_labels[pid]
		var tile: Node3D = board._tiles[i]
		assert_true(holder.get_parent() == tile, "%s: plate belongs to its tile" % pid)
		# Geometric centre of the slab (x/z), on top of it.
		assert_true(absf(holder.position.x) < 0.001 and absf(holder.position.z) < 0.001, "%s: plate at the tile centre (%s)" % [pid, str(holder.position)])
		assert_true(holder.position.y > BoardView.TILE_H, "%s: plate on top of the slab" % pid)
		# Its footprint (rotated by the text yaw) stays inside the tile and
		# clear of the district band on the street edge.
		var yaw := deg_to_rad(holder.rotation_degrees.y)
		var ext := (absf(cos(yaw)) * BoardView.PRICE_PLATE.x + absf(sin(yaw)) * BoardView.PRICE_PLATE.y) * 0.5
		assert_true(ext <= 0.47 - 0.02, "%s: plate inside the tile (half extent %.3f)" % [pid, ext])
		assert_true(ext <= BoardView.BAND_CENTER - BoardView.BAND_DEPTH * 0.5, "%s: plate clear of the band (%.3f)" % [pid, ext])
		# Text faces the match camera and fits on its plate.
		assert_true(is_equal_approx(holder.rotation_degrees.y, cam.yaw), "%s: text turned to the camera (%.1f vs %.1f)" % [pid, holder.rotation_degrees.y, cam.yaw])
		var l: Label3D = holder.get_node("Text")
		var tw := l.font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x * l.pixel_size
		assert_true(tw <= BoardView.PRICE_PLATE.x - 0.06, "%s: price '%s' fits its plate (%.3f m)" % [pid, l.text, tw])
		# On screen: the plate's centre is the tile's centre.
		var a := cam.unproject_position(holder.global_position)
		var b := cam.unproject_position(tile.global_position + Vector3(0, holder.position.y, 0))
		assert_true(a.distance_to(b) < 0.5, "%s: centred on screen (%.2f px)" % [pid, a.distance_to(b)])
		var g := BoardLayout.grid_of(i)
		sides["bottom" if g.y == 7 else ("left" if g.x == 0 else ("top" if g.y == 0 else "right"))] = true
		checked += 1
	assert_eq(checked, board.config.spaces.filter(func(x): return x["space_type"] == "PROPERTY").size(), "every property tile checked")
	assert_true(checked >= 20, "%d property tiles" % checked)
	assert_eq(sides.size(), 4, "all four sides of the board")
	await stop_game()


func test_owned_tile_shows_owner_badge_not_price() -> void:
	await start_game(2, 4)
	var board: BoardView = main.board
	for k in 2:
		var pid: String = ["P_D1_1", "P_D5_2"][k]
		board.show_owner(pid, k)
		await frames(30)
		assert_false(board._price_labels[pid].visible, "%s: price hidden once owned" % pid)
		var badge: Sprite3D = board._owner_badges.get(pid)
		assert_true(badge != null and badge.visible, "%s: owner badge shown" % pid)
		if badge:
			var tile: Node3D = board._tiles[board._lot_tile[pid]]
			var d := Vector2(badge.position.x - tile.position.x, badge.position.z - tile.position.z).length()
			assert_true(d < 0.4, "%s: badge over its own tile (%.2f)" % [pid, d])
			assert_true(badge.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "badge faces the camera")
			assert_true(badge.position.y < 0.8, "badge below the pawn medallions (%.2f)" % badge.position.y)
		board.show_owner(pid, -1)
		await frames(2)
		assert_false(board._owner_badges.has(pid), "%s: badge removed with the owner" % pid)
		assert_true(board._price_labels[pid].visible, "%s: price back for the bank" % pid)
	await stop_game()


func test_four_players_net_worth_and_cash_fit() -> void:
	tree.root.content_scale_size = Vector2i(720, 1280)
	tree.root.size = Vector2i(360, 640)
	await start_game(4, 4)
	await frames(10)
	assert_true(main.hud._compact_cards, "4 cards across a portrait phone: compact cards")
	for c in main.hud._cards:
		for k in ["name", "role", "cash"]:
			var l: Label = c[k]
			var f := l.get_theme_font("font")
			var w := f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
			var ok := w <= l.size.x + 0.5 or (l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.get_line_count() <= l.max_lines_visible)
			assert_true(ok, "seat %d %s '%s' fits (%.0f of %.0f px)" % [c["seat"], k, l.text, w, l.size.x])
			assert_true(l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "%s never trimmed with …" % k)
		assert_true((c["role"] as Label).text.begins_with("Tài sản"), "net worth shown: %s" % (c["role"] as Label).text)
	await stop_game()


func test_tile_info_shows_owner_and_rent_due_now() -> void:
	await start_game(2, 4)
	var pid := "P_D1_1"
	var idx := -1
	for i in engine().config.board_size():
		if engine().config.spaces[i].get("property_id", "") == pid:
			idx = i
	main.hud.open_tile_info(idx)
	await frames(2)
	var t: String = main.hud._info_label.text
	assert_true(t.contains("Giá mua:") and t.contains("chưa có"), "unowned: price and no owner (%s)" % t)
	give(1, [pid])
	main.hud.open_tile_info(idx)
	await frames(2)
	t = main.hud._info_label.text
	assert_true(t.contains("Tiền thuê hiện tại: %d RC" % engine().gross_rent(pid)), "owned: rent due now (%s)" % t)
	assert_true(t.contains(main.theme_data.player_name(1)), "owner named")
	await stop_game()


func test_audio_buses_exist_from_the_project_layout() -> void:
	# Declared in res://default_bus_layout.tres, not added at run time.
	assert_true(FileAccess.file_exists("res://default_bus_layout.tres") or ResourceLoader.exists("res://default_bus_layout.tres"), "bus layout file in the project")
	var layout: AudioBusLayout = load("res://default_bus_layout.tres")
	assert_true(layout != null, "bus layout loads")
	for bus in ["Music", "SFX"]:
		var i := AudioServer.get_bus_index(bus)
		assert_true(i > 0, "%s bus present at start-up" % bus)
		assert_eq(String(AudioServer.get_bus_send(i)), "Master", "%s sends to Master" % bus)


func test_every_sound_has_a_file_and_mute_toggles() -> void:
	for name in AudioDirector.SPEC:
		assert_true(ResourceLoader.exists(AudioDirector.SFX_DIR % name), "sound file for %s" % name)
	assert_true(ResourceLoader.exists(AudioDirector.MUSIC), "music file")
	await start_game(2, 4)
	var a: AudioDirector = AudioDirector.instance
	var was := GameSettings.muted
	assert_false(a.play("no_such_sound"), "an unknown sound is refused, nothing breaks")
	AudioDirector.toggle_mute()
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "HUD toggle mutes the effects")
	main.hud.refresh_sound_button()
	assert_true(main.hud.sound_button.icon == UiTheme.icon("sound_off"), "button shows muted")
	AudioDirector.toggle_mute()
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "and on again")
	GameSettings.muted = was
	a.apply_settings()
	await stop_game()
