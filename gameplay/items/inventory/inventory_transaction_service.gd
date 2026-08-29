extends RefCounted

const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const InventoryStateCodec := preload("res://gameplay/items/inventory/inventory_state_codec.gd")
const InventoryTransactionPlan := preload("res://gameplay/items/inventory/inventory_transaction_plan.gd")

const EPSILON := 0.00001


func validate(plan) -> Dictionary:
	var preflight: Dictionary = _preflight(plan)
	return {
		"success": bool(preflight.get("success", false)),
		"diagnostics": preflight.get("diagnostics", []).duplicate(),
		"transaction_fingerprint": str(preflight.get("transaction_fingerprint", "")),
		"operation_count": int(preflight.get("operation_count", 0)),
		"events": [],
	}


func commit(plan) -> Dictionary:
	var preflight: Dictionary = _preflight(plan)
	if not bool(preflight.get("success", false)):
		return preflight

	var containers: Dictionary = preflight.get("_containers", {})
	var baselines: Dictionary = preflight.get("_baselines", {})
	var container_keys: Array[String] = []
	for raw_key in containers.keys():
		container_keys.append(str(raw_key))
	container_keys.sort()
	for container_key in container_keys:
		var container = containers[container_key]
		if container.canonical_json() != str(baselines.get(container_key, "")):
			return _failure(
				["transaction participant changed after preflight: %s" % container_key],
				str(preflight.get("transaction_fingerprint", ""))
			)

	var events: Array = []
	var ordered_operations: Array = preflight.get("_ordered_operations", [])
	for operation in ordered_operations:
		var container_key: String = str(operation.get("container", ""))
		var container = containers.get(container_key, null)
		var result: Dictionary = _commit_operation(container, operation)
		if not bool(result.get("success", false)):
			var diagnostics: Array[String] = [
				"validated transaction commit failed unexpectedly at %s: %s" % [
					_operation_label(operation),
					str(result.get("diagnostics", [])),
				]
			]
			return _failure(diagnostics, str(preflight.get("transaction_fingerprint", "")))
		events.append(_event_descriptor(operation, result))

	return {
		"success": true,
		"diagnostics": [],
		"transaction_fingerprint": str(preflight.get("transaction_fingerprint", "")),
		"operation_count": ordered_operations.size(),
		"events": events,
	}


func _preflight(plan) -> Dictionary:
	var failures: Array[String] = []
	if plan == null or not plan is InventoryTransactionPlan:
		return _failure(["transaction service requires InventoryTransactionPlan"])

	failures.append_array(plan.failures())
	var containers: Dictionary = plan.containers()
	if containers.is_empty():
		failures.append("transaction plan must bind at least one container")

	var seen_instance_ids: Dictionary = {}
	var baselines: Dictionary = {}
	var projections: Dictionary = {}
	var container_keys: Array[String] = []
	for raw_key in containers.keys():
		container_keys.append(str(raw_key))
	container_keys.sort()
	for container_key in container_keys:
		var container = containers.get(container_key, null)
		if container == null or not container is ItemContainerState:
			failures.append("transaction participant %s is not ItemContainerState" % container_key)
			continue
		var instance_key: String = str(container.get_instance_id())
		if seen_instance_ids.has(instance_key):
			failures.append(
				"same ItemContainerState cannot be bound under multiple transaction keys: %s and %s" % [
					seen_instance_ids[instance_key],
					container_key,
				]
			)
			continue
		seen_instance_ids[instance_key] = container_key
		var container_failures: Array[String] = container.validate_container()
		for failure in container_failures:
			failures.append("%s: %s" % [container_key, failure])
		baselines[container_key] = container.canonical_json()
		projections[container_key] = _projection_from_container(container)

	var operations: Array[Dictionary] = plan.operations()
	if operations.is_empty():
		failures.append("transaction plan must contain at least one operation")
	operations.sort_custom(func(a, b): return _operation_sort_key(a) < _operation_sort_key(b))

	var descriptors: Array = []
	for operation in operations:
		descriptors.append(_operation_descriptor(operation))
	var transaction_fingerprint: String = InventoryStateCodec.canonical_json({
		"schema": "inventory.transaction.v1",
		"operations": descriptors,
	})

	if failures.is_empty():
		for operation in operations:
			var operation_failures: Array[String] = _simulate_operation(containers, projections, operation)
			for failure in operation_failures:
				failures.append("%s: %s" % [_operation_label(operation), failure])

	if not failures.is_empty():
		return _failure(failures, transaction_fingerprint)

	return {
		"success": true,
		"diagnostics": [],
		"transaction_fingerprint": transaction_fingerprint,
		"operation_count": operations.size(),
		"events": [],
		"_containers": containers,
		"_baselines": baselines,
		"_projections": projections,
		"_ordered_operations": operations,
	}


