extends RefCounted

const IntegratedGameSaveContract := preload("res://gameplay/persistence/integrated_game_save_contract.gd")

const DEFAULT_SLOT_PATH := "user://underworld_m3_slot.json"
const CANDIDATE_SUFFIX := ".candidate"
const BACKUP_SUFFIX := ".previous"


func save_slot(
	context,
	delta_store,
	inventory_state,
	equipment_state,
	pending_loot_state,
	resume_position: Vector3,
	slot_path: String = DEFAULT_SLOT_PATH
) -> Dictionary:
	var encoded: Dictionary = IntegratedGameSaveContract.encode(
		context,
		delta_store,
		inventory_state,
		equipment_state,
		pending_loot_state,
		resume_position
	)
	if not bool(encoded.get("success", false)):
		return encoded
	return persist_candidate_json(str(encoded.get("json", "")), slot_path)


func persist_candidate_json(
	candidate_json: String,
	slot_path: String = DEFAULT_SLOT_PATH
) -> Dictionary:
	var path_failure: String = _slot_path_failure(slot_path)
	if not path_failure.is_empty():
		return _failure([path_failure])
	if candidate_json.is_empty():
		return _failure(["SAVE candidate JSON is empty"])

	var candidate_path: String = slot_path + CANDIDATE_SUFFIX
	var backup_path: String = slot_path + BACKUP_SUFFIX
	_remove_file_if_present(candidate_path)

	var candidate_file: FileAccess = FileAccess.open(candidate_path, FileAccess.WRITE)
	if candidate_file == null:
		return _failure([
			"SAVE candidate could not be opened for write: %s" % candidate_path,
		])
	candidate_file.store_string(candidate_json)
	candidate_file.flush()
	candidate_file = null

	var reread: Dictionary = _decode_file(candidate_path)
	if not bool(reread.get("success", false)):
		_remove_file_if_present(candidate_path)
		return _prefixed_failure("SAVE candidate reread", reread.get("diagnostics", []))

	var reread_text: String = str(reread.get("json", ""))
	if reread_text != candidate_json:
		_remove_file_if_present(candidate_path)
		return _failure(["SAVE candidate reread bytes differ from written candidate"])

	var had_previous: bool = FileAccess.file_exists(slot_path)
	_remove_file_if_present(backup_path)
	if had_previous:
		var backup_error: Error = _rename_file(slot_path, backup_path)
		if backup_error != OK:
			_remove_file_if_present(candidate_path)
			return _failure([
				"SAVE could not preserve previous slot before promotion: %s" % error_string(backup_error),
			])

	var promote_error: Error = _rename_file(candidate_path, slot_path)
	if promote_error != OK:
		var failures: Array[String] = [
			"SAVE candidate promotion failed: %s" % error_string(promote_error),
		]
		if had_previous and FileAccess.file_exists(backup_path):
			var restore_error: Error = _rename_file(backup_path, slot_path)
			if restore_error != OK:
				failures.append(
					"SAVE previous slot restoration failed: %s" % error_string(restore_error)
				)
		_remove_file_if_present(candidate_path)
		return _failure(failures)

	_remove_file_if_present(backup_path)
	return {
		"success": true,
		"slot_path": slot_path,
		"candidate": reread.get("candidate", {}),
		"fingerprint": candidate_json.sha256_text(),
		"diagnostics": [],
	}


func load_slot(slot_path: String = DEFAULT_SLOT_PATH) -> Dictionary:
	var path_failure: String = _slot_path_failure(slot_path)
	if not path_failure.is_empty():
		return _failure([path_failure])
	if not FileAccess.file_exists(slot_path):
		return _failure(["SAVE slot does not exist: %s" % slot_path])
	return _decode_file(slot_path)


func probe_slot(slot_path: String = DEFAULT_SLOT_PATH) -> Dictionary:
	var path_failure: String = _slot_path_failure(slot_path)
	if not path_failure.is_empty():
		return {
			"success": true,
			"available": false,
			"diagnostics": [path_failure],
		}
	if not FileAccess.file_exists(slot_path):
		return {
			"success": true,
			"available": false,
			"diagnostics": [],
		}
	var loaded: Dictionary = _decode_file(slot_path)
	if not bool(loaded.get("success", false)):
		return {
			"success": true,
			"available": false,
			"diagnostics": loaded.get("diagnostics", []).duplicate(),
		}
	return {
		"success": true,
		"available": true,
		"world_seed": int(loaded.get("candidate", {}).get("world_seed", 0)),
		"world_id": str(loaded.get("candidate", {}).get("world_id", "")),
		"diagnostics": [],
	}


static func _decode_file(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure(["SAVE slot could not be opened for read: %s" % path])
	var json_text: String = file.get_as_text()
	file = null
	var decoded: Dictionary = IntegratedGameSaveContract.decode(json_text)
	if not bool(decoded.get("success", false)):
		return decoded
	return {
		"success": true,
		"json": json_text,
		"envelope": decoded.get("envelope", {}).duplicate(true),
		"candidate": decoded.get("candidate", {}),
		"diagnostics": [],
	}


static func _slot_path_failure(slot_path: String) -> String:
	if slot_path.is_empty() or slot_path != slot_path.strip_edges():
		return "SAVE slot path must be non-empty and trimmed"
	if not slot_path.begins_with("user://"):
		return "SAVE slot path must remain under user://"
	if slot_path.ends_with(CANDIDATE_SUFFIX) or slot_path.ends_with(BACKUP_SUFFIX):
		return "SAVE slot path must not use internal candidate/backup suffix"
	return ""


static func _rename_file(from_path: String, to_path: String) -> Error:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(from_path),
		ProjectSettings.globalize_path(to_path)
	)


static func _remove_file_if_present(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _prefixed_failure(prefix: String, messages: Array) -> Dictionary:
	var failures: Array[String] = []
	for message in messages:
		failures.append("%s: %s" % [prefix, str(message)])
	return _failure(failures)


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {
		"success": false,
		"diagnostics": diagnostics,
	}
