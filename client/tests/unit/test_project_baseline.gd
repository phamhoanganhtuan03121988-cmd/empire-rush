## M0 smoke tests: prove the project opens on the pinned engine and the test
## runner itself works. Gameplay rule tests start in M1.
extends TestCase


func test_engine_is_pinned_version() -> void:
	var info := Engine.get_version_info()
	assert_eq("%d.%d.%d" % [info.major, info.minor, info.patch], "4.7.2", "engine version")


func test_project_name() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Empire Rush", "project name")


func test_integer_currency_has_no_float_drift() -> void:
	# Guards the "integers only for RC" rule at the language level: GDScript
	# int is 64-bit, so summing many transfers stays exact.
	var total := 0
	for i in 100000:
		total += 15
	assert_eq(total, 1500000, "int accumulation")
	assert_eq(typeof(total), TYPE_INT, "currency type")
