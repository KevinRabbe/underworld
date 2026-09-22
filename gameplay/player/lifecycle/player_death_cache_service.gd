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
	for raw_record in cargo_variant.get("slots", []):
		var record: Dictionary = raw_record
		var state: Dictionary = record.get("state", {})
		var definition = _definitions.get(str(state.get("item_id", "")), null)
		if definition == null or state.is_empty():
			continue
		var result: Dictionary
		if str(record.get("kind", "")) == "stack":
			result = _inventory.add_stack(definition, int(state.get("quantity", 0)), state.get("stack_state", {}))
		else:
			result = _inventory.add_instance(definition, state.get("per_copy_state", {}))
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
	_cache = cache_variant.duplicate(true)
	return {"success": true, "diagnostics": []}


func cache_snapshot() -> Dictionary:
	return _cache.duplicate(true)


func _runtime_valid() -> bool:
	return _inventory != null and _inventory is ItemContainerState and _equipment != null and _equipment.has_method("canonical_snapshot")


static func _is_finite_vector3(value: Vector3) -> bool:
	return not is_nan(value.x) and not is_inf(value.x) and not is_nan(value.y) and not is_inf(value.y) and not is_nan(value.z) and not is_inf(value.z)


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {"success": false, "diagnostics": diagnostics, "events": []}
