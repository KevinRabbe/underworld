extends RefCounted

const IntegratedGameSaveContract := preload("res://gameplay/persistence/integrated_game_save_contract.gd")

const DEFAULT_SLOT_PATH := "user://underworld_m3_slot.json"
const CANDIDATE_SUFFIX := ".candidate"
const BACKUP_SUFFIX := ".previous"

const CLASS_NONE: String = IntegratedGameSaveContract.CLASS_NONE
const CLASS_AVAILABLE: String = IntegratedGameSaveContract.CLASS_AVAILABLE
const CLASS_INCOMPATIBLE: String = IntegratedGameSaveContract.CLASS_INCOMPATIBLE
const CLASS_INVALID: String = IntegratedGameSaveContract.CLASS_INVALID

const SAVE_CONDITION_REPLACE_EXACT_PROTECTED: String = "REPLACE_EXACT_PROTECTED"
const SAVE_CONDITION_REQUIRE_NO_PROTECTED_TARGET: String = "REQUIRE_NO_PROTECTED_TARGET"
const _REPLACE_CONDITION_KEYS: Array[String] = ["expected_content_fingerprint", "mode"]
const _NO_PROTECTED_CONDITION_KEYS: Array[String] = ["mode"]

var _rename_operation: Callable = Callable()


func configure_rename_operation(operation: Callable) -> RefCounted:
	_rename_operation = operation
	return self


func save_slot(
	request_object: Dictionary,
	slot_path: String = DEFAULT_SLOT_PATH,
	condition: Dictionary = {}
) -> Dictionary:
	if not bool(request_object.get("success", false)):
		return _failure(["SAVE request object must be successful before persistence"])
	var request_variant: Variant = request_object.get("request", null)
	if not request_variant is Dictionary:
		return _failure(["SAVE request object must contain detached request Dictionary"])
	var encoded: Dictionary = IntegratedGameSaveContract.encode_v2_request(request_variant)
	if not bool(encoded.get("success", false)):
		return encoded
	return persist_candidate_json(str(encoded.get("json", "")), slot_path, condition)


func persist_candidate_json(
	candidate_json: String,
	slot_path: String = DEFAULT_SLOT_PATH,
	condition: Dictionary = {}
) -> Dictionary:
	var path_failure: String = _slot_path_failure(slot_path)
	if not path_failure.is_empty():
		return _failure([path_failure])
	if candidate_json.is_empty():
		return _failure(["SAVE candidate JSON is empty"])
	var condition_failures: Array[String] = _validate_save_condition(condition)
	if not condition_failures.is_empty():
		return _failure(condition_failures)

	var candidate_path: String = slot_path + CANDIDATE_SUFFIX
	var backup_path: String = slot_path + BACKUP_SUFFIX
	_remove_file_if_present(candidate_path)
	var candidate_file: FileAccess = FileAccess.open(candidate_path, FileAccess.WRITE)
	if candidate_file == null:
		return _failure(["SAVE candidate could not be opened for write: %s" % candidate_path])
	candidate_file.store_string(candidate_json)
	candidate_file.flush()
	candidate_file = null

	var reread: Dictionary = _decode_existing_file(candidate_path)
	if str(reread.get("classification", CLASS_INVALID)) != CLASS_AVAILABLE:
		_remove_file_if_present(candidate_path)
		return _prefixed_failure(
			"SAVE candidate reread",
			["candidate classified %s" % str(reread.get("classification", CLASS_INVALID))] + reread.get("diagnostics", [])
		)
	var reread_text: String = str(reread.get("json", ""))
	if reread_text != candidate_json:
		_remove_file_if_present(candidate_path)
		return _failure(["SAVE candidate reread bytes differ from written candidate"])

	# Conditional overwrite consent is a compare-and-swap check against the
	# protected canonical bytes at the final mutation boundary. Candidate staging
	# and exact reread may take time, so an earlier check cannot authorize later
	# backup/promotion after another writer has replaced the slot.
	var precondition: Dictionary = _check_save_precondition(slot_path, condition)
	if not bool(precondition.get("success", false)):
		_remove_file_if_present(candidate_path)
		return precondition

	var had_previous: bool = FileAccess.file_exists(slot_path)
	_remove_file_if_present(backup_path)
	if had_previous:
		var backup_error: int = _rename_file(slot_path, backup_path)
		if backup_error != OK:
			_remove_file_if_present(candidate_path)
			return _failure(["SAVE could not preserve previous slot before promotion: %s" % error_string(backup_error)])
	var promote_error: int = _rename_file(candidate_path, slot_path)
	if promote_error != OK:
		var failures: Array[String] = ["SAVE candidate promotion failed: %s" % error_string(promote_error)]
		if had_previous and FileAccess.file_exists(backup_path):
			var restore_error: int = _rename_file(backup_path, slot_path)
			if restore_error != OK:
				failures.append("SAVE previous slot restoration failed: %s" % error_string(restore_error))
		_remove_file_if_present(candidate_path)
		return _failure(failures)
	_remove_file_if_present(backup_path)
	return {
		"success": true,
		"classification": CLASS_AVAILABLE,
		"slot_path": slot_path,
		"candidate": reread.get("candidate", {}),
		"fingerprint": candidate_json.sha256_text(),
		"content_fingerprint": candidate_json.sha256_text(),
		"diagnostics": [],
	}


