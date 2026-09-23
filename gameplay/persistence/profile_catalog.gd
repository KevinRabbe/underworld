extends RefCounted

## Small, durable identity catalog for the production entry flow.
## Gameplay state remains in the existing v2 save slot; this catalog owns only
## character/world metadata and the last selected pair.

const PATH := "user://underworld_profiles.json"
const SCHEMA := "underworld.profile-catalog.v1"

static func load_catalog(path: String = PATH) -> Dictionary:
	var canonical := _read_catalog(path)
	if not bool(canonical.get("exists", false)):
		var backup := _read_catalog(path + ".backup")
		if bool(backup.get("success", false)):
			if _restore_backup(path):
				_remove_if_exists(path + ".candidate")
				return {"success": true, "catalog": backup["catalog"], "diagnostics": ["Recovered profile catalog from backup"]}
			return _failure("Profile catalog canonical file is missing and backup recovery failed")
		if bool(backup.get("exists", false)):
			return _failure(str(backup.get("diagnostic", "Profile catalog backup is invalid")))
		var candidate := _read_catalog(path + ".candidate")
		if bool(candidate.get("success", false)) and _promote_candidate(path):
			return {"success": true, "catalog": candidate["catalog"], "diagnostics": ["Recovered profile catalog from candidate"]}
		if bool(candidate.get("exists", false)):
			return _failure("Profile catalog canonical file is missing and transient state is invalid")
		return {"success": true, "catalog": _empty(), "diagnostics": []}
	if not bool(canonical.get("success", false)):
		var invalid_backup := _read_catalog(path + ".backup")
		if bool(invalid_backup.get("success", false)) and _restore_backup(path):
			_remove_if_exists(path + ".candidate")
			return {"success": true, "catalog": invalid_backup["catalog"], "diagnostics": ["Recovered invalid profile catalog from backup"]}
		return _failure(str(canonical.get("diagnostic", "Profile catalog is invalid")))
	_remove_if_exists(path + ".candidate")
	_remove_if_exists(path + ".backup")
	return {"success": true, "catalog": canonical["catalog"], "diagnostics": []}

