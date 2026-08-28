extends SceneTree

const MapDataSerializationTests := preload("res://tests/persistence/test_map_data_serialization_contract.gd")


func _init() -> void:
	var failures: Array[String] = MapDataSerializationTests.run()
	if failures.is_empty():
		print("[MAP DATA SERIALIZATION] PASS")
		quit(0)
		return

	printerr("[MAP DATA SERIALIZATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
