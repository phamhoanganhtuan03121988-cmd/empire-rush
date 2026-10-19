## Phase 4/5: the entry flow. A normal launch shows the title; CHƠI leads
## through the intro (first time) to the setup page; the choices (players,
## character, colour, name) reach the match; the how-to and intro texts are
## generated from the rules data; settings persist and apply; every control
## is touch-sized inside the safe area. Buttons are pressed only when they
## are visible on the current page (as a player would).
extends UiTestCase


func _open_menu(extra := {}) -> void:
	MatchSetup.chosen = false
	MatchSetup.tutorial = false
	MatchSetup.players = 4
	MatchSetup.character = "TYCOON"
	MatchSetup.quality = "low"
	MatchSetup.reduced_motion = false
	MatchSetup.color_index = 0
	MatchSetup.player_name = "Bạn"
	MatchSetup.persona = "khoi"
	GameSettings.intro_seen = false
	GameSettings.muted = false
	GameSettings.music_volume = 0.6
	GameSettings.sfx_volume = 0.8
	var args := {"menu": "1", "telemetry": scratch_telemetry_path()}  # no --players: the menu is shown
	args.merge(extra, true)
	main = load("res://scenes/main.tscn").instantiate()
	main.args_override = args
	tree.root.add_child(main)
	await frames(4)


## Presses a menu button the way a player can: it must be on screen.
func _press(id: String) -> void:
	var m: StartMenu = main.menu
	var b: Button = m.buttons[id]
	assert_true(b.is_visible_in_tree() and not b.disabled, "%s visible and enabled on page %s" % [id, m.page])
	if b.toggle_mode:
		b.button_pressed = not b.button_pressed  # a click on a toggle flips it
	b.pressed.emit()
	await frames(4)


func test_launch_shows_title_and_choices_reach_the_match() -> void:
	await _open_menu({"notch": "1"})
	var m: StartMenu = main.menu
	assert_true(m != null and m.page == "title", "a launch opens the title screen")
	assert_true(main.match_ref == null, "no match before START")
	await _press("title_play")
	assert_eq(m.page, "intro", "first CHƠI goes through the intro")
	await _press("intro_next")
	await _press("intro_skip")
	assert_eq(m.page, "setup", "skip leads to the setup page")
	assert_true(GameSettings.intro_seen, "intro marked as seen")
	await _press("players_3")
	await _press("character_NEGOTIATOR")
	await _press("color_2")
	m._name_edit.text = "An"
	m._name_edit.text_changed.emit("An")
	assert_true(m.buttons["players_3"].get_meta("selected"), "3 players selected")
	assert_false(m.buttons["players_4"].get_meta("selected"), "4 players deselected")
	assert_true(m._ability.text.contains("50%"), "ability text from data: %s" % m._ability.text)
	assert_eq(m._lineup.get_child_count(), 3, "line-up shows the 3 seats")
	var base := ThemeData.load_default().players
	await _press("start")
	await frames(4)
	main.presenter.speed = 0.05
	main.match_ref.bot_delay_range = Vector2(0.02, 0.05)
	assert_true(main.menu == null, "menu closed")
	assert_eq(engine().state.players.size(), 3, "3-player match")
	assert_eq(engine().state.player(0)["character_id"], "NEGOTIATOR", "the human plays the chosen character")
	var chars: Array = engine().state.players.map(func(p): return p["character_id"])
	assert_eq(chars, ["NEGOTIATOR", "TYCOON", "INVESTOR"], "bots take the other characters")
	assert_eq(main.theme_data.player_color(0), Color(base[2]["color"]), "the chosen colour is the player's")
	assert_eq(main.theme_data.player_name(0), "An", "the chosen name is shown")
	assert_false(main.theme_data.player_color(1) == main.theme_data.player_color(0), "bots get other colours")
	assert_eq(int(main.theme_data.players[0]["pawn"]), 2, "the pawn model matches the chosen colour")
	assert_true(MatchSetup.chosen, "choices kept for 'play again'")
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "match playable")


