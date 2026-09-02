extends SceneTree

const WorldSessionTests := preload("res://tests/world_session/test_world_domain_session_state.gd")


func _init() -> void:
	var failures: Array[String] = WorldSessionTests.run()
	if failures.is_empty():
		print("[WORLD SESSION VALIDATION] PASS")
		print("  explicit domains / owned attempt tokens / readiness / atomic commit / rollback / durable snapshot contracts passed")
		quit(0)
		return

	printerr("[WORLD SESSION VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
