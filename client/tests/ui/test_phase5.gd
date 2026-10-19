## Phase 5 (visual overhaul, onboarding, game feel): the hero roll button and
## its states, keyboard roll, the pause menu really pausing the match,
## and audio wired to gameplay. (The guided tutorial moved to the Phase 5.1
## coach: test_phase51_coach.gd.)
extends UiTestCase


func _hero() -> Button:
	for a in main.hud.actions:
		if a["type"] == ErCommand.ROLL_DICE:
			return a["button"]
	return null


func test_hero_roll_button_states() -> void:
	await start_game(2, 3)
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "roll offered")
	await frames(3)
	var b := _hero()
	assert_true(b.has_meta("hero"), "roll button is the hero")
	assert_true(b.size.y >= GameHud.HERO_HEIGHT - 0.5, "hero height %d" % b.size.y)
	assert_eq(b.get_theme_font_size("font_size"), GameHud.HERO_FONT, "hero type size")
	assert_true(b.get_theme_stylebox("hover") != b.get_theme_stylebox("normal"), "hover state differs from normal")
	var v := engine().state.state_version
	b.pressed.emit()
	await frames(2)
	var rolling := _hero()
	assert_true(rolling != null and rolling.disabled, "while rolling the hero stays, disabled")
	assert_true(rolling.text == UiText.t("rolling") or rolling.text.contains("="), "rolling label or the result: %s" % rolling.text)
	assert_eq(engine().state.state_version, v + 1, "one roll sent")
	assert_true(await settle(), "presentation finished")


func test_space_key_rolls() -> void:
	await start_game(2, 3)
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "roll offered")
	var v := engine().state.state_version
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	main.hud._unhandled_key_input(ev)
	await frames(2)
	assert_eq(engine().state.state_version, v + 1, "Space rolled once")
	main.hud._unhandled_key_input(ev)
	await frames(2)
	assert_eq(engine().state.state_version, v + 1, "a second Space while rolling sends nothing")


func test_pause_menu_pauses_the_match() -> void:
	await start_game(2, 3)
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "roll offered")
	main.hud.pause_button.pressed.emit()
	await frames(3)
	assert_true(main.pause_menu != null and main.pause_menu.is_visible_in_tree(), "pause menu open")
	assert_true(main.match_ref.lifecycle.is_paused(), "match paused")
	var left: float = main.match_ref.seconds_left()
	await tree.create_timer(0.6).timeout
	assert_true(absf(main.match_ref.seconds_left() - left) < 0.05, "turn timer frozen (%.2f -> %.2f)" % [left, main.match_ref.seconds_left()])
	main.pause_menu.buttons["guide"].pressed.emit()
	await frames(3)
	assert_eq(main.pause_menu.page, "guide", "guide page")
	main.pause_menu.buttons["guide_back"].pressed.emit()
	main.pause_menu.buttons["settings"].pressed.emit()
	await frames(3)
	assert_eq(main.pause_menu.page, "settings", "settings page")
	main.pause_menu.buttons["settings_back"].pressed.emit()
	main.pause_menu.buttons["resume"].pressed.emit()
	await frames(3)
	assert_true(main.pause_menu == null, "pause menu closed")
	assert_false(main.match_ref.lifecycle.is_paused(), "match running again")
	await tree.create_timer(0.4).timeout
	assert_true(main.match_ref.seconds_left() < left - 0.2, "turn timer runs again")


func test_audio_follows_gameplay() -> void:
	await start_game(2, 3)
	var a: AudioDirector = AudioDirector.instance
	assert_true(a != null, "audio director exists")
	a.played.clear()
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "roll offered")
	await press(ErCommand.ROLL_DICE)
	assert_true(await settle(), "move presented")
	for s in ["ui_click", "dice_roll", "dice_land", "step"]:
		assert_true(s in a.played, "%s played (%s)" % [s, str(a.played)])
	if await wait_for_action(ErCommand.BUY_PROPERTY, 60):
		await press(ErCommand.BUY_PROPERTY)
		await settle()
		assert_true("buy" in a.played, "buy sound on purchase")
	# Overlap control: a burst of the same cue plays once.
	a.played.clear()
	for i in 10:
		a.on_cue("upgrade", {})
	assert_eq(a.played.count("upgrade"), 1, "one upgrade sound for a burst of cues")
	# Mute silences the buses.
	GameSettings.muted = true
	a.apply_settings()
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "muted buses")
	GameSettings.muted = false
	a.apply_settings()
