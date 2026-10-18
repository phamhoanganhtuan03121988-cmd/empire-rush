## UI flow tests: every action goes through a real HUD button; every check is
## against the M1 engine (the UI must never decide rules or money).
extends UiTestCase


func test_roll_moves_token_and_dice_match_engine() -> void:
	await start_game(2, 3)
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "roll button offered on the human turn")
	await press(ErCommand.ROLL_DICE)
	await settle()
	var roll: Array = engine().state.last_roll
	assert_eq(roll.size(), 2, "engine rolled")
	assert_eq(main.dice.top_value(0), roll[0], "die 1 shows the engine value")
	assert_eq(main.dice.top_value(1), roll[1], "die 2 shows the engine value")
	var pos: int = engine().state.player(0)["position"]
	assert_eq(main.presenter.presented_pos[0], pos, "token presented on the engine position")
	var expected: Vector3 = main.board.tile_position(pos)
	assert_true(main.presenter.tokens[0].position.distance_to(expected) < 0.4, "token mesh is on the tile")


func test_buy_flow_updates_owner_cash_and_hud() -> void:
	await start_game(2, 3)
	await wait_for_action(ErCommand.ROLL_DICE)
	await land_human(1)  # Ngõ Cá, tier 1, price 60
	assert_eq(engine().state.phase, GameState.AWAIT_BUY, "buy prompt")
	assert_true(find_action(ErCommand.BUY_PROPERTY) != null, "BUY button")
	assert_true(main.hud._action_body.text.contains("60"), "price shown from data")
	await press(ErCommand.BUY_PROPERTY)
	await settle()
	assert_eq(engine().state.owner["P_D1_1"], 0, "engine owner is the human")
	assert_eq(engine().state.player(0)["cash"], 1440, "engine charged 60")
	assert_eq(main.hud._cards[0]["cash"].text, "1440 RC", "HUD shows the engine balance")
	assert_true(main.board._owner_marks.has("P_D1_1"), "ownership marker on the board")


func test_pass_opens_auction_panel() -> void:
	await start_game(3, 3)
	await wait_for_action(ErCommand.ROLL_DICE)
	await land_human(1)
	await press(ErCommand.PASS_PROPERTY)
	await frames(3)
	assert_eq(engine().state.phase, GameState.AUCTION, "auction opened by the engine")
	assert_true(main.hud._action_title.text.contains("Đấu giá"), "auction panel shown")


func test_rent_is_charged_by_engine_and_presented() -> void:
	await start_game(2, 3)
	await wait_for_action(ErCommand.ROLL_DICE)
	give(1, ["P_D7_1"])
	var before_human: int = engine().state.player(0)["cash"]
	var before_owner: int = engine().state.player(1)["cash"]
	await land_human(25)
	assert_eq(before_human - engine().state.player(0)["cash"], 32, "base rent 32 charged by the engine")
	assert_eq(engine().state.player(1)["cash"] - before_owner, 32, "owner credited")
	assert_eq(main.hud._cards[0]["cash"].text, "%d RC" % engine().state.player(0)["cash"], "HUD payer")
	assert_eq(main.hud._cards[1]["cash"].text, "%d RC" % engine().state.player(1)["cash"], "HUD owner")


func test_upgrade_flow_through_submenu() -> void:
	await start_game(2, 3)
	await wait_for_action(ErCommand.ROLL_DICE)
	give(0, ["P_D1_1", "P_D1_2", "P_D1_3"])
	await land_human(1)  # own property -> strategy phase
	assert_eq(engine().state.phase, GameState.STRATEGY, "strategy")
	await wait_for_action("")  # the UPGRADE opener has no command type
	var opener: Button = null
	for a in main.hud.actions:
		if a["button"].has_meta("opens"):
			opener = a["button"]
	assert_true(opener != null and not opener.disabled, "upgrade opener enabled")
	opener.pressed.emit()
	await frames(3)
	var quote: int = engine().upgrade_quote(0, "P_D1_1")["amount"]
	var before: int = engine().state.player(0)["cash"]
	assert_true(await wait_for_action(ErCommand.UPGRADE), "upgrade items listed")
	await press(ErCommand.UPGRADE)
	await settle()
	var upgraded := 0
	for pid in ["P_D1_1", "P_D1_2", "P_D1_3"]:
		upgraded += engine().state.level[pid]
	assert_eq(upgraded, 1, "exactly one level built")
	assert_eq(before - engine().state.player(0)["cash"], quote, "charged the engine quote")
	assert_eq(engine().state.current_seat, 1, "upgrade used the strategic action and ended the turn")


