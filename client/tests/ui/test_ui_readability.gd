## M2.1 mobile readability guards: the board is large and never covered by
## HUD panels in portrait, and information text is >= UiTheme.MIN_FONT
## (20 px ≈ 11 pt on a 393 pt-wide phone).
extends UiTestCase


## Screen rect of the 28-tile ring (viewport coordinates).
func board_rect() -> Rect2:
	var cam: Camera3D = main.camera
	var bb := Rect2()
	var first := true
	for i in 28:
		var c: Vector3 = BoardLayout.position_of(i)
		var h := 0.5 * (BoardLayout.TILE - BoardLayout.GAP)
		for d in [Vector3(-h, 0.12, -h), Vector3(h, 0.12, -h), Vector3(h, 0.12, h), Vector3(-h, 0.12, h)]:
			var p := cam.unproject_position(c + d)
			if first:
				bb = Rect2(p, Vector2.ZERO)
				first = false
			else:
				bb = bb.expand(p)
	return bb


func _portrait_iphone() -> void:
	# iPhone 14 Pro aspect (1179x2556) at the 720 px design width.
	tree.root.content_scale_size = Vector2i(720, 1561)
	tree.root.size = Vector2i(393, 852)
	await frames(6)


func _restore() -> void:
	tree.root.content_scale_size = Vector2i(720, 1280)
	tree.root.size = Vector2i(405, 720)


func _assert_board_clear(where: String) -> void:
	await frames(4)
	var b := board_rect()
	var vp: Rect2 = main.hud.get_viewport_rect()
	assert_true(vp.encloses(b), "%s: whole tile ring on screen %s in %s" % [where, b, vp])
	var hud: GameHud = main.hud
	var covers := {"top panel": hud._top, "action panel": hud._action_panel, "results": hud._results}
	for name in covers:
		var c: Control = covers[name]
		if c.visible:
			assert_false(c.get_global_rect().intersects(b.grow(-2)), "%s: %s covers the board" % [where, name])
	for t in hud._toasts.get_children():
		assert_false(t.get_global_rect().intersects(b.grow(-2)), "%s: a toast covers the board" % where)


func test_portrait_board_is_large_and_uncovered() -> void:
	await start_game(4, 3, {"notch": "1"})
	await _portrait_iphone()
	await wait_for_action(ErCommand.ROLL_DICE)
	main.hud.show_toast("toast one")
	main.hud.show_toast("toast two")
	await land_human(13)  # buy prompt
	var b := board_rect()
	var vp: Rect2 = main.hud.get_viewport_rect()
	assert_true(b.size.x >= vp.size.x * 0.80, "board ring spans >= 80%% of the width (%.0f%%)" % (100.0 * b.size.x / vp.size.x))
	await _assert_board_clear("buy prompt")
	# Upgrade menu (longest list) must stay inside its band too.
	give(0, ["P_D1_1", "P_D1_2", "P_D1_3", "P_D2_1", "P_D2_2", "P_D2_3"])
	await land_human(1)
	for a in main.hud.actions:
		if a["button"].has_meta("opens"):
			a["button"].pressed.emit()
	await frames(6)
	assert_true(main.hud.actions.size() >= 6, "upgrade list shown (%d buttons)" % main.hud.actions.size())
	await _assert_board_clear("upgrade menu")
	# Results bottom sheet.
	engine()._end_match("round_cap")
	main.match_ref.events_emitted.emit(engine()._commit())
	await settle()
	await frames(30)
	assert_true(main.hud._results.visible, "results shown")
	await _assert_board_clear("results")
	_restore()


func test_information_text_is_at_least_min_font() -> void:
	await start_game(4, 3, {"notch": "1"})
	await wait_for_action(ErCommand.ROLL_DICE)
	main.hud.show_toast("toast")
	await land_human(13)
	await frames(4)
	var small: Array[String] = []
	for n in main.hud.find_children("*", "Control", true, false):
		if not n.is_visible_in_tree() or n.has_meta("decorative"):
			continue
		if n is Label or n is Button:
			var fs: int = n.get_theme_font_size("font_size")
			var txt: String = n.text
			if not txt.strip_edges().is_empty() and fs < UiTheme.MIN_FONT:
				small.append("%s(%d)" % [txt.substr(0, 20), fs])
	assert_true(small.is_empty(), "text below %d px: %s" % [UiTheme.MIN_FONT, str(small)])


func test_owned_tiles_show_owner_tint() -> void:
	await start_game(2, 3)
	await wait_for_action(ErCommand.ROLL_DICE)
	await land_human(1)
	await press(ErCommand.BUY_PROPERTY)
	await settle()
	var mark: Node3D = main.board._owner_marks.get("P_D1_1")
	assert_true(mark != null, "owner mark exists")
	var mi := mark as MeshInstance3D
	assert_true(mi != null and mi.mesh.get_surface_count() >= 1, "owner mark is a single merged mesh")


## Every property lot (corners included) is aligned to the board grid, so
## district bands, owner frames and buildings never sit diagonally (M2.3).
func test_lots_are_axis_aligned() -> void:
	await start_game(2, 3)
	for pid in main.board._lots:
		var r: float = main.board._lots[pid].rotation.y
		var k := fposmod(r, PI * 0.5)
		assert_true(k < 0.001 or k > PI * 0.5 - 0.001, "%s lot rotation %.3f rad is a multiple of 90 degrees" % [pid, r])
