extends RefCounted

const Catalog := preload("res://gameplay/persistence/profile_catalog.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	var path := "user://profile_catalog_contract.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var character := Catalog.create_character("Test Survivor", path)
	_expect(failures, "character creation succeeds", bool(character.get("success", false)))
	var world := Catalog.create_world("Test World", 424242, path)
	_expect(failures, "world creation succeeds", bool(world.get("success", false)))
	if bool(character.get("success", false)) and bool(world.get("success", false)):
		var selected := Catalog.select_pair(character["character"]["character_id"], world["world"]["world_id"], path)
		_expect(failures, "character/world pair selection persists", bool(selected.get("success", false)))
		var last := Catalog.last_pair(path)
		_expect(failures, "last pair reloads", bool(last.get("success", false)))
		_expect(failures, "character name persists", str(last["character"]["display_name"]) == "Test Survivor")
		_expect(failures, "world seed persists", int(last["world"]["world_seed"]) == 424242)
	var corrupt_path := "user://profile_catalog_corrupt.json"
	var corrupt_file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	corrupt_file.store_string("{not-json")
	corrupt_file = null
	var rejected := Catalog.create_character("Must Not Overwrite", corrupt_path)
	_expect(failures, "corrupt catalog create fails closed", not bool(rejected.get("success", false)))
	var preserved := FileAccess.open(corrupt_path, FileAccess.READ)
	_expect(failures, "corrupt catalog remains preserved", preserved != null and preserved.get_as_text() == "{not-json")
	preserved = null
	var invalid_schema_path := "user://profile_catalog_invalid_schema.json"
	var invalid_schema_file := FileAccess.open(invalid_schema_path, FileAccess.WRITE)
	invalid_schema_file.store_string(JSON.stringify({"schema": "underworld.profile-catalog.v1", "characters": {}, "worlds": []}))
	invalid_schema_file = null
	var invalid_schema_result := Catalog.create_world("Must Not Replace", 9, invalid_schema_path)
	_expect(failures, "invalid catalog schema create fails closed", not bool(invalid_schema_result.get("success", false)))
	var invalid_preserved := FileAccess.open(invalid_schema_path, FileAccess.READ)
	_expect(failures, "invalid catalog schema remains preserved", invalid_preserved != null and str(JSON.parse_string(invalid_preserved.get_as_text()).get("characters", null)) == "{}")
	invalid_preserved = null
	if FileAccess.file_exists(corrupt_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_path))
	if FileAccess.file_exists(invalid_schema_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_schema_path))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return failures

static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
