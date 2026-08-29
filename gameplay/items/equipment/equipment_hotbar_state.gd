extends RefCounted

const EquipmentSlotRule := preload("res://gameplay/items/equipment/equipment_slot_rule.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const InventoryStateCodec := preload("res://gameplay/items/inventory/inventory_state_codec.gd")

const SNAPSHOT_SCHEMA := "equipment.hotbar.v1"
const HOTBAR_MIN := 1
const HOTBAR_MAX := 4

var _rules: Dictionary = {}
var _containers: Dictionary = {}
var _definitions: Dictionary = {}
var _hotbar_bindings: Dictionary = {}
var _selected_hotbar: int = HOTBAR_MIN


func configure(rules: Array, hotbar_bindings: Dictionary = {}) -> RefCounted:
	_rules.clear()
	_containers.clear()
	_definitions.clear()
	_hotbar_bindings.clear()
	_selected_hotbar = HOTBAR_MIN
	for candidate in rules:
		if candidate == null or not candidate is EquipmentSlotRule:
			continue
		var key: String = candidate.slot_key
		if key.is_empty() or _rules.has(key):
			continue
		_rules[key] = candidate
		_containers[key] = ItemContainerState.new().configure(1)
	for raw_index in hotbar_bindings.keys():
		bind_hotbar(int(raw_index), str(hotbar_bindings[raw_index]))
	return self


func validate_state() -> Array[String]:
	var failures: Array[String] = []
	if _rules.is_empty():
		failures.append("equipment state requires at least one semantic slot rule")
	var slot_keys: Array[String] = []
	for raw_key in _rules.keys():
		slot_keys.append(str(raw_key))
	slot_keys.sort()
	for slot_key in slot_keys:
		var rule = _rules.get(slot_key, null)
		if rule == null or not rule is EquipmentSlotRule:
			failures.append("equipment state has invalid slot rule: %s" % slot_key)
			continue
		for failure in rule.validate_rule():
			failures.append("%s: %s" % [slot_key, failure])
		var container = _containers.get(slot_key, null)
		if container == null or not container is ItemContainerState:
			failures.append("equipment slot is missing ItemContainerState: %s" % slot_key)
			continue
		for failure in container.validate_container():
			failures.append("%s: %s" % [slot_key, failure])
		var occupied: bool = container.occupied_slot_count() > 0
		var definition = _definitions.get(slot_key, null)
		if occupied and (definition == null or not definition is ItemDefinition):
			failures.append("occupied equipment slot is missing resolved ItemDefinition: %s" % slot_key)
		elif not occupied and definition != null:
			failures.append("empty equipment slot retains resolved ItemDefinition: %s" % slot_key)
		elif occupied:
			var record: Dictionary = container.state_at(0)
			var item_id: String = str(record.get("state", {}).get("item_id", ""))
			if item_id != str(definition.content_id):
				failures.append("equipment slot definition does not match stored item: %s" % slot_key)
			for failure in rule.compatibility_failures(definition):
				failures.append("%s: %s" % [slot_key, failure])
	for hotbar_index in range(HOTBAR_MIN, HOTBAR_MAX + 1):
		if not _hotbar_bindings.has(hotbar_index):
			continue
		var slot_key: String = str(_hotbar_bindings[hotbar_index])
		if not _rules.has(slot_key):
			failures.append("hotbar %d references unknown equipment slot: %s" % [hotbar_index, slot_key])
	if _selected_hotbar < HOTBAR_MIN or _selected_hotbar > HOTBAR_MAX:
		failures.append("selected hotbar index is outside M3 range: %d" % _selected_hotbar)
	failures.sort()
	return failures


func bind_hotbar(index: int, slot_key: String) -> Dictionary:
	if index < HOTBAR_MIN or index > HOTBAR_MAX:
		return _failure(["hotbar index must be 1..4: %d" % index])
	if not _rules.has(slot_key):
		return _failure(["hotbar binding requires known semantic equipment slot: %s" % slot_key])
	_hotbar_bindings[index] = slot_key
	return _success({"hotbar": index, "slot_key": slot_key})


func select_hotbar(index: int) -> Dictionary:
	if index < HOTBAR_MIN or index > HOTBAR_MAX:
		return _failure(["hotbar selection must be 1..4: %d" % index])
	var previous: int = _selected_hotbar
	_selected_hotbar = index
	return _success({
		"previous_hotbar": previous,
		"selected_hotbar": _selected_hotbar,
		"slot_key": selected_slot_key(),
	})


func selected_hotbar() -> int:
	return _selected_hotbar


func selected_slot_key() -> String:
	return str(_hotbar_bindings.get(_selected_hotbar, ""))


func slot_rule(slot_key: String):
	return _rules.get(slot_key, null)


func slot_container(slot_key: String):
	return _containers.get(slot_key, null)


func definition_at(slot_key: String):
	return _definitions.get(slot_key, null)


func state_at(slot_key: String) -> Dictionary:
	var container = slot_container(slot_key)
	if container == null or not container is ItemContainerState:
		return {}
	return container.state_at(0)


func selected_definition():
	var slot_key := selected_slot_key()
	return definition_at(slot_key) if not slot_key.is_empty() else null


func selected_state() -> Dictionary:
	var slot_key := selected_slot_key()
	return state_at(slot_key) if not slot_key.is_empty() else {}


func _commit_definition(slot_key: String, definition) -> void:
	if definition == null:
		_definitions.erase(slot_key)
	else:
		_definitions[slot_key] = definition


func canonical_snapshot() -> Dictionary:
	var slot_records: Array = []
	var slot_keys: Array[String] = []
	for raw_key in _rules.keys():
		slot_keys.append(str(raw_key))
	slot_keys.sort()
	for slot_key in slot_keys:
		var rule = _rules[slot_key]
		var container = _containers[slot_key]
		slot_records.append({
			"slot_key": slot_key,
			"rule": rule.canonical_descriptor(),
			"container": container.canonical_snapshot(),
		})
	var bindings: Array = []
	for index in range(HOTBAR_MIN, HOTBAR_MAX + 1):
		if _hotbar_bindings.has(index):
			bindings.append({"hotbar": index, "slot_key": str(_hotbar_bindings[index])})
	return {
		"schema": SNAPSHOT_SCHEMA,
		"selected_hotbar": _selected_hotbar,
		"hotbar_bindings": bindings,
		"slots": slot_records,
	}


func canonical_json() -> String:
	return InventoryStateCodec.canonical_json(canonical_snapshot())


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
