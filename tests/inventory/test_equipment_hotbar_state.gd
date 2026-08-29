extends RefCounted

const EquipmentSlotRule := preload("res://gameplay/items/equipment/equipment_slot_rule.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquipmentService := preload("res://gameplay/items/equipment/equipment_service.gd")
const EquippedItemResolver := preload("res://gameplay/items/equipment/equipped_item_resolver.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const WeaponDefinition := preload("res://gameplay/items/weapons/definitions/weapon_definition.gd")
const WeaponAttackSetDefinition := preload("res://gameplay/items/weapons/definitions/weapon_attack_set_definition.gd")
const WeaponAttackResolver := preload("res://gameplay/items/weapons/runtime/weapon_attack_resolver.gd")
const PlayerAttackDefinition := preload("res://gameplay/combat/attacks/player_attack_definition.gd")

const EQUIPMENT_ROOT := "category.item.equipment"
const SWORD_CATEGORY := "category.item.equipment.weapon.melee.sword"
const AXE_CATEGORY := "category.item.equipment.weapon.melee.axe"
const PICKAXE_CATEGORY := "category.item.equipment.tool.pickaxe"
const EQUIPABLE := "capability.equipable"
const DAMAGE_DEALER := "capability.damage_dealer"
const HARVEST_TOOL := "capability.harvest_tool"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_sword_equips_and_resolves_through_weapon_contract(failures)
	_test_axe_and_pickaxe_share_generic_equipment_path(failures)
	_test_incompatible_item_rejects_without_mutation(failures)
	_test_unequip_preserves_instance_state(failures)
	_test_hotbar_failure_cannot_duplicate_or_lose_item(failures)
	_test_empty_selection_resolves_to_hands(failures)
	return failures


static func _test_sword_equips_and_resolves_through_weapon_contract(failures: Array[String]) -> void:
	var sword = _weapon("item.weapon.equip_sword", SWORD_CATEGORY, [EQUIPABLE, DAMAGE_DEALER])
	var inventory = ItemContainerState.new().configure(4, 20.0)
	inventory.add_instance(sword, {"durability": 91})
	var equipment = _equipment_state()
	var service = EquipmentService.new()
	var result: Dictionary = service.equip_from_inventory(
		equipment, inventory, 0, sword, "equipment_slot.hotbar.1"
	)
	if not bool(result.get("success", false)):
		failures.append("generic sword equip failed: %s" % [result.get("diagnostics", [])])
		return
	if inventory.quantity_of(sword.content_id) != 0:
		failures.append("sword remained duplicated in inventory after equip")
	equipment.select_hotbar(1)
	var selected: Dictionary = EquippedItemResolver.new().resolve_selected(equipment)
	if str(selected.get("item_id", "")) != sword.content_id:
		failures.append("selected sword did not resolve through equipment state")

	var attack_set = WeaponAttackSetDefinition.new().configure_attack_set(
		sword.attack_set_id,
		{sword.primary_technique_role: "equip_sword_light"}
	)
	var attack = PlayerAttackDefinition.new(
		&"equip_sword_light", 0.15, 0.10, 0.25, 20, 2.8, 1.6, 1.0, 0.1
	)
	var attack_resolver = WeaponAttackResolver.new().configure_attack_definitions([attack])
	var weapon_result: Dictionary = EquippedItemResolver.new().resolve_selected_weapon_attack(
		equipment, attack_set, attack_resolver
	)
	if not bool(weapon_result.get("success", false)):
		failures.append("equipped sword did not resolve through WEAPON-001: %s" % [weapon_result.get("diagnostics", [])])
	elif weapon_result.get("attack_definition", null) != attack:
		failures.append("equipment weapon path replaced gameplay-owned attack definition")
	if str(weapon_result.get("grip_rig_role", "")) != sword.grip_rig_role:
		failures.append("equipment weapon resolution lost semantic grip requirement")
	if str(weapon_result.get("attack_animation_role", "")) != sword.attack_animation_role:
		failures.append("equipment weapon resolution lost semantic animation requirement")


static func _test_axe_and_pickaxe_share_generic_equipment_path(failures: Array[String]) -> void:
	var axe = _weapon(
		"item.weapon.equip_axe",
		AXE_CATEGORY,
		[EQUIPABLE, DAMAGE_DEALER, HARVEST_TOOL]
	)
	var pickaxe = _item(
		"item.tool.equip_pickaxe",
		PICKAXE_CATEGORY,
		[EQUIPABLE, DAMAGE_DEALER, HARVEST_TOOL]
	)
	var inventory = ItemContainerState.new().configure(5, 20.0)
	inventory.add_instance(axe, {"durability": 72})
	inventory.add_instance(pickaxe, {"durability": 63})
	var equipment = _equipment_state()
	var service = EquipmentService.new()
	var axe_result: Dictionary = service.equip_from_inventory(
		equipment, inventory, 0, axe, "equipment_slot.hotbar.2"
	)
	var pickaxe_result: Dictionary = service.equip_from_inventory(
		equipment, inventory, 1, pickaxe, "equipment_slot.hotbar.3"
	)
	if not bool(axe_result.get("success", false)) or not bool(pickaxe_result.get("success", false)):
		failures.append("axe/pickaxe did not share generic equip path: %s / %s" % [
			axe_result.get("diagnostics", []), pickaxe_result.get("diagnostics", [])
		])
		return
	var resolver = EquippedItemResolver.new()
	equipment.select_hotbar(2)
	var selected_axe: Dictionary = resolver.resolve_selected(equipment)
	if not bool(selected_axe.get("can_harvest", false)):
		failures.append("equipped axe lost harvest-tool capability")
	if not resolver.selected_matches_category_root(equipment, AXE_CATEGORY):
		failures.append("axe semantic category distinction was not preserved")
	equipment.select_hotbar(3)
	var selected_pickaxe: Dictionary = resolver.resolve_selected(equipment)
	if not bool(selected_pickaxe.get("can_harvest", false)):
		failures.append("equipped pickaxe lost harvest-tool capability")
	if not resolver.selected_matches_category_root(equipment, PICKAXE_CATEGORY):
		failures.append("pickaxe semantic category distinction was not preserved")
	if selected_pickaxe.get("definition", null) is WeaponDefinition:
		failures.append("generic harvest tool was incorrectly forced into WeaponDefinition")


static func _test_incompatible_item_rejects_without_mutation(failures: Array[String]) -> void:
	var stone = _item("item.resource.equip_stone", "category.item.resource", [])
	var inventory = ItemContainerState.new().configure(3, 20.0)
	inventory.add_instance(stone, {"quality": "rough"})
	var equipment = _equipment_state()
	var inventory_before: String = inventory.canonical_json()
	var equipment_before: String = equipment.canonical_json()
	var result: Dictionary = EquipmentService.new().equip_from_inventory(
		equipment, inventory, 0, stone, "equipment_slot.hotbar.1"
	)
	if bool(result.get("success", false)):
		failures.append("non-equipable item unexpectedly entered equipment slot")
	if inventory.canonical_json() != inventory_before:
		failures.append("incompatible equipment rejection mutated inventory")
	if equipment.canonical_json() != equipment_before:
		failures.append("incompatible equipment rejection mutated equipment state")


static func _test_unequip_preserves_instance_state(failures: Array[String]) -> void:
	var axe = _weapon(
		"item.weapon.stateful_axe",
		AXE_CATEGORY,
		[EQUIPABLE, DAMAGE_DEALER, HARVEST_TOOL]
	)
	var inventory = ItemContainerState.new().configure(4, 20.0)
	inventory.add_instance(axe, {"durability": 77, "modifier": "plain"})
	var equipment = _equipment_state()
	var service = EquipmentService.new()
	var equip_result: Dictionary = service.equip_from_inventory(
		equipment, inventory, 0, axe, "equipment_slot.hotbar.1"
	)
	if not bool(equip_result.get("success", false)):
		failures.append("state-preservation equip setup failed")
		return
	var unequip_result: Dictionary = service.unequip_to_inventory(
		equipment, "equipment_slot.hotbar.1", inventory
	)
	if not bool(unequip_result.get("success", false)):
		failures.append("state-preservation unequip failed: %s" % [unequip_result.get("diagnostics", [])])
		return
	var restored: Dictionary = inventory.state_at(0).get("state", {}).get("per_copy_state", {})
	if int(restored.get("durability", 0)) != 77 or str(restored.get("modifier", "")) != "plain":
		failures.append("equip/unequip did not preserve per-item mutable state")
	if not equipment.state_at("equipment_slot.hotbar.1").is_empty():
		failures.append("unequip retained item ownership in equipment container")


static func _test_hotbar_failure_cannot_duplicate_or_lose_item(failures: Array[String]) -> void:
	var sword = _weapon("item.weapon.hotbar_sword", SWORD_CATEGORY, [EQUIPABLE, DAMAGE_DEALER])
	var stone = _item("item.resource.hotbar_stone", "category.item.resource", [])
	var inventory = ItemContainerState.new().configure(4, 20.0)
	inventory.add_instance(sword, {"durability": 80})
	inventory.add_instance(stone, {})
	var equipment = _equipment_state()
	var service = EquipmentService.new()
	service.equip_from_inventory(equipment, inventory, 0, sword, "equipment_slot.hotbar.1")
	equipment.select_hotbar(1)
	var inventory_before: String = inventory.canonical_json()
	var equipment_before: String = equipment.canonical_json()
	var result: Dictionary = service.equip_from_inventory(
		equipment, inventory, 1, stone, "equipment_slot.hotbar.1"
	)
	if bool(result.get("success", false)):
		failures.append("invalid hotbar replacement unexpectedly succeeded")
	if inventory.canonical_json() != inventory_before or equipment.canonical_json() != equipment_before:
		failures.append("failed hotbar replacement duplicated/lost ownership or changed selection")
	var selected: Dictionary = EquippedItemResolver.new().resolve_selected(equipment)
	if str(selected.get("item_id", "")) != sword.content_id:
		failures.append("failed hotbar replacement changed authoritative selected item")


static func _test_empty_selection_resolves_to_hands(failures: Array[String]) -> void:
	var equipment = _equipment_state()
	var selection_result: Dictionary = equipment.select_hotbar(4)
	var selected: Dictionary = EquippedItemResolver.new().resolve_selected(equipment)
	if str(selected.get("selection_kind", "")) != "hands":
		failures.append("empty hotbar selection did not resolve to default hands state")
	if not str(selected.get("item_id", "")).is_empty():
		failures.append("hands/default state invented concrete item identity")
	var events: Array = selection_result.get("events", [])
	if events.size() != 1 or str(events[0].get("type", "")) != "equipment.hotbar_selected":
		failures.append("hotbar selection did not expose semantic state-change event")


static func _equipment_state():
	var rules: Array = []
	var bindings: Dictionary = {}
	for index in range(1, 5):
		var key := "equipment_slot.hotbar.%d" % index
		rules.append(EquipmentSlotRule.new().configure(key, [EQUIPMENT_ROOT], [EQUIPABLE]))
		bindings[index] = key
	return EquipmentHotbarState.new().configure(rules, bindings)


static func _weapon(content_id: String, category_id: String, capabilities: Array):
	var weapon = WeaponDefinition.new().configure_weapon(
		content_id,
		"attack_set.weapon.equip_test",
		"archetype.weapon.equip_test",
		"weapon_technique.light.primary",
		"animation_role.action.attack.light_01",
		"rig_role.socket.hand.right",
		2.5,
		1
	)
	weapon.configure_schema_declarations([category_id], capabilities)
	return weapon


static func _item(content_id: String, category_id: String, capabilities: Array):
	var item = ItemDefinition.new().configure_item(content_id, 1, 1.5, 1)
	item.configure_schema_declarations([category_id], capabilities)
	return item
