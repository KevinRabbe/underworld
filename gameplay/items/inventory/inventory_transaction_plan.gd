extends RefCounted

const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const InventoryStateCodec := preload("res://gameplay/items/inventory/inventory_state_codec.gd")

const KIND_REMOVE_STACK := "remove_stack"
const KIND_REMOVE_INSTANCE := "remove_instance"
const KIND_ADD_STACK := "add_stack"
const KIND_ADD_INSTANCE := "add_instance"

var _containers: Dictionary = {}
var _operations: Array[Dictionary] = []
var _failures: Array[String] = []


func bind_container(container_key: String, container) -> RefCounted:
	var key: String = container_key.strip_edges()
	if key.is_empty():
		_failures.append("transaction container key must be non-empty")
		return self
	if _containers.has(key):
		_failures.append("transaction container key is already bound: %s" % key)
		return self
	if container == null or not container is ItemContainerState:
		_failures.append("transaction container %s must be ItemContainerState" % key)
		return self
	_containers[key] = container
	return self


func remove_stack(
	container_key: String,
	definition,
	quantity: int,
	stack_state: Dictionary = {}
) -> RefCounted:
	_append_operation({
		"kind": KIND_REMOVE_STACK,
		"container": container_key,
		"definition": definition,
		"quantity": quantity,
		"state": stack_state.duplicate(true),
	})
	return self


func add_stack(
	container_key: String,
	definition,
	quantity: int,
	stack_state: Dictionary = {}
) -> RefCounted:
	_append_operation({
		"kind": KIND_ADD_STACK,
		"container": container_key,
		"definition": definition,
		"quantity": quantity,
		"state": stack_state.duplicate(true),
	})
	return self


func remove_instance(
	container_key: String,
	slot_index: int,
	definition,
	expected_per_copy_state: Variant = null
) -> RefCounted:
	var operation: Dictionary = {
		"kind": KIND_REMOVE_INSTANCE,
		"container": container_key,
		"definition": definition,
		"slot": slot_index,
	}
	if expected_per_copy_state != null:
		if expected_per_copy_state is Dictionary:
			operation["expected_state"] = expected_per_copy_state.duplicate(true)
		else:
			_failures.append("instance removal expected state must be Dictionary when provided")
	_append_operation(operation)
	return self


func add_instance(
	container_key: String,
	definition,
	per_copy_state: Dictionary = {}
) -> RefCounted:
	_append_operation({
		"kind": KIND_ADD_INSTANCE,
		"container": container_key,
		"definition": definition,
		"state": per_copy_state.duplicate(true),
	})
	return self


func transfer_stack(
	source_key: String,
	destination_key: String,
	definition,
	quantity: int,
	stack_state: Dictionary = {}
) -> RefCounted:
	remove_stack(source_key, definition, quantity, stack_state)
	add_stack(destination_key, definition, quantity, stack_state)
	return self


func transfer_instance(
	source_key: String,
	destination_key: String,
	source_slot: int,
	definition
) -> RefCounted:
	var source = _containers.get(source_key, null)
	if source == null or not source is ItemContainerState:
		_failures.append("instance transfer source container is not bound: %s" % source_key)
		return self
	var snapshot: Dictionary = source.state_at(source_slot)
	if str(snapshot.get("kind", "")) != "instance":
		_failures.append("instance transfer source slot is not an instance: %s[%d]" % [source_key, source_slot])
		return self
	var state: Dictionary = snapshot.get("state", {})
	var item_id: String = str(state.get("item_id", ""))
	if definition == null or not definition is ItemDefinition:
		_failures.append("instance transfer requires ItemDefinition")
		return self
	if item_id != str(definition.content_id):
		_failures.append(
			"instance transfer definition does not match source slot: %s != %s" % [
				item_id,
				definition.content_id,
			]
		)
		return self
	var per_copy_state: Dictionary = state.get("per_copy_state", {}).duplicate(true)
	remove_instance(source_key, source_slot, definition, per_copy_state)
	add_instance(destination_key, definition, per_copy_state)
	return self


func containers() -> Dictionary:
	return _containers.duplicate()


func operations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for operation in _operations:
		result.append(operation.duplicate(true))
	return result


func failures() -> Array[String]:
	var result: Array[String] = _failures.duplicate()
	result.sort()
	return result


func canonical_descriptor() -> Dictionary:
	var descriptors: Array = []
	for operation in _operations:
		descriptors.append(_operation_descriptor(operation))
	descriptors.sort_custom(func(a, b): return InventoryStateCodec.canonical_json(a) < InventoryStateCodec.canonical_json(b))
	var container_keys: Array[String] = []
	for raw_key in _containers.keys():
		container_keys.append(str(raw_key))
	container_keys.sort()
	return {
		"schema": "inventory.transaction.plan.v1",
		"containers": container_keys,
		"operations": descriptors,
	}


func _append_operation(operation: Dictionary) -> void:
	var container_key: String = str(operation.get("container", "")).strip_edges()
	if container_key.is_empty():
		_failures.append("transaction operation container key must be non-empty")
		return
	operation["container"] = container_key
	_operations.append(operation)


static func _operation_descriptor(operation: Dictionary) -> Dictionary:
	var definition = operation.get("definition", null)
	var descriptor: Dictionary = {
		"kind": str(operation.get("kind", "")),
		"container": str(operation.get("container", "")),
	}
	if definition != null and definition is ItemDefinition:
		descriptor["item_id"] = str(definition.content_id)
		descriptor["schema_revision"] = int(definition.schema_revision)
		descriptor["stack_limit"] = int(definition.stack_limit)
		descriptor["unit_weight"] = float(definition.unit_weight)
	else:
		descriptor["item_id"] = ""
	if operation.has("quantity"):
		descriptor["quantity"] = int(operation.get("quantity", 0))
	if operation.has("slot"):
		descriptor["slot"] = int(operation.get("slot", -1))
	if operation.has("state"):
		descriptor["state"] = InventoryStateCodec.canonicalize(operation.get("state", {}))
	if operation.has("expected_state"):
		descriptor["expected_state"] = InventoryStateCodec.canonicalize(operation.get("expected_state", {}))
	return descriptor
