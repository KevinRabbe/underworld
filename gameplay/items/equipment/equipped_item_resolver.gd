extends RefCounted

const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const WeaponDefinition := preload("res://gameplay/items/weapons/definitions/weapon_definition.gd")
const WeaponAttackResolver := preload("res://gameplay/items/weapons/runtime/weapon_attack_resolver.gd")
const InventoryStateCodec := preload("res://gameplay/items/inventory/inventory_state_codec.gd")

const HARVEST_TOOL := "capability.harvest_tool"
const DAMAGE_DEALER := "capability.damage_dealer"
const EQUIPABLE := "capability.equipable"


func resolve_selected(equipment_state) -> Dictionary:
	if equipment_state == null or not equipment_state is EquipmentHotbarState:
		return _failure(["equipped item resolver requires EquipmentHotbarState"])
	var slot_key: String = equipment_state.selected_slot_key()
	if slot_key.is_empty():
		return _hands_result(equipment_state.selected_hotbar(), "")
	var definition = equipment_state.selected_definition()
	var stored_state: Dictionary = equipment_state.selected_state()
	if definition == null or stored_state.is_empty():
		return _hands_result(equipment_state.selected_hotbar(), slot_key)
	if not definition is ItemDefinition:
		return _failure(["selected equipment definition is not ItemDefinition"])
	var categories: Array[String] = []
	categories.append_array(definition.category_ids)
	categories.sort()
	var capabilities: Array[String] = []
	capabilities.append_array(definition.capability_ids)
	capabilities.sort()
	return {
		"success": true,
		"diagnostics": [],
		"selection_kind": "item",
		"hotbar": equipment_state.selected_hotbar(),
		"slot_key": slot_key,
		"definition": definition,
		"item_id": str(definition.content_id),
		"categories": categories,
		"capabilities": capabilities,
		"item_state": stored_state.duplicate(true),
		"can_equip": capabilities.has(EQUIPABLE),
		"can_harvest": capabilities.has(HARVEST_TOOL),
		"can_deal_damage": capabilities.has(DAMAGE_DEALER),
	}


func resolve_selected_weapon_attack(
	equipment_state,
	attack_set,
	weapon_attack_resolver
) -> Dictionary:
	var selected: Dictionary = resolve_selected(equipment_state)
	if not bool(selected.get("success", false)):
		return selected
	var definition = selected.get("definition", null)
	if definition == null or not definition is WeaponDefinition:
		return _failure(["selected equipment item is not WeaponDefinition"])
	if weapon_attack_resolver == null or not weapon_attack_resolver is WeaponAttackResolver:
		return _failure(["weapon equipment resolution requires WeaponAttackResolver"])
	var attack_result: Dictionary = weapon_attack_resolver.resolve_primary_attack(definition, attack_set)
	var failures: Array[String] = []
	for failure in attack_result.get("diagnostics", []):
		failures.append(str(failure))
	if not failures.is_empty():
		return _failure(failures)
	return {
		"success": true,
		"diagnostics": [],
		"item_id": str(definition.content_id),
		"slot_key": str(selected.get("slot_key", "")),
		"attack_definition": attack_result.get("attack_definition", null),
		"attack_id": str(attack_result.get("attack_id", "")),
		"technique_role": str(attack_result.get("technique_role", "")),
		"archetype_id": str(definition.archetype_id),
		"attack_animation_role": str(definition.attack_animation_role),
		"grip_rig_role": str(definition.grip_rig_role),
	}


func selected_has_capability(equipment_state, capability_id: String) -> bool:
	var selected: Dictionary = resolve_selected(equipment_state)
	return (
		bool(selected.get("success", false))
		and selected.get("capabilities", []).has(capability_id)
	)


func selected_matches_category_root(equipment_state, category_root: String) -> bool:
	var selected: Dictionary = resolve_selected(equipment_state)
	if not bool(selected.get("success", false)):
		return false
	for category_id in selected.get("categories", []):
		var value: String = str(category_id)
		if value == category_root or value.begins_with(category_root + "."):
			return true
	return false


static func _hands_result(hotbar: int, slot_key: String) -> Dictionary:
	return {
		"success": true,
		"diagnostics": [],
		"selection_kind": "hands",
		"hotbar": hotbar,
		"slot_key": slot_key,
		"definition": null,
		"item_id": "",
		"categories": [],
		"capabilities": [],
		"item_state": {},
		"can_equip": false,
		"can_harvest": false,
		"can_deal_damage": false,
	}


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {
		"success": false,
		"diagnostics": diagnostics,
		"selection_kind": "invalid",
		"definition": null,
		"item_id": "",
	}
