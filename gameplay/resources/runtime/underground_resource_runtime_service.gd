extends RefCounted

const StableId := preload("res://worldgen/identity/stable_id.gd")
const UndergroundPlacementRecord := preload("res://content/placement/underground_placement_record.gd")
const ResourceDefinition := preload("res://gameplay/resources/definitions/resource_definition.gd")
const ResourceYieldRule := preload("res://gameplay/resources/definitions/resource_yield_rule.gd")
const ResourceDepletionState := preload("res://gameplay/resources/state/resource_depletion_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquippedItemResolver := preload("res://gameplay/items/equipment/equipped_item_resolver.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const InventoryTransactionPlan := preload("res://gameplay/items/inventory/inventory_transaction_plan.gd")
const InventoryTransactionService := preload("res://gameplay/items/inventory/inventory_transaction_service.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")

const SNAPSHOT_SCHEMA := "resource.runtime.depletion.v1"
const CAPACITY_PER_OPERATION := 1.0
const INVENTORY_KEY := "inventory"
const REQUIRED_TOOL_CATEGORY := "category.item.equipment.tool.pickaxe"
const REQUIRED_TOOL_CAPABILITY := "capability.harvest_tool"
const PRESENTATION_ARCHETYPE_ROLE := "presentation.archetype"
const EXPECTED_ENVELOPE_KEYS: Array[String] = [
	"depletion",
	"placement_fingerprint",
	"placement_stable_id",
	"resource_content_id",
	"schema",
]
const EXPECTED_DEPLETION_KEYS: Array[String] = [
	"mutable_delta",
	"remaining_capacity_units",
	"resource_content_id",
]


func realize_placement(placement, content_registry, validation_result: Dictionary, archetype_realizer) -> Dictionary:
	var resolved: Dictionary = _resolve_resource(placement, content_registry)
	if not bool(resolved.get("success", false)):
		return resolved
	var definition = resolved.get("definition", null)
	var archetype_id: String = ""
	for reference in definition.validation_references():
		if reference != null and str(reference.role) == PRESENTATION_ARCHETYPE_ROLE:
			var reference_result: Dictionary = content_registry.resolve_reference(reference)
			if not reference_result.get("diagnostics", []).is_empty():
				return _failure(reference_result.get("diagnostics", []))
			archetype_id = str(reference.target_id)
			break
	if archetype_id.is_empty():
		return _failure(["resource is missing required presentation.archetype reference: %s" % definition.content_id])
	if archetype_realizer == null or not archetype_realizer.has_method("realize"):
		return _failure(["resource realization requires ArchetypeRealizer-compatible service"])
	var realized: Dictionary = archetype_realizer.realize(content_registry, validation_result, archetype_id)
	if not bool(realized.get("success", false)):
		return realized
	var instance = realized.get("instance", null)
	if instance == null or not instance is Node:
		return _failure(["resource archetype realization returned no Node instance"])
	instance.set_meta("placement_stable_id", placement.placement_stable_id)
	instance.set_meta("placement_fingerprint", placement.placement_fingerprint)
	instance.set_meta("resource_content_id", placement.target_content_id)
	realized["placement_stable_id"] = placement.placement_stable_id
	realized["resource_content_id"] = placement.target_content_id
	return realized


func mine(
	placement,
	content_registry,
	equipment_state,
	inventory,
	delta_store,
	operation_id: String
) -> Dictionary:
	var failures: Array[String] = []
	if inventory == null or not inventory is ItemContainerState:
		failures.append("resource mining requires ItemContainerState inventory")
	if equipment_state == null or not equipment_state is EquipmentHotbarState:
		failures.append("resource mining requires EquipmentHotbarState")
	if delta_store == null or not delta_store is WorldDeltaStore:
		failures.append("resource mining requires WorldDeltaStore")
	var normalized_operation_id: String = operation_id.strip_edges()
	if normalized_operation_id.is_empty() or normalized_operation_id != operation_id:
		failures.append("resource mining operation id must be non-empty and trimmed")
	if not failures.is_empty():
		return _failure(failures)

	var resolved: Dictionary = _resolve_resource(placement, content_registry)
	if not bool(resolved.get("success", false)):
		return resolved
	var definition = resolved.get("definition", null)

	var equipment_resolution: Dictionary = EquippedItemResolver.new().resolve_selected(equipment_state)
	if not bool(equipment_resolution.get("success", false)):
		return _failure(equipment_resolution.get("diagnostics", []))
	if not bool(equipment_resolution.get("can_harvest", false)):
		return _failure(["selected equipment lacks %s" % REQUIRED_TOOL_CAPABILITY])
	if not EquippedItemResolver.new().selected_matches_category_root(equipment_state, REQUIRED_TOOL_CATEGORY):
		return _failure(["selected harvest tool must match %s" % REQUIRED_TOOL_CATEGORY])

	var loaded: Dictionary = _load_or_create_state(placement, definition, delta_store)
	if not bool(loaded.get("success", false)):
		return loaded
	var current_state = loaded.get("state", null)
	if current_state == null or not current_state is ResourceDepletionState:
		return _failure(["resource runtime failed to reconstruct depletion state"])
	var completed: Array[String] = _completed_operation_ids(current_state)
	if completed.has(normalized_operation_id):
		return _success({
			"duplicate": true,
			"depleted": current_state.remaining_capacity_units <= 0.0,
			"remaining_capacity_units": current_state.remaining_capacity_units,
			"yielded_item_id": "",
			"yielded_quantity": 0,
			"events": [],
		})
	if current_state.remaining_capacity_units < CAPACITY_PER_OPERATION:
		return _failure(["resource deposit has insufficient remaining capacity"])

	var yield_rules: Array = definition.yield_rules()
	if yield_rules.size() != 1 or yield_rules[0] == null or not yield_rules[0] is ResourceYieldRule:
		return _failure(["M3 resource runtime requires exactly one valid yield rule"])
	var yield_rule = yield_rules[0]
	var rule_failures: Array[String] = yield_rule.validate_rule()
	if not rule_failures.is_empty():
		return _failure(rule_failures)
	var item_reference = yield_rule.validation_reference()
	var item_resolution: Dictionary = content_registry.resolve_reference(item_reference)
	if not item_resolution.get("diagnostics", []).is_empty():
		return _failure(item_resolution.get("diagnostics", []))
	var item_definition = item_resolution.get("definition", null)
	if item_definition == null or not item_definition is ItemDefinition:
		return _failure(["resource yield did not resolve to ItemDefinition"])

	var raw_quantity: float = float(yield_rule.quantity_per_capacity_unit) * CAPACITY_PER_OPERATION
	var yield_quantity: int = int(round(raw_quantity))
	if raw_quantity <= 0.0 or not is_equal_approx(raw_quantity, float(yield_quantity)):
		return _failure(["M3 resource yield per operation must be a positive whole quantity"])

	var next_state = ResourceDepletionState.new().configure(
		definition.content_id,
		current_state.remaining_capacity_units,
		current_state.mutable_delta
	)
	var consumed: float = next_state.consume_capacity(CAPACITY_PER_OPERATION)
	if not is_equal_approx(consumed, CAPACITY_PER_OPERATION):
		return _failure(["resource runtime could not consume exactly one capacity unit"])
	completed.append(normalized_operation_id)
	completed.sort()
	next_state.set_delta_value("completed_operation_ids", completed)
	var state_failures: Array[String] = next_state.validate_state()
	if next_state.remaining_capacity_units > float(definition.capacity_units):
		state_failures.append("resource runtime remaining capacity exceeds current authored capacity")
	if not state_failures.is_empty():
		return _failure(state_failures)

	var plan = InventoryTransactionPlan.new()
	plan.bind_container(INVENTORY_KEY, inventory)
	plan.add_stack(INVENTORY_KEY, item_definition, yield_quantity)
	var transaction_service = InventoryTransactionService.new()
	var preflight: Dictionary = transaction_service.validate(plan)
	if not bool(preflight.get("success", false)):
		return _failure(preflight.get("diagnostics", []))

	var previous_delta_snapshot: Dictionary = delta_store.snapshot()
	var next_envelope: Dictionary = _snapshot_envelope(placement, next_state)
	if not delta_store.set_object_state(placement.placement_stable_id, next_envelope):
		return _failure(["WorldDeltaStore rejected validated placement StableId"])
	var committed: Dictionary = transaction_service.commit(plan)
	if not bool(committed.get("success", false)):
		var rollback_failures: Array[String] = delta_store.load_modern_delta_payload(previous_delta_snapshot)
		var restored_snapshot: Dictionary = delta_store.snapshot()
		if not rollback_failures.is_empty() or restored_snapshot != previous_delta_snapshot:
			var diagnostics: Array[String] = []
			for diagnostic in committed.get("diagnostics", []):
				diagnostics.append(str(diagnostic))
			for failure in rollback_failures:
				diagnostics.append("WorldDelta rollback: %s" % failure)
			if restored_snapshot != previous_delta_snapshot:
				diagnostics.append(
					"HARD RESOURCE ROLLBACK INVARIANT FAILURE — WorldDelta snapshot did not restore exactly"
				)
			return _failure(diagnostics)
		return committed

	var events: Array = committed.get("events", []).duplicate(true)
	events.append({
		"type": "resource.mined",
		"placement_stable_id": placement.placement_stable_id,
		"resource_content_id": definition.content_id,
		"operation_id": normalized_operation_id,
		"yielded_item_id": str(item_definition.content_id),
		"yielded_quantity": yield_quantity,
		"remaining_capacity_units": next_state.remaining_capacity_units,
	})
	return _success({
		"duplicate": false,
		"depleted": next_state.remaining_capacity_units <= 0.0,
		"remaining_capacity_units": next_state.remaining_capacity_units,
		"yielded_item_id": str(item_definition.content_id),
		"yielded_quantity": yield_quantity,
		"transaction_fingerprint": str(committed.get("transaction_fingerprint", "")),
		"events": events,
	})


func restore_state(placement, content_registry, delta_store) -> Dictionary:
	var resolved: Dictionary = _resolve_resource(placement, content_registry)
	if not bool(resolved.get("success", false)):
		return resolved
	if delta_store == null or not delta_store is WorldDeltaStore:
		return _failure(["resource restore requires WorldDeltaStore"])
	return _load_or_create_state(placement, resolved.get("definition", null), delta_store)


func _resolve_resource(placement, content_registry) -> Dictionary:
	var failures: Array[String] = _placement_failures(placement)
	if content_registry == null or not content_registry.has_method("resolve"):
		failures.append("resource runtime requires ContentRegistry-compatible resolver")
	if not failures.is_empty():
		return _failure(failures)
	var resolved: Dictionary = content_registry.resolve(placement.target_content_id, "resource")
	for failure in resolved.get("diagnostics", []):
		failures.append(str(failure))
	var definition = resolved.get("definition", null)
	if definition == null or not definition is ResourceDefinition:
		failures.append("placement target is not ResourceDefinition: %s" % placement.target_content_id)
	else:
		for failure in definition.validate_definition():
			failures.append(str(failure))
	if not failures.is_empty():
		return _failure(failures)
	return _success({"definition": definition})


func _load_or_create_state(placement, definition, delta_store) -> Dictionary:
	var envelope: Dictionary = delta_store.get_object_state(placement.placement_stable_id)
	if envelope.is_empty():
		var fresh = ResourceDepletionState.new().configure(definition.content_id, definition.capacity_units, {
			"completed_operation_ids": [],
		})
		var fresh_failures: Array[String] = fresh.validate_state()
		if not fresh_failures.is_empty():
			return _failure(fresh_failures)
		return _success({"state": fresh, "fresh": true})

	var failures: Array[String] = []
	if _sorted_string_keys(envelope) != EXPECTED_ENVELOPE_KEYS:
		failures.append("resource runtime snapshot envelope keys do not match %s" % SNAPSHOT_SCHEMA)

	var schema_variant = envelope.get("schema", null)
	if not schema_variant is String:
		failures.append("resource runtime snapshot schema must be String")
	elif schema_variant != SNAPSHOT_SCHEMA:
		failures.append("resource runtime snapshot schema must be exactly %s" % SNAPSHOT_SCHEMA)

	var placement_id_variant = envelope.get("placement_stable_id", null)
	if not placement_id_variant is String:
		failures.append("saved resource placement StableId must be String")
	elif placement_id_variant != placement.placement_stable_id:
		failures.append("saved resource placement StableId does not match current placement")

	var placement_fingerprint_variant = envelope.get("placement_fingerprint", null)
	if not placement_fingerprint_variant is String:
		failures.append("saved resource placement fingerprint must be String")
	elif placement_fingerprint_variant != placement.placement_fingerprint:
		failures.append("saved resource placement fingerprint does not match current placement")

	var resource_id_variant = envelope.get("resource_content_id", null)
	if not resource_id_variant is String:
		failures.append("saved resource ContentId must be String")
	elif resource_id_variant != placement.target_content_id:
		failures.append("saved resource ContentId does not match current placement target")

	var depletion_variant = envelope.get("depletion", null)
	if not depletion_variant is Dictionary:
		failures.append("resource runtime snapshot depletion payload must be Dictionary")
		return _failure(failures)
	var depletion: Dictionary = depletion_variant
	if _sorted_string_keys(depletion) != EXPECTED_DEPLETION_KEYS:
		failures.append("resource depletion descriptor has unexpected schema keys")

	var depletion_resource_id_variant = depletion.get("resource_content_id", null)
	if not depletion_resource_id_variant is String:
		failures.append("resource depletion resource ContentId must be String")

	var remaining_variant = depletion.get("remaining_capacity_units", null)
	if typeof(remaining_variant) != TYPE_FLOAT and typeof(remaining_variant) != TYPE_INT:
		failures.append("resource depletion remaining_capacity_units must be numeric")

	var mutable_variant = depletion.get("mutable_delta", null)
	if not mutable_variant is Dictionary:
		failures.append("resource depletion mutable_delta must be Dictionary")
		return _failure(failures)
	var mutable_delta: Dictionary = mutable_variant
	var completed_failures: Array[String] = _validate_completed_operation_ids(mutable_delta.get("completed_operation_ids", []))
	failures.append_array(completed_failures)
	if not failures.is_empty():
		return _failure(failures)

	var state = ResourceDepletionState.new().configure(
		depletion_resource_id_variant,
		float(remaining_variant),
		mutable_delta
	)
	failures.append_array(state.validate_state())
	if state.resource_content_id != str(definition.content_id):
		failures.append("saved depletion resource ContentId does not match current definition")
	if state.remaining_capacity_units > float(definition.capacity_units):
		failures.append("saved depletion capacity exceeds current authored capacity")
	if not failures.is_empty():
		return _failure(failures)
	return _success({"state": state, "fresh": false})


func _snapshot_envelope(placement, state) -> Dictionary:
	return {
		"schema": SNAPSHOT_SCHEMA,
		"placement_stable_id": placement.placement_stable_id,
		"placement_fingerprint": placement.placement_fingerprint,
		"resource_content_id": placement.target_content_id,
		"depletion": state.canonical_descriptor(),
	}


func _placement_failures(placement) -> Array[String]:
	var failures: Array[String] = []
	if placement == null or not placement is UndergroundPlacementRecord:
		return ["resource runtime requires UndergroundPlacementRecord"]
	if StableId.parse(placement.placement_stable_id) == null:
		failures.append("resource placement StableId is invalid")
	if placement.target_family != "resource":
		failures.append("resource placement target family must be resource")
	if placement.target_content_id.is_empty():
		failures.append("resource placement target ContentId is empty")
	if placement.placement_fingerprint.is_empty() or not placement.placement_fingerprint.begins_with("upf1:"):
		failures.append("resource placement fingerprint must use upf1 namespace")
	failures.sort()
	return failures


func _completed_operation_ids(state) -> Array[String]:
	var result: Array[String] = []
	var raw = state.get_delta_value("completed_operation_ids", [])
	if not raw is Array:
		return result
	for value in raw:
		result.append(str(value))
	result.sort()
	return result


func _validate_completed_operation_ids(raw) -> Array[String]:
	if not raw is Array:
		return ["completed_operation_ids must be Array"]
	var failures: Array[String] = []
	var seen: Dictionary = {}
	for value in raw:
		if not value is String:
			failures.append("completed operation id must be String")
			continue
		var operation_id: String = value
		if operation_id.is_empty() or operation_id != operation_id.strip_edges():
			failures.append("completed operation id must be non-empty and trimmed")
		if seen.has(operation_id):
			failures.append("duplicate completed operation id: %s" % operation_id)
		seen[operation_id] = true
	failures.sort()
	return failures


func _sorted_string_keys(value: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for raw_key in value.keys():
		keys.append(str(raw_key))
	keys.sort()
	return keys


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {"success": false, "diagnostics": diagnostics, "events": []}


static func _success(extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"success": true, "diagnostics": [], "events": []}
	for key in extra.keys():
		result[key] = extra[key]
	return result