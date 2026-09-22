extends RefCounted

## Owns the one-shot transfer of player cargo into a durable death cache.
## Equipment remains retained by the player; inventory cargo is moved exactly
## once and can later be collected from the cache.

const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")

const SNAPSHOT_SCHEMA := "player.death_cache.v1"

var _inventory = null
var _equipment = null
var _definitions: Dictionary = {}
var _cache: Dictionary = {}


func configure(inventory_state, equipment_state, definitions: Array = []) -> RefCounted:
	_inventory = inventory_state
	_equipment = equipment_state
	_definitions.clear()
	for definition in definitions:
		if definition != null and definition.has_method("validate_definition"):
			_definitions[str(definition.content_id)] = definition
	return self


func capture_death(death_position: Vector3) -> Dictionary:
	if not _is_finite_vector3(death_position):
		return _failure(["death cache position must be finite Vector3"])
	if not _runtime_valid():
		return _failure(["death cache requires canonical inventory and equipment state"])
	if not _cache.is_empty() and not bool(_cache.get("collected", false)):
		return {"success": true, "already_captured": true, "cache": _cache.duplicate(true), "diagnostics": [], "events": []}
	_cache = {
		"schema": SNAPSHOT_SCHEMA,
		"cache_id": "death-cache.1",
		"position": death_position,
		"cargo": _inventory.canonical_snapshot().duplicate(true),
		"retained_equipment": _equipment.canonical_snapshot().duplicate(true),
		"collected": false,
	}
	_inventory.clear_contents()
	return {"success": true, "already_captured": false, "cache": _cache.duplicate(true), "diagnostics": [], "events": [{"type": "player.death_cache_created", "cache_id": "death-cache.1"}]}


func collect_cache() -> Dictionary:
	if _cache.is_empty() or bool(_cache.get("collected", false)):
		return _failure(["death cache is not available"])
	if not _runtime_valid():
		return _failure(["death cache requires canonical inventory and equipment state"])
	var cargo_variant: Variant = _cache.get("cargo", null)
	if not cargo_variant is Dictionary:
		return _failure(["death cache cargo is malformed"])
	var records_result := _validated_cargo_records(cargo_variant)
	if not bool(records_result.get("success", false)):
		return _failure(records_result.get("diagnostics", []))
	# Preflight into an isolated container so collection is atomic: no malformed
	# record or capacity failure may leave a partially restored player inventory.
	var current_snapshot: Dictionary = _inventory.canonical_snapshot()
	var current_records_result := _validated_cargo_records(current_snapshot)
	if not bool(current_records_result.get("success", false)):
		return _failure(current_records_result.get("diagnostics", []))
	var probe := ItemContainerState.new()
	probe.configure(int(current_snapshot.get("slot_capacity", 0)), float(current_snapshot.get("max_weight", -1.0)))
	for record in current_records_result.get("records", []):
		var current_result: Dictionary = _apply_record(probe, record)
		if not bool(current_result.get("success", false)):
			return _failure(current_result.get("diagnostics", []))
	for record in records_result.get("records", []):
		var result: Dictionary = _apply_record(probe, record)
		if not bool(result.get("success", false)):
			return _failure(result.get("diagnostics", []))
	for record in records_result.get("records", []):
		var result: Dictionary = _apply_record(_inventory, record)
		if not bool(result.get("success", false)):
			return _failure(result.get("diagnostics", []))
	_cache["collected"] = true
	return {"success": true, "diagnostics": [], "events": [{"type": "player.death_cache_collected", "cache_id": str(_cache.get("cache_id", ""))}]}


func has_cache() -> bool:
	return not _cache.is_empty() and not bool(_cache.get("collected", false))


func durable_snapshot() -> Dictionary:
	return {"schema": SNAPSHOT_SCHEMA, "cache": _cache.duplicate(true)}


func restore_durable_snapshot(snapshot: Dictionary) -> Dictionary:
	if str(snapshot.get("schema", "")) != SNAPSHOT_SCHEMA:
		return _failure(["unsupported death cache snapshot schema"])
	var cache_variant: Variant = snapshot.get("cache", {})
	if not cache_variant is Dictionary:
		return _failure(["death cache snapshot cache must be Dictionary"])
	if not cache_variant.is_empty():
		if str(cache_variant.get("schema", "")) != SNAPSHOT_SCHEMA or not cache_variant.get("position", null) is Vector3 or not _is_finite_vector3(cache_variant.position) or not cache_variant.get("cargo", null) is Dictionary or not cache_variant.get("retained_equipment", null) is Dictionary or typeof(cache_variant.get("collected", null)) != TYPE_BOOL:
			return _failure(["death cache snapshot cache record is malformed"])
		var cargo_check := _validated_cargo_records(cache_variant.get("cargo"))
		if not bool(cargo_check.get("success", false)):
			return _failure(cargo_check.get("diagnostics", []))
	_cache = cache_variant.duplicate(true)
	return {"success": true, "diagnostics": []}


