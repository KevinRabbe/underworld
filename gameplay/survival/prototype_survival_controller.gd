extends Node3D

signal equipped_tool_changed(tool_id: String)

var settings
var world
var world_seed: int = 0
var player: Node3D

var object_hit_progress: Dictionary = {}
var gathered_wood: int = 0
var gathered_stone: int = 0
var has_stone_axe: bool = false
var has_stone_pickaxe: bool = false
var selected_hotbar_slot: int = 1
var equipped_tool: String = "hands"
var last_action_message: String = "Walk over loose branches and stones"
var pickup_update_timer: float = 0.0


func configure(world_node, survival_settings, seed: int) -> void:
	world = world_node
	settings = survival_settings
	world_seed = seed
	_load_state()


func set_player(player_node: Node3D) -> void:
	player = player_node
	equipped_tool_changed.emit(equipped_tool)


func _process(delta: float) -> void:
	if player == null or world == null or settings == null:
		return

	pickup_update_timer -= delta
	if pickup_update_timer > 0.0:
		return

	pickup_update_timer = maxf(settings.pickup_collect_interval, 0.05)
	_collect_nearby_pickups()


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

	var object_id: String = str(collider.get_meta("world_object_id"))
	if world.is_world_object_destroyed(object_id):
		return

	var object_type: String = str(collider.get_meta("world_object_type"))
	var object_index: int = int(collider.get_meta("world_object_index"))
	var object_chunk_variant: Variant = collider.get_meta("world_object_chunk")
	var object_chunk: Vector2i = object_chunk_variant as Vector2i

	var required_hits: int = 0
	if object_type == "tree":
		if equipped_tool != "stone_axe":
			last_action_message = "Need Stone Axe for trees"
			return
		required_hits = settings.tree_hits_with_axe
	elif object_type == "rock":
		if equipped_tool != "stone_pickaxe":
			last_action_message = "Need Stone Pickaxe for rocks"
			return
		required_hits = settings.rock_hits_with_pickaxe
	else:
		last_action_message = "Nothing harvestable"
		return

	var current_hits: int = int(object_hit_progress.get(object_id, 0)) + 1
	if current_hits < required_hits:
		object_hit_progress[object_id] = current_hits
		last_action_message = "%s hit %d/%d" % [
			object_type.capitalize(), current_hits, required_hits
		]
		return

	object_hit_progress.erase(object_id)
	if not world.destroy_world_object(object_id, object_type, object_index, object_chunk):
		return

	if object_type == "tree":
		gathered_wood += settings.tree_wood_yield
		last_action_message = "Tree harvested  +%d wood" % settings.tree_wood_yield
	else:
		gathered_stone += settings.rock_stone_yield
		last_action_message = "Rock harvested  +%d stone" % settings.rock_stone_yield

	_save_state()


func select_hotbar_slot(slot: int) -> void:
	match slot:
		1:
			selected_hotbar_slot = 1
			equipped_tool = "hands"
			last_action_message = "Hands equipped"
		2:
			if not has_stone_axe:
				last_action_message = "Stone Axe not crafted — press C"
				return
			selected_hotbar_slot = 2
			equipped_tool = "stone_axe"
			last_action_message = "Stone Axe equipped"
		3:
			if not has_stone_pickaxe:
				last_action_message = "Stone Pickaxe not crafted — press V"
				return
			selected_hotbar_slot = 3
			equipped_tool = "stone_pickaxe"
			last_action_message = "Stone Pickaxe equipped"
		_:
			return

	equipped_tool_changed.emit(equipped_tool)
	_save_state()


func request_craft(recipe_id: String) -> void:
	if recipe_id == "stone_axe":
		if has_stone_axe:
			last_action_message = "Stone Axe already crafted"
			return
		if gathered_wood < settings.stone_axe_wood_cost or gathered_stone < settings.stone_axe_stone_cost:
			last_action_message = "Axe needs %d wood + %d stone" % [
				settings.stone_axe_wood_cost, settings.stone_axe_stone_cost
			]
			return
		gathered_wood -= settings.stone_axe_wood_cost
		gathered_stone -= settings.stone_axe_stone_cost
		has_stone_axe = true
		selected_hotbar_slot = 2
		equipped_tool = "stone_axe"
		last_action_message = "Crafted Stone Axe"
	elif recipe_id == "stone_pickaxe":
		if has_stone_pickaxe:
			last_action_message = "Stone Pickaxe already crafted"
			return
		if gathered_wood < settings.stone_pickaxe_wood_cost or gathered_stone < settings.stone_pickaxe_stone_cost:
			last_action_message = "Pickaxe needs %d wood + %d stone" % [
				settings.stone_pickaxe_wood_cost, settings.stone_pickaxe_stone_cost
			]
			return
		gathered_wood -= settings.stone_pickaxe_wood_cost
		gathered_stone -= settings.stone_pickaxe_stone_cost
		has_stone_pickaxe = true
		selected_hotbar_slot = 3
		equipped_tool = "stone_pickaxe"
		last_action_message = "Crafted Stone Pickaxe"
	else:
		return

	equipped_tool_changed.emit(equipped_tool)
	_save_state()


