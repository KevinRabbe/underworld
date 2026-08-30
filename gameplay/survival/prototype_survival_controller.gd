extends Node3D

signal equipped_tool_changed(tool_id: String)
signal harvest_result(event: Dictionary)

const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const InventoryTransactionPlan := preload("res://gameplay/items/inventory/inventory_transaction_plan.gd")
const InventoryTransactionService := preload("res://gameplay/items/inventory/inventory_transaction_service.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquipmentService := preload("res://gameplay/items/equipment/equipment_service.gd")
const SurfaceHarvestInventoryService := preload("res://gameplay/survival/surface_harvest_inventory_service.gd")
const GameplaySaveCatalog := preload("res://gameplay/persistence/gameplay_save_catalog.gd")

const WOOD_ID := "item.resource.wood"
const STONE_ID := "item.resource.stone"
const AXE_ID := "item.tool.stone_axe"
const PICKAXE_ID := "item.tool.stone_pickaxe"
const SLOT_HANDS := "equipment_slot.hotbar.hands"
const SLOT_AXE := "equipment_slot.hotbar.axe"
const SLOT_PICKAXE := "equipment_slot.hotbar.pickaxe"
const SLOT_UTILITY := "equipment_slot.hotbar.utility"
const INVENTORY_KEY := "survival_inventory"
const DEFAULT_INVENTORY_SLOTS := 16
const UNLIMITED_WEIGHT := -1.0

var settings
var world
var world_seed: int = 0
var player: Node3D

var object_hit_progress: Dictionary = {}
# Compatibility mirrors only. Gameplay authority is semantic inventory/equipment state.
var gathered_wood: int = 0
var gathered_stone: int = 0
var has_stone_axe: bool = false
var has_stone_pickaxe: bool = false
var selected_hotbar_slot: int = 1
var equipped_tool: String = "hands"
var last_action_message: String = "Walk over loose branches and stones"
var pickup_update_timer: float = 0.0

var _inventory_slot_capacity: int = DEFAULT_INVENTORY_SLOTS
var _inventory_max_weight: float = UNLIMITED_WEIGHT
var _inventory = null
var _equipment = null
var _equipment_service = EquipmentService.new()
var _transactions = InventoryTransactionService.new()
var _harvest_inventory = null
var _definitions: Dictionary = {}


func configure(
	world_node,
	survival_settings,
	seed: int,
	inventory_slot_capacity: int = DEFAULT_INVENTORY_SLOTS,
	inventory_max_weight: float = UNLIMITED_WEIGHT
) -> void:
	world = world_node
	settings = survival_settings
	world_seed = seed
	_inventory_slot_capacity = maxi(inventory_slot_capacity, 1)
	_inventory_max_weight = inventory_max_weight
	# SAVE-001 owns all durable file lifecycle. Survival always builds clean
	# semantic runtime here and never inspects prototype-v2 files or resets the
	# shared WorldDelta authority during gameplay construction.
	_reset_state()


func legacy_persistence_enabled() -> bool:
	return false


func set_player(player_node: Node3D) -> void:
	player = player_node
	_sync_legacy_mirrors()
	equipped_tool_changed.emit(equipped_tool)


func _process(delta: float) -> void:
	if player == null or world == null or settings == null:
		return

	pickup_update_timer -= delta
	if pickup_update_timer > 0.0:
		return

	pickup_update_timer = maxf(settings.pickup_collect_interval, 0.05)
	collect_nearby_pickups_at(player.global_position)


func try_harvest(origin: Vector3, direction: Vector3, max_distance: float) -> void:
	if player == null or world == null or direction.is_zero_approx():
		return

	var ray_end: Vector3 = origin + direction.normalized() * maxf(max_distance, 0.1)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, ray_end, 1)
	var player_collision: CollisionObject3D = player as CollisionObject3D
	if player_collision != null:
		query.exclude = [player_collision.get_rid()]

	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		last_action_message = "Miss"
		return

	var collider: Object = result.get("collider")
	if collider == null or not collider.has_meta("world_object_id"):
		last_action_message = "Nothing harvestable"
		return

	var object_chunk_variant: Variant = collider.get_meta("world_object_chunk")
	harvest_world_object(
		str(collider.get_meta("world_object_id")),
		str(collider.get_meta("world_object_type")),
		int(collider.get_meta("world_object_index")),
		object_chunk_variant as Vector2i
	)