static func _projection_from_container(container) -> Dictionary:
	var snapshot: Dictionary = container.canonical_snapshot()
	var capacity: int = int(snapshot.get("slot_capacity", container.slot_capacity()))
	var slots: Array = []
	slots.resize(capacity)
	for record_variant in snapshot.get("slots", []):
		if not record_variant is Dictionary:
			continue
		var record: Dictionary = record_variant
		var slot_index: int = int(record.get("slot", -1))
		if slot_index < 0 or slot_index >= slots.size():
			continue
		slots[slot_index] = record.duplicate(true)
	return {
		"slots": slots,
		"weight": float(container.current_weight()),
		"max_weight": float(container.max_weight()),
		"contracts": {},
	}


func _simulate_operation(
	containers: Dictionary,
	projections: Dictionary,
	operation: Dictionary
) -> Array[String]:
	var container_key: String = str(operation.get("container", ""))
	if not containers.has(container_key) or not projections.has(container_key):
		return ["transaction container is not bound: %s" % container_key]
	var container = containers[container_key]
	var projection: Dictionary = projections[container_key]
	var kind: String = str(operation.get("kind", ""))
	match kind:
		InventoryTransactionPlan.KIND_REMOVE_STACK:
			return _simulate_remove_stack(container, projection, operation)
		InventoryTransactionPlan.KIND_REMOVE_INSTANCE:
			return _simulate_remove_instance(container, projection, operation)
		InventoryTransactionPlan.KIND_ADD_STACK:
			return _simulate_add_stack(container, projection, operation)
		InventoryTransactionPlan.KIND_ADD_INSTANCE:
			return _simulate_add_instance(container, projection, operation)
		_:
			return ["unknown inventory transaction operation kind: %s" % kind]


func _simulate_remove_stack(container, projection: Dictionary, operation: Dictionary) -> Array[String]:
	var definition = operation.get("definition", null)
	var failures: Array[String] = _operation_definition_failures(container, projection, definition)
	if definition == null or not definition is ItemDefinition:
		return failures
	if definition.stack_limit <= 1:
		failures.append("stack removal requires stackable ItemDefinition: %s" % definition.content_id)
	var quantity: int = int(operation.get("quantity", 0))
	if quantity <= 0:
		failures.append("stack removal quantity must be > 0")
	var stack_state: Dictionary = operation.get("state", {})
	for failure in InventoryStateCodec.validate_state(stack_state, "transaction.stack_state"):
		failures.append(failure)
	if not failures.is_empty():
		failures.sort()
		return failures

	var compatibility_key: String = _stack_key(str(definition.content_id), stack_state)
	var available: int = 0
	for slot_variant in projection.get("slots", []):
		if slot_variant == null or not slot_variant is Dictionary:
			continue
		var record: Dictionary = slot_variant
		if str(record.get("kind", "")) != "stack":
			continue
		var state: Dictionary = record.get("state", {})
		if _snapshot_stack_key(state) == compatibility_key:
			available += int(state.get("quantity", 0))
	if available < quantity:
		return [
			"insufficient compatible stack quantity for %s: requested %d, available %d" % [
				definition.content_id,
				quantity,
				available,
			]
		]

	var remaining: int = quantity
	var slots: Array = projection.get("slots", [])
	for index in range(slots.size()):
		if remaining <= 0:
			break
		var slot_variant = slots[index]
		if slot_variant == null or not slot_variant is Dictionary:
			continue
		var record: Dictionary = slot_variant
		if str(record.get("kind", "")) != "stack":
			continue
		var state: Dictionary = record.get("state", {})
		if _snapshot_stack_key(state) != compatibility_key:
			continue
		var moved: int = mini(int(state.get("quantity", 0)), remaining)
		var new_quantity: int = int(state.get("quantity", 0)) - moved
		remaining -= moved
		if new_quantity <= 0:
			slots[index] = null
		else:
			state["quantity"] = new_quantity
			record["state"] = state
			slots[index] = record
	projection["slots"] = slots
	projection["weight"] = maxf(float(projection.get("weight", 0.0)) - definition.unit_weight * float(quantity), 0.0)
	return []


