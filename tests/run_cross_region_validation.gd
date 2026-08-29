extends SceneTree

const CrossRegionValidation := preload("res://tests/cross_region_validation/test_cross_region_validation.gd")


func _init() -> void:
	var failures: Array[String] = CrossRegionValidation.run()
	if failures.is_empty():
		print("[CROSS REGION VALIDATION] PASS")
		quit(0)
		return
	printerr("[CROSS REGION VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
