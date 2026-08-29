extends RefCounted

const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemFamilyValidator := preload("res://gameplay/items/validation/item_family_validator.gd")

const WOOD_PATH := "res://content/items/resources/wood_definition.tres"
const STONE_PATH := "res://content/items/resources/stone_definition.tres"
const AXE_PATH := "res://content/items/tools/stone_axe_definition.tres"
const PICKAXE_PATH := "res://content/items/tools/stone_pickaxe_definition.tres"


static func run() -> Array[String]:
	var failures: Array[String] = []
	var expected: Dictionary = {
		WOOD_PATH: ["item.resource.wood", "category.item.resource", ""],
		STONE_PATH: ["item.resource.stone", "category.item.resource", ""],
		AXE_PATH: ["item.tool.stone_axe", "category.item.equipment.weapon.melee.axe", "capability.harvest_tool"],
		PICKAXE_PATH: ["item.tool.stone_pickaxe", "category.item.equipment.tool.pickaxe", "capability.harvest_tool"],
	}
	var validator = ItemFamilyValidator.new().configure_item_rules([])
	for path in expected.keys():
		var loaded: Variant = ResourceLoader.load(path)
		if loaded == null or not loaded is ItemDefinition:
			failures.append("surface harvest content did not load as ItemDefinition: %s" % path)
			continue
		var definition = loaded
		for failure in definition.validate_definition():
			failures.append("%s: %s" % [path, failure])
		for failure in validator.validate_definition(definition, {}):
			failures.append("%s item family: %s" % [path, failure])
		var contract: Array = expected[path]
		if str(definition.content_id) != str(contract[0]):
			failures.append("surface item ContentId changed at %s" % path)
		if not definition.category_ids.has(str(contract[1])):
			failures.append("surface item lacks semantic category %s: %s" % [contract[1], path])
		var capability: String = str(contract[2])
		if not capability.is_empty() and not definition.capability_ids.has(capability):
			failures.append("surface tool lacks semantic harvest capability: %s" % path)
		if str(definition.resource_path) == str(definition.content_id):
			failures.append("surface item physical path leaked into semantic identity: %s" % path)

	var wood: Variant = ResourceLoader.load(WOOD_PATH)
	var stone: Variant = ResourceLoader.load(STONE_PATH)
	var axe: Variant = ResourceLoader.load(AXE_PATH)
	var pickaxe: Variant = ResourceLoader.load(PICKAXE_PATH)
	if wood is ItemDefinition and wood.stack_limit <= 1:
		failures.append("wood harvest output is not stackable")
	if stone is ItemDefinition and stone.stack_limit <= 1:
		failures.append("stone harvest output is not stackable")
	if axe is ItemDefinition and axe.stack_limit != 1:
		failures.append("stone axe must remain an item instance")
	if pickaxe is ItemDefinition and pickaxe.stack_limit != 1:
		failures.append("stone pickaxe must remain an item instance")
	failures.sort()
	return failures
