extends RefCounted

const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquipmentService := preload("res://gameplay/items/equipment/equipment_service.gd")
const GameplaySaveCatalog := preload("res://gameplay/persistence/gameplay_save_catalog.gd")
const GameSaveSlotService := preload("res://gameplay/persistence/game_save_slot_service.gd")

const TEST_SLOT := "user://save_001_slot_service_test.json"
const WOOD_ID := "item.resource.wood"
const AXE_ID := "item.tool.stone_axe"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_cleanup()
	_test_missing_probe_is_non_mutating(failures)
	_test_valid_save_probe_and_load(failures)
	_test_invalid_candidate_preserves_previous_slot(failures)
	_test_corrupt_probe_is_non_mutating(failures)
	_cleanup()
	return failures


static func _test_missing_probe_is_non_mutating(failures: Array[String]) -> void:
	var service = GameSaveSlotService.new()
	var probe: Dictionary = service.probe_slot(TEST_SLOT)
	if not bool(probe.get("success", false)):
		failures.append("missing SAVE probe should execute successfully")
	if bool(probe.get("available", true)):
		failures.append("missing SAVE slot unexpectedly reported Continue availability")
	if FileAccess.file_exists(TEST_SLOT):
		failures.append("missing SAVE probe created the slot")
	if FileAccess.file_exists(TEST_SLOT + GameSaveSlotService.CANDIDATE_SUFFIX):
		failures.append("missing SAVE probe created a candidate file")
	if FileAccess.file_exists(TEST_SLOT + GameSaveSlotService.BACKUP_SUFFIX):
		failures.append("missing SAVE probe created a backup file")


static func _test_valid_save_probe_and_load(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(failures)
	if fixture.is_empty():
		return
	var service = GameSaveSlotService.new()
	var saved: Dictionary = service.save_slot(
		fixture["context"],
		fixture["delta_store"],
		fixture["inventory"],
		fixture["equipment"],
		null,
		fixture["resume_position"],
		TEST_SLOT
	)
	if not _require_success(saved, "atomic SAVE write", failures):
		return
	if not FileAccess.file_exists(TEST_SLOT):
		failures.append("successful SAVE did not promote final slot")
	if FileAccess.file_exists(TEST_SLOT + GameSaveSlotService.CANDIDATE_SUFFIX):
		failures.append("successful SAVE left candidate file behind")
	if FileAccess.file_exists(TEST_SLOT + GameSaveSlotService.BACKUP_SUFFIX):
		failures.append("successful SAVE left backup file behind")

	var probe: Dictionary = service.probe_slot(TEST_SLOT)
	if not bool(probe.get("success", false)) or not bool(probe.get("available", false)):
		failures.append("valid SAVE slot did not enable Continue probe")
	if int(probe.get("world_seed", 0)) != fixture["context"].world_seed:
		failures.append("SAVE probe returned wrong world seed")
	if str(probe.get("world_id", "")) != str(fixture["context"].world_id):
		failures.append("SAVE probe returned wrong WorldId")

	var loaded: Dictionary = service.load_slot(TEST_SLOT)
	if not _require_success(loaded, "atomic SAVE load", failures):
		return
	var candidate: Dictionary = loaded.get("candidate", {})
	if candidate.get("resume_position", Vector3.ZERO) != fixture["resume_position"]:
		failures.append("SAVE slot load changed resume position")
	var restored_inventory = candidate.get("inventory_state", null)
	if restored_inventory == null or restored_inventory.canonical_json() != fixture["inventory"].canonical_json():
		failures.append("SAVE slot load changed inventory state")
	var restored_equipment = candidate.get("equipment_state", null)
	if restored_equipment == null or restored_equipment.canonical_snapshot() != fixture["equipment"].canonical_snapshot():
		failures.append("SAVE slot load changed equipment state")


static func _test_invalid_candidate_preserves_previous_slot(
	failures: Array[String]
) -> void:
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
	if FileAccess.file_exists(TEST_SLOT + GameSaveSlotService.CANDIDATE_SUFFIX):
		failures.append("rejected SAVE candidate file was not cleaned up")
	if FileAccess.file_exists(TEST_SLOT + GameSaveSlotService.BACKUP_SUFFIX):
		failures.append("candidate validation failure disturbed backup lifecycle")


static func _test_corrupt_probe_is_non_mutating(failures: Array[String]) -> void:
	var corrupt_text := "{not-valid-json"
	var file: FileAccess = FileAccess.open(TEST_SLOT, FileAccess.WRITE)
	if file == null:
		failures.append("corrupt probe regression could not replace test slot")
		return
	file.store_string(corrupt_text)
	file.flush()
	file = null
	var before: String = _read_text(TEST_SLOT)
	var service = GameSaveSlotService.new()
	var probe: Dictionary = service.probe_slot(TEST_SLOT)
	if not bool(probe.get("success", false)):
		failures.append("corrupt SAVE probe should report availability without throwing operation failure")
	if bool(probe.get("available", true)):
		failures.append("corrupt SAVE slot unexpectedly reported Continue availability")
	if _read_text(TEST_SLOT) != before:
		failures.append("corrupt SAVE probe mutated slot bytes")
	if FileAccess.file_exists(TEST_SLOT + GameSaveSlotService.CANDIDATE_SUFFIX):
		failures.append("corrupt SAVE probe created candidate state")
	if FileAccess.file_exists(TEST_SLOT + GameSaveSlotService.BACKUP_SUFFIX):
		failures.append("corrupt SAVE probe created backup state")


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
	var wood_add: Dictionary = inventory.add_stack(wood, 5, {"batch": 5, "quality": 1.0})
	if not _require_success(wood_add, "slot fixture wood add", failures):
		return {}
	var axe_add: Dictionary = inventory.add_instance(axe, {"durability": 72})
	if not _require_success(axe_add, "slot fixture axe add", failures):
		return {}
	var equipment = EquipmentHotbarState.new().configure(
		GameplaySaveCatalog.equipment_rules(),
		GameplaySaveCatalog.hotbar_bindings()
	)
	var equipped: Dictionary = EquipmentService.new().equip_from_inventory(
		equipment,
		inventory,
		int(axe_add.get("slot", -1)),
		axe,
		GameplaySaveCatalog.SLOT_AXE
	)
	if not _require_success(equipped, "slot fixture axe equip", failures):
		return {}
	var selected: Dictionary = equipment.select_hotbar(2)
	if not _require_success(selected, "slot fixture hotbar selection", failures):
		return {}

	return {
		"context": WorldGenerationContext.new(217217),
		"delta_store": WorldDeltaStore.new(),
		"inventory": inventory,
		"equipment": equipment,
		"resume_position": Vector3(8.25, 32.0, -11.5),
	}


static func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file = null
	return text


static func _cleanup() -> void:
	for path in [
		TEST_SLOT,
		TEST_SLOT + GameSaveSlotService.CANDIDATE_SUFFIX,
		TEST_SLOT + GameSaveSlotService.BACKUP_SUFFIX,
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _require_success(
	result: Dictionary,
	label: String,
	failures: Array[String]
) -> bool:
	if bool(result.get("success", false)):
		return true
	failures.append("%s failed diagnostics=%s" % [label, result.get("diagnostics", [])])
	return false
