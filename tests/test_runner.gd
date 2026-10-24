extends Node
## Headless test runner.
## Run: godot --headless --path . res://tests/test_runner.tscn

const SUITES := [
	preload("res://tests/unit/save_test.gd"),
	preload("res://tests/unit/utility_test.gd"),
	preload("res://tests/unit/flow_field_test.gd"),
	preload("res://tests/unit/tuning_test.gd"),
	preload("res://tests/unit/character_test.gd"),
	preload("res://tests/integration/night_test.gd"),
]

var _failures: Array[String] = []
var _assertions := 0


func _ready() -> void:
	var started := Time.get_ticks_msec()
	for suite_script: GDScript in SUITES:
		var suite: TestCase = suite_script.new()
		var label := str(suite_script.resource_path.get_file().get_basename())
		await suite.run_all(self, label)
		_assertions += suite.assertions
		_failures.append_array(suite.failures)
		print(
			(
				"[TEST] %-22s %d assertions, %d failures"
				% [label, suite.assertions, suite.failures.size()]
			)
		)
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("[TEST] %d assertions, %d failures, %.1fs" % [_assertions, _failures.size(), elapsed])
	for failure: String in _failures:
		print("[FAIL] ", failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
