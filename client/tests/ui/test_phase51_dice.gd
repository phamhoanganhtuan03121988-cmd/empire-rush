## Phase 5.1 dice: the foreground dice stage shows exactly the engine's roll
## (many seeds), sits in its own 3D world (nothing on the board can cover a
## die), is large enough to read, and skipping or reduced motion changes only
## the timing - never the roll, the command order or the match.
extends UiTestCase


func _cues() -> Array:
	var log: Array = []
	main.presenter.cue.connect(func(n: String, d: Dictionary): log.append([n, d.duplicate()]))
	return log


func _names(log: Array) -> Array:
	return log.map(func(x): return x[0])


func test_shown_result_matches_engine_on_many_seeds() -> void:
	for s in [1, 2, 3, 5, 8, 13, 21, 34]:
		await start_game(2, s)
		var log := _cues()
		assert_true(await wait_for_action(ErCommand.ROLL_DICE), "seed %d: roll offered" % s)
		await press(ErCommand.ROLL_DICE)
		assert_true(await settle(), "seed %d: presented" % s)
		var roll: Array = engine().state.last_roll
		var result := log.filter(func(x): return x[0] == "dice_result")
		assert_eq(result.size(), 1, "seed %d: one result beat" % s)
		if result.size() == 1:
			assert_eq([result[0][1]["d1"], result[0][1]["d2"]], roll, "seed %d: result card = engine roll" % s)
		assert_eq(main.dice_stage._result.text, "%d + %d = %d" % [roll[0], roll[1], roll[0] + roll[1]], "seed %d: card text" % s)
		assert_eq([main.dice.top_value(0), main.dice.top_value(1)], roll, "seed %d: dice faces = engine roll" % s)
		await stop_game()


func test_dice_are_in_their_own_world_and_readable() -> void:
	await start_game(2, 3)
	var st: DiceStage = main.dice_stage
	assert_true(st._vp.own_world_3d, "stage has its own 3D world")
	assert_true(main.dice.get_world_3d() != main.board.get_world_3d(), "no board object shares the dice world (cannot cover a die)")
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "roll offered")
	main.presenter.speed = 1.0
	await press(ErCommand.ROLL_DICE)
	for i in 300:
		await tree.process_frame
		if st._card.visible:
			break
	assert_true(st.visible and st._card.visible, "result card on screen")
	# Projected size of one die on screen (design px, portrait 720x1280).
	var cam: Camera3D = st._cam
	var die: Node3D = main.dice._dice[0]
	var half: float = DiceView.SIZE * 0.5 * main.dice.scale.x
	var a := cam.unproject_position(die.global_position + Vector3(-half, 0, 0))
	var b := cam.unproject_position(die.global_position + Vector3(half, 0, 0))
	var px := a.distance_to(b) * st._box.size.x / float(st._vp.size.x)
	assert_true(px >= 60.0, "a die is %.0f px wide on a 720x1280 screen (>= 60)" % px)
	assert_true(st._dim.color.a > 0.3 and st._dim.size == st.get_viewport_rect().size, "board dimmed behind the dice")
	var box := Rect2(st._box.position, st._box.size)
	assert_true(Rect2(Vector2.ZERO, st.get_viewport_rect().size).encloses(box), "tray fully on screen")
	assert_true(await settle(), "presented")
	assert_false(st.visible, "stage gone before the pawn moves")


func test_skip_changes_timing_only() -> void:
	# Same seed twice: once watched at full speed, once skipped by a tap.
	var finals := []
	for skip in [false, true]:
		await start_game(2, 7)
		main.presenter.speed = 1.0
		var log := _cues()
		assert_true(await wait_for_action(ErCommand.ROLL_DICE), "roll offered")
		var v := engine().state.state_version
		await press(ErCommand.ROLL_DICE)
		var t0 := Time.get_ticks_msec()
		if skip:
			await frames(3)
			var tap := InputEventMouseButton.new()
			tap.button_index = MOUSE_BUTTON_LEFT
			tap.pressed = true
			main.dice_stage._gui_input(tap)
		for i in 600:
			await tree.process_frame
			if "step" in _names(log):
				break
		var ms := Time.get_ticks_msec() - t0
		assert_eq(engine().state.state_version, v + 1, "one command, skip=%s" % skip)
		finals.append({"roll": engine().state.last_roll.duplicate(), "ms": ms, "faces": [main.dice.top_value(0), main.dice.top_value(1)],
			"pos": engine().state.player(0)["position"], "bounces": _names(log).count("dice_bounce")})
		await settle()
		await stop_game()
	assert_eq(finals[1]["roll"], finals[0]["roll"], "skipping does not change the roll")
	assert_eq(finals[1]["faces"], finals[0]["roll"], "skipped dice still show the engine roll")
	assert_eq(finals[1]["pos"], finals[0]["pos"], "same move")
	assert_true(finals[1]["ms"] < finals[0]["ms"] - 400, "skip is faster (%d ms vs %d ms)" % [finals[1]["ms"], finals[0]["ms"]])
	assert_eq(finals[1]["bounces"], 0, "a skipped throw makes no burst of bounce sounds")
	var full_ms: int = finals[0]["ms"]
	assert_true(full_ms < 2600, "full roll presentation stays short (%d ms)" % full_ms)


func test_beats_and_sounds_are_in_order() -> void:
	await start_game(2, 3)
	main.presenter.speed = 1.0
	var a: AudioDirector = AudioDirector.instance
	var log := _cues()
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "roll offered")
	a.played.clear()
	await press(ErCommand.ROLL_DICE)
	for i in 600:
		await tree.process_frame
		if "step" in _names(log):
			break
	var n := _names(log)
	var order := ["dice_roll", "dice_bounce", "dice_land", "dice_result", "step"]
	var last := -1
	for name in order:
		var idx := n.find(name)
		assert_true(idx > last, "%s after the previous beat (%s)" % [name, str(n)])
		last = idx
	for s in ["dice_roll", "dice_bounce", "dice_land", "dice_result"]:
		assert_true(s in a.played, "%s sound played (%s)" % [s, str(a.played)])


func test_reduced_motion_shows_result_without_throw() -> void:
	await start_game(2, 3, {"reduced-motion": "1"})
	main.presenter.speed = 1.0
	var log := _cues()
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "roll offered")
	await press(ErCommand.ROLL_DICE)
	assert_true(await settle(), "presented")
	var n := _names(log)
	assert_false("dice_bounce" in n, "no tumbling bounces with reduced motion")
	assert_true("dice_land" in n and "dice_result" in n, "result still announced")
	var roll: Array = engine().state.last_roll
	assert_eq([main.dice.top_value(0), main.dice.top_value(1)], roll, "faces = engine roll")
