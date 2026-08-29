extends SceneTree

const WorldDefinitionServiceTests := preload("res://tests/world_definition_service/test_world_definition_service_lifecycle.gd")


func _init() -> void:
	var failures: Array[String] = WorldDefinitionServiceTests.run()

	if failures.is_empty():
		print("[WORLD DEFINITION SERVICE VALIDATION] PASS")
		print("  configure/cache lifecycle contracts passed")
		print("  StableAddress/StableId cache ownership contracts passed")
		print("  deterministic request/order-independence contracts passed")
		print("  surface entrance descriptor store/query lifecycle contracts passed")
		quit(0)
		return

	printerr("[WORLD DEFINITION SERVICE VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