func harvest_world_object(
	object_id: String,
	object_type: String,
	object_index: int,
	object_chunk: Vector2i
) -> Dictionary:
	if world == null or settings == null or _harvest_inventory == null:
		return _harvest_failure(["surface harvest runtime is not configured"])
	if object_id.is_empty() or world.is_world_object_destroyed(object_id):
		return _harvest_failure(["world object is already depleted: %s" % object_id])

	var required_hits: int = 0
	var yield_quantity: int = 0
	if object_type == "tree":
		required_hits = settings.tree_hits_with_axe
		yield_quantity = settings.tree_wood_yield
	elif object_type == "rock":
		required_hits = settings.rock_hits_with_pickaxe
		yield_quantity = settings.rock_stone_yield
	else:
		last_action_message = "Nothing harvestable"
		return _harvest_failure(["unsupported harvest object type: %s" % object_type])

	var eligibility: Dictionary = _harvest_inventory.tool_eligibility(object_type)
	if not bool(eligibility.get("success", false)):
		last_action_message = "Need Stone Axe for trees" if object_type == "tree" else "Need Stone Pickaxe for rocks"
		return eligibility

	var previous_hits: int = int(object_hit_progress.get(object_id, 0))
	var next_hits: int = previous_hits + 1
	if next_hits < required_hits:
		object_hit_progress[object_id] = next_hits
		last_action_message = "%s hit %d/%d" % [object_type.capitalize(), next_hits, required_hits]
		return _harvest_success({
			"object_id": object_id,
			"object_type": object_type,
			"hits": next_hits,
			"required_hits": required_hits,
			"completed": false,
			"events": [{
				"type": "harvest.hit_registered",
				"object_id": object_id,
				"object_type": object_type,
				"hits": next_hits,
				"required_hits": required_hits,
			}],
		})

	var item_id: String = _harvest_inventory.item_id_for_world_object(object_type)
	var transfer: Dictionary = _harvest_inventory.commit_yield(item_id, yield_quantity, object_id)
	if not bool(transfer.get("success", false)):
		last_action_message = "Inventory cannot accept %s yield" % object_type
		return transfer

	if not world.destroy_world_object(object_id, object_type, object_index, object_chunk):
		var rollback: Dictionary = _harvest_inventory.rollback_yield(item_id, yield_quantity, object_id)
		if not bool(rollback.get("success", false)):
			push_error("HARVEST HARD INVARIANT: world depletion failed and inventory rollback failed: %s" % [
				rollback.get("diagnostics", []),
			])
			last_action_message = "Harvest invariant failure"
			return rollback
		last_action_message = "World object changed before harvest could commit"
		return _harvest_failure(["world depletion failed after inventory transfer; yield rolled back"])

	object_hit_progress.erase(object_id)
	_sync_legacy_mirrors()
	if object_type == "tree":
		last_action_message = "Tree harvested  +%d wood" % yield_quantity
	else:
		last_action_message = "Rock harvested  +%d stone" % yield_quantity
	var event: Dictionary = {
		"type": "harvest.completed",
		"object_id": object_id,
		"object_type": object_type,
		"item_id": item_id,
		"quantity": yield_quantity,
	}
	harvest_result.emit(event)
	return _harvest_success({
		"object_id": object_id,
		"object_type": object_type,
		"item_id": item_id,
		"quantity": yield_quantity,
		"hits": required_hits,
		"required_hits": required_hits,
		"completed": true,
		"events": transfer.get("events", []).duplicate(true) + [event],
	})