func _simulate_add_stack(container, projection: Dictionary, operation: Dictionary) -> Array[String]:
	var definition = operation.get("definition", null)
	var failures: Array[String] = _operation_definition_failures(container, projection, definition)
	if definition == null or not definition is ItemDefinition:
		return failures
	if definition.stack_limit <= 1:
		failures.append("stack addition requires stackable ItemDefinition: %s" % definition.content_id)
	var quantity: int = int(operation.get("quantity", 0))
	if quantity <= 0:
		failures.append("stack addition quantity must be > 0")
	var stack_state: Dictionary = operation.get("state", {})
	for failure in InventoryStateCodec.validate_state(stack_state, "transaction.stack_state"):
		failures.append(failure)
	if not failures.is_empty():
		failures.sort()
		return failures

	var compatibility_key: String = _stack_key(str(definition.content_id), stack_state)
	var available_units: int = 0
	var slots: Array = projection.get("slots", [])
	for slot_variant in slots:
		if slot_variant == null:
			available_units += definition.stack_limit
			continue
		if not slot_variant is Dictionary:
			continue
		var record: Dictionary = slot_variant
		if str(record.get("kind", "")) != "stack":
			continue
		var state: Dictionary = record.get("state", {})
		if _snapshot_stack_key(state) == compatibility_key:
			available_units += maxi(definition.stack_limit - int(state.get("quantity", 0)), 0)
	if available_units < quantity:
		return [
			"insufficient stack-slot capacity for %s: requested %d, available %d" % [
				definition.content_id,
				quantity,
				available_units,
			]
		]

	var projected_weight: float = float(projection.get("weight", 0.0)) + definition.unit_weight * float(quantity)
	if not _projection_weight_allows(projection, projected_weight):
		return ["inventory weight capacity would be exceeded by %s x%d" % [definition.content_id, quantity]]

	var remaining: int = quantity
	for index in range(slots.size()):
		if remaining <= 0:
			break
		var slot_variant = slots[index]
		if slot_variant == null or not slot_variant is Dictionary:
			continue
		var record: Dictionary = slot_variant
		if str(record.get("kind", "")) != "stack":
			continue
		var state: Dictionary = record.get("state", {})
		if _snapshot_stack_key(state) != compatibility_key:
			continue
		var available: int = maxi(definition.stack_limit - int(state.get("quantity", 0)), 0)
		var moved: int = mini(available, remaining)
		state["quantity"] = int(state.get("quantity", 0)) + moved
		record["state"] = state
		slots[index] = record
		remaining -= moved

	for index in range(slots.size()):
		if remaining <= 0:
			break
		if slots[index] != null:
			continue
		var moved: int = mini(definition.stack_limit, remaining)
		slots[index] = {
			"slot": index,
			"kind": "stack",
			"state": {
				"item_id": str(definition.content_id),
				"quantity": moved,
				"stack_state": InventoryStateCodec.canonicalize(stack_state),
			},
		}
		remaining -= moved

	projection["slots"] = slots
	projection["weight"] = projected_weight
	return []


