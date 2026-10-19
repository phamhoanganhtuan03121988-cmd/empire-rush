## Phase 5.1 coach: the guided tutorial teaches one action at a time on a
## real match; contextual tips explain a mechanic the first time it happens
## (once each, persisted, can be switched off); a "what next" hint appears
## when the player waits. The coach never sends commands or changes rules.
extends UiTestCase


func _reset_tips() -> void:
	GameSettings.tips_enabled = true
	GameSettings.tips_seen.clear()


func _wait(cond: Callable, max_frames := 900) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await tree.process_frame
	return cond.call()


func test_guided_tutorial_one_action_at_a_time() -> void:
	_reset_tips()
	MatchSetup.chosen = false
	MatchSetup.tutorial = false
	MatchSetup.players = 4
	GameSettings.intro_seen = true
	main = load("res://scenes/main.tscn").instantiate()
	main.args_override = {"menu": "1", "telemetry": scratch_telemetry_path(), "quality": "low"}
	tree.root.add_child(main)
	await frames(4)
	main.menu.buttons["title_tutorial"].pressed.emit()
	await frames(6)
	main.presenter.speed = 0.05
	main.match_ref.bot_delay_range = Vector2(0.02, 0.05)
	var c: CoachOverlay = main.coach
	assert_true(c != null and c.guided, "guided coach in the tutorial")
	assert_eq(engine().state.players.size(), 2, "tutorial is a 2-player match")
	assert_eq(c.current.get("id", ""), "welcome", "welcome card first")
	assert_true(main.match_ref.lifecycle.is_paused(), "timer and bots wait while the card is up")
	c.buttons["ok"].pressed.emit()
	assert_true(await _wait(func(): return c.current.get("id", "") == "roll"), "step: roll (shown %s)" % str(c.shown))
	assert_true(main.match_ref.lifecycle.is_paused(), "the roll step waits for the reader")
	assert_true(c.is_pointing(), "the roll button is highlighted")
	await press(ErCommand.ROLL_DICE)
	assert_true(await _wait(func(): return c.current.get("id", "") == "buy"), "step: buy after the real roll (shown %s)" % str(c.shown))
	assert_false("roll" == c.current.get("id", ""), "the roll card closed when the player acted")
	await press(ErCommand.BUY_PROPERTY)
	assert_true(await _wait(func(): return c.current.get("id", "") in ["strategy", "upgrade", "ability"]), "step: one action, then end turn (shown %s)" % str(c.shown))
	assert_true(await wait_for_action(ErCommand.END_TURN), "end turn offered")
	await press(ErCommand.END_TURN)
	assert_true(await _wait(func(): return "watch" in c.shown), "the bot's turn is explained")
	assert_true(await _wait(func(): return c.current.get("id", "") == "done", 3000), "closing card when the player's turn comes back")
	c.buttons["ok"].pressed.emit()
	await frames(2)
	assert_false(c.guided, "tutorial over")
	assert_false(MatchSetup.tutorial, "play again starts a normal match")
	assert_false(main.match_ref.lifecycle.is_paused(), "match runs")
	var order: Array = c.shown.filter(func(x): return x in ["roll", "buy", "strategy", "upgrade", "ability", "watch"])
	assert_eq(order[0], "roll", "roll taught first")
	assert_eq(order[1], "buy", "then buying")


