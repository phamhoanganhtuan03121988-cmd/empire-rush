## Web/PWA launch: the match in progress autosaves at every turn start and
## resumes from the title screen after the page/app is closed. Resuming
## replays the logged commands, so it must land on the saved state exactly;
## a broken save is discarded and never blocks the game.
extends UiTestCase


func _play_one_human_turn() -> void:
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "roll offered")
	await press(ErCommand.ROLL_DICE)
	for i in 900:
		await tree.process_frame
		if find_action(ErCommand.BUY_PROPERTY) or find_action(ErCommand.END_TURN):
			break
	if find_action(ErCommand.BUY_PROPERTY):
		await press(ErCommand.BUY_PROPERTY)
	assert_true(await wait_for_action(ErCommand.END_TURN), "end turn offered")
	await press(ErCommand.END_TURN)


func test_autosave_and_resume_rebuild_the_same_match() -> void:
	SavedMatch.path = "user://test_telemetry/saved_match.json"
	SavedMatch.clear()
	await start_game(2, 5, {"save": "1"})
	await _play_one_human_turn()
	# Back on the human's turn: a save from this turn start exists.
	assert_true(await wait_for_action(ErCommand.ROLL_DICE, 3000), "the bot played, the human is up again")
	assert_true(SavedMatch.exists(), "autosaved")
	var rec := SavedMatch.load_record()
	var hash: String = engine().state.state_hash()
	assert_eq(str(rec["state_hash"]), hash, "the save is the current turn start")
	var cash: Array = engine().state.players.map(func(p): return p["cash"])
	var owned: Array = engine().state.properties_of(0)
	var pos: int = engine().state.player(0)["position"]
	await stop_game()
	# "Close the app" and resume from the save.
	main = load("res://scenes/main.tscn").instantiate()
	main.args_override = {"resume": "1", "quality": "low", "telemetry": scratch_telemetry_path()}
	tree.root.add_child(main)
	await frames(6)
	main.presenter.speed = 0.05
	assert_true(main._resumed, "match resumed")
	assert_eq(engine().state.state_hash(), hash, "replay rebuilds the exact saved state")
	assert_eq(engine().state.players.map(func(p): return p["cash"]), cash, "cash")
	assert_eq(engine().state.properties_of(0), owned, "owned land")
	assert_true(main.presenter.tokens[0].position.distance_to(main.board.tile_position(pos)) < 0.4, "pawn shown on its tile")
	assert_eq(main.hud._cards[0]["cash"].text, "%d RC" % cash[0], "HUD shows the saved cash")
	for pid in owned:
		assert_true(main.board._owner_marks.has(pid), "%s shows its owner" % pid)
	# The resumed match plays on.
	main.match_ref.bot_delay_range = Vector2(0.02, 0.05)
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "roll offered after resume")
	var v := engine().state.state_version
	await press(ErCommand.ROLL_DICE)
	await frames(3)
	assert_eq(engine().state.state_version, v + 1, "commands accepted after resume")
	SavedMatch.clear()


func test_broken_save_is_discarded() -> void:
	SavedMatch.path = "user://test_telemetry/saved_match.json"
	DirAccess.make_dir_recursive_absolute("user://test_telemetry")
	var f := FileAccess.open(SavedMatch.path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_true(SavedMatch.load_record().is_empty(), "unreadable save gives nothing")
	assert_false(SavedMatch.exists(), "and is removed")
	# A save that does not replay to its hash starts a fresh match instead.
	await start_game(2, 5, {"save": "1"})
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "roll offered")
	SavedMatch.save(engine(), main.theme_data.players, [0])
	var rec := SavedMatch.load_record()
	rec["state_hash"] = "tampered"
	var g := FileAccess.open(SavedMatch.path, FileAccess.WRITE)
	g.store_string(JSON.stringify(rec))
	g.close()
	await stop_game()
	main = load("res://scenes/main.tscn").instantiate()
	main.args_override = {"resume": "1", "quality": "low", "telemetry": scratch_telemetry_path()}
	tree.root.add_child(main)
	await frames(6)
	assert_false(main._resumed, "a save that does not replay exactly is refused")
	assert_true(main.match_ref.engine != null, "a fresh match started instead")
	SavedMatch.clear()


func test_title_offers_resume_only_with_a_save() -> void:
	SavedMatch.path = "user://test_telemetry/saved_match.json"
	SavedMatch.clear()
	MatchSetup.chosen = false
	main = load("res://scenes/main.tscn").instantiate()
	main.args_override = {"menu": "1", "telemetry": scratch_telemetry_path()}
	tree.root.add_child(main)
	await frames(4)
	assert_false(main.menu.buttons.has("title_resume"), "no save: no resume button")
	await stop_game()
	await start_game(2, 5, {"save": "1"})
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "roll offered")
	main._autosave()
	await stop_game()
	MatchSetup.chosen = false
	main = load("res://scenes/main.tscn").instantiate()
	main.args_override = {"menu": "1", "telemetry": scratch_telemetry_path()}
	tree.root.add_child(main)
	await frames(4)
	assert_true(main.menu.buttons.has("title_resume") and main.menu.buttons["title_resume"].is_visible_in_tree(), "resume offered")
	main.menu.buttons["title_resume"].pressed.emit()
	await frames(6)
	assert_true(main._resumed, "TIẾP TỤC TRẬN resumes the saved match")
	SavedMatch.clear()
