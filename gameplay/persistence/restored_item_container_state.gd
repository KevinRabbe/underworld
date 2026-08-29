extends "res://gameplay/items/inventory/item_container_state.gd"

const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemStackState := preload("res://gameplay/items/inventory/item_stack_state.gd")
const ItemInstanceState := preload("res://gameplay/items/inventory/item_instance_state.gd")
const InventoryStateCodec := preload("res://gameplay/items/inventory/inventory_state_codec.gd")


func restore_record_at(
	slot_index: int,
	definition,
	kind: String,
	state_snapshot: Dictionary
) -> Dictionary:
	var failures: Array[String] = []
	if slot_index < 0 or slot_index >= slot_capacity():
		failures.append("restore slot is outside container: %d" % slot_index)
	elif _slots[slot_index] != null:
		failures.append("restore slot is already occupied: %d" % slot_index)
	if definition == null or not definition is ItemDefinition:
		failures.append("restore record requires ItemDefinition")
	else:
		for failure in definition.validate_definition():
			failures.append("item definition: %s" % failure)
	for failure in InventoryStateCodec.validate_state(state_snapshot, "restore_state"):
		failures.append(failure)
	if not failures.is_empty():
		return _failure(failures)

	var saved_item_id = state_snapshot.get("item_id", null)
	if typeof(saved_item_id) != TYPE_STRING:
		failures.append("restore state item_id must be String")
	elif str(saved_item_id) != str(definition.content_id):
		failures.append("restore state item id does not match definition: %s != %s" % [
			str(saved_item_id),
			str(definition.content_id),
		])

	var restored_state = null
	if kind == "stack":
		var raw_quantity = state_snapshot.get("quantity", null)
		var raw_stack_state = state_snapshot.get("stack_state", null)
		if typeof(raw_quantity) != TYPE_INT:
			failures.append("restore stack quantity must be int")
		if not raw_stack_state is Dictionary:
			failures.append("restore stack_state must be Dictionary")
		if failures.is_empty():
			restored_state = ItemStackState.new().configure(
				definition,
				int(raw_quantity),
				raw_stack_state
			)
	elif kind == "instance":
		var raw_per_copy_state = state_snapshot.get("per_copy_state", null)
		if not raw_per_copy_state is Dictionary:
			failures.append("restore per_copy_state must be Dictionary")
		if failures.is_empty():
			restored_state = ItemInstanceState.new().configure(definition, raw_per_copy_state)
	else:
		failures.append("restore record kind must be 'stack' or 'instance': %s" % kind)

	if restored_state != null:
		for failure in restored_state.validate_against(definition):
			failures.append(failure)
	if not failures.is_empty():
		return _failure(failures)

	_slots[slot_index] = {"definition": definition, "state": restored_state}
	var container_failures: Array[String] = validate_container()
	if not container_failures.is_empty():
		_slots[slot_index] = null
		for failure in container_failures:
			failures.append("restored container: %s" % failure)
		return _failure(failures)
	return _success({"slot": slot_index, "item_id": str(definition.content_id), "kind": kind})


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {"success": false, "diagnostics": diagnostics}


static func _success(extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"success": true, "diagnostics": []}
	for key in extra.keys():
		result[key] = extra[key]
	return result
