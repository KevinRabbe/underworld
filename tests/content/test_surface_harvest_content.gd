extends RefCounted

const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemFamilyValidator := preload("res://gameplay/items/validation/item_family_validator.gd")
const WeaponItemRuleExtension := preload("res://gameplay/items/weapons/validation/weapon_item_rule_extension.gd")
const CharacterSemanticSchemaCatalog := preload("res://presentation/characters/animation/character_semantic_schema_catalog.gd")

const WOOD_PATH := "res://content/items/resources/wood_definition.tres"
const STONE_PATH := "res://content/items/resources/stone_definition.tres"
const AXE_PATH := "res://content/items/tools/stone_axe_definition.tres"
const PICKAXE_PATH := "res://content/items/tools/stone_pickaxe_definition.tres"

const ITEM_ROOT := "category.item"
const ITEM_RESOURCE := "category.item.resource"
const ITEM_EQUIPMENT := "category.item.equipment"
const ITEM_WEAPON := "category.item.equipment.weapon"
const ITEM_WEAPON_MELEE := "category.item.equipment.weapon.melee"
const ITEM_WEAPON_AXE := "category.item.equipment.weapon.melee.axe"
const ITEM_TOOL := "category.item.equipment.tool"
const ITEM_TOOL_AXE := "category.item.equipment.tool.axe"
const ITEM_TOOL_PICKAXE := "category.item.equipment.tool.pickaxe"


static func run() -> Array[String]:
	var failures: Array[String] = []
	var expected: Dictionary = {
		WOOD_PATH: ["item.resource.wood", ITEM_RESOURCE, ""],
		STONE_PATH: ["item.resource.stone", ITEM_RESOURCE, ""],
		AXE_PATH: ["item.tool.stone_axe", ITEM_TOOL_AXE, "capability.harvest_tool"],
		PICKAXE_PATH: ["item.tool.stone_pickaxe", ITEM_TOOL_PICKAXE, "capability.harvest_tool"],
	}
	var validator = _item_validator()
	var validator_failures: Array[String] = validator.validate_validator()
	if not validator_failures.is_empty():
		failures.append("surface harvest item validator is invalid: %s" % [validator_failures])
	var categories = _categories()
	var context: Dictionary = {"category_registry": categories}
	for path in expected.keys():
		var loaded: Variant = ResourceLoader.load(path)
		if loaded == null or not loaded is ItemDefinition:
			failures.append("surface harvest content did not load as ItemDefinition: %s" % path)
			continue
		var definition = loaded
		for failure in definition.validate_definition():
			failures.append("%s: %s" % [path, failure])
		for failure in validator.validate_definition(definition, context):
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
	if axe is ItemDefinition and axe.capability_ids.has("capability.damage_dealer"):
		failures.append("plain harvest axe retained weapon-only damage-dealer capability")

	_test_weapon_rule_extension_cannot_be_bypassed(validator, context, failures)
	failures.sort()
	return failures


static func _item_validator():
	var extension = WeaponItemRuleExtension.new()
	extension.configure_weapon_rules(CharacterSemanticSchemaCatalog.build_registry())
	return ItemFamilyValidator.new().configure_item_rules([extension])


static func _categories():
	var registry = CategorySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CategorySchema.new().configure(ITEM_ROOT),
		CategorySchema.new().configure(ITEM_RESOURCE, [ITEM_ROOT]),
		CategorySchema.new().configure(ITEM_EQUIPMENT, [ITEM_ROOT]),
		CategorySchema.new().configure(ITEM_WEAPON, [ITEM_EQUIPMENT]),
		CategorySchema.new().configure(ITEM_WEAPON_MELEE, [ITEM_WEAPON]),
		CategorySchema.new().configure(ITEM_WEAPON_AXE, [ITEM_WEAPON_MELEE]),
		CategorySchema.new().configure(ITEM_TOOL, [ITEM_EQUIPMENT]),
		CategorySchema.new().configure(ITEM_TOOL_AXE, [ITEM_TOOL]),
		CategorySchema.new().configure(ITEM_TOOL_PICKAXE, [ITEM_TOOL]),
	])
	assert(diagnostics.is_empty())
	return registry


static func _test_weapon_rule_extension_cannot_be_bypassed(
	validator,
	context: Dictionary,
	failures: Array[String]
) -> void:
	var malformed = ItemDefinition.new()
	malformed.configure_item("item.tool.invalid_weapon_category_axe", 1, 2.0, 1)
	malformed.configure_schema_declarations(
		[ITEM_WEAPON_AXE],
		["capability.equipable", "capability.harvest_tool"]
	)
	var diagnostics: Array[String] = validator.validate_definition(malformed, context)
	if not _has_fragment(diagnostics, "weapon-category item must inherit WeaponDefinition"):
		failures.append("surface content validation bypassed accepted WeaponItemRuleExtension")


static func _has_fragment(messages: Array[String], fragment: String) -> bool:
	for message in messages:
		if message.contains(fragment):
			return true
	return false