func collect_nearby_pickups_at(player_world_position: Vector3) -> Dictionary:
	if world == null or settings == null or _harvest_inventory == null:
		return _harvest_failure(["surface pickup runtime is not configured"])
	if not world.has_method("find_nearby_pickups"):
		return _harvest_failure(["surface world does not expose non-mutating pickup discovery"])

	var candidates: Array = world.find_nearby_pickups(
		player_world_position,
		settings.pickup_collect_radius
	)
	var branch_count: int = 0
	var stone_count: int = 0
	var events: Array = []
	var diagnostics: Array[String] = []
	for pickup_variant in candidates:
		if not pickup_variant is Dictionary:
			continue
		var pickup: Dictionary = pickup_variant
		var object_id: String = str(pickup.get("object_id", ""))
		var object_type: String = str(pickup.get("object_type", ""))
		var object_index: int = int(pickup.get("index", -1))
		var object_chunk_variant: Variant = pickup.get("object_chunk", Vector2i.ZERO)
		var object_chunk: Vector2i = object_chunk_variant as Vector2i
		var item_id: String = _harvest_inventory.item_id_for_world_object(object_type)
		if item_id.is_empty() or object_id.is_empty():
			continue
		if world.is_world_object_destroyed(object_id):
			continue

		var transfer: Dictionary = _harvest_inventory.commit_yield(item_id, 1, object_id)
		if not bool(transfer.get("success", false)):
			for diagnostic in transfer.get("diagnostics", []):
				diagnostics.append(str(diagnostic))
			continue
		if not world.destroy_world_object(object_id, object_type, object_index, object_chunk):
			var rollback: Dictionary = _harvest_inventory.rollback_yield(item_id, 1, object_id)
			if not bool(rollback.get("success", false)):
				push_error("HARVEST HARD INVARIANT: pickup consume failed and inventory rollback failed: %s" % [
					rollback.get("diagnostics", []),
				])
				return rollback
			diagnostics.append("pickup world consumption failed after transfer; yield rolled back: %s" % object_id)
			continue

		if object_type == "branch":
			branch_count += 1
		elif object_type == "loose_stone":
			stone_count += 1
		var event: Dictionary = {
			"type": "harvest.pickup_collected",
			"object_id": object_id,
			"object_type": object_type,
			"item_id": item_id,
			"quantity": 1,
		}
		events.append(event)
		harvest_result.emit(event)

	if branch_count == 0 and stone_count == 0:
		return {
			"success": diagnostics.is_empty(),
			"diagnostics": diagnostics,
			"events": events,
			"wood": 0,
			"stone": 0,
		}

	_sync_legacy_mirrors()
	if branch_count > 0 and stone_count > 0:
		last_action_message = "Picked up %d wood + %d stone" % [branch_count, stone_count]
	elif branch_count > 0:
		last_action_message = "Picked up %d wood" % branch_count
	else:
		last_action_message = "Picked up %d stone" % stone_count
	return {
		"success": diagnostics.is_empty(),
		"diagnostics": diagnostics,
		"events": events,
		"wood": branch_count,
		"stone": stone_count,
	}


func select_hotbar_slot(slot: int) -> void:
	if _equipment == null or slot < 1 or slot > 4:
		return
	var selection: Dictionary = _equipment.select_hotbar(slot)
	if not bool(selection.get("success", false)):
		return
	_sync_legacy_mirrors()
	if equipped_tool == "hands":
		last_action_message = "Hands equipped"
	elif equipped_tool == "stone_axe":
		last_action_message = "Stone Axe equipped"
	elif equipped_tool == "stone_pickaxe":
		last_action_message = "Stone Pickaxe equipped"
	else:
		last_action_message = "Equipment selected"
	equipped_tool_changed.emit(equipped_tool)