func load_slot(slot_path: String = DEFAULT_SLOT_PATH) -> Dictionary:
	var classified: Dictionary = _classify_slot(slot_path)
	var classification: String = str(classified.get("classification", CLASS_INVALID))
	var result: Dictionary = {
		"success": true,
		"classification": classification,
		"available": classification == CLASS_AVAILABLE,
		"diagnostics": classified.get("diagnostics", []).duplicate(),
	}
	if classification != CLASS_AVAILABLE:
		return result
	for key in ["candidate", "content_fingerprint", "envelope", "json", "world_seed", "world_id", "active_domain"]:
		if classified.has(key):
			result[key] = classified[key]
	return result


func probe_slot(slot_path: String = DEFAULT_SLOT_PATH) -> Dictionary:
	var classified: Dictionary = _classify_slot(slot_path)
	var classification: String = str(classified.get("classification", CLASS_INVALID))
	var result: Dictionary = {
		"success": true,
		"classification": classification,
		"available": classification == CLASS_AVAILABLE,
		"diagnostics": classified.get("diagnostics", []).duplicate(),
	}
	if classification == CLASS_AVAILABLE:
		for key in ["content_fingerprint", "world_seed", "world_id", "active_domain"]:
			if classified.has(key):
				result[key] = classified[key]
	return result


func _classify_slot(slot_path: String) -> Dictionary:
	var path_failure: String = _slot_path_failure(slot_path)
	if not path_failure.is_empty():
		return _classification_result(CLASS_INVALID, [path_failure])
	if not FileAccess.file_exists(slot_path):
		return _classification_result(CLASS_NONE, [])
	return _decode_existing_file(slot_path)


