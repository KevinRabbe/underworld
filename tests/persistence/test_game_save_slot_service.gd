extends RefCounted

const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const WorldDomainSessionState := preload("res://gameplay/world_session/world_domain_session_state.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquipmentService := preload("res://gameplay/items/equipment/equipment_service.gd")
const GameplaySaveCatalog := preload("res://gameplay/persistence/gameplay_save_catalog.gd")
const IntegratedGameSaveContract := preload("res://gameplay/persistence/integrated_game_save_contract.gd")
const GameSaveSlotService := preload("res://gameplay/persistence/game_save_slot_service.gd")

const TEST_SLOT := "user://save_001_slot_service_test.json"
const WOOD_ID := "item.resource.wood"
const AXE_ID := "item.tool.stone_axe"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_cleanup()
	_test_missing_probe_is_non_mutating(failures)
	_test_valid_save_probe_and_load(failures)
	_test_conditional_save_preconditions(failures)
	_test_invalid_candidate_preserves_previous_slot(failures)
	_test_promotion_failure_restores_previous_slot(failures)
	_test_legacy_v1_probe_and_load_are_incompatible(failures)
	_test_corrupt_probe_is_non_mutating(failures)
	_cleanup()
	return failures


static func _test_missing_probe_is_non_mutating(failures: Array[String]) -> void:
	var service = GameSaveSlotService.new()
	var probe: Dictionary = service.probe_slot(TEST_SLOT)
	if not bool(probe.get("success", false)):
		failures.append("missing SAVE probe should execute successfully")
	if str(probe.get("classification", "")) != GameSaveSlotService.CLASS_NONE:
		failures.append("missing SAVE slot did not classify NONE")
	if bool(probe.get("available", true)):
		failures.append("missing SAVE slot unexpectedly reported Continue availability")
	if probe.has("candidate"):
		failures.append("missing SAVE probe exposed a candidate")
	_assert_no_internal_artifacts(failures, "missing SAVE probe")
	if FileAccess.file_exists(TEST_SLOT):
		failures.append("missing SAVE probe created the slot")


static func _test_valid_save_probe_and_load(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(failures)
	if fixture.is_empty():
		return
	var service = GameSaveSlotService.new()
	var saved: Dictionary = service.save_slot(fixture["request_object"], TEST_SLOT)
	if not _require_success(saved, "atomic SAVE write", failures):
		return
	if str(saved.get("classification", "")) != GameSaveSlotService.CLASS_AVAILABLE:
		failures.append("successful SAVE did not return AVAILABLE classification")
	if not FileAccess.file_exists(TEST_SLOT):
		failures.append("successful SAVE did not promote final slot")
	_assert_no_internal_artifacts(failures, "successful SAVE")

	var probe: Dictionary = service.probe_slot(TEST_SLOT)
	if not _require_available(probe, "valid SAVE probe", failures):
		return
	if probe.has("candidate"):
		failures.append("SAVE probe exposed detached Continue candidate")
	if int(probe.get("world_seed", 0)) != fixture["context"].world_seed:
		failures.append("SAVE probe returned wrong world seed")
	if str(probe.get("world_id", "")) != str(fixture["context"].world_id):
		failures.append("SAVE probe returned wrong WorldId")
	if str(probe.get("active_domain", "")) != WorldDomainSessionState.DOMAIN_OVERWORLD:
		failures.append("SAVE probe returned wrong active domain")
	if str(probe.get("content_fingerprint", "")) != _read_text(TEST_SLOT).sha256_text():
		failures.append("SAVE probe content fingerprint does not identify exact canonical bytes")

	var loaded: Dictionary = service.load_slot(TEST_SLOT)
	if not _require_available(loaded, "atomic SAVE load", failures):
		return
	var candidate: Dictionary = loaded.get("candidate", {})
	if candidate.get("resume_position", Vector3.ZERO) != fixture["resume_position"]:
		failures.append("SAVE slot load changed resume position")
	if str(candidate.get("active_domain", "")) != WorldDomainSessionState.DOMAIN_OVERWORLD:
		failures.append("SAVE slot load changed active domain")
	var restored_session = candidate.get("world_session_state", null)
	if restored_session == null or restored_session.active_domain() != WorldDomainSessionState.DOMAIN_OVERWORLD:
		failures.append("SAVE slot load did not reconstruct detached ACTIVE world-session state")
	var restored_inventory = candidate.get("inventory_state", null)
	if restored_inventory == null or restored_inventory.canonical_json() != fixture["inventory"].canonical_json():
		failures.append("SAVE slot load changed inventory state")
	var restored_equipment = candidate.get("equipment_state", null)
	if restored_equipment == null or restored_equipment.canonical_snapshot() != fixture["equipment"].canonical_snapshot():
		failures.append("SAVE slot load changed equipment state")
	var pending_variant: Variant = candidate.get("pending_loot_states", null)
	if not pending_variant is Array or not pending_variant.is_empty():
		failures.append("SAVE slot load invented pending-loot state for empty durable set")
	var vitals: Dictionary = candidate.get("player_vitals", {})
	if int(vitals.get("current_health", -1)) != 83:
		failures.append("SAVE slot load changed current Health")
	if not is_equal_approx(float(vitals.get("current_stamina", -1.0)), 47.25):
		failures.append("SAVE slot load changed current Stamina")


static func _test_conditional_save_preconditions(failures: Array[String]) -> void:
	if not FileAccess.file_exists(TEST_SLOT):
		failures.append("conditional SAVE regression requires valid existing slot")
		return
	var fixture: Dictionary = _fixture(failures)
	if fixture.is_empty():
		return
	var service = GameSaveSlotService.new()
	var initial_probe: Dictionary = service.probe_slot(TEST_SLOT)
	if not _require_available(initial_probe, "conditional SAVE initial probe", failures):
		return
	var initial_fingerprint: String = str(initial_probe.get("content_fingerprint", ""))
	var replacement_request: Dictionary = fixture["request"].duplicate(true)
	replacement_request["player_resume"]["x"] = float(replacement_request["player_resume"]["x"]) + 2.0
	var replaced: Dictionary = service.save_slot(
		_successful_request_object(replacement_request),
		TEST_SLOT,
		{
			"mode": GameSaveSlotService.SAVE_CONDITION_REPLACE_EXACT_PROTECTED,
			"expected_content_fingerprint": initial_fingerprint,
		}
	)
	if not _require_success(replaced, "exact-protected conditional SAVE", failures):
		return
	var after_replace_probe: Dictionary = service.probe_slot(TEST_SLOT)
	if not _require_available(after_replace_probe, "post-replace probe", failures):
		return
	if str(after_replace_probe.get("content_fingerprint", "")) == initial_fingerprint:
		failures.append("successful conditional SAVE did not change exact content fingerprint")

	var protected_before: String = _read_text(TEST_SLOT)
	var stale_request: Dictionary = fixture["request"].duplicate(true)
	stale_request["player_resume"]["z"] = float(stale_request["player_resume"]["z"]) - 3.0
	var stale: Dictionary = service.save_slot(
		_successful_request_object(stale_request),
		TEST_SLOT,
		{
			"mode": GameSaveSlotService.SAVE_CONDITION_REPLACE_EXACT_PROTECTED,
			"expected_content_fingerprint": initial_fingerprint,
		}
	)
	if bool(stale.get("success", true)) or not bool(stale.get("precondition_stale", false)):
		failures.append("stale exact-protected fingerprint did not fail as precondition-stale")
	if _read_text(TEST_SLOT) != protected_before:
		failures.append("stale exact-protected SAVE changed canonical slot bytes")
	_assert_no_internal_artifacts(failures, "stale exact-protected SAVE")

	var protected_guard: Dictionary = service.save_slot(
		_successful_request_object(stale_request),
		TEST_SLOT,
		{"mode": GameSaveSlotService.SAVE_CONDITION_REQUIRE_NO_PROTECTED_TARGET}
	)
	if bool(protected_guard.get("success", true)) or not bool(protected_guard.get("precondition_stale", false)):
		failures.append("require-no-protected condition did not reject AVAILABLE target")
	if _read_text(TEST_SLOT) != protected_before:
		failures.append("require-no-protected rejection changed protected slot bytes")
	_assert_no_internal_artifacts(failures, "require-no-protected protected rejection")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SLOT))
	var no_target: Dictionary = service.save_slot(
		fixture["request_object"],
		TEST_SLOT,
		{"mode": GameSaveSlotService.SAVE_CONDITION_REQUIRE_NO_PROTECTED_TARGET}
	)
	if not _require_success(no_target, "require-no-protected SAVE against NONE", failures):
		return
	if str(service.probe_slot(TEST_SLOT).get("classification", "")) != GameSaveSlotService.CLASS_AVAILABLE:
		failures.append("require-no-protected SAVE against NONE did not produce AVAILABLE slot")
	_assert_no_internal_artifacts(failures, "require-no-protected SAVE against NONE")


