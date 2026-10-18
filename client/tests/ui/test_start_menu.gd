## Phase 4 (playtest readiness): the start menu - a normal launch shows it,
## its choices reach the match, how-to-play text is generated from the rules
## data, and every control is touch-sized inside the safe area.
extends UiTestCase


func _open_menu(extra := {}) -> void:
	MatchSetup.chosen = false
	MatchSetup.players = 4
	MatchSetup.character = "TYCOON"
	MatchSetup.quality = "low"
	MatchSetup.reduced_motion = false
	var args := {"menu": "1"}  # no --players: the menu is shown
	args.merge(extra, true)
	main = load("res://scenes/main.tscn").instantiate()
	main.args_override = args
	tree.root.add_child(main)
	await frames(4)


func test_launch_shows_menu_and_choices_reach_the_match() -> void:
	await _open_menu({"notch": "1"})
	assert_true(main.menu != null, "start menu shown")
	assert_true(main.match_ref == null, "no match before START")
	var m: StartMenu = main.menu
	m.buttons["players_3"].pressed.emit()
	m.buttons["character_NEGOTIATOR"].pressed.emit()
	m.buttons["reduced_motion"].toggled.emit(true)
	m.buttons["reduced_motion"].button_pressed = true
	assert_true(m.buttons["players_3"].get_meta("selected"), "3 players selected")
	assert_false(m.buttons["players_4"].get_meta("selected"), "4 players deselected")
	assert_true(m._ability.text.contains("50%"), "ability text from data: %s" % m._ability.text)
	m.buttons["start"].pressed.emit()
	await frames(4)
	main.presenter.speed = 0.05
	main.match_ref.bot_delay_range = Vector2(0.02, 0.05)
	assert_true(main.menu == null, "menu closed")
	assert_eq(engine().state.players.size(), 3, "3-player match")
	assert_eq(engine().state.player(0)["character_id"], "NEGOTIATOR", "the human plays the chosen character")
	var chars: Array = engine().state.players.map(func(p): return p["character_id"])
	assert_eq(chars, ["NEGOTIATOR", "TYCOON", "INVESTOR"], "bots take the other characters")
	assert_true(main.presenter.reduced_motion, "reduced motion applied")
	assert_true(MatchSetup.chosen, "choices kept for 'play again'")
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "match playable")


func test_menu_controls_are_touch_sized_inside_safe_area() -> void:
	await _open_menu({"notch": "1"})
	await frames(4)
	var m: StartMenu = main.menu
	var safe := Rect2(Vector2(0, 108), m.get_viewport_rect().size - Vector2(0, 108 + 62))
	for id in m.buttons:
		var b: Button = m.buttons[id]
		if not b.is_visible_in_tree():
			continue
		assert_true(b.size.y >= UiTheme.MIN_TOUCH - 0.5, "%s touch height %d" % [id, b.size.y])
		if id in ["start", "how_to"]:
			assert_true(safe.grow(1).encloses(b.get_global_rect()), "%s inside the safe area: %s" % [id, str(b.get_global_rect())])
	m.buttons["how_to"].pressed.emit()
	await frames(3)
	assert_true(m.how_to.visible, "how-to opens")
	var text := m.how_to_label.text
	assert_true(text.contains("%d RC" % main.config.balance["starting_cash"]), "starting cash from rules data")
	assert_true(text.contains("4 người: %d vòng" % main.config.max_rounds_for(4)), "round cap from rules data")
	m.buttons["how_to_close"].pressed.emit()
	assert_false(m.how_to.visible, "how-to closes")


func test_landscape_menu_fits() -> void:
	await _open_menu()
	tree.root.content_scale_size = Vector2i(1280, 720)
	tree.root.size = Vector2i(1280, 720)
	await frames(6)
	var m: StartMenu = main.menu
	var vp := m.get_viewport_rect()
	var b: Button = m.buttons["start"]
	# START is pinned: always fully on screen without scrolling.
	assert_true(vp.grow(1).encloses(b.get_global_rect()), "START on screen in landscape: %s" % str(b.get_global_rect()))
	assert_true(vp.grow(1).encloses(m._card.get_global_rect()), "menu card inside the screen")
	tree.root.content_scale_size = Vector2i(720, 1280)
	tree.root.size = Vector2i(405, 720)


func test_results_offer_menu_button() -> void:
	await start_game(2, 21, {"autoplay": "1"})
	main.autopilot.think_seconds = Vector2(0.01, 0.03)
	Engine.time_scale = 4.0
	for i in 60000:
		await tree.process_frame
		if engine().is_ended() and main.presenter.is_idle():
			break
	Engine.time_scale = 1.0
	await frames(10)
	var b: Button = main.hud.results_menu_button
	assert_true(b != null and b.is_visible_in_tree(), "MENU button on the results sheet")
	assert_true(b.size.y >= UiTheme.MIN_TOUCH - 0.5, "MENU button touch-sized")
