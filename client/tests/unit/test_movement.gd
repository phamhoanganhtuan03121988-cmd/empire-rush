## Dice, movement, Start reward, doubles (GDD §3; G5).
extends TestCase


func test_roll_moves_by_dice_sum() -> void:
	var f := ErFixture.make()
	var res := f.cmd(0, ErCommand.ROLL_DICE)
	assert_true(res["ok"], "roll accepted")
	var roll: Array = f.state.last_roll
	assert_eq(f.state.player(0)["position"], roll[0] + roll[1], "position == d1 + d2")
	assert_true(f.types(res["events"]).has("DiceRolled"), "DiceRolled emitted")
	assert_healthy(f)


func test_passing_start_pays_reward() -> void:
	var f := ErFixture.make()
	f.state.player(0)["position"] = 26
	f.engine._move_by(0, 5, "dice")
	f.engine._commit()
	assert_eq(f.state.player(0)["position"], 3, "wrapped position")
	assert_eq(f.cash(0), 1700, "start reward paid")


func test_landing_exactly_on_start_pays_reward() -> void:
	var f := ErFixture.make()
	f.state.player(0)["position"] = 24
	f.engine._move_by(0, 4, "dice")
	f.engine._commit()
	assert_eq(f.state.player(0)["position"], 0, "on start")
	assert_eq(f.cash(0), 1700, "start reward paid")


func test_no_reward_without_passing_start() -> void:
	var f := ErFixture.make()
	f.engine._move_by(0, 11, "dice")
	f.engine._commit()
	assert_eq(f.cash(0), 1500, "no reward")


func test_doubles_do_not_grant_extra_roll() -> void:
	# Seat 0 owns every property so most landings go straight to the strategy
	# phase, where an extra-roll bug would reopen AwaitRoll.
	var checked := 0
	for seed_value in range(1, 400):
		var f := ErFixture.make(2, seed_value)
		f.give(0, f.config().property_ids)
		f.cmd(0, ErCommand.ROLL_DICE)
		var roll: Array = f.state.last_roll
		if roll[0] != roll[1]:
			continue
		checked += 1
		assert_ne(f.state.phase, GameState.AWAIT_ROLL, "doubles must not reopen AwaitRoll (seed %d)" % seed_value)
		var again := f.cmd(0, ErCommand.ROLL_DICE)
		assert_false(again["ok"], "second roll rejected (seed %d)" % seed_value)
	assert_true(checked >= 3, "found %d doubles cases" % checked)


func test_same_seed_same_dice() -> void:
	var a := ErFixture.make(2, 77)
	var b := ErFixture.make(2, 77)
	a.cmd(0, ErCommand.ROLL_DICE)
	b.cmd(0, ErCommand.ROLL_DICE)
	assert_eq(a.state.last_roll, b.state.last_roll, "dice")
