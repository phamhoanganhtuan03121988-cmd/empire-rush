## Base class for tests run by test_runner.gd. Assertions record failures
## instead of aborting so one run reports every broken expectation.
class_name TestCase
extends RefCounted

var errors: Array[String] = []


func assert_true(condition: bool, message: String = "expected true") -> void:
	if not condition:
		errors.append(message)


func assert_false(condition: bool, message: String = "expected false") -> void:
	if condition:
		errors.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		errors.append("%s expected <%s> got <%s>" % [message, str(expected), str(actual)])


func assert_ne(actual: Variant, other: Variant, message: String = "") -> void:
	if typeof(actual) == typeof(other) and actual == other:
		errors.append("%s expected anything but <%s>" % [message, str(other)])


## The command must be rejected with `code` and leave the state hash untouched.
func assert_rejected(f: ErFixture, result: Dictionary, code: String, before_hash: String, message: String = "") -> void:
	assert_false(result["ok"], message + " should be rejected")
	assert_eq(result.get("error"), code, message + " error code")
	assert_eq(f.state.state_hash(), before_hash, message + " state must not change")


func assert_healthy(f: ErFixture, message: String = "") -> void:
	var errs := f.invariants()
	if not errs.is_empty():
		errors.append("%s invariants: %s" % [message, str(errs)])
