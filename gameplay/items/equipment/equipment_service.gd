extends RefCounted

const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquipmentSlotRule := preload("res://gameplay/items/equipment/equipment_slot_rule.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const InventoryTransactionPlan := preload("res://gameplay/items/inventory/inventory_transaction_plan.gd")
const InventoryTransactionService := preload("res://gameplay/items/inventory/inventory_transaction_service.gd")


func equip_from_inventory(
	equipment_state,
	inventory,
	source_slot: int,
	definition,
	target_slot_key: String
) -> Dictionary:
	var failures := _common_failures(equipment_state, inventory, definition, target_slot_key)
	if not failures.is_empty():
		return _failure(failures)
	var rule = equipment_state.slot_rule(target_slot_key)
	failures.append_array(rule.compatibility_failures(definition))
	var source_record: Dictionary = inventory.state_at(source_slot)
	failures.append_array(_record_definition_failures(source_record, definition, "inventory source"))
	if not failures.is_empty():
		return _failure(failures)

	var target_container = equipment_state.slot_container(target_slot_key)
	var target_record: Dictionary = target_container.state_at(0)
	var target_definition = equipment_state.definition_at(target_slot_key)
	if not target_record.is_empty() and (target_definition == null or not target_definition is ItemDefinition):
		return _failure(["occupied equipment slot is missing resolved ItemDefinition: %s" % target_slot_key])

	var plan = InventoryTransactionPlan.new()
	plan.bind_container("equipment", target_container)
	plan.bind_container("inventory", inventory)
	if not target_record.is_empty():
		_append_record_transfer(plan, "equipment", "inventory", 0, target_record, target_definition)
	_append_record_transfer(plan, "inventory", "equipment", source_slot, source_record, definition)
	if not plan.failures().is_empty():
		return _failure(plan.failures())

	var result: Dictionary = InventoryTransactionService.new().commit(plan)
	if not bool(result.get("success", false)):
		return result
	equipment_state._commit_definition(target_slot_key, definition)
	var events: Array = result.get("events", []).duplicate(true)
	events.append({
		"type": "equipment.slot_changed",
		"slot_key": target_slot_key,
		"item_id": str(definition.content_id),
		"replaced_item_id": str(target_definition.content_id) if target_definition != null else "",
	})
	result["events"] = events
	result["slot_key"] = target_slot_key
	return result


func unequip_to_inventory(
	equipment_state,
	target_slot_key: String,
	inventory
) -> Dictionary:
	var failures: Array[String] = []
	if equipment_state == null or not equipment_state is EquipmentHotbarState:
		failures.append("equipment service requires EquipmentHotbarState")
	if inventory == null or not inventory is ItemContainerState:
		failures.append("equipment service requires inventory ItemContainerState")
	if not failures.is_empty():
		return _failure(failures)
	var target_container = equipment_state.slot_container(target_slot_key)
	if target_container == null or not target_container is ItemContainerState:
		return _failure(["unknown semantic equipment slot: %s" % target_slot_key])
	var target_record: Dictionary = target_container.state_at(0)
	if target_record.is_empty():
		return _failure(["equipment slot is already empty: %s" % target_slot_key])
	var definition = equipment_state.definition_at(target_slot_key)
	if definition == null or not definition is ItemDefinition:
		return _failure(["occupied equipment slot is missing resolved ItemDefinition: %s" % target_slot_key])

	var plan = InventoryTransactionPlan.new()
	plan.bind_container("equipment", target_container)
	plan.bind_container("inventory", inventory)
	_append_record_transfer(plan, "equipment", "inventory", 0, target_record, definition)
	if not plan.failures().is_empty():
		return _failure(plan.failures())
	var result: Dictionary = InventoryTransactionService.new().commit(plan)
	if not bool(result.get("success", false)):
		return result
	equipment_state._commit_definition(target_slot_key, null)
	var events: Array = result.get("events", []).duplicate(true)
	events.append({
		"type": "equipment.slot_changed",
		"slot_key": target_slot_key,
		"item_id": "",
		"unequipped_item_id": str(definition.content_id),
	})
	result["events"] = events
	result["slot_key"] = target_slot_key
	return result


static func _common_failures(
	equipment_state,
	inventory,
	definition,
	target_slot_key: String
) -> Array[String]:
	var failures: Array[String] = []
	if equipment_state == null or not equipment_state is EquipmentHotbarState:
		failures.append("equipment service requires EquipmentHotbarState")
		return failures
	if inventory == null or not inventory is ItemContainerState:
		failures.append("equipment service requires inventory ItemContainerState")
	if definition == null or not definition is ItemDefinition:
		failures.append("equipment service requires ItemDefinition")
	if equipment_state.slot_rule(target_slot_key) == null:
		failures.append("unknown semantic equipment slot: %s" % target_slot_key)
	for failure in equipment_state.validate_state():
		failures.append("equipment state: %s" % failure)
	failures.sort()
	return failures


static func _record_definition_failures(
	record: Dictionary,
	definition,
	label: String
) -> Array[String]:
	var failures: Array[String] = []
	if record.is_empty():
		return ["%s slot is empty" % label]
	var state: Dictionary = record.get("state", {})
	var item_id: String = str(state.get("item_id", ""))
	if definition == null or not definition is ItemDefinition:
		failures.append("%s requires ItemDefinition" % label)
	elif item_id != str(definition.content_id):
		failures.append("%s definition does not match stored item: %s != %s" % [
			label,
			item_id,
			definition.content_id,
		])
	if str(record.get("kind", "")) != "instance" and str(record.get("kind", "")) != "stack":
		failures.append("%s has unsupported item-state kind" % label)
	failures.sort()
	return failures


static func _append_record_transfer(
	plan,
	source_key: String,
	destination_key: String,
	source_slot: int,
	record: Dictionary,
	definition
) -> void:
	var kind: String = str(record.get("kind", ""))
	var state: Dictionary = record.get("state", {})
	if kind == "instance":
		plan.transfer_instance(source_key, destination_key, source_slot, definition)
		return
	if kind == "stack":
		plan.transfer_stack(
			source_key,
			destination_key,
			definition,
			int(state.get("quantity", 0)),
			state.get("stack_state", {})
		)


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {
		"success": false,
		"diagnostics": diagnostics,
		"events": [],
		"transaction_fingerprint": "",
		"operation_count": 0,
	}
