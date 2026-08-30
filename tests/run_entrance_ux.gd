extends SceneTree

const NaturalEntranceRouteTests := preload("res://tests/geometry/test_natural_entrance_route.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = NaturalEntranceRouteTests.run()
	if failures.is_empty():
		print("[ENTRANCE UX VALIDATION] PASS")
		print("  deterministic generated selection / bounded approach spawn / source identity / production runtime backtrack passed")
		quit(0)
		return
	printerr("[ENTRANCE UX VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
