extends SceneTree

const MapDataSerializationTests := preload("res://tests/persistence/test_map_data_serialization_contract.gd")
const MapExactContextTests := preload("res://tests/persistence/test_map_exact_context_validation.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(MapDataSerializationTests.run())
	failures.append_array(MapExactContextTests.run())
	if failures.is_empty():
		print("[MAP DATA SERIALIZATION] PASS")
		quit(0)
		return

	printerr("[MAP DATA SERIALIZATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
