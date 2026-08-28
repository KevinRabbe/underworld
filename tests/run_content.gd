extends SceneTree

const ContentRegistryTests := preload("res://tests/content/test_content_registry.gd")


func _init() -> void:
	var failures: Array[String] = ContentRegistryTests.run()
	if failures.is_empty():
		print("[VALIDATION] PASS content")
		print("  semantic content ids / deterministic registry / typed references passed")
		quit(0)
		return

	printerr("[VALIDATION] FAIL content — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
