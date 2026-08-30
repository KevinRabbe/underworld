extends RefCounted

const GAME_SCENE_PATH := "res://app/game/game.tscn"
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

const TEST_SEED: int = 2174242
const WOOD_ID := "item.resource.wood"
const AXE_ID := "item.tool.stone_axe"
const CHITIN_ID := "item.resource.burrower_chitin"
const PROFILE_ID := "loot_profile.creature.burrower.m3"


static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var fixture: Dictionary = _fixture(failures)
	if fixture.is_empty():
		return failures

	var packed = ResourceLoader.load(GAME_SCENE_PATH)
	if packed == null or not packed is PackedScene:
		failures.append("integrated SAVE runtime proof could not load game.tscn")
		return failures
	var game: Node = packed.instantiate()
	if game == null:
		failures.append("integrated SAVE runtime proof could not instantiate Game")
		return failures
	game.set("enable_debug_hud", false)

	var candidate: Dictionary = fixture["candidate"]
	var expected_delta: Dictionary = fixture["delta_store"].snapshot()
	var expected_inventory: String = fixture["inventory"].canonical_json()
	var expected_equipment: Dictionary = fixture["equipment"].canonical_snapshot()
	var expected_pending: Dictionary = fixture["pending_loot"].canonical_snapshot()
	var expected_resume: Vector3 = fixture["resume_position"]
	var stable_id: String = fixture["stable_id"]

	if not bool(game.call("prepare_continue", candidate)):
		failures.append("real Game rejected valid detached Continue candidate")
		game.free()
		return failures
	if game.is_inside_tree():
		failures.append("Game entered SceneTree during prepare_continue")

	# Deliberately mutate every caller-owned mutable component after preparation.
	# Live runtime must still realize the owned clone captured by Game.
	fixture["delta_store"].set_object_state(stable_id, {
		"schema": "mutated.after.prepare",
		"remaining_capacity_units": 999.0,
	})
	var wood = fixture["registry"].get_definition(WOOD_ID)
	fixture["inventory"].add_stack(wood, 1)
	fixture["equipment"].select_hotbar(1)
	fixture["pending_loot"].consume_after_commit()
	candidate["resume_position"] = Vector3(999.0, 999.0, 999.0)

	tree.root.add_child(game)

	if str(game.call("startup_mode")) != "continue":
		failures.append("real Game did not retain Continue startup mode")
	var live_store = game.get("world_delta_store")
	if live_store == null or live_store.snapshot() != expected_delta:
		failures.append("real Game Continue activation changed or aliased WorldDelta state")
	elif live_store == fixture["delta_store"]:
		failures.append("real Game retained caller-owned WorldDeltaStore instance")

	var survival = game.get("survival")
	if survival == null:
		failures.append("real Game Continue activation did not create Survival")
	else:
		var live_inventory = survival.get_inventory_state()
		var live_equipment = survival.get_equipment_state()
		if live_inventory == null or live_inventory.canonical_json() != expected_inventory:
			failures.append("real Game Continue activation changed or aliased inventory")
		elif live_inventory == fixture["inventory"]:
			failures.append("real Game retained caller-owned inventory instance")
		if live_equipment == null or live_equipment.canonical_snapshot() != expected_equipment:
			failures.append("real Game Continue activation changed or aliased equipment")
		elif live_equipment == fixture["equipment"]:
			failures.append("real Game retained caller-owned equipment instance")
		if live_equipment != null and live_equipment.selected_hotbar() != 4:
			failures.append("real Game Continue activation lost selected hotbar slot 4")

	var live_pending = game.call("restored_pending_loot_state")
	if live_pending == null or live_pending.canonical_snapshot() != expected_pending:
		failures.append("real Game Continue activation changed or aliased pending loot")
	elif live_pending == fixture["pending_loot"]:
		failures.append("real Game retained caller-owned pending-loot instance")

	var player = game.get("player")
	if player == null or player.global_position != expected_resume:
		failures.append("real Game Continue activation did not restore exact safe Player resume position")
	if int(game.get("world_settings").world_seed) != TEST_SEED:
		failures.append("real Game Continue activation changed world seed")

	game.queue_free()
	await tree.process_frame
	return failures


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
	if not _require_success(
		inventory.add_stack(wood, 7, {"batch": "runtime"}),
		"runtime SAVE wood fixture",
		failures
	):
		return {}
	var axe_add: Dictionary = inventory.add_instance(axe, {"durability": 73})
	if not _require_success(axe_add, "runtime SAVE axe fixture", failures):
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
			GameplaySaveCatalog.SLOT_UTILITY
		),
		"runtime SAVE utility equip",
		failures
	):
		return {}
	if not _require_success(
		equipment.select_hotbar(4),
		"runtime SAVE hotbar-4 fixture",
		failures
	):
		return {}

	var context = WorldGenerationContext.new(TEST_SEED)
	var delta_store = WorldDeltaStore.new()
	var address = StableAddress.generated_child(
		StableAddress.underground_region(0, 0),
		"save-runtime-fixture",
		0
	)
	var stable_id: String = StableId.from_address(address).value()
	if not delta_store.set_object_state(stable_id, {
		"schema": "resource.runtime.depletion.v1",
		"remaining_capacity_units": 3.0,
		"completed_operation_ids": ["operation.save-runtime"],
	}):
		failures.append("runtime SAVE fixture could not install WorldDelta state")
		return {}

	var definition_contract: String = InventoryStateCodec.canonical_json(
		chitin.canonical_descriptor()
	)
	var pending = PendingLootState.new().configure(
		"burrower_42",
		PROFILE_ID,
		[{
			"item_id": CHITIN_ID,
			"quantity": 2,
			"definition_contract": definition_contract,
		}]
	)
	if not pending.validate_state().is_empty():
		failures.append("runtime SAVE fixture pending loot is invalid")
		return {}

	# Keep X/Z close to the current initial surface bootstrap while still proving
	# exact Y restoration. A later accepted streaming card may move chunk policy;
	# SAVE owns only the durable resume coordinate.
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
			"pending_loot_state": pending,
			"resume_position": resume_position,
		},
	}


static func _require_success(
	result: Dictionary,
	label: String,
	failures: Array[String]
) -> bool:
	if bool(result.get("success", false)):
		return true
	failures.append("%s failed diagnostics=%s" % [label, result.get("diagnostics", [])])
	return false
