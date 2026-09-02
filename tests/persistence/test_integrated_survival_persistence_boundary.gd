extends RefCounted

const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquipmentService := preload("res://gameplay/items/equipment/equipment_service.gd")
const GameplaySaveCatalog := preload("res://gameplay/persistence/gameplay_save_catalog.gd")
const IntegratedSurvivalController := preload("res://gameplay/survival/integrated_survival_controller.gd")

const TEST_SEED := 217991
const LEGACY_PATH := "user://underworld_seed_%d.json" % TEST_SEED
const WOOD_ID := "item.resource.wood"
const AXE_ID := "item.tool.stone_axe"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_cleanup()
	_test_integrated_startup_ignores_and_never_writes_legacy_v2(failures)
	_test_detached_state_activation(failures)
	_cleanup()
	return failures


static func _test_integrated_startup_ignores_and_never_writes_legacy_v2(
	failures: Array[String]
) -> void:
	var legacy_text := '{"version":2,"world_seed":%d,"destroyed_objects":[],"wood":9,"stone":8,"stone_axe":true,"stone_pickaxe":true,"selected_slot":3}' % TEST_SEED
	var file: FileAccess = FileAccess.open(LEGACY_PATH, FileAccess.WRITE)
	if file == null:
		failures.append("integrated survival legacy fixture could not be written")
		return
	file.store_string(legacy_text)
	file.flush()
	file = null

	var controller = IntegratedSurvivalController.new()
	controller.configure_integrated(null, RefCounted.new(), TEST_SEED)
	if controller.legacy_persistence_enabled():
		failures.append("integrated survival reports legacy persistence enabled")
	var inventory = controller.get_inventory_state()
	if inventory == null or inventory.quantity_of(WOOD_ID) != 0:
		failures.append("integrated survival activated stale legacy-v2 inventory during startup")
	if controller.has_tool("stone_axe") or controller.has_tool("stone_pickaxe"):
		failures.append("integrated survival activated stale legacy-v2 equipment during startup")

	# Hotbar selection is one of the inherited normal mutation paths that used to
	# call the prototype _save_state(). The integrated override must leave the old
	# file byte-identical rather than silently dual-writing it.
	controller.select_hotbar_slot(1)
	var after: String = _read_text(LEGACY_PATH)
	if after != legacy_text:
		failures.append("integrated hotbar mutation wrote or altered prototype-v2 save data")
	controller.free()


static func _test_detached_state_activation(failures: Array[String]) -> void:
	var catalog_result: Dictionary = GameplaySaveCatalog.build_registry()
	if not _require_success(catalog_result, "integrated survival registry", failures):
		return
	var registry = catalog_result.get("registry", null)
	var wood = registry.get_definition(WOOD_ID)
	var axe = registry.get_definition(AXE_ID)
	if wood == null or axe == null:
		failures.append("integrated survival restore fixture lacks production definitions")
		return

	var inventory = ItemContainerState.new().configure(8, 100.0)
	if not _require_success(
		inventory.add_stack(wood, 4, {"batch": 4}),
		"integrated survival wood fixture",
		failures
	):
		return
	var axe_add: Dictionary = inventory.add_instance(axe, {"durability": 66})
	if not _require_success(axe_add, "integrated survival axe fixture", failures):
		return
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
	if not _require_success(equipped, "integrated survival equip fixture", failures):
		return
	if not _require_success(
		equipment.select_hotbar(2),
		"integrated survival selection fixture",
		failures
	):
		return

	var inventory_before: String = inventory.canonical_json()
	var equipment_before: Dictionary = equipment.canonical_snapshot()
	var controller = IntegratedSurvivalController.new()
	controller.configure_integrated(null, RefCounted.new(), TEST_SEED + 1)
	var restore_failures: Array[String] = controller.activate_restored_state(inventory, equipment)
	if not restore_failures.is_empty():
		failures.append("integrated survival rejected detached restored state: %s" % [restore_failures])
		controller.free()
		return
	if controller.get_inventory_state().canonical_json() != inventory_before:
		failures.append("integrated survival activation changed restored inventory")
	if controller.get_equipment_state().canonical_snapshot() != equipment_before:
		failures.append("integrated survival activation changed restored equipment")
	if controller.get_selected_hotbar_slot() != 2:
		failures.append("integrated survival activation lost selected hotbar")
	if controller.get_equipped_tool() != "stone_axe":
		failures.append("integrated survival activation did not resolve selected semantic tool")
	controller.free()


static func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file = null
	return text


static func _cleanup() -> void:
	if FileAccess.file_exists(LEGACY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_PATH))


static func _require_success(
	result: Dictionary,
	label: String,
	failures: Array[String]
) -> bool:
	if bool(result.get("success", false)):
		return true
	failures.append("%s failed diagnostics=%s" % [label, result.get("diagnostics", [])])
	return false