func cache_snapshot() -> Dictionary:
	return _cache.duplicate(true)


func _runtime_valid() -> bool:
	return _inventory != null and _inventory is ItemContainerState and _equipment != null and _equipment.has_method("canonical_snapshot")

func _validated_cargo_records(cargo: Dictionary) -> Dictionary:
	var failures: Array[String] = []
	if str(cargo.get("schema", "")) != ItemContainerState.SNAPSHOT_SCHEMA:
		failures.append("death cache cargo inventory schema is unsupported")
	var slots: Variant = cargo.get("slots", null)
	if not slots is Array:
		failures.append("death cache cargo slots must be Array")
	if typeof(cargo.get("slot_capacity", null)) != TYPE_INT or int(cargo.get("slot_capacity", 0)) < 1:
		failures.append("death cache cargo slot_capacity is invalid")
	if (typeof(cargo.get("max_weight", null)) != TYPE_INT and typeof(cargo.get("max_weight", null)) != TYPE_FLOAT) or is_nan(float(cargo.get("max_weight", 0.0))) or is_inf(float(cargo.get("max_weight", 0.0))):
		failures.append("death cache cargo max_weight is invalid")
	if not slots is Array or not failures.is_empty():
		return {"success": false, "diagnostics": failures}
	var records: Array = []
	var seen_slots: Dictionary = {}
	for raw_record in slots:
		if not raw_record is Dictionary:
			failures.append("death cache cargo slot record must be Dictionary")
			continue
		var record: Dictionary = raw_record
		var record_keys: Array[String] = []
		for key in record.keys(): record_keys.append(str(key))
		record_keys.sort()
		if record_keys != ["kind", "slot", "state"]:
			failures.append("death cache cargo slot record keys are not canonical")
		var slot: Variant = record.get("slot", null)
		var kind := str(record.get("kind", ""))
		var state: Variant = record.get("state", null)
		if typeof(slot) != TYPE_INT or seen_slots.has(slot) or int(slot) < 0 or int(slot) >= int(cargo.get("slot_capacity", 0)):
			failures.append("death cache cargo slot index is invalid or duplicated")
		seen_slots[slot] = true
		if kind not in ["stack", "instance"] or not state is Dictionary:
			failures.append("death cache cargo record kind/state is malformed")
			continue
		var item_id := str(state.get("item_id", ""))
		var state_keys: Array[String] = []
		for key in state.keys(): state_keys.append(str(key))
		state_keys.sort()
		var expected_state_keys: Array[String] = ["item_id", "quantity", "stack_state"] if kind == "stack" else ["item_id", "per_copy_state"]
		if state_keys != expected_state_keys:
			failures.append("death cache cargo item state keys are not canonical")
		var definition = _definitions.get(item_id, null)
		if definition == null or item_id.is_empty():
			failures.append("death cache cargo references unknown item definition: %s" % item_id)
			continue
		if kind == "stack" and (typeof(state.get("quantity", null)) != TYPE_INT or int(state.get("quantity", 0)) <= 0 or not state.get("stack_state", null) is Dictionary):
			failures.append("death cache stack record is malformed")
		if kind == "instance" and not state.get("per_copy_state", null) is Dictionary:
			failures.append("death cache instance record is malformed")
		records.append(record)
	if not failures.is_empty():
		return {"success": false, "diagnostics": failures}
	return {"success": true, "records": records, "diagnostics": []}

func _apply_record(container, record: Dictionary) -> Dictionary:
	var state: Dictionary = record.get("state", {})
	var definition = _definitions.get(str(state.get("item_id", "")), null)
	if str(record.get("kind", "")) == "stack":
		return container.add_stack(definition, int(state.get("quantity", 0)), state.get("stack_state", {}))
	return container.add_instance(definition, state.get("per_copy_state", {}))


static func _is_finite_vector3(value: Vector3) -> bool:
	return not is_nan(value.x) and not is_inf(value.x) and not is_nan(value.y) and not is_inf(value.y) and not is_nan(value.z) and not is_inf(value.z)


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	if diagnostics.is_empty():
		diagnostics.append("death cache operation rejected malformed or incompatible state")
	diagnostics.sort()
	return {"success": false, "diagnostics": diagnostics, "events": []}