func _simulate_remove_instance(container, projection: Dictionary, operation: Dictionary) -> Array[String]:
	var definition = operation.get("definition", null)
	var failures: Array[String] = _operation_definition_failures(container, projection, definition)
	if definition == null or not definition is ItemDefinition:
		return failures
	if definition.stack_limit != 1:
		failures.append("instance removal requires non-stackable ItemDefinition: %s" % definition.content_id)
	var slot_index: int = int(operation.get("slot", -1))
	var slots: Array = projection.get("slots", [])
	if slot_index < 0 or slot_index >= slots.size():
		failures.append("instance removal slot is outside container: %d" % slot_index)
		failures.sort()
		return failures
	var record_variant = slots[slot_index]
	if record_variant == null or not record_variant is Dictionary:
		failures.append("instance removal slot is empty: %d" % slot_index)
		failures.sort()
		return failures
	var record: Dictionary = record_variant
	if str(record.get("kind", "")) != "instance":
		failures.append("instance removal slot does not contain an instance: %d" % slot_index)
		failures.sort()
		return failures
	var state: Dictionary = record.get("state", {})
	if str(state.get("item_id", "")) != str(definition.content_id):
		failures.append(
			"instance removal definition does not match slot %d: %s != %s" % [
				slot_index,
				state.get("item_id", ""),
				definition.content_id,
			]
		)
	if operation.has("expected_state"):
		var expected_json: String = InventoryStateCodec.canonical_json(operation.get("expected_state", {}))
		var actual_json: String = InventoryStateCodec.canonical_json(state.get("per_copy_state", {}))
		if expected_json != actual_json:
			failures.append("instance removal mutable state changed before commit at slot %d" % slot_index)
	if not failures.is_empty():
		failures.sort()
		return failures
	slots[slot_index] = null
	projection["slots"] = slots
	projection["weight"] = maxf(float(projection.get("weight", 0.0)) - definition.unit_weight, 0.0)
	return []


func _simulate_add_instance(container, projection: Dictionary, operation: Dictionary) -> Array[String]:
	var definition = operation.get("definition", null)
	var failures: Array[String] = _operation_definition_failures(container, projection, definition)
	if definition == null or not definition is ItemDefinition:
		return failures
	if definition.stack_limit != 1:
		failures.append("instance addition requires non-stackable ItemDefinition: %s" % definition.content_id)
	var per_copy_state: Dictionary = operation.get("state", {})
	for failure in InventoryStateCodec.validate_state(per_copy_state, "transaction.per_copy_state"):
		failures.append(failure)
	if not failures.is_empty():
		failures.sort()
		return failures

	var slots: Array = projection.get("slots", [])
	var empty_slot: int = -1
	for index in range(slots.size()):
		if slots[index] == null:
			empty_slot = index
			break
	if empty_slot < 0:
		return ["inventory has no empty slot for item instance: %s" % definition.content_id]
	var projected_weight: float = float(projection.get("weight", 0.0)) + definition.unit_weight
	if not _projection_weight_allows(projection, projected_weight):
		return ["inventory weight capacity would be exceeded by item instance: %s" % definition.content_id]

	slots[empty_slot] = {
		"slot": empty_slot,
		"kind": "instance",
		"state": {
			"item_id": str(definition.content_id),
			"per_copy_state": InventoryStateCodec.canonicalize(per_copy_state),
		},
	}
	projection["slots"] = slots
	projection["weight"] = projected_weight
	return []


func _operation_definition_failures(
	container,
	projection: Dictionary,
	definition
) -> Array[String]:
	var failures: Array[String] = []
	if definition == null or not definition is ItemDefinition:
		return ["transaction operation requires ItemDefinition"]
	for failure in definition.validate_definition():
		failures.append("item definition: %s" % failure)
	if not failures.is_empty():
		failures.sort()
		return failures

	for failure in container._same_content_id_definition_failures(definition):
		failures.append(failure)

	var item_id: String = str(definition.content_id)
	var contracts: Dictionary = projection.get("contracts", {})
	var incoming_contract: String = _definition_contract_key(definition)
	if contracts.has(item_id) and str(contracts[item_id]) != incoming_contract:
		failures.append("planned authored item definition mismatch for %s" % item_id)
	else:
		contracts[item_id] = incoming_contract
		projection["contracts"] = contracts
	failures.sort()
	return failures