func test_tips_show_once_and_persist() -> void:
	_reset_tips()
	await start_game(2, 4, {"coach": "1"})
	var c: CoachOverlay = main.coach
	assert_true(c != null and not c.guided, "contextual coach")
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "roll offered")
	assert_true(await _wait(func(): return "roll" in c.shown), "first-turn tip")
	assert_false(main.match_ref.lifecycle.is_paused(), "an info tip does not pause the match")
	await press(ErCommand.ROLL_DICE)
	assert_true(await _wait(func(): return c.current.get("id", "") == "buy"), "buy tip at the first buy prompt (shown %s)" % str(c.shown))
	assert_true(main.match_ref.lifecycle.is_paused(), "a decision tip pauses the timer")
	var left: float = main.match_ref.seconds_left()
	await tree.create_timer(0.4).timeout
	assert_true(absf(main.match_ref.seconds_left() - left) < 0.05, "timer frozen while reading")
	await press(ErCommand.BUY_PROPERTY)
	await frames(3)
	assert_false(c.current.get("id", "") == "buy", "acting closes the tip")
	assert_true("roll" in GameSettings.tips_seen and "buy" in GameSettings.tips_seen, "seen tips saved: %s" % str(GameSettings.tips_seen))
	await stop_game()
	# A new match: the same tips are not shown again.
	await start_game(2, 4, {"coach": "1"})
	c = main.coach
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "roll offered")
	await press(ErCommand.ROLL_DICE)
	assert_true(await wait_for_action(ErCommand.BUY_PROPERTY), "buy prompt again")
	await frames(5)
	assert_false("buy" in c.shown or "roll" in c.shown, "seen tips stay quiet (shown %s)" % str(c.shown))
	assert_false(main.match_ref.lifecycle.is_paused(), "nothing pauses")


func test_contextual_rent_tip_and_switch_off() -> void:
	_reset_tips()
	await start_game(2, 3, {"coach": "1"})
	var c: CoachOverlay = main.coach
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "roll offered")
	give(1, ["P_D1_1"])
	await land_human(1)
	assert_true(await _wait(func(): return "rent_paid" in c.shown), "rent explained when the player pays rent (shown %s)" % str(c.shown))
	c.buttons["off"].pressed.emit()
	await frames(2)
	assert_false(GameSettings.tips_enabled, "tips switched off")
	assert_true(c.current.is_empty() and not main.match_ref.lifecycle.is_paused(), "card gone, match runs")
	give(1, ["P_D1_2"])
	await land_human(2)
	await frames(5)
	assert_eq(c.shown.count("rent_paid"), 1, "no more tips once off")
	GameSettings.tips_enabled = true


func test_next_action_hint_when_waiting() -> void:
	_reset_tips()
	GameSettings.tips_seen.append_array(["roll", "buy", "strategy"])
	await start_game(2, 3, {"coach": "1"})
	var c: CoachOverlay = main.coach
	c.idle_hint_s = 0.3
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "roll offered")
	assert_true(await _wait(func(): return c.idle_hint.visible, 300), "a hint after waiting")
	assert_true(c.idle_hint.text.contains("ĐỔ XÚC XẮC"), "it names the next step: %s" % c.idle_hint.text)
	await press(ErCommand.ROLL_DICE)
	await frames(2)
	assert_false(c.idle_hint.visible, "hint gone once the player acts")


func test_texts_follow_rules_data() -> void:
	var g := RulesGuide.new(GameConfig.load_from_dir())
	var pages := g.intro_pages()
	assert_eq(pages.size(), 2, "two short pages: goal and one turn")
	assert_eq(pages[0]["title"], "Mục tiêu của bạn", "goal page")
	assert_eq(pages[1]["title"], "Bạn làm gì trong mỗi lượt?", "turn page")
	assert_true(pages[0]["body"].contains("1500"), "starting cash from data")
	var steps := g.tutorial_steps()
	assert_true(steps[0]["body"].contains("dừng đúng ô Xuất phát"), "start reward also when landing on Start (engine rule)")
	assert_false(steps[4]["body"].contains("đề nghị giao dịch,"), "no promise of a trade button the HUD does not have")
	var t := g.tips()
	for id in t:
		assert_true(t[id]["body"].length() < 330, "tip %s stays short (%d chars)" % [id, t[id]["body"].length()])


func test_cards_show_net_worth() -> void:
	await start_game(2, 3)
	assert_true(await wait_for_action(ErCommand.ROLL_DICE), "roll offered")
	await land_human(1)  # Ngõ Cá, buyable
	await press(ErCommand.BUY_PROPERTY)
	await settle()
	var card: Dictionary = main.hud._cards[0]
	var worth: int = engine().net_worth(0)
	assert_true(card["role"].text.ends_with("Tài sản %d" % worth), "card shows net worth %d: %s" % [worth, card["role"].text])
	assert_true(worth < engine().state.player(0)["cash"] + 60, "buying lowers net worth on paper (resale < price)")
