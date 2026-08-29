extends RefCounted

const ContentId := preload("res://core/content/identity/content_id.gd")
const FiniteNumber := preload("res://core/content/validation/finite_number.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemStackState := preload("res://gameplay/items/inventory/item_stack_state.gd")
const ItemInstanceState := preload("res://gameplay/items/inventory/item_instance_state.gd")
const InventoryStateCodec := preload("res://gameplay/items/inventory/inventory_state_codec.gd")

const SNAPSHOT_SCHEMA := "inventory.container.v1"
const UNLIMITED_WEIGHT := -1.0

var _slot_capacity: int = 0
var _max_weight: float = UNLIMITED_WEIGHT
var _slots: Array = []


func configure(p_slot_capacity: int, p_max_weight: float = UNLIMITED_WEIGHT) -> RefCounted:
	_slot_capacity = p_slot_capacity
	_max_weight = p_max_weight
	_slots.clear()
	_slots.resize(maxi(p_slot_capacity, 0))
	return self


func slot_capacity() -> int:
	return _slot_capacity


func max_weight() -> float:
	return _max_weight


func occupied_slot_count() -> int:
	var count: int = 0
	for slot in _slots:
		if slot != null:
			count += 1
	return count


func current_weight() -> float:
	var total: float = 0.0
	for slot in _slots:
		if slot == null or not slot is Dictionary:
			continue
		var definition = slot.get("definition", null)
		var state = slot.get("state", null)
		if definition == null or not definition is ItemDefinition or state == null:
			continue
		if state is ItemStackState:
			total += definition.unit_weight * float(state.quantity)
		elif state is ItemInstanceState:
			total += definition.unit_weight
	return total


func validate_container() -> Array[String]:
	var failures: Array[String] = []
	if _slot_capacity < 1:
		failures.append("inventory slot capacity must be >= 1")
	if not FiniteNumber.is_finite_number(_max_weight):
		failures.append("inventory max_weight must be finite")
	elif not _is_valid_weight_capacity(_max_weight):
		failures.append("inventory max weight must be -1 (unlimited) or >= 0")
	if _slots.size() != maxi(_slot_capacity, 0):
		failures.append("inventory slot storage size does not match configured slot capacity")

	for index in range(_slots.size()):
		var slot = _slots[index]
		if slot == null:
			continue
		if not slot is Dictionary:
			failures.append("inventory slot %d has invalid internal record type" % index)
			continue
		var definition = slot.get("definition", null)
		var state = slot.get("state", null)
		if definition == null or not definition is ItemDefinition:
			failures.append("inventory slot %d is missing resolved ItemDefinition" % index)
			continue
		if state == null or (not state is ItemStackState and not state is ItemInstanceState):
			failures.append("inventory slot %d has incompatible item state type" % index)
			continue
		for failure in state.validate_against(definition):
			failures.append("slot %d: %s" % [index, failure])

	var occupied_weight: float = current_weight()
	if not FiniteNumber.is_finite_number(occupied_weight):
		failures.append("inventory current_weight must be finite")
	elif FiniteNumber.is_finite_number(_max_weight) and _max_weight >= 0.0 and occupied_weight > _max_weight + 0.00001:
		failures.append(
			"inventory occupied weight exceeds configured capacity: %.6f > %.6f" % [
				occupied_weight,
				_max_weight,
			]
		)
	failures.sort()
	return failures


func add_stack(definition, quantity: int, stack_state: Dictionary = {}) -> Dictionary:
	var failures: Array[String] = validate_container()
	failures.append_array(_definition_failures(definition))
	if quantity <= 0:
		failures.append("stack add quantity must be > 0")
	if definition != null and definition is ItemDefinition and definition.stack_limit <= 1:
		failures.append("non-stackable item requires add_instance: %s" % definition.content_id)
	for failure in InventoryStateCodec.validate_state(stack_state, "stack_state"):
		failures.append(failure)
	if not failures.is_empty():
		return _failure(failures)

	var contract_failures: Array[String] = _same_content_id_definition_failures(definition)
	if not contract_failures.is_empty():
		return _failure(contract_failures)

	var compatibility_key: String = _stack_key(str(definition.content_id), stack_state)
	var available_units: int = 0
	for slot in _slots:
		if slot == null:
			available_units += definition.stack_limit
			continue
		var state = slot.get("state", null) if slot is Dictionary else null
		if state != null and state is ItemStackState and state.compatibility_key() == compatibility_key:
			available_units += maxi(definition.stack_limit - state.quantity, 0)
	if available_units < quantity:
		return _failure([
			"inventory lacks stack-slot capacity for %s: requested %d, available %d" % [
				definition.content_id,
				quantity,
				available_units,
			]
		])

	var added_weight: float = definition.unit_weight * float(quantity)
	var projected_weight: float = current_weight() + added_weight
	if not FiniteNumber.is_finite_number(projected_weight):
		return _failure([
			"inventory projected_weight must be finite for stack add: %s x%d" % [
				definition.content_id,
				quantity,
			]
		])
	if not _weight_allows(projected_weight):
		return _failure([
			"inventory weight capacity would be exceeded by %s x%d" % [definition.content_id, quantity]
		])

	var remaining: int = quantity
	for index in range(_slots.size()):
		if remaining <= 0:
			break
		var slot = _slots[index]
		if slot == null or not slot is Dictionary:
			continue
		var state = slot.get("state", null)
		if state == null or not state is ItemStackState or state.compatibility_key() != compatibility_key:
			continue
		var available: int = maxi(definition.stack_limit - state.quantity, 0)
		var moved: int = mini(available, remaining)
		state.quantity += moved
		remaining -= moved

	for index in range(_slots.size()):
		if remaining <= 0:
			break
		if _slots[index] != null:
			continue
		var moved: int = mini(definition.stack_limit, remaining)
		var state = ItemStackState.new().configure(definition, moved, stack_state)
		_slots[index] = {"definition": definition, "state": state}
		remaining -= moved

	return _success({"added": quantity, "item_id": str(definition.content_id)})


func remove_stack(item_content_id: String, quantity: int, stack_state: Dictionary = {}) -> Dictionary:
	var failures: Array[String] = validate_container()
	for failure in ContentId.validate(item_content_id):
		failures.append("stack remove item id: %s" % failure)
	if quantity <= 0:
		failures.append("stack remove quantity must be > 0")
	for failure in InventoryStateCodec.validate_state(stack_state, "stack_state"):
		failures.append(failure)
	if not failures.is_empty():
		return _failure(failures)

	var compatibility_key: String = _stack_key(item_content_id, stack_state)
	var available: int = 0
	for slot in _slots:
		if slot == null or not slot is Dictionary:
			continue
		var state = slot.get("state", null)
		if state != null and state is ItemStackState and state.compatibility_key() == compatibility_key:
			available += state.quantity
	if available < quantity:
		return _failure([
			"inventory lacks requested compatible stack quantity for %s: requested %d, available %d" % [
				item_content_id,
				quantity,
				available,
			]
		])

	var remaining: int = quantity
	for index in range(_slots.size()):
		if remaining <= 0:
			break
		var slot = _slots[index]
		if slot == null or not slot is Dictionary:
			continue
		var state = slot.get("state", null)
		if state == null or not state is ItemStackState or state.compatibility_key() != compatibility_key:
			continue
		var moved: int = mini(state.quantity, remaining)
		state.quantity -= moved
		remaining -= moved
		if state.quantity == 0:
			_slots[index] = null

	return _success({"removed": quantity, "item_id": item_content_id})


func add_instance(definition, per_copy_state: Dictionary = {}) -> Dictionary:
	var failures: Array[String] = validate_container()
	failures.append_array(_definition_failures(definition))
	if definition != null and definition is ItemDefinition and definition.stack_limit != 1:
		failures.append("stackable item requires add_stack: %s" % definition.content_id)
	for failure in InventoryStateCodec.validate_state(per_copy_state, "per_copy_state"):
		failures.append(failure)
	if not failures.is_empty():
		return _failure(failures)

	var contract_failures: Array[String] = _same_content_id_definition_failures(definition)
	if not contract_failures.is_empty():
		return _failure(contract_failures)

	var empty_slot: int = _first_empty_slot()
	if empty_slot < 0:
		return _failure(["inventory has no empty slot for item instance: %s" % definition.content_id])
	var projected_weight: float = current_weight() + definition.unit_weight
	if not FiniteNumber.is_finite_number(projected_weight):
		return _failure([
			"inventory projected_weight must be finite for item instance: %s" % definition.content_id
		])
	if not _weight_allows(projected_weight):
		return _failure(["inventory weight capacity would be exceeded by item instance: %s" % definition.content_id])

	var state = ItemInstanceState.new().configure(definition, per_copy_state)
	var state_failures: Array[String] = state.validate_against(definition)
	if not state_failures.is_empty():
		return _failure(state_failures)
	_slots[empty_slot] = {"definition": definition, "state": state}
	return _success({"slot": empty_slot, "item_id": str(definition.content_id)})


func remove_instance_at(slot_index: int) -> Dictionary:
	var failures: Array[String] = validate_container()
	if slot_index < 0 or slot_index >= _slots.size():
		failures.append("instance remove slot is outside container: %d" % slot_index)
	if not failures.is_empty():
		return _failure(failures)
	var slot = _slots[slot_index]
	if slot == null or not slot is Dictionary:
		return _failure(["instance remove slot is empty: %d" % slot_index])
	var state = slot.get("state", null)
	if state == null or not state is ItemInstanceState:
		return _failure(["slot does not contain ItemInstanceState: %d" % slot_index])
	var removed: Dictionary = state.snapshot()
	_slots[slot_index] = null
	return _success({"slot": slot_index, "instance": removed})


func stack_quantity(item_content_id: String, stack_state: Dictionary = {}) -> int:
	var key: String = _stack_key(item_content_id, stack_state)
	var total: int = 0
	for slot in _slots:
		if slot == null or not slot is Dictionary:
			continue
		var state = slot.get("state", null)
		if state != null and state is ItemStackState and state.compatibility_key() == key:
			total += state.quantity
	return total


func instance_count(item_content_id: String) -> int:
	var count: int = 0
	for slot in _slots:
		if slot == null or not slot is Dictionary:
			continue
		var state = slot.get("state", null)
		if state != null and state is ItemInstanceState and state.item_content_id == item_content_id:
			count += 1
	return count


func quantity_of(item_content_id: String) -> int:
	var total: int = instance_count(item_content_id)
	for slot in _slots:
		if slot == null or not slot is Dictionary:
			continue
		var state = slot.get("state", null)
		if state != null and state is ItemStackState and state.item_content_id == item_content_id:
			total += state.quantity
	return total


func state_at(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= _slots.size():
		return {}
	return _slot_snapshot(slot_index)


func resize_capacity(new_slot_capacity: int, new_max_weight: float) -> Dictionary:
	var failures: Array[String] = validate_container()
	if new_slot_capacity < 1:
		failures.append("new inventory slot capacity must be >= 1")
	if not FiniteNumber.is_finite_number(new_max_weight):
		failures.append("new inventory max_weight must be finite")
	elif not _is_valid_weight_capacity(new_max_weight):
		failures.append("new inventory max weight must be -1 (unlimited) or >= 0")
	if new_slot_capacity < _slots.size():
		for index in range(new_slot_capacity, _slots.size()):
			if _slots[index] != null:
				failures.append("cannot shrink inventory across occupied slot %d" % index)
	var occupied_weight: float = current_weight()
	if (
		FiniteNumber.is_finite_number(new_max_weight)
		and FiniteNumber.is_finite_number(occupied_weight)
		and new_max_weight >= 0.0
		and occupied_weight > new_max_weight + 0.00001
	):
		failures.append(
			"cannot reduce inventory weight capacity below occupied weight: %.6f > %.6f" % [
				occupied_weight,
				new_max_weight,
			]
		)
	if not failures.is_empty():
		return _failure(failures)

	_slot_capacity = new_slot_capacity
	_max_weight = new_max_weight
	_slots.resize(new_slot_capacity)
	return _success({"slot_capacity": _slot_capacity, "max_weight": _max_weight})


func canonical_snapshot() -> Dictionary:
	var records: Array = []
	for index in range(_slots.size()):
		var record: Dictionary = _slot_snapshot(index)
		if not record.is_empty():
			records.append(record)
	return {
		"schema": SNAPSHOT_SCHEMA,
		"slot_capacity": _slot_capacity,
		"max_weight": _max_weight,
		"slots": records,
	}


func canonical_json() -> String:
	return InventoryStateCodec.canonical_json(canonical_snapshot())


func _slot_snapshot(index: int) -> Dictionary:
	var slot = _slots[index]
	if slot == null or not slot is Dictionary:
		return {}
	var state = slot.get("state", null)
	if state != null and state is ItemStackState:
		return {"slot": index, "kind": "stack", "state": state.snapshot()}
	if state != null and state is ItemInstanceState:
		return {"slot": index, "kind": "instance", "state": state.snapshot()}
	return {}


func _first_empty_slot() -> int:
	for index in range(_slots.size()):
		if _slots[index] == null:
			return index
	return -1


func _weight_allows(projected_weight: float) -> bool:
	if not FiniteNumber.is_finite_number(projected_weight):
		return false
	if not _is_valid_weight_capacity(_max_weight):
		return false
	return _max_weight < 0.0 or projected_weight <= _max_weight + 0.00001


static func _is_valid_weight_capacity(value: float) -> bool:
	return (
		FiniteNumber.is_finite_number(value)
		and (value >= 0.0 or is_equal_approx(value, UNLIMITED_WEIGHT))
	)


static func _stack_key(item_content_id: String, stack_state: Dictionary) -> String:
	return "%s|%s" % [item_content_id, InventoryStateCodec.canonical_json(stack_state)]


func _same_content_id_definition_failures(incoming_definition) -> Array[String]:
	var failures: Array[String] = []
	if incoming_definition == null or not incoming_definition is ItemDefinition:
		return failures
	var incoming_content_id: String = str(incoming_definition.content_id)
	for index in range(_slots.size()):
		var slot = _slots[index]
		if slot == null or not slot is Dictionary:
			continue
		var state = slot.get("state", null)
		if state == null or (not state is ItemStackState and not state is ItemInstanceState):
			continue
		if str(state.item_content_id) != incoming_content_id:
			continue
		var stored_definition = slot.get("definition", null)
		for failure in _authored_definition_compatibility_failures(stored_definition, incoming_definition):
			failures.append("slot %d: %s" % [index, failure])
	failures.sort()
	return failures


static func _authored_definition_compatibility_failures(
	stored_definition,
	incoming_definition
) -> Array[String]:
	if stored_definition == null or not stored_definition is ItemDefinition:
		return ["authored item definition mismatch: stored slot definition is not ItemDefinition"]
	if incoming_definition == null or not incoming_definition is ItemDefinition:
		return ["authored item definition mismatch: incoming definition is not ItemDefinition"]

	var stored_descriptor_json: String = InventoryStateCodec.canonical_json(
		stored_definition.canonical_descriptor()
	)
	var incoming_descriptor_json: String = InventoryStateCodec.canonical_json(
		incoming_definition.canonical_descriptor()
	)
	if stored_descriptor_json == incoming_descriptor_json:
		return []
	return [
		"authored item definition mismatch for %s: canonical authored descriptor differs" % str(
			incoming_definition.content_id
		)
	]


static func _definition_failures(definition) -> Array[String]:
	var failures: Array[String] = []
	if definition == null or not definition is ItemDefinition:
		return ["inventory operation requires ItemDefinition"]
	for failure in definition.validate_definition():
		failures.append("item definition: %s" % failure)
	return failures


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
