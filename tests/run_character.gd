extends SceneTree

const MannequinTests := preload("res://tests/character/test_prototype_mannequin.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(MannequinTests.run())

	if failures.is_empty():
		print("[CHARACTER VALIDATION] PASS")
		print("  articulated mannequin rig / sockets / placeholder poses passed")
		quit(0)
		return

	printerr("[CHARACTER VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
