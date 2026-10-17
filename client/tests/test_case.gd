## Base class for tests run by test_runner.gd. Assertions record failures
## instead of aborting so one run reports every broken expectation.
class_name TestCase
extends RefCounted

var errors: Array[String] = []


func assert_true(condition: bool, message: String = "expected true") -> void:
	if not condition:
		errors.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		errors.append("%s expected <%s> got <%s>" % [message, str(expected), str(actual)])