func _collect_nearby_pickups() -> void:
	if player == null or world == null:
		return

	var collected: Array = world.collect_nearby_pickups(
		player.global_position,
		settings.pickup_collect_radius
	)
	if collected.is_empty():
		return

	var branch_count: int = 0
	var stone_count: int = 0
	for pickup_variant in collected:
		var pickup: Dictionary = pickup_variant
		var object_type: String = str(pickup.get("object_type", ""))
		if object_type == "branch":
			gathered_wood += 1
			branch_count += 1
		elif object_type == "loose_stone":
			gathered_stone += 1
			stone_count += 1

	if branch_count == 0 and stone_count == 0:
		return

	if branch_count > 0 and stone_count > 0:
		last_action_message = "Picked up %d wood + %d stone" % [branch_count, stone_count]
	elif branch_count > 0:
		last_action_message = "Picked up %d wood" % branch_count
	else:
		last_action_message = "Picked up %d stone" % stone_count
	_save_state()


func get_resource_counts() -> Vector2i:
	return Vector2i(gathered_wood, gathered_stone)


func get_last_harvest_message() -> String:
	return last_action_message


func get_last_action_message() -> String:
	return last_action_message


func get_equipped_tool() -> String:
	return equipped_tool


func get_selected_hotbar_slot() -> int:
	return selected_hotbar_slot


func has_tool(tool_id: String) -> bool:
	if tool_id == "stone_axe":
		return has_stone_axe
	if tool_id == "stone_pickaxe":
		return has_stone_pickaxe
	return tool_id == "hands"


func get_crafting_cost(recipe_id: String) -> Vector2i:
	if recipe_id == "stone_axe":
		return Vector2i(settings.stone_axe_wood_cost, settings.stone_axe_stone_cost)
	if recipe_id == "stone_pickaxe":
		return Vector2i(settings.stone_pickaxe_wood_cost, settings.stone_pickaxe_stone_cost)
	return Vector2i.ZERO


func _get_save_path() -> String:
	return "user://underworld_seed_%d.json" % world_seed


func _reset_state() -> void:
	object_hit_progress.clear()
	gathered_wood = 0
	gathered_stone = 0
	has_stone_axe = false
	has_stone_pickaxe = false
	selected_hotbar_slot = 1
	equipped_tool = "hands"
	last_action_message = "Walk over loose branches and stones"


func _load_state() -> void:
	_reset_state()
	if world != null:
		world.load_destroyed_object_ids([])

	var save_path: String = _get_save_path()
	if not FileAccess.file_exists(save_path):
		return

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return

	var save_data: Dictionary = parsed
	if int(save_data.get("world_seed", -1)) != world_seed:
		return

	var destroyed_list: Array = save_data.get("destroyed_objects", [])
	if world != null:
		world.load_destroyed_object_ids(destroyed_list)

	gathered_wood = int(save_data.get("wood", 0))
	gathered_stone = int(save_data.get("stone", 0))
	has_stone_axe = bool(save_data.get("stone_axe", false))
	has_stone_pickaxe = bool(save_data.get("stone_pickaxe", false))
	selected_hotbar_slot = clampi(int(save_data.get("selected_slot", 1)), 1, 3)
	_resolve_equipped_tool_from_slot()

	if world != null and world.get_destroyed_object_count() > 0:
		last_action_message = "Loaded %d world modifications" % world.get_destroyed_object_count()


func _resolve_equipped_tool_from_slot() -> void:
	if selected_hotbar_slot == 2 and has_stone_axe:
		equipped_tool = "stone_axe"
	elif selected_hotbar_slot == 3 and has_stone_pickaxe:
		equipped_tool = "stone_pickaxe"
	else:
		selected_hotbar_slot = 1
		equipped_tool = "hands"


func _save_state() -> void:
	var destroyed_list: Array = []
	if world != null:
		destroyed_list = world.get_destroyed_object_ids()

	var save_data: Dictionary = {
		"version": 2,
		"world_seed": world_seed,
		"destroyed_objects": destroyed_list,
		"wood": gathered_wood,
		"stone": gathered_stone,
		"stone_axe": has_stone_axe,
		"stone_pickaxe": has_stone_pickaxe,
		"selected_slot": selected_hotbar_slot,
	}

	var file: FileAccess = FileAccess.open(_get_save_path(), FileAccess.WRITE)
	if file == null:
		last_action_message = "Save failed"
		return
	file.store_string(JSON.stringify(save_data, "  "))
