extends SceneTree

const StableIdentityTests := preload("res://tests/foundation/test_stable_identity.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(StableIdentityTests.run())

	if failures.is_empty():
		print("[FOUNDATION TESTS] PASS")
		print("  StableAddress / StableId vectors and invariants passed")
		quit(0)
		return

	printerr("[FOUNDATION TESTS] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
