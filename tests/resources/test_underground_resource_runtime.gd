extends RefCounted

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const UndergroundPlacementRecord := preload("res://content/placement/underground_placement_record.gd")
const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const ArchetypeRealizer := preload("res://core/content/archetypes/archetype_realizer.gd")
const PackedSceneArchetypeAdapter := preload("res://core/content/archetypes/packed_scene_archetype_adapter.gd")
const EquipmentSlotRule := preload("res://gameplay/items/equipment/equipment_slot_rule.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquipmentService := preload("res://gameplay/items/equipment/equipment_service.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const RuntimeService := preload("res://gameplay/resources/runtime/underground_resource_runtime_service.gd")

const RESOURCE_PATH := "res://content/resources/iron_outcrop_definition.tres"
const IRON_ITEM_PATH := "res://content/items/resources/iron_chunk_definition.tres"
const PICKAXE_PATH := "res://content/items/tools/stone_pickaxe_definition.tres"
const STONE_PATH := "res://content/items/resources/stone_definition.tres"
const ARCHETYPE_PATH := "res://content/resources/archetypes/iron_outcrop_archetype.tres"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_production_content_and_realization(failures)
	_test_pickaxe_mining_depletion_and_idempotence(failures)
	_test_inventory_failure_is_atomic(failures)
	_test_restore_schema_and_current_placement_compatibility(failures)
	_test_wrong_tool_fails_closed(failures)
	return failures


static func _test_production_content_and_realization(failures: Array[String]) -> void:
	var fixture: Dictionary = _content_fixture(failures)
	if fixture.is_empty():
		return
	var definition = fixture["resource"]
	var iron_item = fixture["iron_item"]
	var archetype = fixture["archetype"]
	_expect_equal(failures, "iron runtime resource owns four capacity units", definition.capacity_units, 4.0)
	_expect_equal(failures, "iron runtime yields exact iron chunk ContentId", definition.primary_yield_item_id, "item.resource.iron_chunk")
	_expect_equal(failures, "iron chunk is stackable", iron_item.stack_limit, 99)
	_expect_equal(failures, "resource archetype id is semantic", definition.presentation_archetype_id, archetype.content_id)

	var realizer = ArchetypeRealizer.new()
	var adapter_failures: Array[String] = realizer.register_adapter(PackedSceneArchetypeAdapter.new())
	if not adapter_failures.is_empty():
		failures.append("iron resource realizer rejected packed.scene adapter: %s" % [adapter_failures])
		return
	var validation: Dictionary = {
		"success": true,
		"diagnostics": [],
		"validated_definition_ids": [archetype.content_id],
	}
	var service = RuntimeService.new()
	var result: Dictionary = service.realize_placement(_placement(), fixture["registry"], validation, realizer)
	_expect_true(failures, "iron placement realizes through semantic archetype", bool(result.get("success", false)))
	var instance = result.get("instance", null)
	if instance != null and instance is Node:
		_expect_equal(failures, "realized node stores placement identity only as runtime metadata", str(instance.get_meta("placement_stable_id", "")), _placement().placement_stable_id)
		_expect_equal(failures, "realized node stores resource semantic id", str(instance.get_meta("resource_content_id", "")), "resource.deposit.iron_outcrop")
		_expect_true(failures, "realized root exposes semantic archetype role", instance.is_in_group("archetype_role:root"))
		instance.free()


static func _test_pickaxe_mining_depletion_and_idempotence(failures: Array[String]) -> void:
	var fixture: Dictionary = _content_fixture(failures)
	if fixture.is_empty():
		return
	var equipment_fixture: Dictionary = _pickaxe_equipment(fixture["pickaxe"], failures)
	if equipment_fixture.is_empty():
		return
	var output = ItemContainerState.new().configure(2)
	var store = WorldDeltaStore.new()
	var service = RuntimeService.new()
	var placement = _placement()

	var first: Dictionary = service.mine(placement, fixture["registry"], equipment_fixture["equipment"], output, store, "mine-1")
	_expect_true(failures, "pickaxe mining succeeds", bool(first.get("success", false)))
	_expect_equal(failures, "one capacity unit yields one iron chunk", output.quantity_of("item.resource.iron_chunk"), 1)
	_expect_equal(failures, "first mine leaves three capacity units", float(first.get("remaining_capacity_units", -1.0)), 3.0)

	var duplicate: Dictionary = service.mine(placement, fixture["registry"], equipment_fixture["equipment"], output, store, "mine-1")
	_expect_true(failures, "repeated callback is an idempotent success", bool(duplicate.get("success", false)))
	_expect_true(failures, "repeated operation reports duplicate", bool(duplicate.get("duplicate", false)))
	_expect_equal(failures, "repeated callback does not duplicate iron", output.quantity_of("item.resource.iron_chunk"), 1)
	_expect_equal(failures, "repeated callback does not consume capacity", float(duplicate.get("remaining_capacity_units", -1.0)), 3.0)

	for index in range(2, 5):
		var result: Dictionary = service.mine(placement, fixture["registry"], equipment_fixture["equipment"], output, store, "mine-%d" % index)
		_expect_true(failures, "mine operation %d succeeds" % index, bool(result.get("success", false)))
	_expect_equal(failures, "four authored operations yield sword recipe iron count", output.quantity_of("item.resource.iron_chunk"), 4)
	var restored: Dictionary = service.restore_state(placement, fixture["registry"], store)
	_expect_true(failures, "depleted state restores", bool(restored.get("success", false)))
	if bool(restored.get("success", false)):
		_expect_equal(failures, "depletion reaches zero after four operations", float(restored["state"].remaining_capacity_units), 0.0)
	var exhausted: Dictionary = service.mine(placement, fixture["registry"], equipment_fixture["equipment"], output, store, "mine-5")
	_expect_true(failures, "exhausted resource fails closed", not bool(exhausted.get("success", true)))
	_expect_equal(failures, "exhausted resource cannot yield extra iron", output.quantity_of("item.resource.iron_chunk"), 4)


static func _test_inventory_failure_is_atomic(failures: Array[String]) -> void:
	var fixture: Dictionary = _content_fixture(failures)
	if fixture.is_empty():
		return
	var equipment_fixture: Dictionary = _pickaxe_equipment(fixture["pickaxe"], failures)
	if equipment_fixture.is_empty():
		return
	var full_inventory = ItemContainerState.new().configure(1)
	var fill: Dictionary = full_inventory.add_stack(fixture["stone"], 1)
	_expect_true(failures, "atomicity fixture inventory fills", bool(fill.get("success", false)))
	var store = WorldDeltaStore.new()
	var service = RuntimeService.new()
	var placement = _placement()
	var before_inventory: String = full_inventory.canonical_json()
	var before_store: Dictionary = store.snapshot()
	var result: Dictionary = service.mine(placement, fixture["registry"], equipment_fixture["equipment"], full_inventory, store, "full-inventory")
	_expect_true(failures, "inventory-capacity failure rejects mining", not bool(result.get("success", true)))
	_expect_equal(failures, "inventory failure leaves inventory canonical state unchanged", full_inventory.canonical_json(), before_inventory)
	_expect_equal(failures, "inventory failure leaves WorldDeltaStore unchanged", store.snapshot(), before_store)


static func _test_restore_schema_and_current_placement_compatibility(failures: Array[String]) -> void:
	var fixture: Dictionary = _content_fixture(failures)
	if fixture.is_empty():
		return
	var equipment_fixture: Dictionary = _pickaxe_equipment(fixture["pickaxe"], failures)
	if equipment_fixture.is_empty():
		return
	var output = ItemContainerState.new().configure(2)
	var store = WorldDeltaStore.new()
	var service = RuntimeService.new()
	var placement = _placement()
	var mined: Dictionary = service.mine(placement, fixture["registry"], equipment_fixture["equipment"], output, store, "persist-1")
	_expect_true(failures, "restore fixture mining succeeds", bool(mined.get("success", false)))
	var valid: Dictionary = store.get_object_state(placement.placement_stable_id)

	var wrong_schema: Dictionary = valid.duplicate(true)
	wrong_schema["schema"] = "resource.runtime.depletion.v0"
	store.set_object_state(placement.placement_stable_id, wrong_schema)
	var rejected_schema: Dictionary = service.restore_state(placement, fixture["registry"], store)
	_expect_true(failures, "wrong runtime snapshot schema fails closed", not bool(rejected_schema.get("success", true)))

	var extra_key: Dictionary = valid.duplicate(true)
	extra_key["unexpected"] = true
	store.set_object_state(placement.placement_stable_id, extra_key)
	var rejected_shape: Dictionary = service.restore_state(placement, fixture["registry"], store)
	_expect_true(failures, "snapshot with unexpected envelope shape fails closed", not bool(rejected_shape.get("success", true)))

	store.set_object_state(placement.placement_stable_id, valid)
	var changed_placement = _placement("upf1:iron-runtime-replanned")
	var rejected_fingerprint: Dictionary = service.restore_state(changed_placement, fixture["registry"], store)
	_expect_true(failures, "saved depletion is rejected against changed current placement fingerprint", not bool(rejected_fingerprint.get("success", true)))
	_expect_equal(failures, "failed compatibility restore does not rewrite saved state", store.get_object_state(placement.placement_stable_id), valid)


static func _test_wrong_tool_fails_closed(failures: Array[String]) -> void:
	var fixture: Dictionary = _content_fixture(failures)
	if fixture.is_empty():
		return
	var rule = EquipmentSlotRule.new().configure(
		"equipment_slot.tool.primary",
		["category.item.equipment.tool.pickaxe"],
		["capability.harvest_tool"]
	)
	var equipment = EquipmentHotbarState.new().configure([rule], {1: "equipment_slot.tool.primary"})
	var output = ItemContainerState.new().configure(2)
	var store = WorldDeltaStore.new()
	var result: Dictionary = RuntimeService.new().mine(_placement(), fixture["registry"], equipment, output, store, "hands-1")
	_expect_true(failures, "hands cannot mine iron deposit", not bool(result.get("success", true)))
	_expect_equal(failures, "wrong tool yields no iron", output.quantity_of("item.resource.iron_chunk"), 0)
	_expect_true(failures, "wrong tool creates no durable depletion", store.get_object_state(_placement().placement_stable_id).is_empty())


static func _content_fixture(failures: Array[String]) -> Dictionary:
	var definition = ResourceLoader.load(RESOURCE_PATH)
	var iron_item = ResourceLoader.load(IRON_ITEM_PATH)
	var pickaxe = ResourceLoader.load(PICKAXE_PATH)
	var stone = ResourceLoader.load(STONE_PATH)
	var archetype = ResourceLoader.load(ARCHETYPE_PATH)
	for pair in [
		["resource", definition],
		["iron item", iron_item],
		["pickaxe", pickaxe],
		["stone", stone],
		["archetype", archetype],
	]:
		if pair[1] == null:
			failures.append("production %s fixture failed to load" % pair[0])
	if definition == null or iron_item == null or pickaxe == null or stone == null or archetype == null:
		return {}
	var registry = ContentRegistry.new()
	var registry_failures: Array[String] = registry.index_definitions([definition, iron_item, pickaxe, stone, archetype])
	if not registry_failures.is_empty():
		failures.append("production resource runtime registry invalid: %s" % [registry_failures])
		return {}
	for reference in definition.validation_references():
		var resolution: Dictionary = registry.resolve_reference(reference)
		if not resolution.get("diagnostics", []).is_empty():
			failures.append("production iron resource reference failed resolution: %s" % [resolution.get("diagnostics", [])])
	return {
		"registry": registry,
		"resource": definition,
		"iron_item": iron_item,
		"pickaxe": pickaxe,
		"stone": stone,
		"archetype": archetype,
	}


static func _pickaxe_equipment(pickaxe, failures: Array[String]) -> Dictionary:
	var rule = EquipmentSlotRule.new().configure(
		"equipment_slot.tool.primary",
		["category.item.equipment.tool.pickaxe"],
		["capability.harvest_tool"]
	)
	var equipment = EquipmentHotbarState.new().configure([rule], {1: "equipment_slot.tool.primary"})
	var source = ItemContainerState.new().configure(2)
	var add_result: Dictionary = source.add_instance(pickaxe)
	if not bool(add_result.get("success", false)):
		failures.append("pickaxe fixture could not add instance: %s" % [add_result.get("diagnostics", [])])
		return {}
	var equip_result: Dictionary = EquipmentService.new().equip_from_inventory(
		equipment,
		source,
		int(add_result.get("slot", -1)),
		pickaxe,
		"equipment_slot.tool.primary"
	)
	if not bool(equip_result.get("success", false)):
		failures.append("pickaxe fixture could not equip through EQUIP-001 service: %s" % [equip_result.get("diagnostics", [])])
		return {}
	return {"equipment": equipment, "source_inventory": source}


static func _placement(fingerprint: String = "upf1:iron-runtime-current"):
	var address = StableAddress.from_segments(["underworld", "resource", "iron", "slot", "0"])
	var stable_id = StableId.from_address(address)
	var candidate_address = StableAddress.from_segments(["underworld", "resource", "iron"])
	var candidate_id = StableId.from_address(candidate_address)
	return UndergroundPlacementRecord.new(
		stable_id.value(),
		candidate_id.value(),
		0,
		"placement_policy.resource.iron_outcrop",
		"resource.deposit.iron_outcrop",
		"resource",
		fingerprint
	)


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])
