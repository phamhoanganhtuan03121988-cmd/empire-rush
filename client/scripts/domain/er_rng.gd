## Deterministic PRNG (xorshift128, 32-bit lanes). Uses only xor, shifts and
## masks, so every step stays inside 32 bits and the sequence can be ported
## exactly to another runtime (see docs/PROTOCOL.md, Option B in the plan).
## Never use randi()/RandomNumberGenerator in rules code.
class_name ErRng
extends RefCounted

const MASK32 := 0xFFFFFFFF

var _s: Array[int] = [0, 0, 0, 0]


func _init(seed_value: int = 1) -> void:
	set_seed(seed_value)


func set_seed(seed_value: int) -> void:
	# splitmix-style scrambling done in 32-bit steps so seeds 0/1/2 diverge.
	var x := seed_value & MASK32
	for i in 4:
		x = (x + 0x9E3779B9) & MASK32
		var z := x
		z = ((z ^ (z >> 16)) * 0x85EB) & MASK32
		z = ((z ^ (z >> 13)) * 0xC2B2) & MASK32
		z = z ^ (z >> 16)
		_s[i] = z
	if _s[0] == 0 and _s[1] == 0 and _s[2] == 0 and _s[3] == 0:
		_s[0] = 1


func next_u32() -> int:
	var t := _s[3]
	var s := _s[0]
	_s[3] = _s[2]
	_s[2] = _s[1]
	_s[1] = s
	t = (t ^ (t << 11)) & MASK32
	t = t ^ (t >> 8)
	_s[0] = (t ^ s ^ (s >> 19)) & MASK32
	return _s[0]


## Uniform integer in [0, n) without modulo bias (rejection sampling).
func range_int(n: int) -> int:
	assert(n > 0 and n <= MASK32)
	var limit := (MASK32 + 1) - ((MASK32 + 1) % n)
	while true:
		var v := next_u32()
		if v < limit:
			return v % n
	return 0


func roll_die() -> int:
	return range_int(6) + 1


## Fisher-Yates shuffle in place.
func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := range_int(i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func get_state() -> Array[int]:
	return _s.duplicate()


func set_state(state: Array) -> void:
	for i in 4:
		_s[i] = int(state[i]) & MASK32
