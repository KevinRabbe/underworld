extends SceneTree

const ItemContainerTests := preload("res://tests/inventory/test_item_container_state.gd")
const InventoryTransactionTests := preload("res://tests/inventory/test_inventory_transaction_service.gd")
const LootCollectionTests := preload("res://tests/inventory/test_loot_collection.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(ItemContainerTests.run())
	failures.append_array(InventoryTransactionTests.run())
	failures.append_array(LootCollectionTests.run())
	if failures.is_empty():
		print("[INVENTORY VALIDATION] PASS")
		print("  container invariants / atomic local mutation / stable snapshot / atomic transaction / loot collection contracts passed")
		quit(0)
		return

	printerr("[INVENTORY VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
