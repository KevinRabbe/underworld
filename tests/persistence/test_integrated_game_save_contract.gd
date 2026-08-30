extends RefCounted

const TypedJsonWire := preload("res://worldgen/persistence/typed_json_wire.gd")
const MapSerializationContract := preload("res://worldgen/persistence/map_data_serialization_contract.gd")
const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const InventoryStateCodec := preload("res://gameplay/items/inventory/inventory_state_codec.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquipmentService := preload("res://gameplay/items/equipment/equipment_service.gd")
const PendingLootState := preload("res://gameplay/loot/runtime/pending_loot_state.gd")
const GameplaySaveCatalog := preload("res://gameplay/persistence/gameplay_save_catalog.gd")
const IntegratedGameSaveContract := preload("res://gameplay/persistence/integrated_game_save_contract.gd")

const WOOD_ID := "item.resource.wood"
const AXE_ID := "item.tool.stone_axe"
const CHITIN_ID := "item.resource.burrower_chitin"
const PROFILE_ID := "loot_profile.creature.burrower.m3"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_catalog_and_typed_wire(failures)
	_test_integrated_round_trip(failures)
	_test_nullable_pending_loot(failures)
	_test_strict_outer_and_current_manifest_fail_closed(failures)
	_test_non_finite_resume_fails_closed(failures)
	return failures


static func _test_catalog_and_typed_wire(failures: Array[String]) -> void:
	var catalog_failures: Array[String] = GameplaySaveCatalog.validate_catalog()
	if not catalog_failures.is_empty():
		failures.append("production SAVE catalog is invalid: %s" % [catalog_failures])
		return
	var catalog_result: Dictionary = GameplaySaveCatalog.build_registry()
	if not bool(catalog_result.get("success", false)):
		failures.append("production SAVE registry failed to build")
		return
	var registry = catalog_result.get("registry", null)
	for required_id in [WOOD_ID, AXE_ID, CHITIN_ID, PROFILE_ID]:
		if registry == null or not registry.has_definition(required_id):
			failures.append("production SAVE registry is missing durable definition: %s" % required_id)
	if registry != null and registry.has_definition("item.weapon.iron_sword"):
		failures.append("SAVE catalog invented unaccepted production iron-sword authority")

	var typed_fixture: Dictionary = {
		"integer": 2,
		"whole_float": 2.0,
		"nested": [3, 3.0, {"integer": 4, "whole_float": 4.0}],
	}
	var encoded: Dictionary = TypedJsonWire.encode(typed_fixture, "typed fixture")
	if not _require_success(encoded, "typed wire encode", failures):
		return
	var decoded: Dictionary = TypedJsonWire.decode(str(encoded.get("json", "")), "typed fixture")
	if not _require_success(decoded, "typed wire decode", failures):
		return
	var restored: Dictionary = decoded.get("value", {})
	if typeof(restored.get("integer")) != TYPE_INT:
		failures.append("typed wire changed integer into another numeric type")
	if typeof(restored.get("whole_float")) != TYPE_FLOAT:
		failures.append("typed wire changed whole-valued float into integer")
	var nested: Array = restored.get("nested", [])
	if nested.size() != 3:
		failures.append("typed wire changed nested fixture shape")
	elif typeof(nested[0]) != TYPE_INT or typeof(nested[1]) != TYPE_FLOAT:
		failures.append("typed wire lost nested int/float distinction")


static func _test_integrated_round_trip(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(failures, true)
	if fixture.is_empty():
		return
	var encoded: Dictionary = IntegratedGameSaveContract.encode(
		fixture["context"],
		fixture["delta_store"],
		fixture["inventory"],
		fixture["equipment"],
		fixture["pending_loot"],
		fixture["resume_position"]
	)
	if not _require_success(encoded, "integrated save encode", failures):
		return
	var envelope: Dictionary = encoded.get("envelope", {})
	var expected_keys: Array[String] = [
		"equipment_json",
		"inventory_json",
		"map_json",
		"pending_loot_json",
		"player_resume",
		"save_schema_version",
		"schema",
	]
	if _sorted_keys(envelope) != expected_keys:
		failures.append("integrated save envelope leaked unexpected runtime fields")
	for forbidden in ["velocity", "camera", "action_state", "player_node", "mesh", "collision"]:
		if envelope.has(forbidden):
			failures.append("integrated save persisted transient runtime field: %s" % forbidden)

	var decoded: Dictionary = IntegratedGameSaveContract.decode(str(encoded.get("json", "")))
	if not _require_success(decoded, "integrated save decode", failures):
		return
	var candidate: Dictionary = decoded.get("candidate", {})
	if int(candidate.get("world_seed", 0)) != int(fixture["context"].world_seed):
		failures.append("integrated save changed exact world seed")
	if str(candidate.get("world_id", "")) != str(fixture["context"].world_id):
		failures.append("integrated save changed WorldId")
	var restored_store = candidate.get("delta_store", null)
	if restored_store == null or restored_store.snapshot() != fixture["delta_store"].snapshot():
		failures.append("integrated save changed WorldDeltaStore snapshot")
	var restored_inventory = candidate.get("inventory_state", null)
	if restored_inventory == null or restored_inventory.canonical_json() != fixture["inventory"].canonical_json():
		failures.append("integrated save changed inventory canonical state")
	else:
		var stack_state: Dictionary = restored_inventory.state_at(0).get("state", {}).get("stack_state", {})
		if typeof(stack_state.get("serial")) != TYPE_INT:
			failures.append("integrated save changed mutable inventory integer type")
		if typeof(stack_state.get("whole_float")) != TYPE_FLOAT:
			failures.append("integrated save changed mutable inventory whole-float type")
	var restored_equipment = candidate.get("equipment_state", null)
	if restored_equipment == null or restored_equipment.canonical_snapshot() != fixture["equipment"].canonical_snapshot():
		failures.append("integrated save changed equipment/hotbar state")
	elif restored_equipment.selected_hotbar() != 4:
		failures.append("integrated save did not restore semantic hotbar slot 4")
	var restored_pending = candidate.get("pending_loot_state", null)
	if restored_pending == null or restored_pending.canonical_snapshot() != fixture["pending_loot"].canonical_snapshot():
		failures.append("integrated save changed pending-loot exactly-once state")
	if candidate.get("resume_position", Vector3.ZERO) != fixture["resume_position"]:
		failures.append("integrated save changed safe resume position")


static func _test_nullable_pending_loot(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(failures, false)
	if fixture.is_empty():
		return
	var encoded: Dictionary = IntegratedGameSaveContract.encode(
		fixture["context"],
		fixture["delta_store"],
		fixture["inventory"],
		fixture["equipment"],
		null,
		fixture["resume_position"]
	)
	if not _require_success(encoded, "null pending-loot encode", failures):
		return
	if encoded.get("envelope", {}).get("pending_loot_json", "sentinel") != null:
		failures.append("integrated save fabricated pending-loot identity when no reward is pending")
	var decoded: Dictionary = IntegratedGameSaveContract.decode(str(encoded.get("json", "")))
	if not _require_success(decoded, "null pending-loot decode", failures):
		return
	if decoded.get("candidate", {}).get("pending_loot_state", "sentinel") != null:
		failures.append("integrated save reconstructed fake pending-loot state from null")


static func _test_strict_outer_and_current_manifest_fail_closed(
	failures: Array[String]
) -> void:
	if bool(IntegratedGameSaveContract.decode(
		'{"version":2,"world_seed":1,"wood":4,"selected_slot":1}'
	).get("success", false)):
		failures.append("legacy prototype-v2 payload unexpectedly decoded as integrated SAVE")

	var fixture: Dictionary = _fixture(failures, false)
	if fixture.is_empty():
		return
	var encoded: Dictionary = IntegratedGameSaveContract.encode(
		fixture["context"],
		fixture["delta_store"],
		fixture["inventory"],
		fixture["equipment"],
		null,
		fixture["resume_position"]
	)
	if not bool(encoded.get("success", false)):
		failures.append("strict outer regression setup failed")
		return
	var unknown: Dictionary = encoded.get("envelope", {}).duplicate(true)
	unknown["future_runtime_state"] = {"velocity": [1, 2, 3]}
	var unknown_wire: Dictionary = TypedJsonWire.encode(unknown, "unknown outer fixture")
	if bool(unknown_wire.get("success", false)) and bool(IntegratedGameSaveContract.decode(
		str(unknown_wire.get("json", ""))
	).get("success", false)):
		failures.append("integrated save accepted unknown outer structural field")

	var map_decoded: Dictionary = MapSerializationContract.decode(
		str(encoded.get("envelope", {}).get("map_json", ""))
	)
	if not bool(map_decoded.get("success", false)):
		failures.append("manifest-drift regression map setup failed")
		return
	var stale_map: Dictionary = map_decoded.get("envelope", {}).duplicate(true)
	stale_map["world"]["generator_manifest_canonical"] = "gm1|stale-runtime-contract"
	stale_map["world"]["generator_manifest_id"] = "gm-sha256:" + str(
		stale_map["world"]["generator_manifest_canonical"]
	).sha256_text()
	var stale_map_json: Dictionary = MapSerializationContract.canonical_json(stale_map)
	if not bool(stale_map_json.get("success", false)):
		failures.append("manifest-drift regression could not produce internally valid MAP payload")
		return
	var stale_outer: Dictionary = encoded.get("envelope", {}).duplicate(true)
	stale_outer["map_json"] = str(stale_map_json.get("json", ""))
	var stale_outer_wire: Dictionary = TypedJsonWire.encode(stale_outer, "stale manifest fixture")
	if bool(stale_outer_wire.get("success", false)) and bool(IntegratedGameSaveContract.decode(
		str(stale_outer_wire.get("json", ""))
	).get("success", false)):
		failures.append("integrated save accepted generator manifest incompatible with current runtime")


static func _test_non_finite_resume_fails_closed(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(failures, false)
	if fixture.is_empty():
		return
	for bad_position in [
		Vector3(NAN, 1.0, 2.0),
		Vector3(1.0, INF, 2.0),
		Vector3(1.0, 2.0, -INF),
	]:
		var encoded: Dictionary = IntegratedGameSaveContract.encode(
			fixture["context"],
			fixture["delta_store"],
			fixture["inventory"],
			fixture["equipment"],
			null,
			bad_position
		)
		if bool(encoded.get("success", false)):
			failures.append("integrated save accepted non-finite resume position: %s" % bad_position)


static func _fixture(failures: Array[String], with_pending: bool) -> Dictionary:
	var catalog_result: Dictionary = GameplaySaveCatalog.build_registry()
	if not _require_success(catalog_result, "SAVE fixture registry", failures):
		return {}
	var registry = catalog_result.get("registry", null)
	var wood = registry.get_definition(WOOD_ID)
	var axe = registry.get_definition(AXE_ID)
	var chitin = registry.get_definition(CHITIN_ID)
	if wood == null or axe == null or chitin == null:
		failures.append("SAVE fixture could not resolve production item definitions")
		return {}

	var inventory = ItemContainerState.new().configure(8, 100.0)
	var wood_add: Dictionary = inventory.add_stack(
		wood,
		7,
		{"grade": "rough", "serial": 7, "whole_float": 2.0}
	)
	if not _require_success(wood_add, "SAVE fixture wood add", failures):
		return {}
	var axe_add: Dictionary = inventory.add_instance(axe, {"durability": 83})
	if not _require_success(axe_add, "SAVE fixture axe add", failures):
		return {}

	var equipment = EquipmentHotbarState.new().configure(
		GameplaySaveCatalog.equipment_rules(),
		GameplaySaveCatalog.hotbar_bindings()
	)
	var equip_result: Dictionary = EquipmentService.new().equip_from_inventory(
		equipment,
		inventory,
		int(axe_add.get("slot", -1)),
		axe,
		GameplaySaveCatalog.SLOT_UTILITY
	)
	if not _require_success(equip_result, "SAVE fixture utility equip", failures):
		return {}
	var selection: Dictionary = equipment.select_hotbar(4)
	if not _require_success(selection, "SAVE fixture hotbar 4 selection", failures):
		return {}

	var context = WorldGenerationContext.new(9007199254740997)
	var delta_store = WorldDeltaStore.new()
	var address = StableAddress.generated_child(
		StableAddress.underground_region(0, 0),
		"save-fixture-resource",
		0
	)
	var stable_id: String = StableId.from_address(address).value()
	if not delta_store.set_object_state(stable_id, {
		"schema": "resource.runtime.depletion.v1",
		"remaining_capacity_units": 3.0,
		"completed_operation_ids": ["operation.save-fixture"],
		"integer_marker": 3,
	}):
		failures.append("SAVE fixture could not install WorldDelta object state")
		return {}

	var pending = null
	if with_pending:
		var definition_contract: String = InventoryStateCodec.canonical_json(
			chitin.canonical_descriptor()
		)
		pending = PendingLootState.new().configure(
			"burrower_41",
			PROFILE_ID,
			[{
				"item_id": CHITIN_ID,
				"quantity": 2,
				"definition_contract": definition_contract,
			}]
		)
		if not pending.validate_state().is_empty():
			failures.append("SAVE fixture pending loot is invalid")
			return {}

	return {
		"context": context,
		"delta_store": delta_store,
		"inventory": inventory,
		"equipment": equipment,
		"pending_loot": pending,
		"resume_position": Vector3(12.5, 44.0, -3.25),
	}


static func _sorted_keys(value: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for raw_key in value.keys():
		result.append(str(raw_key))
	result.sort()
	return result


static func _require_success(
	result: Dictionary,
	label: String,
	failures: Array[String]
) -> bool:
	if bool(result.get("success", false)):
		return true
	failures.append("%s failed diagnostics=%s" % [label, result.get("diagnostics", [])])
	return false
