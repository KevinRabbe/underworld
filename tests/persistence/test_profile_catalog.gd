extends RefCounted

const Catalog := preload("res://gameplay/persistence/profile_catalog.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	var path := "user://profile_catalog_contract.json"
	for stale_path in [
		path,
		"user://profile_catalog_legacy_migration.json",
		"user://profile_catalog_rejected_legacy.json",
		"user://profile_catalog_old_schema.json",
		"user://profile_catalog_corrupt.json",
		"user://profile_catalog_invalid_schema.json",
		"user://profile_catalog_recovery.json",
		"user://profile_catalog_binding_failure.json",
		"user://profile_catalog_invalid_backup.json",
		"user://profile_catalog_corrupt_binding.json"
	]:
		_clear_path_and_transients(stale_path)
	var character := Catalog.create_character("Test Survivor", path)
	_expect(failures, "character creation succeeds", bool(character.get("success", false)))
	var world := Catalog.create_world("Test World", 424242, path)
	_expect(failures, "world creation succeeds: " + str(world.get("diagnostics", [])), bool(world.get("success", false)))
	if bool(character.get("success", false)) and bool(world.get("success", false)):
		var selected := Catalog.select_pair(character["character"]["character_id"], world["world"]["world_id"], path)
		_expect(failures, "character/world pair selection persists", bool(selected.get("success", false)))
		var last := Catalog.last_pair(path)
		_expect(failures, "last pair reloads", bool(last.get("success", false)))
		_expect(failures, "character name persists", str(last["character"]["display_name"]) == "Test Survivor")
		_expect(failures, "world seed persists", int(last["world"]["world_seed"]) == 424242)
		var saved := Catalog.record_successful_save(character["character"]["character_id"], world["world"]["world_id"], "wid1:canonical-world", 424242, "save-fingerprint-1", path)
		_expect(failures, "successful save pair binding persists", bool(saved.get("success", false)))
		var saved_pair := Catalog.saved_pair(path)
		_expect(failures, "saved pair resolves canonical world identity", bool(saved_pair.get("success", false)) and str(saved_pair.get("canonical_world_id", "")) == "wid1:canonical-world")
		var refreshed := Catalog.record_successful_save(character["character"]["character_id"], world["world"]["world_id"], "wid1:canonical-world", 424242, "save-fingerprint-2", path)
		var refreshed_pair := Catalog.saved_pair(path)
		_expect(failures, "subsequent save refreshes exact binding fingerprint", bool(refreshed.get("success", false)) and str(refreshed_pair.get("content_fingerprint", "")) == "save-fingerprint-2")
		var migrated_path := "user://profile_catalog_legacy_migration.json"
		var migrated := Catalog.migrate_legacy_save("wid1:legacy-world", 77, "legacy-fingerprint-1", migrated_path)
		_expect(failures, "legacy save migration creates durable pair", bool(migrated.get("success", false)))
		var migrated_pair := Catalog.saved_pair(migrated_path)
		_expect(failures, "legacy migration preserves canonical world identity", bool(migrated_pair.get("success", false)) and str(migrated_pair.get("canonical_world_id", "")) == "wid1:legacy-world")
		var migrated_again := Catalog.migrate_legacy_save("wid1:legacy-world", 77, "legacy-fingerprint-1", migrated_path)
		var migrated_catalog := Catalog.load_catalog(migrated_path)
		_expect(failures, "repeated legacy migration is idempotent", bool(migrated_again.get("success", false)) and migrated_catalog["catalog"]["characters"].size() == 1 and migrated_catalog["catalog"]["worlds"].size() == 1)
		if FileAccess.file_exists(migrated_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(migrated_path))
	var rejected_legacy := Catalog.migrate_legacy_save("wid1:legacy-world", 77, "", "user://profile_catalog_rejected_legacy.json")
	_expect(failures, "legacy migration rejects missing save fingerprint", not bool(rejected_legacy.get("success", false)))
	var old_catalog_path := "user://profile_catalog_old_schema.json"
	var old_catalog_file := FileAccess.open(old_catalog_path, FileAccess.WRITE)
	if old_catalog_file != null:
		old_catalog_file.store_string(JSON.stringify({"schema": "underworld.profile-catalog.v1", "characters": [{"character_id": "character:old", "display_name": "Old"}], "worlds": [{"world_id": "world:old", "world_name": "Old World", "world_seed": 1}]}))
	old_catalog_file = null
	var old_loaded := Catalog.load_catalog(old_catalog_path)
	_expect(failures, "older catalog without saved-pair fields remains readable: " + str(old_loaded.get("diagnostics", [])), bool(old_loaded.get("success", false)) and not bool(Catalog.saved_pair(old_catalog_path).get("success", false)))
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
	var invalid_preserved_data: Variant = JSON.parse_string(invalid_preserved.get_as_text()) if invalid_preserved != null else null
	_expect(failures, "invalid catalog schema remains preserved", invalid_preserved_data is Dictionary and invalid_preserved_data.get("characters", null) is Dictionary)
	invalid_preserved = null
	var recovery_path := "user://profile_catalog_recovery.json"
	var recovery_catalog := {"schema": "underworld.profile-catalog.v1", "characters": [{"character_id": "character:keep", "display_name": "Keep Me"}], "worlds": [{"world_id": "world:keep", "world_name": "Keep World", "world_seed": 9}], "last_character_id": "character:keep", "last_world_id": "world:keep", "saved_character_id": "character:keep", "saved_world_id": "world:keep", "saved_canonical_world_id": "wid1:keep", "saved_world_seed": 9, "saved_content_fingerprint": "keep-fingerprint"}
	var recovery_file := FileAccess.open(recovery_path + ".backup", FileAccess.WRITE)
	if recovery_file != null:
		recovery_file.store_string(JSON.stringify(recovery_catalog))
	recovery_file = null
	var staged_candidate := FileAccess.open(recovery_path + ".candidate", FileAccess.WRITE)
	if staged_candidate != null:
		staged_candidate.store_string(JSON.stringify(Catalog._empty()))
	staged_candidate = null
	var recovered := Catalog.load_catalog(recovery_path)
	_expect(failures, "missing canonical recovers valid backup: " + str(recovered.get("diagnostics", [])), bool(recovered.get("success", false)) and str(recovered["catalog"]["characters"][0]["display_name"]) == "Keep Me")
	_expect(failures, "recovered catalog is not treated as empty: " + str(recovered.get("diagnostics", [])), bool(recovered.get("success", false)) and recovered["catalog"]["characters"].size() == 1)
	_expect(failures, "recovered saved-pair metadata survives: " + str(Catalog.saved_pair(recovery_path).get("diagnostics", [])), bool(Catalog.saved_pair(recovery_path).get("success", false)))
	_expect(failures, "recovery removes stale candidate", not FileAccess.file_exists(recovery_path + ".candidate"))
	var promoted := Catalog.create_world("After Recovery", 77, recovery_path)
	_expect(failures, "promotion after recovery succeeds", bool(promoted.get("success", false)))
	_expect(failures, "successful promotion leaves no backup", not FileAccess.file_exists(recovery_path + ".backup"))
	_expect(failures, "successful promotion leaves no candidate", not FileAccess.file_exists(recovery_path + ".candidate"))
	var failed_binding_path := "user://profile_catalog_binding_failure.json"
	var failed_binding_character := Catalog.create_character("Binding Survivor", failed_binding_path)
	var failed_binding_world := Catalog.create_world("Binding World", 12, failed_binding_path)
	if bool(failed_binding_character.get("success", false)) and bool(failed_binding_world.get("success", false)):
		Catalog.record_successful_save(failed_binding_character["character"]["character_id"], failed_binding_world["world"]["world_id"], "wid1:binding", 12, "old-fingerprint", failed_binding_path)
		DirAccess.make_dir_absolute(ProjectSettings.globalize_path(failed_binding_path + ".candidate"))
		var failed_binding := Catalog.record_successful_save(failed_binding_character["character"]["character_id"], failed_binding_world["world"]["world_id"], "wid1:binding", 12, "new-fingerprint", failed_binding_path)
		var preserved_binding := Catalog.saved_pair(failed_binding_path)
		_expect(failures, "binding write failure reports failure", not bool(failed_binding.get("success", false)))
		_expect(failures, "binding write failure preserves last successful fingerprint", str(preserved_binding.get("content_fingerprint", "")) == "old-fingerprint")
	var invalid_backup_path := "user://profile_catalog_invalid_backup.json"
	var invalid_backup_file := FileAccess.open(invalid_backup_path + ".backup", FileAccess.WRITE)
	if invalid_backup_file != null:
		invalid_backup_file.store_string("{invalid-backup")
	invalid_backup_file = null
	var invalid_backup_load := Catalog.load_catalog(invalid_backup_path)
	_expect(failures, "invalid backup with missing canonical fails closed", not bool(invalid_backup_load.get("success", false)))
	var invalid_backup_create := Catalog.create_character("Must Not Replace Backup", invalid_backup_path)
	_expect(failures, "invalid backup cannot be overwritten by create", not bool(invalid_backup_create.get("success", false)))
	var corrupt_binding_path := "user://profile_catalog_corrupt_binding.json"
	var corrupt_binding_file := FileAccess.open(corrupt_binding_path, FileAccess.WRITE)
	if corrupt_binding_file != null:
		corrupt_binding_file.store_string(JSON.stringify({"schema": "underworld.profile-catalog.v1", "characters": [], "worlds": [], "saved_character_id": 4, "saved_world_id": "", "saved_canonical_world_id": "", "saved_world_seed": 0, "saved_content_fingerprint": ""}))
	corrupt_binding_file = null
	_expect(failures, "malformed saved-pair metadata fails closed", not bool(Catalog.load_catalog(corrupt_binding_path).get("success", false)))
	var partial_binding_path := "user://profile_catalog_partial_binding.json"
	var partial_binding_file := FileAccess.open(partial_binding_path, FileAccess.WRITE)
	if partial_binding_file != null:
		partial_binding_file.store_string(JSON.stringify({
			"schema": "underworld.profile-catalog.v1",
			"characters": [{"character_id": "character:partial", "display_name": "Partial"}],
			"worlds": [{"world_id": "world:partial", "world_name": "Partial World", "world_seed": 12}],
			"saved_character_id": "character:partial",
			"saved_world_id": "world:partial",
			"saved_canonical_world_id": "",
			"saved_world_seed": 12,
			"saved_content_fingerprint": ""
		}))
	partial_binding_file = null
	var partial_binding_load := Catalog.load_catalog(partial_binding_path)
	_expect(failures, "partially populated saved-pair metadata fails closed", not bool(partial_binding_load.get("success", false)))
	var partial_binding_create := Catalog.create_character("Must Not Replace Partial Binding", partial_binding_path)
	_expect(failures, "partial binding cannot be overwritten by create", not bool(partial_binding_create.get("success", false)))
	if FileAccess.file_exists(corrupt_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_path))
	if FileAccess.file_exists(invalid_schema_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_schema_path))
	for transient in [recovery_path, recovery_path + ".candidate", recovery_path + ".backup"]:
		if FileAccess.file_exists(transient):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(transient))
	for transient in [invalid_backup_path, invalid_backup_path + ".backup"]:
		if FileAccess.file_exists(transient):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(transient))
	if FileAccess.file_exists(corrupt_binding_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_binding_path))
	if FileAccess.file_exists(partial_binding_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(partial_binding_path))
	for transient in [old_catalog_path, failed_binding_path, failed_binding_path + ".candidate"]:
		if FileAccess.file_exists(transient):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(transient))
		elif DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(transient)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(transient))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return failures

static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)

static func _clear_path_and_transients(path: String) -> void:
	for candidate in [path, path + ".candidate", path + ".backup"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
		elif DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(candidate)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
