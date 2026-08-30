extends SceneTree

const ItemContainerTests := preload("res://tests/inventory/test_item_container_state.gd")
const AuthoredDefinitionIdentityTests := preload("res://tests/inventory/test_authored_definition_identity.gd")
const InventoryTransactionTests := preload("res://tests/inventory/test_inventory_transaction_service.gd")
const EquipmentHotbarTests := preload("res://tests/inventory/test_equipment_hotbar_state.gd")
const SurfaceHarvestTests := preload("res://tests/inventory/test_surface_harvest_inventory.gd")
const LootCollectionTests := preload("res://tests/inventory/test_loot_collection.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(ItemContainerTests.run())
	failures.append_array(AuthoredDefinitionIdentityTests.run())
	failures.append_array(InventoryTransactionTests.run())
	failures.append_array(EquipmentHotbarTests.run())
	failures.append_array(SurfaceHarvestTests.run())
	failures.append_array(LootCollectionTests.run())
	if failures.is_empty():
		print("[INVENTORY VALIDATION] PASS")
		print("  container / authored-definition-identity / transaction / equipment-hotbar / surface-harvest / loot-collection contracts passed")
		quit(0)
		return

	printerr("[INVENTORY VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