static func _test_invalid_candidate_preserves_previous_slot(failures: Array[String]) -> void:
	if not FileAccess.file_exists(TEST_SLOT):
		failures.append("prior-slot preservation regression requires valid existing slot")
		return
	var before: String = _read_text(TEST_SLOT)
	if before.is_empty():
		failures.append("prior-slot preservation regression could not read existing slot")
		return
	var service = GameSaveSlotService.new()
	var rejected: Dictionary = service.persist_candidate_json(
		'{"schema":"not-an-integrated-save"}',
		TEST_SLOT
	)
	if bool(rejected.get("success", false)):
		failures.append("invalid SAVE candidate unexpectedly promoted")
	var after: String = _read_text(TEST_SLOT)
	if after != before:
		failures.append("candidate reread/validation failure changed previous valid slot bytes")
	_assert_no_internal_artifacts(failures, "candidate validation failure")


static func _test_promotion_failure_restores_previous_slot(failures: Array[String]) -> void:
	if not FileAccess.file_exists(TEST_SLOT):
		failures.append("promotion-failure regression requires valid existing slot")
		return
	var before: String = _read_text(TEST_SLOT)
	if before.is_empty():
		failures.append("promotion-failure regression could not read previous slot")
		return
	var fixture: Dictionary = _fixture(failures)
	if fixture.is_empty():
		return
	var replacement_request: Dictionary = fixture["request"].duplicate(true)
	replacement_request["player_resume"]["x"] = float(replacement_request["player_resume"]["x"]) + 1.0
	var encoded: Dictionary = IntegratedGameSaveContract.encode_v2_request(replacement_request)
	if not _require_success(encoded, "promotion-failure replacement encode", failures):
		return
	var replacement_json: String = str(encoded.get("json", ""))
	if replacement_json == before:
		failures.append("promotion-failure regression replacement candidate did not differ from previous slot")
		return

	var calls: Array[String] = []
	var service = GameSaveSlotService.new().configure_rename_operation(
		func(from_path: String, to_path: String) -> int:
			calls.append("%s->%s" % [from_path, to_path])
			if from_path == TEST_SLOT + GameSaveSlotService.CANDIDATE_SUFFIX and to_path == TEST_SLOT:
				return ERR_CANT_CREATE
			return int(DirAccess.rename_absolute(
				ProjectSettings.globalize_path(from_path),
				ProjectSettings.globalize_path(to_path)
			))
	)
	var rejected: Dictionary = service.persist_candidate_json(replacement_json, TEST_SLOT)
	if bool(rejected.get("success", false)):
		failures.append("forced candidate promotion failure unexpectedly succeeded")
	var expected_calls: Array[String] = [
		"%s->%s" % [TEST_SLOT, TEST_SLOT + GameSaveSlotService.BACKUP_SUFFIX],
		"%s->%s" % [TEST_SLOT + GameSaveSlotService.CANDIDATE_SUFFIX, TEST_SLOT],
		"%s->%s" % [TEST_SLOT + GameSaveSlotService.BACKUP_SUFFIX, TEST_SLOT],
	]
	if calls != expected_calls:
		failures.append("promotion-failure rename sequence was not backup -> failed promote -> restore: %s" % [calls])
	if _read_text(TEST_SLOT) != before:
		failures.append("failed candidate promotion did not restore previous slot byte-identically")
	_assert_no_internal_artifacts(failures, "failed candidate promotion")
	var probe: Dictionary = GameSaveSlotService.new().probe_slot(TEST_SLOT)
	if not _require_available(probe, "restored previous slot probe", failures):
		failures.append("restored previous slot lost Continue authority after failed promotion")


