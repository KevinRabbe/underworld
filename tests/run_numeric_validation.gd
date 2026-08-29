extends SceneTree

const NumericSafetyTests := preload("res://tests/foundation/test_numeric_safety.gd")


func _init() -> void:
	var failures: Array[String] = NumericSafetyTests.run()
	if failures.is_empty():
		print("[NUMERIC VALIDATION] PASS")
		print("  finite semantic/state boundaries and atomic failure contracts passed")
		quit(0)
		return

	printerr("[NUMERIC VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