static func _read_catalog(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "success": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": true, "success": false, "diagnostic": "Profile catalog exists but cannot be opened"}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"exists": true, "success": false, "diagnostic": "Profile catalog is malformed JSON"}
	if str(parsed.get("schema", "")) != SCHEMA:
		return {"exists": true, "success": false, "diagnostic": "Profile catalog schema is unsupported"}
	if not parsed.get("characters", null) is Array or not parsed.get("worlds", null) is Array:
		return {"exists": true, "success": false, "diagnostic": "Profile catalog schema has invalid record collections"}
	if not _records_valid(parsed["characters"], "character_id", ["display_name"]):
		return {"exists": true, "success": false, "diagnostic": "Profile catalog contains invalid character records"}
	if not _records_valid(parsed["worlds"], "world_id", ["world_name", "world_seed"]):
		return {"exists": true, "success": false, "diagnostic": "Profile catalog contains invalid world records"}
	if parsed.has("last_character_id") and not parsed["last_character_id"] is String:
		return {"exists": true, "success": false, "diagnostic": "Profile catalog has invalid last character selection"}
	if parsed.has("last_world_id") and not parsed["last_world_id"] is String:
		return {"exists": true, "success": false, "diagnostic": "Profile catalog has invalid last world selection"}
	var result := _empty()
	result["characters"] = _sanitize_records(parsed.get("characters", []), "character_id", ["display_name"])
	result["worlds"] = _sanitize_records(parsed.get("worlds", []), "world_id", ["world_name", "world_seed"])
	result["last_character_id"] = str(parsed.get("last_character_id", ""))
	result["last_world_id"] = str(parsed.get("last_world_id", ""))
	return {"exists": true, "success": true, "catalog": result, "diagnostics": []}

static func create_character(display_name: String, path: String = PATH) -> Dictionary:
	var name := display_name.strip_edges()
	if name.is_empty():
		return _failure("Character name must not be empty")
	var loaded := load_catalog(path)
	if not bool(loaded.get("success", false)):
		return loaded
	var catalog: Dictionary = loaded["catalog"]
	var id := "character:%s" % (name.to_lower().sha256_text().substr(0, 16))
	var suffix := 1
	while _find(catalog["characters"], "character_id", id) != null:
		id = "character:%s-%d" % [name.to_lower().sha256_text().substr(0, 12), suffix]
		suffix += 1
	catalog["characters"].append({"character_id": id, "display_name": name, "created_at": int(Time.get_unix_time_from_system())})
	if not _write(catalog, path):
		return _failure("Character catalog could not be persisted")
	return {"success": true, "character": catalog["characters"][-1].duplicate(true), "catalog": catalog}

static func create_world(world_name: String, seed: int, path: String = PATH) -> Dictionary:
	var name := world_name.strip_edges()
	if name.is_empty():
		return _failure("World name must not be empty")
	var loaded := load_catalog(path)
	if not bool(loaded.get("success", false)):
		return loaded
	var catalog: Dictionary = loaded["catalog"]
	var id := "world:%d:%s" % [seed, name.to_lower().sha256_text().substr(0, 12)]
	var suffix := 1
	while _find(catalog["worlds"], "world_id", id) != null:
		id = "world:%d:%s-%d" % [seed, name.to_lower().sha256_text().substr(0, 8), suffix]
		suffix += 1
	catalog["worlds"].append({"world_id": id, "world_name": name, "world_seed": seed, "created_at": int(Time.get_unix_time_from_system())})
	if not _write(catalog, path):
		return _failure("World catalog could not be persisted")
	return {"success": true, "world": catalog["worlds"][-1].duplicate(true), "catalog": catalog}

static func select_pair(character_id: String, world_id: String, path: String = PATH) -> Dictionary:
	var loaded := load_catalog(path)
	if not bool(loaded.get("success", false)):
		return loaded
	var catalog: Dictionary = loaded["catalog"]
	if _find(catalog["characters"], "character_id", character_id) == null:
		return _failure("Selected character does not exist")
	if _find(catalog["worlds"], "world_id", world_id) == null:
		return _failure("Selected world does not exist")
	catalog["last_character_id"] = character_id
	catalog["last_world_id"] = world_id
	if not _write(catalog, path):
		return _failure("Selected profile pair could not be persisted")
	return {"success": true, "catalog": catalog}

static func last_pair(path: String = PATH) -> Dictionary:
	var loaded := load_catalog(path)
	if not bool(loaded.get("success", false)):
		return loaded
	var catalog: Dictionary = loaded["catalog"]
	var character = _find(catalog["characters"], "character_id", catalog["last_character_id"])
	var world = _find(catalog["worlds"], "world_id", catalog["last_world_id"])
	return {"success": character != null and world != null, "character": character, "world": world, "catalog": catalog, "diagnostics": []}

static func _empty() -> Dictionary:
	return {"schema": SCHEMA, "characters": [], "worlds": [], "last_character_id": "", "last_world_id": ""}

static func _sanitize_records(raw: Variant, id_key: String, required: Array) -> Array:
	var result: Array = []
	if not raw is Array:
		return result
	for value in raw:
		if not value is Dictionary or str(value.get(id_key, "")).is_empty():
			continue
		var valid := true
		for key in required:
			if not value.has(key):
				valid = false
		if valid:
			result.append(value.duplicate(true))
	return result

static func _records_valid(raw: Array, id_key: String, required: Array) -> bool:
	for value in raw:
		if not value is Dictionary or not value.has(id_key) or not value[id_key] is String or str(value[id_key]).is_empty():
			return false
		for key in required:
			if not value.has(key):
				return false
			if key == "world_seed":
				if not value[key] is int:
					return false
			elif not value[key] is String or str(value[key]).is_empty():
				return false
	return true

static func _find(records: Array, key: String, value: String):
	for record in records:
		if str(record.get(key, "")) == value:
			return record
	return null

static func _write(catalog: Dictionary, path: String) -> bool:
	var candidate_path := path + ".candidate"
	var backup_path := path + ".backup"
	var file := FileAccess.open(candidate_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(catalog, "", false))
	file.flush()
	file = null
	var verify := FileAccess.open(candidate_path, FileAccess.READ)
	if verify == null or JSON.parse_string(verify.get_as_text()) == null:
		return false
	verify = null
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
		if not DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup_path)) == OK:
			return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(candidate_path), ProjectSettings.globalize_path(path)) != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_path), ProjectSettings.globalize_path(path))
		return false
	_remove_if_exists(backup_path)
	_remove_if_exists(candidate_path)
	return true

static func _promote_candidate(path: String) -> bool:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".candidate"), ProjectSettings.globalize_path(path)) == OK

static func _restore_backup(path: String) -> bool:
	if not FileAccess.file_exists(path + ".backup"):
		return false
	_remove_if_exists(path)
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".backup"), ProjectSettings.globalize_path(path)) == OK

static func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func _failure(message: String) -> Dictionary:
	return {"success": false, "diagnostics": [message]}