static func _test_legacy_v1_probe_and_load_are_incompatible(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(failures)
	if fixture.is_empty():
		return
	for resume_y in [32.0, 0.0, -32.0]:
		var legacy_resume := Vector3(8.25, resume_y, -11.5)
		var legacy: Dictionary = IntegratedGameSaveContract.encode(
			fixture["context"],
			fixture["delta_store"],
			fixture["inventory"],
			fixture["equipment"],
			[],
			legacy_resume
		)
		if not _require_success(legacy, "legacy-v1 classification fixture", failures):
			return
		_write_text(TEST_SLOT, str(legacy.get("json", "")), failures)
		var service = GameSaveSlotService.new()
		var probe: Dictionary = service.probe_slot(TEST_SLOT)
		if str(probe.get("classification", "")) != GameSaveSlotService.CLASS_INCOMPATIBLE:
			failures.append("legacy v1 probe did not classify INCOMPATIBLE for resume Y=%s" % resume_y)
		if bool(probe.get("available", true)):
			failures.append("legacy v1 probe reported Continue availability for resume Y=%s" % resume_y)
		if probe.has("candidate"):
			failures.append("legacy v1 probe exposed candidate for resume Y=%s" % resume_y)
		var loaded: Dictionary = service.load_slot(TEST_SLOT)
		if str(loaded.get("classification", "")) != GameSaveSlotService.CLASS_INCOMPATIBLE:
			failures.append("legacy v1 load disagreed with probe classification for resume Y=%s" % resume_y)
		if loaded.has("candidate"):
			failures.append("legacy v1 load exposed detached candidate for resume Y=%s" % resume_y)
		if not _diagnostics_contain(loaded, IntegratedGameSaveContract.LEGACY_DOMAIN_MISSING_DIAGNOSTIC):
			failures.append("legacy v1 load omitted stable domain-missing diagnostic for resume Y=%s" % resume_y)


static func _test_corrupt_probe_is_non_mutating(failures: Array[String]) -> void:
	var corrupt_text := "{not-valid-json"
	_write_text(TEST_SLOT, corrupt_text, failures)
	var before: String = _read_text(TEST_SLOT)
	var service = GameSaveSlotService.new()
	var probe: Dictionary = service.probe_slot(TEST_SLOT)
	if not bool(probe.get("success", false)):
		failures.append("corrupt SAVE probe should classify without throwing operation failure")
	if str(probe.get("classification", "")) != GameSaveSlotService.CLASS_INVALID:
		failures.append("corrupt SAVE slot did not classify INVALID")
	if bool(probe.get("available", true)):
		failures.append("corrupt SAVE slot unexpectedly reported Continue availability")
	if probe.has("candidate"):
		failures.append("corrupt SAVE probe exposed a candidate")
	var loaded: Dictionary = service.load_slot(TEST_SLOT)
	if str(loaded.get("classification", "")) != GameSaveSlotService.CLASS_INVALID:
		failures.append("corrupt SAVE load disagreed with probe classification")
	if loaded.has("candidate"):
		failures.append("corrupt SAVE load exposed a candidate")
	if _read_text(TEST_SLOT) != before:
		failures.append("corrupt SAVE probe/load mutated slot bytes")
	_assert_no_internal_artifacts(failures, "corrupt SAVE probe/load")


static func _fixture(failures: Array[String]) -> Dictionary:
	var catalog_result: Dictionary = GameplaySaveCatalog.build_registry()
	if not _require_success(catalog_result, "slot fixture registry", failures):
		return {}
	var registry = catalog_result.get("registry", null)
	var wood = registry.get_definition(WOOD_ID)
	var axe = registry.get_definition(AXE_ID)
	if wood == null or axe == null:
		failures.append("slot fixture could not resolve production item definitions")
		return {}
	var inventory = ItemContainerState.new().configure(8, 100.0)
	if not _require_success(inventory.add_stack(wood, 5, {"batch": 5, "quality": 1.0}), "slot fixture wood add", failures):
		return {}
	var axe_add: Dictionary = inventory.add_instance(axe, {"durability": 72})
	if not _require_success(axe_add, "slot fixture axe add", failures):
		return {}
	var equipment = EquipmentHotbarState.new().configure(
		GameplaySaveCatalog.equipment_rules(),
		GameplaySaveCatalog.hotbar_bindings()
	)
	if not _require_success(
		EquipmentService.new().equip_from_inventory(
			equipment,
			inventory,
			int(axe_add.get("slot", -1)),
			axe,
			GameplaySaveCatalog.SLOT_AXE
		),
		"slot fixture axe equip",
		failures
	):
		return {}
	if not _require_success(equipment.select_hotbar(2), "slot fixture hotbar selection", failures):
		return {}
	var context = WorldGenerationContext.new(217217)
	var delta_store = WorldDeltaStore.new()
	var session = WorldDomainSessionState.new(WorldDomainSessionState.DOMAIN_OVERWORLD, {})
	var resume_position := Vector3(8.25, 32.0, -11.5)
	var captured: Dictionary = IntegratedGameSaveContract.capture_v2_request({
		"world_context": context,
		"world_session_state": session,
		"delta_store": delta_store,
		"inventory_state": inventory,
		"equipment_state": equipment,
		"pending_loot_states": [],
		"resume_position": resume_position,
		"current_health": 83,
		"current_stamina": 47.25,
	})
	if not _require_success(captured, "slot fixture v2 request capture", failures):
		return {}
	return {
		"context": context,
		"delta_store": delta_store,
		"inventory": inventory,
		"equipment": equipment,
		"resume_position": resume_position,
		"request_object": captured.duplicate(true),
		"request": captured.get("request", {}).duplicate(true),
	}


static func _successful_request_object(request: Dictionary) -> Dictionary:
	return {
		"success": true,
		"request": request.duplicate(true),
		"diagnostics": [],
	}


static func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file = null
	return text


static func _write_text(path: String, text: String, failures: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("could not open slot fixture for write: %s" % path)
		return
	file.store_string(text)
	file.flush()
	file = null


static func _cleanup() -> void:
	for path in [
		TEST_SLOT,
		TEST_SLOT + GameSaveSlotService.CANDIDATE_SUFFIX,
		TEST_SLOT + GameSaveSlotService.BACKUP_SUFFIX,
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _assert_no_internal_artifacts(failures: Array[String], label: String) -> void:
	if FileAccess.file_exists(TEST_SLOT + GameSaveSlotService.CANDIDATE_SUFFIX):
		failures.append("%s left candidate artifact" % label)
	if FileAccess.file_exists(TEST_SLOT + GameSaveSlotService.BACKUP_SUFFIX):
		failures.append("%s left backup artifact" % label)


static func _diagnostics_contain(result: Dictionary, fragment: String) -> bool:
	for diagnostic in result.get("diagnostics", []):
		if str(diagnostic).contains(fragment):
			return true
	return false


static func _require_available(result: Dictionary, label: String, failures: Array[String]) -> bool:
	if not bool(result.get("success", false)):
		failures.append("%s operation failed diagnostics=%s" % [label, result.get("diagnostics", [])])
		return false
	if str(result.get("classification", "")) != GameSaveSlotService.CLASS_AVAILABLE:
		failures.append("%s classified %s diagnostics=%s" % [
			label,
			result.get("classification", ""),
			result.get("diagnostics", []),
		])
		return false
	return true


static func _require_success(result: Dictionary, label: String, failures: Array[String]) -> bool:
	if bool(result.get("success", false)):
		return true
	failures.append("%s failed diagnostics=%s" % [label, result.get("diagnostics", [])])
	return false