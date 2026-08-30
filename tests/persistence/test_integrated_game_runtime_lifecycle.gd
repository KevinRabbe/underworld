extends RefCounted

const GAME_SCENE_PATH := "res://app/game/game.tscn"
const TEST_SLOT := "user://save_001_runtime_lifecycle.json"
const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const InventoryStateCodec := preload("res://gameplay/items/inventory/inventory_state_codec.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquipmentService := preload("res://gameplay/items/equipment/equipment_service.gd")
const PendingLootState := preload("res://gameplay/loot/runtime/pending_loot_state.gd")
const GameplaySaveCatalog := preload("res://gameplay/persistence/gameplay_save_catalog.gd")
const GameSaveSlotService := preload("res://gameplay/persistence/game_save_slot_service.gd")

const TEST_SEED: int = 2174242
const WOOD_ID := "item.resource.wood"
const AXE_ID := "item.tool.stone_axe"
const CHITIN_ID := "item.resource.burrower_chitin"
const PROFILE_ID := "loot_profile.creature.burrower.m3"
const OCCURRENCE_ID := "burrower_42"


static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_cleanup_slot()
	var fixture: Dictionary = _fixture(failures)
	if fixture.is_empty():
		return failures
	var packed = ResourceLoader.load(GAME_SCENE_PATH)
	if packed == null or not packed is PackedScene:
		return ["integrated SAVE runtime proof could not load game.tscn"]

	var expected_delta: Dictionary = fixture["delta_store"].snapshot()
	var expected_inventory: String = fixture["inventory"].canonical_json()
	var expected_equipment: Dictionary = fixture["equipment"].canonical_snapshot()
	var expected_pending: Dictionary = fixture["pending_loot"].canonical_snapshot()
	var expected_resume: Vector3 = fixture["resume_position"]
	var stable_id: String = fixture["stable_id"]

	var game: Node = packed.instantiate()
	game.set("enable_debug_hud", false)
	var candidate: Dictionary = fixture["candidate"]
	if not bool(game.call("prepare_continue", candidate)):
		failures.append("real Game rejected valid detached Continue candidate")
		game.free()
		_cleanup_slot()
		return failures
	if game.is_inside_tree():
		failures.append("Game entered SceneTree during prepare_continue")

	# Mutate every caller-owned component after preparation; Game must activate its
	# strict deep-owned clone instead of observing these changes.
	fixture["delta_store"].set_object_state(stable_id, {
		"schema": "mutated.after.prepare",
		"remaining_capacity_units": 999.0,
	})
	var wood = fixture["registry"].get_definition(WOOD_ID)
	fixture["inventory"].add_stack(wood, 1)
	fixture["equipment"].select_hotbar(1)
	fixture["pending_loot"].consume_after_commit()
	candidate["resume_position"] = Vector3(999.0, 999.0, 999.0)
	candidate["pending_loot_states"] = []

	tree.root.add_child(game)
	_verify_live_runtime(
		game,
		expected_delta,
		expected_inventory,
		expected_equipment,
		expected_pending,
		expected_resume,
		failures
	)

	# Production snapshot -> atomic slot -> teardown -> detached load -> Continue.
	var request_variant: Variant = game.call("build_save_request")
	if not request_variant is Dictionary or not bool(request_variant.get("success", false)):
		failures.append("live Game could not build production SAVE request: %s" % [
		request_variant.get("diagnostics", []) if request_variant is Dictionary else [],
		])
		game.queue_free()
		await tree.process_frame
		_cleanup_slot()
		return failures
	var request: Dictionary = request_variant
	var request_pending: Variant = request.get("pending_loot_states", null)
	if not request_pending is Array or request_pending.size() != 1:
		failures.append("live Game snapshot did not capture complete pending-loot set")
	elif request_pending[0].canonical_snapshot() != expected_pending:
		failures.append("live Game snapshot changed restored pending-loot state")

	var service = GameSaveSlotService.new()
	var saved: Dictionary = service.save_slot(
		request.get("context", null),
		request.get("delta_store", null),
		request.get("inventory_state", null),
		request.get("equipment_state", null),
		request.get("pending_loot_states", []),
		request.get("resume_position", Vector3.ZERO),
		TEST_SLOT
	)
	if not _require_success(saved, "live runtime atomic SAVE", failures):
		game.queue_free()
		await tree.process_frame
		_cleanup_slot()
		return failures
	var loaded: Dictionary = service.load_slot(TEST_SLOT)
	if not _require_success(loaded, "live runtime slot reload", failures):
		game.queue_free()
		await tree.process_frame
		_cleanup_slot()
		return failures
	var loaded_candidate_variant: Variant = loaded.get("candidate", null)
	if not loaded_candidate_variant is Dictionary:
		failures.append("live runtime slot reload did not return detached candidate")
		game.queue_free()
		await tree.process_frame
		_cleanup_slot()
		return failures
	var loaded_candidate: Dictionary = loaded_candidate_variant

	game.queue_free()
	await tree.process_frame

	var resumed: Node = packed.instantiate()
	resumed.set("enable_debug_hud", false)
	if not bool(resumed.call("prepare_continue", loaded_candidate)):
		failures.append("recreated Game rejected atomically loaded Continue candidate")
		resumed.free()
		_cleanup_slot()
		return failures
	# Mutating the loaded candidate after preparation must also not alias Game 2.
	loaded_candidate["resume_position"] = Vector3(-999.0, -999.0, -999.0)
	var loaded_pending: Array = loaded_candidate.get("pending_loot_states", [])
	if not loaded_pending.is_empty():
		loaded_pending[0].consume_after_commit()
	tree.root.add_child(resumed)
	_verify_live_runtime(
		resumed,
		expected_delta,
		expected_inventory,
		expected_equipment,
		expected_pending,
		expected_resume,
		failures
	)

	var survival = resumed.get("survival")
	var encounter = resumed.get("encounter_controller")
	if survival != null and encounter != null:
		var live_inventory = survival.get_inventory_state()
		var before_chitin: int = live_inventory.quantity_of(CHITIN_ID)
		var collected: Dictionary = encounter.collect_nearby_pending_loot(live_inventory)
		if not bool(collected.get("success", false)):
			failures.append("restored pending loot was not reachable through accepted proximity route: %s" % [collected.get("diagnostics", [])])
		var after_chitin: int = live_inventory.quantity_of(CHITIN_ID)
		if after_chitin != before_chitin + 2:
			failures.append("restored pending loot did not award exact chitin quantity once")
		if encounter.get_pending_loot_count() != 0:
			failures.append("successful restored loot collection did not clear pending authority")
		if encounter.has_pending_loot_locator(OCCURRENCE_ID):
			failures.append("successful restored loot collection did not clear transient locator")
		var duplicate: Dictionary = encounter.collect_pending_loot(OCCURRENCE_ID, live_inventory)
		if bool(duplicate.get("success", false)):
			failures.append("restored pending loot could be collected twice")
		if live_inventory.quantity_of(CHITIN_ID) != after_chitin:
			failures.append("duplicate restored loot collection changed inventory")
		var after_request: Dictionary = resumed.call("build_save_request")
		if not bool(after_request.get("success", false)):
			failures.append("post-collection Game SAVE snapshot failed")
		elif not after_request.get("pending_loot_states", ["sentinel"]).is_empty():
			failures.append("post-collection SAVE snapshot retained consumed pending loot")

	resumed.queue_free()
	await tree.process_frame
	_cleanup_slot()
	return failures


static func _verify_live_runtime(
	game: Node,
	expected_delta: Dictionary,
	expected_inventory: String,
	expected_equipment: Dictionary,
	expected_pending: Dictionary,
	expected_resume: Vector3,
	failures: Array[String]
) -> void:
	if str(game.call("startup_mode")) != "continue":
		failures.append("real Game did not retain Continue startup mode")
	var live_store = game.get("world_delta_store")
	if live_store == null or live_store.snapshot() != expected_delta:
		failures.append("real Game Continue activation changed WorldDelta state")
	var survival = game.get("survival")
	if survival == null:
		failures.append("real Game Continue activation did not create Survival")
	else:
		var live_inventory = survival.get_inventory_state()
		var live_equipment = survival.get_equipment_state()
		if live_inventory == null or live_inventory.canonical_json() != expected_inventory:
			failures.append("real Game Continue activation changed inventory")
		if live_equipment == null or live_equipment.canonical_snapshot() != expected_equipment:
			failures.append("real Game Continue activation changed equipment")
		elif live_equipment.selected_hotbar() != 4:
			failures.append("real Game Continue activation lost selected hotbar slot 4")
	var encounter = game.get("encounter_controller")
	if encounter == null:
		failures.append("real Game Continue activation did not create encounter controller")
	else:
		if encounter.get_pending_loot_count() != 1:
			failures.append("real Game Continue activation did not restore pending loot into runtime authority")
		if encounter.get_pending_loot_snapshot(OCCURRENCE_ID) != expected_pending:
			failures.append("real Game Continue activation changed pending-loot snapshot")
		if not encounter.has_pending_loot_locator(OCCURRENCE_ID):
			failures.append("real Game Continue activation did not restore pending-loot recovery locator")
		elif encounter.get_pending_loot_locator(OCCURRENCE_ID) != expected_resume:
			failures.append("real Game Continue activation changed pending-loot recovery anchor")
	var player = game.get("player")
	if player == null or player.global_position != expected_resume:
		failures.append("real Game Continue activation did not restore exact safe Player resume position")
	if int(game.get("world_settings").world_seed) != TEST_SEED:
		failures.append("real Game Continue activation changed world seed")


static func _fixture(failures: Array[String]) -> Dictionary:
	var catalog_result: Dictionary = GameplaySaveCatalog.build_registry()
	if not _require_success(catalog_result, "runtime SAVE catalog", failures):
		return {}
	var registry = catalog_result.get("registry", null)
	var wood = registry.get_definition(WOOD_ID)
	var axe = registry.get_definition(AXE_ID)
	var chitin = registry.get_definition(CHITIN_ID)
	if wood == null or axe == null or chitin == null:
		failures.append("runtime SAVE fixture is missing production item definitions")
		return {}
	var inventory = ItemContainerState.new().configure(8, 100.0)
	if not _require_success(inventory.add_stack(wood, 7, {"batch": "runtime"}), "runtime SAVE wood fixture", failures):
		return {}
	var axe_add: Dictionary = inventory.add_instance(axe, {"durability": 73})
	if not _require_success(axe_add, "runtime SAVE axe fixture", failures):
		return {}
	var equipment = EquipmentHotbarState.new().configure(GameplaySaveCatalog.equipment_rules(), GameplaySaveCatalog.hotbar_bindings())
	if not _require_success(
		EquipmentService.new().equip_from_inventory(equipment, inventory, int(axe_add.get("slot", -1)), axe, GameplaySaveCatalog.SLOT_UTILITY),
		"runtime SAVE utility equip",
		failures
	):
		return {}
	if not _require_success(equipment.select_hotbar(4), "runtime SAVE hotbar-4 fixture", failures):
		return {}
	var context = WorldGenerationContext.new(TEST_SEED)
	var delta_store = WorldDeltaStore.new()
	var address = StableAddress.generated_child(StableAddress.underground_region(0, 0), "save-runtime-fixture", 0)
	var stable_id: String = StableId.from_address(address).value()
	if not delta_store.set_object_state(stable_id, {
		"schema": "resource.runtime.depletion.v1",
		"remaining_capacity_units": 3.0,
		"completed_operation_ids": ["operation.save-runtime"],
	}):
		failures.append("runtime SAVE fixture could not install WorldDelta state")
		return {}
	var definition_contract: String = InventoryStateCodec.canonical_json(chitin.canonical_descriptor())
	var pending = PendingLootState.new().configure(OCCURRENCE_ID, PROFILE_ID, [{
		"item_id": CHITIN_ID,
		"quantity": 2,
		"definition_contract": definition_contract,
	}])
	if not pending.validate_state().is_empty():
		failures.append("runtime SAVE fixture pending loot is invalid")
		return {}
	var resume_position := Vector3(8.0, 44.0, 8.0)
	return {
		"registry": registry,
		"delta_store": delta_store,
		"inventory": inventory,
		"equipment": equipment,
		"pending_loot": pending,
		"resume_position": resume_position,
		"stable_id": stable_id,
		"candidate": {
			"world_context": context,
			"world_seed": TEST_SEED,
			"world_id": context.world_id,
			"delta_store": delta_store,
			"inventory_state": inventory,
			"equipment_state": equipment,
			"pending_loot_states": [pending],
			"resume_position": resume_position,
		},
	}


static func _cleanup_slot() -> void:
	for path in [
		TEST_SLOT,
		TEST_SLOT + GameSaveSlotService.CANDIDATE_SUFFIX,
		TEST_SLOT + GameSaveSlotService.BACKUP_SUFFIX,
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _require_success(result: Dictionary, label: String, failures: Array[String]) -> bool:
	if bool(result.get("success", false)):
		return true
	failures.append("%s failed diagnostics=%s" % [label, result.get("diagnostics", [])])
	return false
