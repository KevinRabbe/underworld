extends SceneTree

const LifecycleTests := preload("res://tests/persistence/test_profile_entry_lifecycle.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = await LifecycleTests.run_runtime(self)
	if failures.is_empty():
		print("[PROFILE ENTRY LIFECYCLE VALIDATION] PASS")
		quit(0)
		return
	printerr("[PROFILE ENTRY LIFECYCLE VALIDATION] FAIL")
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
