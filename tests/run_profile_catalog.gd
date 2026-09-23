extends SceneTree

const Tests := preload("res://tests/persistence/test_profile_catalog.gd")

func _init() -> void:
	var failures := Tests.run()
	if failures.is_empty():
		print("[PROFILE CATALOG VALIDATION] PASS")
		quit(0)
		return
	printerr("[PROFILE CATALOG VALIDATION] FAIL")
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