static func _decode_existing_file(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _classification_result(CLASS_INVALID, ["SAVE slot could not be opened for read: %s" % path])
	var json_text: String = file.get_as_text()
	file = null
	var decoded: Dictionary = IntegratedGameSaveContract.decode_v2_classified(json_text)
	var classification: String = str(decoded.get("classification", CLASS_INVALID))
	var result: Dictionary = _classification_result(classification, decoded.get("diagnostics", []))
	if classification != CLASS_AVAILABLE:
		return result
	var candidate: Dictionary = decoded.get("candidate", {})
	result["json"] = json_text
	result["envelope"] = decoded.get("envelope", {}).duplicate(true)
	result["candidate"] = candidate
	result["content_fingerprint"] = json_text.sha256_text()
	result["world_seed"] = int(candidate.get("world_seed", 0))
	result["world_id"] = str(candidate.get("world_id", ""))
	result["active_domain"] = str(candidate.get("active_domain", ""))
	return result


func _check_save_precondition(slot_path: String, condition: Dictionary) -> Dictionary:
	if condition.is_empty():
		return {"success": true, "diagnostics": []}
	var current: Dictionary = _classify_slot(slot_path)
	var classification: String = str(current.get("classification", CLASS_INVALID))
	var mode: String = str(condition.get("mode", ""))
	if mode == SAVE_CONDITION_REPLACE_EXACT_PROTECTED:
		var expected: String = str(condition.get("expected_content_fingerprint", ""))
		if classification != CLASS_AVAILABLE:
			return _precondition_stale(classification, ["SAVE protected-target precondition expected AVAILABLE slot"])
		if str(current.get("content_fingerprint", "")) != expected:
			return _precondition_stale(classification, ["SAVE protected-target content fingerprint changed"])
		return {"success": true, "diagnostics": []}
	if mode == SAVE_CONDITION_REQUIRE_NO_PROTECTED_TARGET:
		if classification == CLASS_AVAILABLE:
			return _precondition_stale(classification, ["SAVE no-protected-target precondition found AVAILABLE slot"])
		return {"success": true, "diagnostics": []}
	return _failure(["SAVE condition has unsupported mode: %s" % mode])


static func _validate_save_condition(condition: Dictionary) -> Array[String]:
	if condition.is_empty():
		return []
	var mode_variant: Variant = condition.get("mode", null)
	if typeof(mode_variant) != TYPE_STRING:
		return ["SAVE condition mode must be String"]
	var mode: String = str(mode_variant)
	if mode == SAVE_CONDITION_REPLACE_EXACT_PROTECTED:
		var failures: Array[String] = _exact_key_failures(condition, _REPLACE_CONDITION_KEYS, "SAVE replace-exact condition")
		var fingerprint_variant: Variant = condition.get("expected_content_fingerprint", null)
		if typeof(fingerprint_variant) != TYPE_STRING:
			failures.append("SAVE replace-exact expected_content_fingerprint must be String")
		elif str(fingerprint_variant).is_empty() or str(fingerprint_variant) != str(fingerprint_variant).strip_edges():
			failures.append("SAVE replace-exact expected_content_fingerprint must be non-empty and trimmed")
		failures.sort()
		return failures
	if mode == SAVE_CONDITION_REQUIRE_NO_PROTECTED_TARGET:
		return _exact_key_failures(condition, _NO_PROTECTED_CONDITION_KEYS, "SAVE require-no-protected condition")
	return ["SAVE condition has unsupported mode: %s" % mode]


static func _exact_key_failures(source: Dictionary, expected_keys: Array[String], label: String) -> Array[String]:
	var actual: Array[String] = []
	for raw_key in source.keys():
		actual.append(str(raw_key))
	actual.sort()
	var expected: Array[String] = expected_keys.duplicate()
	expected.sort()
	if actual == expected:
		return []
	return ["%s keys must be exact expected=%s actual=%s" % [label, expected, actual]]


static func _classification_result(classification: String, diagnostics: Array) -> Dictionary:
	var normalized: Array[String] = []
	for diagnostic in diagnostics:
		normalized.append(str(diagnostic))
	normalized.sort()
	return {"success": true, "classification": classification, "available": classification == CLASS_AVAILABLE, "diagnostics": normalized}


static func _precondition_stale(target_classification: String, diagnostics: Array) -> Dictionary:
	var normalized: Array[String] = []
	for diagnostic in diagnostics:
		normalized.append(str(diagnostic))
	normalized.sort()
	return {"success": false, "precondition_stale": true, "target_classification": target_classification, "diagnostics": normalized}


static func _slot_path_failure(slot_path: String) -> String:
	if slot_path.is_empty() or slot_path != slot_path.strip_edges():
		return "SAVE slot path must be non-empty and trimmed"
	if not slot_path.begins_with("user://"):
		return "SAVE slot path must remain under user://"
	if slot_path.ends_with(CANDIDATE_SUFFIX) or slot_path.ends_with(BACKUP_SUFFIX):
		return "SAVE slot path must not use internal candidate/backup suffix"
	return ""


func _rename_file(from_path: String, to_path: String) -> int:
	if _rename_operation.is_valid():
		var result: Variant = _rename_operation.call(from_path, to_path)
		if typeof(result) != TYPE_INT:
			return ERR_INVALID_DATA
		return int(result)
	return int(DirAccess.rename_absolute(ProjectSettings.globalize_path(from_path), ProjectSettings.globalize_path(to_path)))


static func _remove_file_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
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
	return {"success": false, "diagnostics": diagnostics}
