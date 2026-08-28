extends SceneTree

const EdgeCaseContracts := preload("res://tests/worldgen_edge_cases/test_worldgen_edge_cases.gd")


func _init() -> void:
	var failures: Array[String] = []
	EdgeCaseContracts.run(failures)
	if failures.is_empty():
		print("[WORLDGEN EDGE CASES] PASS")
		quit(0)
		return
	printerr("[WORLDGEN EDGE CASES] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
