extends SceneTree

const GameplayStateCodecTests := preload("res://tests/persistence/test_gameplay_state_codec.gd")


func _init() -> void:
	var failures: Array[String] = GameplayStateCodecTests.run()
	if failures.is_empty():
		print("[PERSISTENCE STATE VALIDATION] PASS")
		print("  inventory / equipment-hotbar / pending-loot durable reconstruction contracts passed")
		quit(0)
		return

	printerr("[PERSISTENCE STATE VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
