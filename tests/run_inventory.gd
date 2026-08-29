extends SceneTree

const ItemContainerTests := preload("res://tests/inventory/test_item_container_state.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(ItemContainerTests.run())
	if failures.is_empty():
		print("[INVENTORY VALIDATION] PASS")
		print("  stack / per-copy instance / slot+weight capacity / atomic local mutation / stable snapshot contracts passed")
		quit(0)
		return

	printerr("[INVENTORY VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
