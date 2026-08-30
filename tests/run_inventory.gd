extends SceneTree

const ItemContainerTests := preload("res://tests/inventory/test_item_container_state.gd")
const AuthoredDefinitionIdentityTests := preload("res://tests/inventory/test_authored_definition_identity.gd")
const InventoryTransactionTests := preload("res://tests/inventory/test_inventory_transaction_service.gd")
const EquipmentHotbarTests := preload("res://tests/inventory/test_equipment_hotbar_state.gd")
const SurfaceHarvestTests := preload("res://tests/inventory/test_surface_harvest_inventory.gd")
const LootCollectionTests := preload("res://tests/inventory/test_loot_collection.gd")
const LootRestoreProbe := preload("res://tests/inventory/test_loot_restore_probe.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(ItemContainerTests.run())
	failures.append_array(AuthoredDefinitionIdentityTests.run())
	failures.append_array(InventoryTransactionTests.run())
	failures.append_array(EquipmentHotbarTests.run())
	failures.append_array(SurfaceHarvestTests.run())
	var loot_failures: Array[String] = []
	LootCollectionTests._test_burrower_death_to_exactly_once_collection(loot_failures)
	LootCollectionTests._test_loot_unready_does_not_gate_encounter_runtime(loot_failures)
	LootCollectionTests._test_capacity_failure_preserves_inventory_and_pending(loot_failures)
	LootCollectionTests._test_weight_failure_preserves_inventory_and_pending(loot_failures)
	LootCollectionTests._test_definition_contract_drift_fails_closed(loot_failures)
	LootCollectionTests._test_reward_events_are_semantic(loot_failures)
	LootCollectionTests._test_locator_retry_and_nearby_collection(loot_failures)
	LootCollectionTests._test_service_import_is_atomic_and_deep_owned(loot_failures)
	failures.append_array(loot_failures)
	failures.append_array(LootRestoreProbe.run())
	if failures.is_empty():
		print("[INVENTORY VALIDATION] PASS")
		print("  container / authored-definition-identity / transaction / equipment-hotbar / surface-harvest / loot-collection contracts passed")
		quit(0)
		return

	printerr("[INVENTORY VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
