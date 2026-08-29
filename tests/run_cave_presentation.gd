extends SceneTree

const CavePresentationTests := preload("res://tests/presentation/test_cave_presentation_contract.gd")


func _init() -> void:
	var failures: Array[String] = CavePresentationTests.run()
	if failures.is_empty():
		print("[CAVE PRESENTATION VALIDATION] PASS")
		print("  authored profiles / double-sided cave material / identity separation / disposable rebuild contracts passed")
		quit(0)
		return
	printerr("[CAVE PRESENTATION VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