func test_back_and_play_again_keep_choices() -> void:
	await _open_menu()
	var m: StartMenu = main.menu
	await _press("title_play")
	await _press("intro_skip")
	await _press("players_2")
	await _press("setup_back")
	assert_eq(m.page, "title", "MENU on the setup page goes back to the title")
	await _press("title_play")
	assert_eq(m.page, "setup", "intro is not shown again")
	assert_true(m.buttons["players_2"].get_meta("selected"), "2 players kept after back")
	await _press("setup_back")
	await _press("title_intro")
	assert_eq(m.page, "intro", "the intro can be re-read from the title")
	await _press("intro_back")
	assert_eq(m.page, "title", "back on the first intro page returns to the title")


func test_intro_and_how_to_come_from_the_rules_data() -> void:
	await _open_menu()
	var m: StartMenu = main.menu
	await _press("title_intro")
	var body: String = m._intro_parts["body"].text
	assert_true(body.contains("%d RC" % main.config.balance["starting_cash"]), "starting cash from rules data")
	for i in 3:
		await _press("intro_next")
	assert_true(m._intro_parts["body"].text.contains("4 người: %d vòng" % main.config.max_rounds_for(4)), "round caps from rules data")
	assert_eq(m.buttons["intro_next"].text, "BẮT ĐẦU", "last page offers to start")
	await _press("intro_next")
	assert_eq(m.page, "setup", "the intro ends on the setup page")
	await _press("how_to")
	assert_true(m.how_to.visible, "how-to opens")
	var text := m.how_to_label.text
	assert_true(text.contains("%d RC" % main.config.balance["starting_cash"]), "starting cash from rules data")
	assert_true(text.contains("4 người: %d vòng" % main.config.max_rounds_for(4)), "round cap from rules data")
	assert_true(text.contains("%d giây" % int(main.config.balance["auction"]["timer_ms"] / 1000)), "auction timer from rules data")
	await _press("how_to_close")
	assert_false(m.how_to.visible, "how-to closes")


func test_menu_controls_are_touch_sized_inside_safe_area() -> void:
	await _open_menu({"notch": "1"})
	var m: StartMenu = main.menu
	var safe := Rect2(Vector2(0, 108), m.get_viewport_rect().size - Vector2(0, 108 + 62))
	for page in ["title", "intro", "setup", "settings"]:
		m.show_page(page)
		await frames(6)
		var seen := 0
		for id in m.buttons:
			var b: Button = m.buttons[id]
			if not b.is_visible_in_tree():
				continue
			seen += 1
			assert_true(b.size.y >= UiTheme.MIN_TOUCH - 0.5, "%s/%s touch height %d" % [page, id, b.size.y])
			# Buttons outside a scroll area must sit fully inside the safe area.
			var in_scroll := false
			var p := b.get_parent()
			while p != null and p != m:
				if p is ScrollContainer:
					in_scroll = true
				p = p.get_parent()
			if not in_scroll:
				assert_true(safe.grow(1).encloses(b.get_global_rect()), "%s/%s inside the safe area: %s" % [page, id, str(b.get_global_rect())])
		assert_true(seen >= 3, "page %s shows its buttons (%d)" % [page, seen])
		# Regression (Phase 5 portrait screenshots): the intro card grew past
		# the screen edges (a title beside its badge was not counted).
		if page != "title":
			var card: Rect2 = m._cards[page].get_global_rect()
			assert_true(safe.grow(1).encloses(card), "%s card inside the safe area: %s" % [page, str(card)])


func test_landscape_menu_fits() -> void:
	await _open_menu()
	var m: StartMenu = main.menu
	for canvas in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		tree.root.content_scale_size = canvas
		tree.root.size = Vector2i(1280, 720)
		for page in ["title", "setup", "settings", "intro"]:
			m.show_page(page)
			await frames(8)
			var vp := m.get_viewport_rect()
			for id in m.buttons:
				var b: Button = m.buttons[id]
				if b.is_visible_in_tree() and not b.get_parent() is GridContainer:
					var r := b.get_global_rect()
					assert_true(vp.grow(1).encloses(r) or _in_scroll(b, m), "%s %s/%s on screen: %s" % [str(canvas), page, id, str(r)])
			if page != "title":
				assert_true(vp.grow(1).encloses(m._cards[page].get_global_rect()), "%s %s card inside the screen" % [str(canvas), page])
	tree.root.content_scale_size = Vector2i(720, 1280)
	tree.root.size = Vector2i(405, 720)


func _in_scroll(b: Control, stop: Node) -> bool:
	var p := b.get_parent()
	while p != null and p != stop:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