func request_craft(recipe_id: String) -> void:
	# Temporary compatibility bridge for the existing C/V prototype controls.
	# Recipe rulebook ownership remains CRAFT-001; this path only preserves current playability.
	_sync_legacy_mirrors()
	var tool_id: String = ""
	var target_slot: String = ""
	var target_hotbar: int = 1
	var wood_cost: int = 0
	var stone_cost: int = 0
	if recipe_id == "stone_axe":
		tool_id = AXE_ID
		target_slot = SLOT_AXE
		target_hotbar = 2
		wood_cost = settings.stone_axe_wood_cost
		stone_cost = settings.stone_axe_stone_cost
	elif recipe_id == "stone_pickaxe":
		tool_id = PICKAXE_ID
		target_slot = SLOT_PICKAXE
		target_hotbar = 3
		wood_cost = settings.stone_pickaxe_wood_cost
		stone_cost = settings.stone_pickaxe_stone_cost
	else:
		return

	if has_tool(recipe_id):
		last_action_message = "%s already crafted" % ["Stone Axe" if recipe_id == "stone_axe" else "Stone Pickaxe"]
		return
	if gathered_wood < wood_cost or gathered_stone < stone_cost:
		last_action_message = "%s needs %d wood + %d stone" % [
			"Axe" if recipe_id == "stone_axe" else "Pickaxe",
			wood_cost,
			stone_cost,
		]
		return

	var wood_definition = _definitions.get(WOOD_ID, null)
	var stone_definition = _definitions.get(STONE_ID, null)
	var tool_definition = _definitions.get(tool_id, null)
	if (
		wood_definition == null or not wood_definition is ItemDefinition
		or stone_definition == null or not stone_definition is ItemDefinition
		or tool_definition == null or not tool_definition is ItemDefinition
	):
		last_action_message = "Craft content unavailable"
		return
	var plan = InventoryTransactionPlan.new().bind_container(INVENTORY_KEY, _inventory)
	plan.remove_stack(INVENTORY_KEY, wood_definition, wood_cost)
	plan.remove_stack(INVENTORY_KEY, stone_definition, stone_cost)
	plan.add_instance(INVENTORY_KEY, tool_definition)
	var crafted: Dictionary = _transactions.commit(plan)
	if not bool(crafted.get("success", false)):
		last_action_message = "%s" % [crafted.get("diagnostics", [])]
		return

	var tool_slot: int = _find_inventory_instance_slot(tool_id)
	if tool_slot < 0:
		last_action_message = "Crafted tool could not be resolved in inventory"
		return
	var equipped: Dictionary = _equipment_service.equip_from_inventory(
		_equipment,
		_inventory,
		tool_slot,
		tool_definition,
		target_slot
	)
	if not bool(equipped.get("success", false)):
		last_action_message = "Crafted tool remains in inventory"
		_sync_legacy_mirrors()
		return
	_equipment.select_hotbar(target_hotbar)
	_sync_legacy_mirrors()
	last_action_message = "Crafted Stone Axe" if recipe_id == "stone_axe" else "Crafted Stone Pickaxe"
	equipped_tool_changed.emit(equipped_tool)


func get_resource_counts() -> Vector2i:
	_sync_legacy_mirrors()
	return Vector2i(gathered_wood, gathered_stone)


func get_last_harvest_message() -> String:
	return last_action_message


func get_last_action_message() -> String:
	return last_action_message


func get_equipped_tool() -> String:
	_sync_legacy_mirrors()
	return equipped_tool


func get_selected_hotbar_slot() -> int:
	_sync_legacy_mirrors()
	return selected_hotbar_slot