func test_end_turn_button_passes_turn() -> void:
	await start_game(2, 3)
	await wait_for_action(ErCommand.ROLL_DICE)
	await land_human(12)  # Rest tile -> strategy
	await press(ErCommand.END_TURN)
	await frames(2)
	assert_eq(engine().state.current_seat, 1, "turn passed")


func test_buttons_are_touch_sized_and_inside_safe_area() -> void:
	await start_game(2, 3, {"notch": "1"})
	await wait_for_action(ErCommand.ROLL_DICE)
	await land_human(1)
	await frames(3)
	var safe: Rect2 = main.hud.safe_rect()
	assert_true(main.hud.actions.size() >= 2, "buy + pass shown")
	for a in main.hud.actions:
		var b: Button = a["button"]
		var r := b.get_global_rect()
		assert_true(r.size.y >= UiTheme.MIN_TOUCH, "button %s height %.0f >= %d" % [b.text, r.size.y, UiTheme.MIN_TOUCH])
		assert_true(safe.grow(1).encloses(r), "button %s inside the safe area" % b.text)


func test_landscape_layout_keeps_panels_on_screen() -> void:
	await start_game(2, 3)
	tree.root.content_scale_size = Vector2i(1280, 720)
	tree.root.size = Vector2i(1280, 720)
	await frames(4)
	await wait_for_action(ErCommand.ROLL_DICE)
	await frames(3)
	var vp: Rect2 = main.hud.get_viewport_rect()
	assert_true(vp.size.x > vp.size.y, "landscape viewport")
	var top: Rect2 = main.hud._top.get_global_rect()
	var act: Rect2 = main.hud._action_panel.get_global_rect()
	assert_true(vp.grow(1).encloses(top), "top panel on screen")
	assert_true(vp.grow(1).encloses(act), "action panel on screen")
	assert_false(top.intersects(act), "panels do not overlap in landscape")
	tree.root.content_scale_size = Vector2i(720, 1280)
	tree.root.size = Vector2i(405, 720)


func test_full_match_completes_with_results_screen() -> void:
	# Autopilot plays the human seat through HUD buttons; bots play the rest.
	await start_game(2, 21, {"autoplay": "1"})
	main.autopilot.think_seconds = Vector2(0.01, 0.03)
	Engine.time_scale = 4.0
	var ok := false
	for i in 60000:
		await tree.process_frame
		if engine().is_ended() and main.presenter.is_idle():
			ok = true
			break
	Engine.time_scale = 1.0
	assert_true(ok, "match ended")
	await frames(30)
	assert_true(main.hud._results.visible, "results screen shown")
	assert_true(main.autopilot.presses > 10, "human seat was played through HUD buttons (%d presses)" % main.autopilot.presses)
	for seat in engine().state.players.size():
		assert_eq(main.presenter.presented_cash[seat], engine().state.player(seat)["cash"], "presented cash == engine cash (seat %d)" % seat)
	var inv := Invariants.check(engine())
	assert_true(inv.is_empty(), "engine invariants: %s" % str(inv))
	assert_true(engine().state.end_reason in ["round_cap", "last_solvent", "time_cap"], "valid end")


## Phase 2 (A4): every explicit line of an action label fits its button, so
## automatic wrapping never splits "cấp 2" or a price onto its own line.
func test_upgrade_item_lines_fit_their_buttons() -> void:
	await start_game(2, 3, {"notch": "1"})
	await wait_for_action(ErCommand.ROLL_DICE)
	give(0, ["P_D1_1", "P_D1_2", "P_D1_3", "P_D2_1", "P_D2_2", "P_D2_3"])
	await land_human(1)
	await wait_for_action("")
	for a in main.hud.actions:
		if a["button"].has_meta("opens"):
			a["button"].pressed.emit()
	await frames(3)
	assert_true(await wait_for_action(ErCommand.UPGRADE), "upgrade items listed")
	await frames(3)
	var checked := 0
	for a in main.hud.actions:
		var b: Button = a["button"]
		var font := b.get_theme_font("font")
		var fs := b.get_theme_font_size("font_size")
		var sb := b.get_theme_stylebox("normal")
		var icon_w := 0.0
		if b.icon != null:
			var maxw := b.get_theme_constant("icon_max_width")
			icon_w = (mini(maxw, b.icon.get_width()) if maxw > 0 else b.icon.get_width()) + b.get_theme_constant("h_separation")
		var avail := b.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT) - icon_w
		for line in b.text.split("\n"):
			var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			assert_true(w <= avail, "'%s' fits (%d <= %d px)" % [line, w, avail])
			checked += 1
	assert_true(checked >= 6, "checked %d label lines" % checked)
