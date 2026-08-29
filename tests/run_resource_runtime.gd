extends SceneTree

const RuntimeTests := preload("res://tests/resources/test_underground_resource_runtime.gd")


func _init() -> void:
	var failures: Array[String] = RuntimeTests.run()
	if failures.is_empty():
		print("[RESOURCE RUNTIME VALIDATION] PASS")
		print("  iron content / archetype realization / semantic pickaxe eligibility / atomic inventory yield / persistent depletion / idempotence / strict restore compatibility passed")
		quit(0)
		return

	printerr("[RESOURCE RUNTIME VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
