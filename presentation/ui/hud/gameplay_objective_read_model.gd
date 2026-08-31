extends RefCounted
class_name GameplayObjectiveReadModel

const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const StoneAxeRecipe := preload("res://content/recipes/stone_axe.tres")
const StonePickaxeRecipe := preload("res://content/recipes/stone_pickaxe.tres")
const IronSwordRecipe := preload("res://content/recipes/iron_sword.tres")

const WOOD_ID := "item.resource.wood"
const STONE_ID := "item.resource.stone"
const IRON_ID := "item.resource.iron_chunk"
const CHITIN_ID := "item.resource.burrower_chitin"
const AXE_ID := "item.tool.stone_axe"
const PICKAXE_ID := "item.tool.stone_pickaxe"
const SWORD_ID := "item.weapon.iron_sword"

const SLOT_AXE := "equipment_slot.hotbar.axe"
const SLOT_PICKAXE := "equipment_slot.hotbar.pickaxe"
const SLOT_UTILITY := "equipment_slot.hotbar.utility"


func sample(game, player, inventory_state, equipment_state) -> Dictionary:
	var failures: Array[String] = []
	if inventory_state == null or not inventory_state is ItemContainerState:
		failures.append("UX objective inventory source must be ItemContainerState")
	else:
		for failure in inventory_state.validate_container():
			failures.append("UX objective inventory source: %s" % failure)
	if equipment_state == null or not equipment_state is EquipmentHotbarState:
		failures.append("UX objective equipment source must be EquipmentHotbarState")
	else:
		for failure in equipment_state.validate_state():
			failures.append("UX objective equipment source: %s" % failure)
	if game == null:
		failures.append("UX objective requires live Game read authority")
	else:
		for method_name in [
			"selected_entrance_route_snapshot",
			"natural_entrance_route_ready",
			"startup_mode",
		]:
			if not game.has_method(method_name):
				failures.append("UX objective Game source lacks read API: %s" % method_name)
	if player == null or not player is Node3D or not _is_finite_vector3(player.global_position):
		failures.append("UX objective requires finite live Player position")
	if not failures.is_empty():
		return _failure(failures)

	var inventory = inventory_state as ItemContainerState
	var equipment = equipment_state as EquipmentHotbarState
	var axe_equipped: bool = _equipped_item_id(equipment, SLOT_AXE) == AXE_ID
	var pickaxe_equipped: bool = _equipped_item_id(equipment, SLOT_PICKAXE) == PICKAXE_ID
	var sword_equipped: bool = _equipped_item_id(equipment, SLOT_UTILITY) == SWORD_ID

	var required_wood: int = 0
	var required_stone: int = 0
	if not axe_equipped:
		required_wood += _ingredient_quantity(StoneAxeRecipe, WOOD_ID)
		required_stone += _ingredient_quantity(StoneAxeRecipe, STONE_ID)
	if not pickaxe_equipped:
		required_wood += _ingredient_quantity(StonePickaxeRecipe, WOOD_ID)
		required_stone += _ingredient_quantity(StonePickaxeRecipe, STONE_ID)
	if not sword_equipped:
		# Reserve the sword's surface ingredient before committing to the cave route.
		required_wood += _ingredient_quantity(IronSwordRecipe, WOOD_ID)

	var wood_quantity: int = inventory.quantity_of(WOOD_ID)
	var stone_quantity: int = inventory.quantity_of(STONE_ID)
	if wood_quantity < required_wood or stone_quantity < required_stone:
		return _objective(
			"gather_surface_materials",
			"Gather resources — Wood %d/%d, Stone %d/%d" % [
				wood_quantity,
				required_wood,
				stone_quantity,
				required_stone,
			],
			{
				"wood": wood_quantity,
				"wood_required": required_wood,
				"stone": stone_quantity,
				"stone_required": required_stone,
			}
		)

	if not axe_equipped or not pickaxe_equipped:
		var missing: Array[String] = []
		if not axe_equipped:
			missing.append("Stone Axe")
		if not pickaxe_equipped:
			missing.append("Stone Pickaxe")
		return _objective(
			"craft_equip_stone_tools",
			"Craft and equip %s" % " + ".join(missing),
			{"axe_equipped": axe_equipped, "pickaxe_equipped": pickaxe_equipped}
		)

	var route_variant: Variant = game.call("selected_entrance_route_snapshot")
	if not route_variant is Dictionary:
		return _failure(["UX objective natural route snapshot must be Dictionary"])
	var route: Dictionary = route_variant
	var route_ready: bool = bool(game.call("natural_entrance_route_ready"))
	var in_cave: bool = _player_is_in_cave(game)
	var iron_required: int = _ingredient_quantity(IronSwordRecipe, IRON_ID)
	var iron_quantity: int = inventory.quantity_of(IRON_ID)

	if iron_quantity < iron_required:
		if not in_cave:
			return _route_objective(game, player as Node3D, route, route_ready, "Reach the natural cave entrance")
		return _objective(
			"mine_iron",
			"Mine iron — %d/%d" % [iron_quantity, iron_required],
			{"iron": iron_quantity, "iron_required": iron_required, "in_cave": true}
		)

	if not sword_equipped:
		return _objective(
			"craft_equip_iron_sword",
			"Craft and equip the Iron Sword in hotbar 4",
			{"iron": iron_quantity, "iron_required": iron_required}
		)

	var chitin_quantity: int = inventory.quantity_of(CHITIN_ID)
	var pending_loot_count: int = _pending_loot_count(game)
	if chitin_quantity <= 0:
		if pending_loot_count > 0:
			return _objective(
				"collect_burrower_reward",
				"Collect the Burrower reward",
				{"pending_loot_count": pending_loot_count}
			)
		if not in_cave:
			return _route_objective(game, player as Node3D, route, route_ready, "Return to the cave and defeat a Burrower")
		return _objective("defeat_burrower", "Defeat a Burrower", {"in_cave": true})

	var startup_mode: StringName = game.call("startup_mode")
	if startup_mode == &"continue":
		var complete := _objective(
			"m3_route_complete",
			"Expedition resumed — M3 route complete",
			{"startup_mode": str(startup_mode), "reward_quantity": chitin_quantity}
		)
		complete["complete"] = true
		return complete
	return _objective(
		"save_quit_continue",
		"Save & Quit, then Continue from the Title screen",
		{"startup_mode": str(startup_mode), "reward_quantity": chitin_quantity}
	)