func has_tool(tool_id: String) -> bool:
	if tool_id == "hands":
		return true
	var semantic_id: String = AXE_ID if tool_id == "stone_axe" else PICKAXE_ID if tool_id == "stone_pickaxe" else ""
	if semantic_id.is_empty() or _inventory == null or _equipment == null:
		return false
	if _inventory.quantity_of(semantic_id) > 0:
		return true
	var slot_key: String = SLOT_AXE if semantic_id == AXE_ID else SLOT_PICKAXE
	var definition = _equipment.definition_at(slot_key)
	return definition != null and definition is ItemDefinition and str(definition.content_id) == semantic_id


func get_crafting_cost(recipe_id: String) -> Vector2i:
	if recipe_id == "stone_axe":
		return Vector2i(settings.stone_axe_wood_cost, settings.stone_axe_stone_cost)
	if recipe_id == "stone_pickaxe":
		return Vector2i(settings.stone_pickaxe_wood_cost, settings.stone_pickaxe_stone_cost)
	return Vector2i.ZERO


func get_inventory_state():
	return _inventory


func get_equipment_state():
	return _equipment


func get_item_definition(item_id: String):
	return _definitions.get(item_id, null)


func get_object_hit_progress(object_id: String) -> int:
	return int(object_hit_progress.get(object_id, 0))


func _reset_state() -> void:
	object_hit_progress.clear()
	last_action_message = "Walk over loose branches and stones"
	_configure_semantic_runtime()
	_sync_legacy_mirrors()


func _configure_semantic_runtime() -> void:
	_definitions.clear()
	var catalog_result: Dictionary = GameplaySaveCatalog.build_registry()
	if not bool(catalog_result.get("success", false)):
		push_error("Survival durable gameplay catalog failed: %s" % [catalog_result.get("diagnostics", [])])
	else:
		var registry = catalog_result.get("registry", null)
		if registry != null:
			for content_id in registry.definition_ids():
				var definition = registry.get_definition(content_id)
				if definition != null and definition is ItemDefinition:
					_definitions[content_id] = definition

	_inventory = ItemContainerState.new().configure(_inventory_slot_capacity, _inventory_max_weight)
	_equipment = EquipmentHotbarState.new().configure(
		GameplaySaveCatalog.equipment_rules(),
		GameplaySaveCatalog.hotbar_bindings()
	)
	_equipment.select_hotbar(1)
	_harvest_inventory = SurfaceHarvestInventoryService.new().configure(
		_inventory,
		_equipment,
		_definitions.values()
	)


func _find_inventory_instance_slot(item_id: String) -> int:
	if _inventory == null:
		return -1
	for index in range(_inventory.slot_capacity()):
		var record: Dictionary = _inventory.state_at(index)
		if str(record.get("kind", "")) != "instance":
			continue
		if str(record.get("state", {}).get("item_id", "")) == item_id:
			return index
	return -1


func _sync_legacy_mirrors() -> void:
	if _harvest_inventory == null or _inventory == null or _equipment == null:
		gathered_wood = 0
		gathered_stone = 0
		has_stone_axe = false
		has_stone_pickaxe = false
		selected_hotbar_slot = 1
		equipped_tool = "hands"
		return
	var counts: Vector2i = _harvest_inventory.resource_counts()
	gathered_wood = counts.x
	gathered_stone = counts.y
	has_stone_axe = has_tool("stone_axe")
	has_stone_pickaxe = has_tool("stone_pickaxe")
	selected_hotbar_slot = _equipment.selected_hotbar()
	var selected: Dictionary = _harvest_inventory.selected_descriptor()
	var item_id: String = str(selected.get("item_id", ""))
	if item_id == AXE_ID:
		equipped_tool = "stone_axe"
	elif item_id == PICKAXE_ID:
		equipped_tool = "stone_pickaxe"
	else:
		equipped_tool = "hands"


static func _harvest_failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {"success": false, "diagnostics": diagnostics, "events": []}


static func _harvest_success(extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"success": true, "diagnostics": [], "events": []}
	for key in extra.keys():
		result[key] = extra[key]
	return result
