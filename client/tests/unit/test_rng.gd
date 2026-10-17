## Deterministic RNG.
extends TestCase


func test_same_seed_same_sequence() -> void:
	var a := ErRng.new(42)
	var b := ErRng.new(42)
	for i in 1000:
		assert_eq(a.next_u32(), b.next_u32(), "step %d" % i)
		if not errors.is_empty():
			return


func test_different_seeds_differ() -> void:
	var a := ErRng.new(1)
	var b := ErRng.new(2)
	var same := 0
	for i in 100:
		if a.next_u32() == b.next_u32():
			same += 1
	assert_true(same < 3, "seeds 1 and 2 produced %d equal values" % same)


func test_golden_values() -> void:
	# Golden values, also reproduced by an independent Python port of the same
	# algorithm. Changing the generator breaks replays of stored matches.
	var r := ErRng.new(12345)
	assert_eq([r.next_u32(), r.next_u32(), r.next_u32()], [3392784802, 789921493, 4135656049], "seed 12345")


func test_dice_uniform_enough() -> void:
	var r := ErRng.new(7)
	var counts := [0, 0, 0, 0, 0, 0]
	for i in 60000:
		var d := r.roll_die()
		assert_true(d >= 1 and d <= 6, "die out of range")
		counts[d - 1] += 1
	for c in counts:
		assert_true(c > 9400 and c < 10600, "die face count %d far from 10000" % c)


func test_state_roundtrip() -> void:
	var r := ErRng.new(9)
	r.next_u32()
	var saved := r.get_state()
	var expected := r.next_u32()
	var r2 := ErRng.new(1)
	r2.set_state(saved)
	assert_eq(r2.next_u32(), expected, "restored state continues identically")


func test_shuffle_is_permutation() -> void:
	var r := ErRng.new(3)
	var arr := range(12)
	r.shuffle(arr)
	var sorted := arr.duplicate()
	sorted.sort()
	assert_eq(sorted, range(12), "shuffle keeps every element")
