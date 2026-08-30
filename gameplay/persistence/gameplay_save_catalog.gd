extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const EquipmentSlotRule := preload("res://gameplay/items/equipment/equipment_slot_rule.gd")

const SLOT_HANDS := "equipment_slot.hotbar.hands"
const SLOT_AXE := "equipment_slot.hotbar.axe"
const SLOT_PICKAXE := "equipment_slot.hotbar.pickaxe"
const SLOT_UTILITY := "equipment_slot.hotbar.utility"

const DURABLE_CONTENT_PATHS: Array[String] = [
	"res://content/items/resources/burrower_chitin_definition.tres",
	"res://content/items/resources/iron_chunk_definition.tres",
	"res://content/items/resources/stone_definition.tres",
	"res://content/items/resources/wood_definition.tres",
	"res://content/items/tools/stone_axe_definition.tres",
	"res://content/items/tools/stone_pickaxe_definition.tres",
	"res://content/loot/profiles/prototype_burrower_reward_profile.tres",
]


static func build_registry() -> Dictionary:
	var registry = ContentRegistry.new()
	var failures: Array[String] = registry.load_resource_paths(DURABLE_CONTENT_PATHS)
	if not failures.is_empty():
		return _failure(failures)
	if not registry.is_valid():
		return _failure(registry.diagnostics())
	return {
		"success": true,
		"registry": registry,
		"diagnostics": [],
	}


static func equipment_rules() -> Array:
	return [
		EquipmentSlotRule.new().configure(
			SLOT_HANDS,
			["category.item.equipment"],
			["capability.equipable"]
		),
		EquipmentSlotRule.new().configure(
			SLOT_AXE,
			["category.item.equipment.tool.axe"],
			["capability.equipable", "capability.harvest_tool"]
		),
		EquipmentSlotRule.new().configure(
			SLOT_PICKAXE,
			["category.item.equipment.tool.pickaxe"],
			["capability.equipable", "capability.harvest_tool"]
		),
		EquipmentSlotRule.new().configure(
			SLOT_UTILITY,
			["category.item.equipment"],
			["capability.equipable"]
		),
	]


static func hotbar_bindings() -> Dictionary:
	return {
		1: SLOT_HANDS,
		2: SLOT_AXE,
		3: SLOT_PICKAXE,
		4: SLOT_UTILITY,
	}


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = []
	var registry_result: Dictionary = build_registry()
	if not bool(registry_result.get("success", false)):
		for diagnostic in registry_result.get("diagnostics", []):
			failures.append(str(diagnostic))
	var rules: Array = equipment_rules()
	var seen_slots: Dictionary = {}
	for rule in rules:
		if rule == null:
			failures.append("SAVE catalog contains null equipment rule")
			continue
		for diagnostic in rule.validate_rule():
			failures.append("SAVE catalog equipment rule: %s" % diagnostic)
		if seen_slots.has(rule.slot_key):
			failures.append("SAVE catalog duplicate equipment slot: %s" % rule.slot_key)
		seen_slots[rule.slot_key] = true
	var bindings: Dictionary = hotbar_bindings()
	for hotbar_index in range(1, 5):
		if not bindings.has(hotbar_index):
			failures.append("SAVE catalog missing hotbar binding: %d" % hotbar_index)
			continue
		var slot_key: String = str(bindings[hotbar_index])
		if not seen_slots.has(slot_key):
			failures.append("SAVE catalog hotbar binding targets unknown slot: %s" % slot_key)
	failures.sort()
	return failures


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {
		"success": false,
		"diagnostics": diagnostics,
	}
