extends "res://gameplay/persistence/game_save_slot_service.gd"

var replacement_json: String = ""
var replacement_performed: bool = false
var saw_candidate_before_replacement: bool = false
var replacement_failed: bool = false


func configure_replacement(json_text: String) -> RefCounted:
	replacement_json = json_text
	return self


func _check_save_precondition(slot_path: String, condition: Dictionary) -> Dictionary:
	if not replacement_performed:
		saw_candidate_before_replacement = FileAccess.file_exists(slot_path + CANDIDATE_SUFFIX)
		var file: FileAccess = FileAccess.open(slot_path, FileAccess.WRITE)
		if file == null:
			replacement_failed = true
		else:
			file.store_string(replacement_json)
			file.flush()
			file = null
		replacement_performed = true
	return super._check_save_precondition(slot_path, condition)