static func _commit_operation(container, operation: Dictionary) -> Dictionary:
	var definition = operation.get("definition", null)
	match str(operation.get("kind", "")):
		InventoryTransactionPlan.KIND_REMOVE_STACK:
			return container.remove_stack(
				str(definition.content_id),
				int(operation.get("quantity", 0)),
				operation.get("state", {})
			)
		InventoryTransactionPlan.KIND_REMOVE_INSTANCE:
			return container.remove_instance_at(int(operation.get("slot", -1)))
		InventoryTransactionPlan.KIND_ADD_STACK:
			return container.add_stack(
				definition,
				int(operation.get("quantity", 0)),
				operation.get("state", {})
			)
		InventoryTransactionPlan.KIND_ADD_INSTANCE:
			return container.add_instance(definition, operation.get("state", {}))
		_:
			return {"success": false, "diagnostics": ["unknown transaction operation kind"]}


static func _operation_sort_key(operation: Dictionary) -> String:
	var kind: String = str(operation.get("kind", ""))
	var phase: int = 99
	match kind:
		InventoryTransactionPlan.KIND_REMOVE_INSTANCE:
			phase = 0
		InventoryTransactionPlan.KIND_REMOVE_STACK:
			phase = 1
		InventoryTransactionPlan.KIND_ADD_STACK:
			phase = 2
		InventoryTransactionPlan.KIND_ADD_INSTANCE:
			phase = 3
	var definition = operation.get("definition", null)
	var item_id: String = str(definition.content_id) if definition != null and definition is ItemDefinition else ""
	var state_json: String = InventoryStateCodec.canonical_json(
		operation.get("state", operation.get("expected_state", {}))
	)
	return "%02d|%s|%s|%s|%010d|%010d" % [
		phase,
		str(operation.get("container", "")),
		item_id,
		state_json,
		int(operation.get("slot", -1)) + 1,
		int(operation.get("quantity", 0)),
	]


static func _operation_descriptor(operation: Dictionary) -> Dictionary:
	var definition = operation.get("definition", null)
	var descriptor: Dictionary = {
		"kind": str(operation.get("kind", "")),
		"container": str(operation.get("container", "")),
		"item_id": "",
	}
	if definition != null and definition is ItemDefinition:
		descriptor["item_id"] = str(definition.content_id)
		descriptor["schema_revision"] = int(definition.schema_revision)
		descriptor["stack_limit"] = int(definition.stack_limit)
		descriptor["unit_weight"] = float(definition.unit_weight)
	if operation.has("quantity"):
		descriptor["quantity"] = int(operation.get("quantity", 0))
	if operation.has("slot"):
		descriptor["slot"] = int(operation.get("slot", -1))
	if operation.has("state"):
		descriptor["state"] = InventoryStateCodec.canonicalize(operation.get("state", {}))
	if operation.has("expected_state"):
		descriptor["expected_state"] = InventoryStateCodec.canonicalize(operation.get("expected_state", {}))
	return descriptor


static func _event_descriptor(operation: Dictionary, result: Dictionary) -> Dictionary:
	return {
		"operation": _operation_descriptor(operation),
		"result": InventoryStateCodec.canonicalize(result),
	}


static func _operation_label(operation: Dictionary) -> String:
	var descriptor: Dictionary = _operation_descriptor(operation)
	return "%s[%s:%s]" % [
		descriptor.get("kind", ""),
		descriptor.get("container", ""),
		descriptor.get("item_id", ""),
	]


static func _definition_contract_key(definition) -> String:
	return InventoryStateCodec.canonical_json({
		"item_id": str(definition.content_id),
		"schema_revision": int(definition.schema_revision),
		"stack_limit": int(definition.stack_limit),
		"unit_weight": float(definition.unit_weight),
	})


static func _snapshot_stack_key(state: Dictionary) -> String:
	return _stack_key(
		str(state.get("item_id", "")),
		state.get("stack_state", {})
	)


static func _stack_key(item_content_id: String, stack_state: Dictionary) -> String:
	return "%s|%s" % [item_content_id, InventoryStateCodec.canonical_json(stack_state)]


static func _projection_weight_allows(projection: Dictionary, projected_weight: float) -> bool:
	var max_weight: float = float(projection.get("max_weight", -1.0))
	return max_weight < 0.0 or projected_weight <= max_weight + EPSILON


static func _failure(messages: Array, fingerprint: String = "") -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {
		"success": false,
		"diagnostics": diagnostics,
		"transaction_fingerprint": fingerprint,
		"operation_count": 0,
		"events": [],
	}
