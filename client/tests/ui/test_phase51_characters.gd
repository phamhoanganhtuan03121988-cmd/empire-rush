## Phase 5.1 characters: a real persona choice (portrait, name, colour,
## bio) that is cosmetic only. The chosen persona and colour reach the HUD
## card and the pawn on the board, bots get the other personas, the choice
## persists, and the rules never see it (roles and rules are unchanged).
extends UiTestCase


func _open_menu() -> void:
	MatchSetup.chosen = false
	MatchSetup.tutorial = false
	MatchSetup.players = 4
	MatchSetup.character = "TYCOON"
	MatchSetup.quality = "low"
	MatchSetup.reduced_motion = false
	MatchSetup.color_index = 0
	MatchSetup.player_name = "Bạn"
	MatchSetup.persona = "khoi"
	GameSettings.intro_seen = true
	main = load("res://scenes/main.tscn").instantiate()
	main.args_override = {"menu": "1", "telemetry": scratch_telemetry_path()}
	tree.root.add_child(main)
	await frames(4)


func _press(id: String) -> void:
	var m: StartMenu = main.menu
	var b: Button = m.buttons[id]
	assert_true(b.is_visible_in_tree() and not b.disabled, "%s visible and enabled on page %s" % [id, m.page])
	b.pressed.emit()
	await frames(4)


func test_every_persona_has_a_portrait_and_no_rules_data() -> void:
	var t := ThemeData.load_default()
	assert_true(t.personas.size() >= 8, "at least 8 personas (%d)" % t.personas.size())
	var names := {}
	for p in t.personas:
		assert_true(t.portrait(p["id"]) != null, "%s has a portrait" % p["id"])
		assert_true(str(p.get("bio", "")) != "" and str(p.get("name", "")) != "", "%s has name and bio" % p["id"])
		for k in p:
			assert_false(k in ["ability", "bonus", "cash", "rent", "character_id", "stats"], "%s carries no gameplay key (%s)" % [p["id"], k])
		names[p["name"]] = true
	assert_eq(names.size(), t.personas.size(), "persona names are unique")


func test_choice_reaches_hud_and_pawn_bots_get_others() -> void:
	await _open_menu()
	await _press("title_play")
	assert_eq(main.menu.page, "setup", "setup page (intro already seen)")
	var roles_before := MatchSetup.seat_characters(3, MatchSetup.character)
	await _press("players_3")
	await _press("persona_ha")
	var m: StartMenu = main.menu
	assert_true(m.buttons["persona_ha"].get_meta("selected"), "Thu Hà highlighted")
	assert_false(m.buttons["persona_khoi"].get_meta("selected"), "the old choice is not")
	assert_eq(MatchSetup.player_name, "Thu Hà", "the name follows the persona")
	assert_eq(m._name_edit.text, "Thu Hà", "name field updated")
	assert_true(m._persona_bio.text.begins_with("Thu Hà"), "bio shown: %s" % m._persona_bio.text)
	await _press("color_3")
	m._name_edit.text = "Hà Nội"
	m._name_edit.text_changed.emit("Hà Nội")
	assert_eq(m._lineup.get_child_count(), 3, "line-up: 3 portraits")
	assert_eq(MatchSetup.seat_characters(3, MatchSetup.character), roles_before, "a persona does not change roles")
	await _press("start")
	await frames(4)
	main.presenter.speed = 0.05
	var t: ThemeData = main.theme_data
	assert_eq(t.players[0]["persona"], "ha", "seat 0 plays Thu Hà")
	assert_eq(t.player_name(0), "Hà Nội", "typed name kept")
	var personas := [t.players[0]["persona"], t.players[1]["persona"], t.players[2]["persona"]]
	assert_eq(personas.size(), 3, "3 seats")
	assert_false("ha" in [personas[1], personas[2]], "bots never take the player's persona")
	assert_true(personas[1] != personas[2], "bots have different personas")
	assert_eq(t.player_name(1), t.persona(personas[1])["name"], "bot named after its persona")
	assert_eq(main.hud._cards[0]["avatar"].get_child(0).texture, t.portrait("ha"), "HUD card shows the portrait")
	var tok: TokenView = main.presenter.tokens[0]
	assert_eq(tok.medallion.texture, t.portrait("ha"), "the pawn carries the portrait")
	var pawn: MeshInstance3D = tok.get_node("Pawn") if tok.has_node("Pawn") else tok.find_child("Pawn", true, false)
	assert_eq(pawn.mesh.resource_path, "res://assets/models/tokens/pawn_3.res", "pawn model in the chosen colour")
	assert_eq(t.player_color(0), Color(ThemeData.load_default().players[3]["color"]), "seat colour = chosen colour")
	assert_eq(engine().state.player(0)["character_id"], "TYCOON", "role unchanged by the persona")
	assert_eq(engine().state.player(0)["cash"], engine().config.balance["starting_cash"], "no cash bonus from a persona")


func test_persona_choice_persists() -> void:
	await _open_menu()
	await _press("title_play")
	await _press("persona_long")
	await _press("start")
	await frames(2)
	MatchSetup.persona = "khoi"
	MatchSetup.player_name = "x"
	GameSettings.load_settings()
	assert_eq(MatchSetup.persona, "long", "persona restored from settings")
	assert_eq(MatchSetup.player_name, "Hoàng Long", "name restored")
