extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const ArchetypeFamilyValidator := preload("res://core/content/archetypes/archetype_family_validator.gd")
const ItemFamilyValidator := preload("res://gameplay/items/validation/item_family_validator.gd")
const WeaponItemRuleExtension := preload("res://gameplay/items/weapons/validation/weapon_item_rule_extension.gd")
const RecipeFamilyValidator := preload("res://gameplay/crafting/validation/recipe_family_validator.gd")
const CharacterSemanticSchemaCatalog := preload("res://presentation/characters/animation/character_semantic_schema_catalog.gd")

const WOOD_PATH := "res://content/items/resources/wood_definition.tres"
const IRON_PATH := "res://content/items/resources/iron_chunk_definition.tres"
const SWORD_PATH := "res://content/items/weapons/iron_sword_definition.tres"
const ATTACK_SET_PATH := "res://content/items/weapons/iron_sword_attack_set.tres"
const ARCHETYPE_PATH := "res://content/items/weapons/iron_sword_archetype.tres"
const RECIPE_PATH := "res://content/recipes/iron_sword.tres"

const RECIPE_ID := "recipe.hand.iron_sword"
const SWORD_ID := "item.weapon.iron_sword"
const SLOT_UTILITY := "equipment_slot.hotbar.utility"
const PREFERRED_HOTBAR := 4

const ITEM_ROOT := "category.item"
const ITEM_RESOURCE := "category.item.resource"
const ITEM_EQUIPMENT := "category.item.equipment"
const ITEM_WEAPON := "category.item.equipment.weapon"
const ITEM_WEAPON_MELEE := "category.item.equipment.weapon.melee"
const ITEM_SWORD := "category.item.equipment.weapon.melee.sword"
const EQUIPABLE := "capability.equipable"
const DAMAGE_DEALER := "capability.damage_dealer"

const PRODUCTION_PATHS: Array[String] = [
	WOOD_PATH,
	IRON_PATH,
	SWORD_PATH,
	ATTACK_SET_PATH,
	ARCHETYPE_PATH,
	RECIPE_PATH,
]


static func build() -> Dictionary:
	var failures: Array[String] = []
	var definitions: Array = []
	for path in PRODUCTION_PATHS:
		var definition = ResourceLoader.load(path)
		if definition == null:
			failures.append("weapon runtime content failed to load: %s" % path)
			continue
		definitions.append(definition)

	var categories = CategorySchemaRegistry.new()
	for failure in categories.index_schemas([
		CategorySchema.new().configure(ITEM_ROOT),
		CategorySchema.new().configure(ITEM_RESOURCE, [ITEM_ROOT]),
		CategorySchema.new().configure(ITEM_EQUIPMENT, [ITEM_ROOT]),
		CategorySchema.new().configure(ITEM_WEAPON, [ITEM_EQUIPMENT]),
		CategorySchema.new().configure(ITEM_WEAPON_MELEE, [ITEM_WEAPON]),
		CategorySchema.new().configure(ITEM_SWORD, [ITEM_WEAPON_MELEE]),
	]):
		failures.append("weapon runtime category schema: %s" % failure)

	var capabilities = CapabilitySchemaRegistry.new()
	for failure in capabilities.index_schemas([
		CapabilitySchema.new().configure(EQUIPABLE),
		CapabilitySchema.new().configure(DAMAGE_DEALER),
	]):
		failures.append("weapon runtime capability schema: %s" % failure)

	if not failures.is_empty():
		return _failure(failures)

	var weapon_extension = WeaponItemRuleExtension.new()
	weapon_extension.configure_weapon_rules(CharacterSemanticSchemaCatalog.build_registry())
	var item_validator = ItemFamilyValidator.new()
	item_validator.configure_item_rules([weapon_extension])
	var validation: Dictionary = ContentValidationPipeline.new().validate_all(
		definitions,
		categories,
		capabilities,
		[
			item_validator,
			ArchetypeFamilyValidator.new().configure("archetype"),
			RecipeFamilyValidator.new().configure_recipe_rules(),
		]
	)
	if not bool(validation.get("success", false)):
		for diagnostic in validation.get("diagnostics", []):
			failures.append("weapon runtime CONTENT-005/006: %s" % diagnostic)
		return _failure(failures)

	var registry = ContentRegistry.new()
	for failure in registry.index_definitions(definitions):
		failures.append("weapon runtime registry: %s" % failure)
	if not failures.is_empty() or not registry.is_valid():
		for diagnostic in registry.diagnostics():
			failures.append("weapon runtime registry: %s" % diagnostic)
		return _failure(failures)

	return {
		"success": true,
		"registry": registry,
		"validation": validation.duplicate(true),
		"craft_capabilities": craft_capabilities(),
		"diagnostics": [],
	}


static func craft_capabilities() -> Array:
	return [{
		"recipe_id": RECIPE_ID,
		"output_item_id": SWORD_ID,
		"target_slot_key": SLOT_UTILITY,
		"preferred_hotbar": PREFERRED_HOTBAR,
		"supports_craft": true,
		"supports_craft_and_equip": true,
	}]


static func capability_for_recipe(recipe_id: String) -> Dictionary:
	for capability_variant in craft_capabilities():
		var capability: Dictionary = capability_variant
		if str(capability.get("recipe_id", "")) == recipe_id:
			return capability.duplicate(true)
	return {}


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {
		"success": false,
		"registry": null,
		"validation": {},
		"craft_capabilities": [],
		"diagnostics": diagnostics,
	}
