extends "res://gameplay/items/equipment/equipment_hotbar_state.gd"

const RestoredItemContainerState := preload("res://gameplay/persistence/restored_item_container_state.gd")


func restore_owned_slot(
	slot_key: String,
	definition,
	kind: String,
	state_snapshot: Dictionary
) -> Dictionary:
	var failures: Array[String] = []
	var rule = slot_rule(slot_key)
	if rule == null:
		failures.append("saved equipment slot has no current authored rule: %s" % slot_key)
	if definition == null or not definition is ItemDefinition:
		failures.append("equipment restore requires ItemDefinition: %s" % slot_key)
	if not state_at(slot_key).is_empty():
		failures.append("equipment restore slot is already occupied: %s" % slot_key)
	if rule != null and definition != null and definition is ItemDefinition:
		for failure in rule.compatibility_failures(definition):
			failures.append("equipment restore %s: %s" % [slot_key, failure])
	if not failures.is_empty():
		return _failure(failures)

	var restored_container = RestoredItemContainerState.new().configure(1)
	var restore_result: Dictionary = restored_container.restore_record_at(
		0,
		definition,
		kind,
		state_snapshot
	)
	if not bool(restore_result.get("success", false)):
		for diagnostic in restore_result.get("diagnostics", []):
			failures.append("equipment restore %s: %s" % [slot_key, diagnostic])
		return _failure(failures)

	var previous_container = _containers.get(slot_key, null)
	var previous_definition = _definitions.get(slot_key, null)
	_containers[slot_key] = restored_container
	_commit_definition(slot_key, definition)

	for failure in validate_state():
		failures.append("restored equipment: %s" % failure)
	if not failures.is_empty():
		_containers[slot_key] = previous_container
		_commit_definition(slot_key, previous_definition)
		return _failure(failures)
	return _success({"slot_key": slot_key, "item_id": str(definition.content_id)})


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
