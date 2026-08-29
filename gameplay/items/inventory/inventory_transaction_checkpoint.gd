extends RefCounted

const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemStackState := preload("res://gameplay/items/inventory/item_stack_state.gd")
const ItemInstanceState := preload("res://gameplay/items/inventory/item_instance_state.gd")

const SCHEMA := "inventory.transaction.checkpoint.v1"
const EPSILON := 0.00001


# Process-local rollback state only. This deliberately retains resolved definition
# references and must never be treated as a persistence/save representation.
static func capture(container) -> Dictionary:
	if container == null or not container is ItemContainerState:
		return {}
	var records: Array = []
	records.resize(container._slots.size())
	for index in range(container._slots.size()):
		var slot = container._slots[index]
		if slot == null:
			continue
		if not slot is Dictionary:
			return {}
		var definition = slot.get("definition", null)
		var state = slot.get("state", null)
		if definition == null or not definition is ItemDefinition:
			return {}
		if state is ItemStackState:
			records[index] = {
				"kind": "stack",
				"definition": definition,
				"item_content_id": state.item_content_id,
				"quantity": state.quantity,
				"stack_state": state.stack_state.duplicate(true),
			}
		elif state is ItemInstanceState:
			records[index] = {
				"kind": "instance",
				"definition": definition,
				"item_content_id": state.item_content_id,
				"per_copy_state": state.per_copy_state.duplicate(true),
			}
		else:
			return {}
	return {
		"schema": SCHEMA,
		"slot_capacity": container._slot_capacity,
		"max_weight": container._max_weight,
		"slots": records,
		"canonical_json": container.canonical_json(),
	}


static func restore(container, checkpoint: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if container == null or not container is ItemContainerState:
		return ["transaction checkpoint restore requires ItemContainerState"]
	if str(checkpoint.get("schema", "")) != SCHEMA:
		return ["transaction checkpoint schema mismatch"]
	var slot_capacity: int = int(checkpoint.get("slot_capacity", 0))
	var max_weight: float = float(checkpoint.get("max_weight", -2.0))
	var source_slots = checkpoint.get("slots", null)
	if slot_capacity < 1:
		failures.append("transaction checkpoint slot capacity must be >= 1")
	if max_weight < 0.0 and not is_equal_approx(max_weight, ItemContainerState.UNLIMITED_WEIGHT):
		failures.append("transaction checkpoint max weight is invalid")
	if not source_slots is Array or source_slots.size() != slot_capacity:
		failures.append("transaction checkpoint slot storage does not match capacity")
	if not failures.is_empty():
		failures.sort()
		return failures

	var restored_slots: Array = []
	restored_slots.resize(slot_capacity)
	var restored_weight: float = 0.0
	for index in range(source_slots.size()):
		var record_variant = source_slots[index]
		if record_variant == null:
			continue
		if not record_variant is Dictionary:
			failures.append("transaction checkpoint slot %d record is invalid" % index)
			continue
		var record: Dictionary = record_variant
		var definition = record.get("definition", null)
		if definition == null or not definition is ItemDefinition:
			failures.append("transaction checkpoint slot %d definition is invalid" % index)
			continue
		var item_content_id: String = str(record.get("item_content_id", ""))
		if item_content_id != str(definition.content_id):
			failures.append("transaction checkpoint slot %d item id does not match definition" % index)
			continue
		match str(record.get("kind", "")):
			"stack":
				var stack_state_variant = record.get("stack_state", null)
				if not stack_state_variant is Dictionary:
					failures.append("transaction checkpoint stack state is invalid at slot %d" % index)
					continue
				var stack_state: Dictionary = stack_state_variant
				var state = ItemStackState.new().configure(
					definition,
					int(record.get("quantity", 0)),
					stack_state
				)
				for failure in state.validate_against(definition):
					failures.append("transaction checkpoint slot %d: %s" % [index, failure])
				restored_slots[index] = {"definition": definition, "state": state}
				restored_weight += definition.unit_weight * float(state.quantity)
			"instance":
				var per_copy_variant = record.get("per_copy_state", null)
				if not per_copy_variant is Dictionary:
					failures.append("transaction checkpoint per-copy state is invalid at slot %d" % index)
					continue
				var per_copy_state: Dictionary = per_copy_variant
				var state = ItemInstanceState.new().configure(definition, per_copy_state)
				for failure in state.validate_against(definition):
					failures.append("transaction checkpoint slot %d: %s" % [index, failure])
				restored_slots[index] = {"definition": definition, "state": state}
				restored_weight += definition.unit_weight
			_:
				failures.append("transaction checkpoint slot %d kind is invalid" % index)

	if max_weight >= 0.0 and restored_weight > max_weight + EPSILON:
		failures.append("transaction checkpoint occupied weight exceeds checkpoint capacity")
	if not failures.is_empty():
		failures.sort()
		return failures

	container._slot_capacity = slot_capacity
	container._max_weight = max_weight
	container._slots = restored_slots
	var restored_failures: Array[String] = container.validate_container()
	for failure in restored_failures:
		failures.append("restored container invalid: %s" % failure)
	if container.canonical_json() != str(checkpoint.get("canonical_json", "")):
		failures.append("transaction checkpoint restore did not reproduce canonical baseline")
	failures.sort()
	return failures
