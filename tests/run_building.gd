extends SceneTree

const BuildingTests := preload("res://tests/building/test_building_runtime.gd")
const CampTests := preload("res://tests/building/test_chest_bed_persistence.gd")

func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(BuildingTests.run())
	failures.append_array(CampTests.run())
	if failures.is_empty():
		print("[BUILDING VALIDATION] PASS — shelter / chest storage / bed claim persistence")
		quit(0)
		return
	printerr("[BUILDING VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
