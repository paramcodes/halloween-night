class_name TestCase
extends RefCounted
## Minimal assertion suite. No addon, no network: the runner discovers every
## `test_*` method and awaits it, so physics-frame tests work too.

var suite_name := "suite"
var failures: Array[String] = []
var assertions := 0
var runner: Node


func run_all(owner: Node, label: String) -> void:
	suite_name = label
	runner = owner
	for method: Dictionary in get_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with("test_"):
			continue
		await call(method_name)


func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append("%s: %s" % [suite_name, message])


func equal(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual != expected:
		failures.append("%s: %s (expected %s, got %s)" % [suite_name, message, expected, actual])


func almost(actual: float, expected: float, tolerance: float, message: String) -> void:
	assertions += 1
	if absf(actual - expected) > tolerance:
		failures.append(
			(
				"%s: %s (expected %.3f +/- %.3f, got %.3f)"
				% [suite_name, message, expected, tolerance, actual]
			)
		)


func greater(actual: float, threshold: float, message: String) -> void:
	assertions += 1
	if actual <= threshold:
		failures.append(
			"%s: %s (expected > %.3f, got %.3f)" % [suite_name, message, threshold, actual]
		)


func less(actual: float, threshold: float, message: String) -> void:
	assertions += 1
	if actual >= threshold:
		failures.append(
			"%s: %s (expected < %.3f, got %.3f)" % [suite_name, message, threshold, actual]
		)


func wait_physics(frames: int) -> void:
	for _i in range(frames):
		await runner.get_tree().physics_frame
