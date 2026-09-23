extends RefCounted

const GameSaveSlotService := preload("res://gameplay/persistence/game_save_slot_service.gd")
const SlotFixtures := preload("res://tests/persistence/test_game_save_slot_service.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	var service = GameSaveSlotService.new()
	var a_w1 := GameSaveSlotService.pair_slot_path("character:a", "world:1")
	var b_w2 := GameSaveSlotService.pair_slot_path("character:b", "world:2")
	var a_w2 := GameSaveSlotService.pair_slot_path("character:a", "world:2")
	var b_w1 := GameSaveSlotService.pair_slot_path("character:b", "world:1")
	_expect(failures, "pair slot paths are deterministic", a_w1 == GameSaveSlotService.pair_slot_path("character:a", "world:1"))
	_expect(failures, "pair slot paths are independent", a_w1 != b_w2 and a_w1 != a_w2 and a_w1 != b_w1)
	var fixture_failures: Array[String] = []
	var fixture: Dictionary = SlotFixtures._fixture(fixture_failures)
	if not fixture_failures.is_empty() or fixture.is_empty():
		failures.append_array(fixture_failures)
		return failures
	var a_request: Dictionary = fixture["request"].duplicate(true)
	a_request["player_resume"]["x"] = 11.0
	var b_request: Dictionary = fixture["request"].duplicate(true)
	b_request["player_resume"]["x"] = 22.0
	var a_saved: Dictionary = service.save_slot({"success": true, "request": a_request}, a_w1)
	var b_saved: Dictionary = service.save_slot({"success": true, "request": b_request}, b_w2)
	_expect(failures, "A/W1 pair SAVE succeeds", bool(a_saved.get("success", false)))
	_expect(failures, "B/W2 pair SAVE succeeds", bool(b_saved.get("success", false)))
	var a_loaded: Dictionary = service.load_slot(a_w1)
	var b_loaded: Dictionary = service.load_slot(b_w2)
	_expect(failures, "A/W1 restores its own durable state", bool(a_loaded.get("candidate", {}).get("resume_position", Vector3.ZERO).x == 11.0))
	_expect(failures, "B/W2 restores its own durable state", bool(b_loaded.get("candidate", {}).get("resume_position", Vector3.ZERO).x == 22.0))
	_expect(failures, "A/W2 starts independently", str(service.probe_slot(a_w2).get("classification", "")) == GameSaveSlotService.CLASS_NONE)
	_expect(failures, "B/W1 starts independently", str(service.probe_slot(b_w1).get("classification", "")) == GameSaveSlotService.CLASS_NONE)
	var corrupt_file := FileAccess.open(a_w1, FileAccess.WRITE)
	if corrupt_file != null:
		corrupt_file.store_string("{corrupt-pair")
	corrupt_file = null
	_expect(failures, "corrupt A/W1 fails closed", str(service.probe_slot(a_w1).get("classification", "")) == GameSaveSlotService.CLASS_INVALID)
	_expect(failures, "corrupt A/W1 does not damage B/W2", str(service.probe_slot(b_w2).get("classification", "")) == GameSaveSlotService.CLASS_AVAILABLE)
	var legacy_path := "user://underworld_m3_pair_isolation_legacy.json"
	_cleanup([a_w1, b_w2, a_w2, b_w1, legacy_path])
	var encoded: Dictionary = service.save_slot({"success": true, "request": a_request}, legacy_path)
	_expect(failures, "legacy global fixture SAVE succeeds", bool(encoded.get("success", false)))
	var migrated: Dictionary = service.persist_candidate_json(_read(legacy_path), a_w1)
	_expect(failures, "legacy global SAVE migrates to pair slot", bool(migrated.get("success", false)))
	_expect(failures, "legacy source remains protected", FileAccess.file_exists(legacy_path))
	_cleanup([a_w1, b_w2, a_w2, b_w1, legacy_path])
	return failures

static func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""

static func _cleanup(paths: Array[String]) -> void:
	for path in paths:
		for candidate in [path, path + GameSaveSlotService.CANDIDATE_SUFFIX, path + GameSaveSlotService.BACKUP_SUFFIX]:
			if FileAccess.file_exists(candidate):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))

static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