func _route_objective(
	game,
	player: Node3D,
	route: Dictionary,
	route_ready: bool,
	prefix: String
) -> Dictionary:
	if not route_ready:
		var diagnostics: Array = []
		if game.has_method("natural_entrance_route_diagnostics"):
			diagnostics = game.call("natural_entrance_route_diagnostics")
		if diagnostics.is_empty():
			diagnostics = ["Natural cave route is not ready"]
		return _failure(diagnostics)
	var target_variant: Variant = route.get("surface_world_position", null)
	if not target_variant is Vector3 or not _is_finite_vector3(target_variant):
		return _failure(["UX objective natural route lacks finite surface target"])
	var target: Vector3 = target_variant
	var distance: float = Vector2(
		player.global_position.x - target.x,
		player.global_position.z - target.z
	).length()
	if is_nan(distance) or is_inf(distance):
		return _failure(["UX objective natural route distance must be finite"])
	return _objective(
		"reach_natural_cave",
		"%s — %.0f m" % [prefix, distance],
		{"route_ready": true, "distance": distance}
	)


static func _equipped_item_id(equipment: EquipmentHotbarState, slot_key: String) -> String:
	var state: Dictionary = equipment.state_at(slot_key)
	return str(state.get("state", {}).get("item_id", ""))


static func _ingredient_quantity(recipe, item_id: String) -> int:
	if recipe == null:
		return 0
	var quantity: int = 0
	for ingredient in recipe.ingredients:
		if ingredient != null and str(ingredient.item_content_id) == item_id:
			quantity += maxi(int(ingredient.quantity), 0)
	return quantity


static func _player_is_in_cave(game) -> bool:
	var runtime = game.get("underworld_runtime")
	if runtime == null or not is_instance_valid(runtime):
		return false
	if not runtime.has_method("player_is_in_realized_cave"):
		return false
	return bool(runtime.call("player_is_in_realized_cave"))


static func _pending_loot_count(game) -> int:
	var encounter = game.get("encounter_controller")
	if encounter == null or not is_instance_valid(encounter):
		return 0
	if not encounter.has_method("get_pending_loot_count"):
		return 0
	return maxi(int(encounter.call("get_pending_loot_count")), 0)


static func _objective(objective_id: String, text: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"success": true,
		"diagnostics": [],
		"objective_id": objective_id,
		"text": text,
		"complete": false,
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {
		"success": false,
		"diagnostics": diagnostics,
		"objective_id": "",
		"text": "",
		"complete": false,
	}


static func _is_finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)
