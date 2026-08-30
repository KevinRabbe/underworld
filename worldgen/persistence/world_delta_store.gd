extends RefCounted
class_name UnderworldWorldDeltaStore

const StableIdScript := preload("res://worldgen/identity/stable_id.gd")

var _destroyed_objects: Dictionary = {}
var _object_state: Dictionary = {}
var _special_location_state: Dictionary = {}
var _terrain_delta_index: Dictionary = {}
var _player_created_objects: Dictionary = {}


func clear() -> void:
	_destroyed_objects.clear()
	_object_state.clear()
	_special_location_state.clear()
	_terrain_delta_index.clear()
	_player_created_objects.clear()


func load_modern_delta_payload(delta_payload: Dictionary) -> Array[String]:
	clear()
	var failures: Array[String] = replace_destroyed_object_ids(
		delta_payload.get("destroyed_objects", [])
	)

	_copy_map(delta_payload.get("object_state", {}), _object_state)
	_copy_map(delta_payload.get("special_location_state", {}), _special_location_state)
	_copy_map(delta_payload.get("terrain_delta_index", {}), _terrain_delta_index)
	_copy_map(delta_payload.get("player_created_objects", {}), _player_created_objects)
	return failures


func replace_destroyed_object_ids(object_ids: Array) -> Array[String]:
	_destroyed_objects.clear()
	var failures: Array[String] = []
	for id_variant in object_ids:
		var stable_id: String = str(id_variant)
		if StableIdScript.parse(stable_id) == null:
			failures.append("WorldDeltaStore rejected invalid destroyed StableId: %s" % stable_id)
			continue
		_destroyed_objects[stable_id] = true
	return failures


func mark_generated_object_destroyed(stable_id: String) -> bool:
	if StableIdScript.parse(stable_id) == null:
		return false
	_destroyed_objects[stable_id] = true
	return true


func is_generated_object_destroyed(stable_id: String) -> bool:
	return _destroyed_objects.has(stable_id)


func set_object_state(stable_id: String, state: Dictionary) -> bool:
	if StableIdScript.parse(stable_id) == null:
		return false
	_object_state[stable_id] = state.duplicate(true)
	return true


func get_object_state(stable_id: String) -> Dictionary:
	if not _object_state.has(stable_id):
		return {}
	return _object_state[stable_id].duplicate(true)


func snapshot() -> Dictionary:
	var destroyed: Array = _destroyed_objects.keys()
	destroyed.sort()
	return {
		"destroyed_objects": destroyed,
		"object_state": _object_state.duplicate(true),
		"special_location_state": _special_location_state.duplicate(true),
		"terrain_delta_index": _terrain_delta_index.duplicate(true),
		"player_created_objects": _player_created_objects.duplicate(true),
	}


static func _copy_map(source_variant, target: Dictionary) -> void:
	if not source_variant is Dictionary:
		return
	var source: Dictionary = source_variant
	for key in source.keys():
		target[key] = _deep_owned_value(source[key])


static func _deep_owned_value(value):
	if value is Dictionary:
		return value.duplicate(true)
	if value is Array:
		return value.duplicate(true)
	return value
