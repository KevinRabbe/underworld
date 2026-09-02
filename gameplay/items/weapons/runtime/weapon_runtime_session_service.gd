extends RefCounted

const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const CraftingContext := preload("res://gameplay/crafting/runtime/crafting_context.gd")
const CraftingService := preload("res://gameplay/crafting/runtime/crafting_service.gd")
const ProgressionCraftEquipService := preload("res://gameplay/crafting/runtime/progression_craft_equip_service.gd")
const WeaponRuntimeContentCatalog := preload("res://gameplay/items/weapons/runtime/weapon_runtime_content_catalog.gd")
const SelectedEquipmentWeaponCompositionService := preload("res://gameplay/items/weapons/runtime/selected_equipment_weapon_composition_service.gd")

var _player = null
var _inventory = null
var _equipment = null
var _registry = null
var _validation: Dictionary = {}
var _crafting = null
var _progression = null
var _composition = SelectedEquipmentWeaponCompositionService.new()
var _configuration_failures: Array[String] = []


func configure(player, inventory, equipment_state) -> Dictionary:
	clear()
	_configuration_failures.clear()
	if player == null or not is_instance_valid(player):
		_configuration_failures.append("weapon runtime session requires live Player")
	if inventory == null or not inventory is ItemContainerState:
		_configuration_failures.append("weapon runtime session requires ItemContainerState")
	elif not inventory.validate_container().is_empty():
		for diagnostic in inventory.validate_container():
			_configuration_failures.append("inventory state: %s" % diagnostic)
	if equipment_state == null or not equipment_state is EquipmentHotbarState:
		_configuration_failures.append("weapon runtime session requires EquipmentHotbarState")
	elif not equipment_state.validate_state().is_empty():
		for diagnostic in equipment_state.validate_state():
			_configuration_failures.append("equipment state: %s" % diagnostic)
	if not _configuration_failures.is_empty():
		_configuration_failures.sort()
		return _failure("configure", _configuration_failures)

	var content: Dictionary = WeaponRuntimeContentCatalog.build()
	if not bool(content.get("success", false)):
		for diagnostic in content.get("diagnostics", []):
			_configuration_failures.append("weapon content: %s" % diagnostic)
		_configuration_failures.sort()
		return _failure("configure", _configuration_failures)

	_player = player
	_inventory = inventory
	_equipment = equipment_state
	_registry = content.get("registry", null)
	_validation = content.get("validation", {}).duplicate(true)
	_crafting = CraftingService.new().configure(_registry, _validation)
	_progression = ProgressionCraftEquipService.new().configure(_crafting, _registry)

	var synced: Dictionary = sync_selected()
	if not bool(synced.get("success", false)):
		return synced
	return {
		"success": true,
		"stage": "complete",
		"diagnostics": [],
		"selection": synced.duplicate(true),
		"craft_capabilities": craft_capabilities(),
	}


func is_configured() -> bool:
	return (
		_configuration_failures.is_empty()
		and _player != null and is_instance_valid(_player)
		and _inventory != null and _inventory is ItemContainerState
		and _equipment != null and _equipment is EquipmentHotbarState
		and _registry != null
		and _crafting != null
		and _progression != null
	)


func sync_selected() -> Dictionary:
	if not is_configured():
		return _failure("sync", _configuration_failures if not _configuration_failures.is_empty() else [
			"weapon runtime session is not configured"
		])
	return _composition.sync_selected(_equipment, _registry, _validation, _player)


func craft_capabilities() -> Array:
	return WeaponRuntimeContentCatalog.craft_capabilities()


func craft(recipe_id: String) -> Dictionary:
	var capability: Dictionary = WeaponRuntimeContentCatalog.capability_for_recipe(recipe_id)
	if capability.is_empty() or not bool(capability.get("supports_craft", false)):
		return _failure("craft", ["weapon runtime has no craft capability for recipe: %s" % recipe_id])
	if not is_configured():
		return _failure("craft", ["weapon runtime session is not configured"])
	var crafted: Dictionary = _crafting.craft(recipe_id, CraftingContext.new(), _inventory)
	var result: Dictionary = crafted.duplicate(true)
	result["stage"] = "craft"
	result["capability"] = capability.duplicate(true)
	return result


func craft_and_equip(recipe_id: String) -> Dictionary:
	var capability: Dictionary = WeaponRuntimeContentCatalog.capability_for_recipe(recipe_id)
	if capability.is_empty() or not bool(capability.get("supports_craft_and_equip", false)):
		return _failure("craft_and_equip", [
			"weapon runtime has no craft-and-equip capability for recipe: %s" % recipe_id
		])
	if not is_configured():
		return _failure("craft_and_equip", ["weapon runtime session is not configured"])

	var progressed: Dictionary = _progression.craft_and_equip(
		recipe_id,
		CraftingContext.new(),
		_inventory,
		_equipment,
		str(capability.get("output_item_id", "")),
		str(capability.get("target_slot_key", "")),
		int(capability.get("preferred_hotbar", 0))
	)
	if not bool(progressed.get("success", false)):
		var failed_progression: Dictionary = progressed.duplicate(true)
		failed_progression["capability"] = capability.duplicate(true)
		failed_progression["selection_sync_attempted"] = false
		return failed_progression

	var synced: Dictionary = sync_selected()
	var result: Dictionary = progressed.duplicate(true)
	result["capability"] = capability.duplicate(true)
	result["selection_sync_attempted"] = true
	result["selection"] = synced.duplicate(true)
	if not bool(synced.get("success", false)):
		result["success"] = false
		result["stage"] = str(synced.get("stage", "selection_sync"))
		result["diagnostics"] = synced.get("diagnostics", []).duplicate()
	return result


func selected_equipment_state():
	return _equipment


func presented_weapon_instance():
	return _composition.presented_instance()


func clear() -> void:
	_composition.clear()
	_player = null
	_inventory = null
	_equipment = null
	_registry = null
	_validation.clear()
	_crafting = null
	_progression = null


static func _failure(stage: String, messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {
		"success": false,
		"stage": stage,
		"diagnostics": diagnostics,
		"craft_capabilities": [],
	}
