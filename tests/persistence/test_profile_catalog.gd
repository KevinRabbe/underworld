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
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return failures

static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
