extends RefCounted

const WorldSettings := preload("res://world/runtime/config/world_settings.gd")
const InventoryStateCodec := preload("res://gameplay/items/inventory/inventory_state_codec.gd")
const PendingLootState := preload("res://gameplay/loot/runtime/pending_loot_state.gd")
const GameplaySaveCatalog := preload("res://gameplay/persistence/gameplay_save_catalog.gd")
const BurrowerEncounterController := preload("res://gameplay/creatures/spawning/prototype_burrower_encounter_controller.gd")

const OCCURRENCE_ID := "burrower_42"
const PROFILE_ID := "loot_profile.creature.burrower.m3"
const CHITIN_ID := "item.resource.burrower_chitin"


static func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog_result: Dictionary = GameplaySaveCatalog.build_registry()
	if not bool(catalog_result.get("success", false)):
		return ["allocator restore fixture could not build production catalog"]
	var registry = catalog_result.get("registry", null)
	var chitin = registry.get_definition(CHITIN_ID) if registry != null else null
	if chitin == null:
		return ["allocator restore fixture could not resolve Burrower chitin"]
	var pending = PendingLootState.new().configure(OCCURRENCE_ID, PROFILE_ID, [{
		"item_id": CHITIN_ID,
		"quantity": 2,
		"definition_contract": InventoryStateCodec.canonical_json(chitin.canonical_descriptor()),
	}])
	if not pending.validate_state().is_empty():
		return ["allocator restore fixture produced invalid PendingLootState"]

	var settings = WorldSettings.new()
	settings.world_seed = 2174242
	var controller = BurrowerEncounterController.new()
	controller.configure(null, null, settings)
	var anchor := Vector3(8.0, 44.0, 8.0)
	var imported: Dictionary = controller.import_pending_loot_states([pending], anchor)
	if not bool(imported.get("success", false)):
		failures.append("accepted pending-loot import rejected allocator fixture: %s" % [imported.get("diagnostics", [])])
	else:
		if controller.spawn_serial != 42:
			failures.append("restored burrower_42 did not advance encounter spawn_serial to 42")
		if controller.get_pending_loot_count() != 1:
			failures.append("allocator proof import did not retain unresolved pending loot")
		if not controller.has_pending_loot_locator(OCCURRENCE_ID):
			failures.append("allocator proof import did not install recovery locator")
		elif controller.get_pending_loot_locator(OCCURRENCE_ID) != anchor:
			failures.append("allocator proof import changed recovery anchor")
	controller.free()
	return failures