## Regression (Phase 4 screenshots): picking a character with a longer
## description grew the content but the scroll area kept its old height.
## Every pick must re-measure: the scroll shows all content when it fits,
## or all the space the card has when it does not.
func test_menu_grows_when_the_ability_text_grows() -> void:
	await _open_menu({"notch": "1"})
	var m: StartMenu = main.menu
	await _press("title_play")
	await _press("intro_skip")
	for c in ["INVESTOR", "NEGOTIATOR", "TYCOON", "INVESTOR"]:
		await _press("character_" + c)
		await frames(4)
		var want: float = m._content.get_combined_minimum_size().y
		var got: float = m._scroll.custom_minimum_size.y
		var room: float = m.safe_rect().size.y
		assert_true(absf(got - want) < 1.0 or got > room * 0.45, "%s: scroll %d for content %d (room %d)" % [c, got, want, room])


## Regression (Phase 4 screenshots): in landscape the how-to sheet spanned the
## whole width (lines of ~200 characters). It is now a centred column.
func test_landscape_how_to_is_a_readable_column() -> void:
	await _open_menu()
	tree.root.content_scale_size = Vector2i(1280, 720)
	tree.root.size = Vector2i(1280, 720)
	await frames(6)
	var m: StartMenu = main.menu
	m.show_page("setup")
	await frames(4)
	await _press("how_to")
	await frames(6)
	var r: Rect2 = m.how_to.get_global_rect()
	var vp := m.get_viewport_rect()
	assert_true(r.size.x <= StartMenu.READ_WIDTH + 1.0, "how-to width %d <= %d" % [r.size.x, StartMenu.READ_WIDTH])
	assert_true(absf(r.get_center().x - vp.get_center().x) < 2.0, "how-to centred")
	assert_true(vp.grow(1).encloses(r), "whole sheet on screen (title included): %s in %s" % [str(r), str(vp)])
	assert_true(vp.grow(1).encloses(m.buttons["how_to_close"].get_global_rect()), "ĐÃ HIỂU on screen")
	tree.root.content_scale_size = Vector2i(720, 1280)
	tree.root.size = Vector2i(405, 720)


## Phase 5 settings: saved to the (test) settings file, reloaded, and applied
## live - mute really silences the Music and SFX buses.
func test_settings_persist_and_apply() -> void:
	await _open_menu()
	var m: StartMenu = main.menu
	await _press("title_settings")
	assert_eq(m.page, "settings", "settings page")
	await _press("quality_high")
	assert_eq(main.quality, "high", "preset applied live")
	m.settings.sliders["music"].value = 25
	m.settings.sliders["sfx"].value = 40
	await _press("mute")
	var music := AudioServer.get_bus_index("Music")
	var sfx := AudioServer.get_bus_index("SFX")
	assert_true(music >= 0 and sfx >= 0, "Music and SFX buses exist")
	assert_true(AudioServer.is_bus_mute(music) and AudioServer.is_bus_mute(sfx), "mute silences both buses")
	await _press("mute")
	assert_false(AudioServer.is_bus_mute(music) or AudioServer.is_bus_mute(sfx), "unmute restores both buses")
	assert_true(absf(AudioServer.get_bus_volume_db(music) - linear_to_db(0.25)) < 0.1, "music volume applied (%.1f dB)" % AudioServer.get_bus_volume_db(music))
	await _press("reduced_motion")
	assert_true(MatchSetup.reduced_motion, "reduced motion on")
	await _press("settings_back")
	assert_eq(m.page, "title", "XONG returns to the title")
	# Reload from the file: the values survive a restart.
	MatchSetup.quality = "low"
	MatchSetup.reduced_motion = false
	GameSettings.music_volume = 1.0
	GameSettings.sfx_volume = 1.0
	GameSettings.load_settings()
	assert_eq(MatchSetup.quality, "high", "preset persisted")
	assert_true(MatchSetup.reduced_motion, "reduced motion persisted")
	assert_true(absf(GameSettings.music_volume - 0.25) < 0.001 and absf(GameSettings.sfx_volume - 0.4) < 0.001, "volumes persisted")
	assert_true(GameSettings.path.begins_with("user://test_telemetry/"), "tests never write the player's settings file")
	MatchSetup.reduced_motion = false
	MatchSetup.quality = "low"


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
