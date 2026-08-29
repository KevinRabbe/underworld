extends RefCounted

const ContentDefinition := preload("res://core/content/registry/content_definition.gd")
const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemFamilyValidator := preload("res://gameplay/items/validation/item_family_validator.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const RecipeItemAmount := preload("res://gameplay/crafting/definitions/recipe_item_amount.gd")
const RecipeDefinition := preload("res://gameplay/crafting/definitions/recipe_definition.gd")
const RecipeFamilyValidator := preload("res://gameplay/crafting/validation/recipe_family_validator.gd")
const CraftingContext := preload("res://gameplay/crafting/runtime/crafting_context.gd")
const CraftingService := preload("res://gameplay/crafting/runtime/crafting_service.gd")

const AXE_RECIPE_PATH := "res://content/recipes/stone_axe.tres"
const PICKAXE_RECIPE_PATH := "res://content/recipes/stone_pickaxe.tres"
const SWORD_RECIPE_PATH := "res://content/recipes/iron_sword.tres"
const ACCEPTED_SWORD_PATH := "res://tests/fixtures/content/weapon_path_a/iron_sword.tres"

const ITEM_ROOT := "category.item"
const ITEM_RESOURCE := "category.item.resource"
const ITEM_TOOL := "category.item.tool"
const ITEM_WEAPON := "category.item.weapon"
const HARVEST_TOOL := "capability.harvest_tool"
const CRAFTING_HAND := "capability.crafting.hand"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_authored_m3_recipes_and_identity(failures)
	_test_equivalent_declaration_order_is_canonical(failures)
	_test_missing_item_reference_fails_content005(failures)
	_test_wrong_recipe_definition_type_fails_closed(failures)
	_test_crafting_context_eligibility(failures)
	_test_insufficient_ingredients_are_atomic(failures)
	_test_valid_stone_tool_crafts_are_atomic(failures)
	_test_sword_uses_accepted_weapon_definition(failures)
	return failures


static func _test_authored_m3_recipes_and_identity(failures: Array[String]) -> void:
	var axe = ResourceLoader.load(AXE_RECIPE_PATH)
	var pickaxe = ResourceLoader.load(PICKAXE_RECIPE_PATH)
	var sword = ResourceLoader.load(SWORD_RECIPE_PATH)
	if (
		axe == null or not axe is RecipeDefinition
		or pickaxe == null or not pickaxe is RecipeDefinition
		or sword == null or not sword is RecipeDefinition
	):
		failures.append("authored M3 recipe resources did not load as RecipeDefinition")
		return
	_expect_equal(failures, "axe recipe id", axe.content_id, "recipe.hand.stone_axe")
	_expect_equal(failures, "pickaxe recipe id", pickaxe.content_id, "recipe.hand.stone_pickaxe")
	_expect_equal(failures, "sword recipe id", sword.content_id, "recipe.hand.iron_sword")
	_expect_equal(failures, "axe wood cost", _quantity(axe.aggregated_ingredients(), "item.resource.wood"), 4)
	_expect_equal(failures, "axe stone cost", _quantity(axe.aggregated_ingredients(), "item.resource.stone"), 3)
	_expect_equal(failures, "pickaxe wood cost", _quantity(pickaxe.aggregated_ingredients(), "item.resource.wood"), 3)
	_expect_equal(failures, "pickaxe stone cost", _quantity(pickaxe.aggregated_ingredients(), "item.resource.stone"), 4)
	_expect_equal(failures, "sword underground material", _quantity(sword.aggregated_ingredients(), "item.resource.iron_chunk"), 4)

	var mirror = RecipeDefinition.new().configure_recipe(
		axe.content_id,
		[
			_amount("item.resource.wood", 4),
			_amount("item.resource.stone", 3),
		],
		[_amount("item.tool.stone_axe", 1)]
	)
	mirror.resource_name = "A display label that is not identity"
	if str(axe.resource_path) == str(mirror.resource_path):
		failures.append("recipe identity proof did not compare distinct physical resource paths")
	if axe.canonical_descriptor() != mirror.canonical_descriptor():
		failures.append("recipe semantic descriptor depends on resource path or display label")


static func _test_equivalent_declaration_order_is_canonical(failures: Array[String]) -> void:
	var first = RecipeDefinition.new().configure_recipe(
		"recipe.test.order",
		[_amount("item.resource.wood", 2), _amount("item.resource.stone", 1)],
		[_amount("item.tool.stone_axe", 1)]
	)
	var second = RecipeDefinition.new().configure_recipe(
		"recipe.test.order",
		[_amount("item.resource.stone", 1), _amount("item.resource.wood", 2)],
		[_amount("item.tool.stone_axe", 1)]
	)
	if first.canonical_descriptor() != second.canonical_descriptor():
		failures.append("logically equivalent recipe declaration order changed canonical descriptor")


static func _test_missing_item_reference_fails_content005(failures: Array[String]) -> void:
	var recipe = RecipeDefinition.new().configure_recipe(
		"recipe.test.missing_reference",
		[_amount("item.resource.missing_ore", 1)],
		[_amount("item.tool.stone_axe", 1)]
	)
	var definitions: Array = [recipe, _item("item.tool.stone_axe", 1, ITEM_TOOL)]
	var result: Dictionary = _validate(definitions)
	if not _has_diagnostic(result, "reference_resolution", "missing content definition"):
		failures.append("missing recipe ingredient did not fail through CONTENT-005 reference resolution")


static func _test_wrong_recipe_definition_type_fails_closed(failures: Array[String]) -> void:
	var wrong_type = ContentDefinition.new()
	wrong_type.configure("recipe.invalid.generic_definition", "recipe", 1)
	var validator = RecipeFamilyValidator.new().configure_recipe_rules()
	if not validator.applies_to(wrong_type):
		failures.append("recipe validator did not select semantic recipe family for wrong subtype")
		return
	var result: Dictionary = ContentValidationPipeline.new().validate_all(
		[wrong_type],
		_categories(),
		_capabilities(),
		[validator]
	)
	if not _has_diagnostic(result, "family_rule", "must inherit RecipeDefinition"):
		failures.append("generic ContentDefinition under recipe family bypassed recipe rulebook")


static func _test_crafting_context_eligibility(failures: Array[String]) -> void:
	var recipe = RecipeDefinition.new().configure_recipe(
		"recipe.test.context",
		[_amount("item.resource.wood", 1)],
		[_amount("item.tool.stone_axe", 1)],
		[CRAFTING_HAND]
	)
	var definitions: Array = [
		recipe,
		_item("item.resource.wood", 64, ITEM_RESOURCE),
		_item("item.tool.stone_axe", 1, ITEM_TOOL),
	]
	var validation: Dictionary = _validate(definitions)
	if not bool(validation.get("success", false)):
		failures.append("valid context-gated recipe failed CONTENT-005 validation: %s" % [validation.get("diagnostics", [])])
		return
	var registry = _registry(definitions, failures)
	if registry == null:
		return
	var inventory = ItemContainerState.new().configure(2, 10.0)
	inventory.add_stack(definitions[1], 1)
	var service = CraftingService.new().configure(registry, validation)
	var denied: Dictionary = service.build_plan(recipe.content_id, CraftingContext.new(), inventory)
	if bool(denied.get("success", false)) or not _has_fragment(denied, "lacks required capability"):
		failures.append("crafting context eligibility did not reject missing capability")
	var allowed: Dictionary = service.build_plan(
		recipe.content_id,
		CraftingContext.new().configure([CRAFTING_HAND]),
		inventory
	)
	if not bool(allowed.get("success", false)):
		failures.append("valid crafting context did not satisfy recipe: %s" % [allowed.get("diagnostics", [])])


static func _test_insufficient_ingredients_are_atomic(failures: Array[String]) -> void:
	var recipe = ResourceLoader.load(AXE_RECIPE_PATH)
	var wood = _item("item.resource.wood", 64, ITEM_RESOURCE)
	var stone = _item("item.resource.stone", 64, ITEM_RESOURCE)
	var axe = _item("item.tool.stone_axe", 1, ITEM_TOOL)
	var definitions: Array = [recipe, wood, stone, axe]
	var validation: Dictionary = _validate(definitions)
	var registry = _registry(definitions, failures)
	if registry == null or not bool(validation.get("success", false)):
		failures.append("atomic failure setup did not validate")
		return
	var inventory = ItemContainerState.new().configure(3, 20.0)
	inventory.add_stack(wood, 3)
	inventory.add_stack(stone, 3)
	var before: String = inventory.canonical_json()
	var result: Dictionary = CraftingService.new().configure(registry, validation).craft(
		recipe.content_id,
		CraftingContext.new(),
		inventory
	)
	if bool(result.get("success", false)):
		failures.append("craft with insufficient wood unexpectedly succeeded")
	elif not _has_fragment(result, "insufficient compatible stack quantity"):
		failures.append("insufficient ingredient failure did not come from INV-002: %s" % [result.get("diagnostics", [])])
	if inventory.canonical_json() != before:
		failures.append("failed craft partially mutated inventory")


static func _test_valid_stone_tool_crafts_are_atomic(failures: Array[String]) -> void:
	_run_tool_craft(
		failures,
		AXE_RECIPE_PATH,
		"item.tool.stone_axe",
		4,
		3
	)
	_run_tool_craft(
		failures,
		PICKAXE_RECIPE_PATH,
		"item.tool.stone_pickaxe",
		3,
		4
	)


static func _run_tool_craft(
	failures: Array[String],
	recipe_path: String,
	output_id: String,
	wood_cost: int,
	stone_cost: int
) -> void:
	var recipe = ResourceLoader.load(recipe_path)
	var wood = _item("item.resource.wood", 64, ITEM_RESOURCE)
	var stone = _item("item.resource.stone", 64, ITEM_RESOURCE)
	var output = _item(output_id, 1, ITEM_TOOL)
	output.configure_schema_declarations([ITEM_TOOL], [HARVEST_TOOL])
	var definitions: Array = [recipe, wood, stone, output]
	var validation: Dictionary = _validate(definitions)
	var registry = _registry(definitions, failures)
	if registry == null or not bool(validation.get("success", false)):
		failures.append("valid tool craft setup failed for %s: %s" % [output_id, validation.get("diagnostics", [])])
		return
	var inventory = ItemContainerState.new().configure(3, 30.0)
	inventory.add_stack(wood, wood_cost)
	inventory.add_stack(stone, stone_cost)
	var result: Dictionary = CraftingService.new().configure(registry, validation).craft(
		recipe.content_id,
		CraftingContext.new(),
		inventory
	)
	if not bool(result.get("success", false)):
		failures.append("valid tool craft failed for %s: %s" % [output_id, result.get("diagnostics", [])])
		return
	_expect_equal(failures, "%s wood consumed" % output_id, inventory.quantity_of(wood.content_id), 0)
	_expect_equal(failures, "%s stone consumed" % output_id, inventory.quantity_of(stone.content_id), 0)
	_expect_equal(failures, "%s output produced" % output_id, inventory.quantity_of(output_id), 1)
	if str(result.get("transaction_fingerprint", "")).is_empty():
		failures.append("successful craft omitted INV-002 transaction fingerprint: %s" % output_id)


static func _test_sword_uses_accepted_weapon_definition(failures: Array[String]) -> void:
	var recipe = ResourceLoader.load(SWORD_RECIPE_PATH)
	var sword = ResourceLoader.load(ACCEPTED_SWORD_PATH)
	if sword == null:
		failures.append("accepted WEAPON-001 sword fixture did not load")
		return
	sword.configure_schema_declarations([ITEM_WEAPON], [])
	var sword_before: Dictionary = sword.canonical_descriptor().duplicate(true)
	var wood = _item("item.resource.wood", 64, ITEM_RESOURCE)
	var iron = _item("item.resource.iron_chunk", 64, ITEM_RESOURCE)
	var attack_set = ContentDefinition.new().configure(
		"attack_set.weapon.sword.basic", "attack_set", 1
	)
	var archetype = ContentDefinition.new().configure(
		"archetype.weapon.iron_sword", "archetype", 1
	)
	var definitions: Array = [recipe, wood, iron, sword, attack_set, archetype]
	var validation: Dictionary = _validate(definitions)
	var registry = _registry(definitions, failures)
	if registry == null or not bool(validation.get("success", false)):
		failures.append("accepted sword craft setup failed validation: %s" % [validation.get("diagnostics", [])])
		return
	if registry.get_definition("item.weapon.iron_sword") != sword:
		failures.append("craft registry replaced accepted WEAPON-001 sword definition")
	var inventory = ItemContainerState.new().configure(3, 30.0)
	inventory.add_stack(wood, 1)
	inventory.add_stack(iron, 4)
	var result: Dictionary = CraftingService.new().configure(registry, validation).craft(
		recipe.content_id,
		CraftingContext.new(),
		inventory
	)
	if not bool(result.get("success", false)):
		failures.append("valid accepted-sword craft failed: %s" % [result.get("diagnostics", [])])
		return
	_expect_equal(failures, "iron sword output produced", inventory.quantity_of("item.weapon.iron_sword"), 1)
	if sword.canonical_descriptor() != sword_before:
		failures.append("crafting mutated or cloned WEAPON-001 authored sword definition")


static func _validate(definitions: Array) -> Dictionary:
	return ContentValidationPipeline.new().validate_all(
		definitions,
		_categories(),
		_capabilities(),
		[
			ItemFamilyValidator.new().configure_item_rules([]),
			RecipeFamilyValidator.new().configure_recipe_rules(),
		]
	)


static func _registry(definitions: Array, failures: Array[String]):
	var registry = ContentRegistry.new()
	var diagnostics: Array[String] = registry.index_definitions(definitions)
	if not diagnostics.is_empty():
		failures.append("craft ContentRegistry setup failed: %s" % [diagnostics])
		return null
	return registry


static func _categories():
	var registry = CategorySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CategorySchema.new().configure(ITEM_ROOT),
		CategorySchema.new().configure(ITEM_RESOURCE, [ITEM_ROOT]),
		CategorySchema.new().configure(ITEM_TOOL, [ITEM_ROOT]),
		CategorySchema.new().configure(ITEM_WEAPON, [ITEM_ROOT]),
	])
	assert(diagnostics.is_empty())
	return registry


static func _capabilities():
	var registry = CapabilitySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CapabilitySchema.new().configure(HARVEST_TOOL),
		CapabilitySchema.new().configure(CRAFTING_HAND),
	])
	assert(diagnostics.is_empty())
	return registry


static func _item(content_id: String, stack_limit: int, category_id: String):
	var definition = ItemDefinition.new().configure_item(content_id, stack_limit, 0.1, 1)
	definition.configure_schema_declarations([category_id], [])
	return definition


static func _amount(item_id: String, quantity: int):
	return RecipeItemAmount.new().configure(item_id, quantity)


static func _quantity(descriptors: Array[Dictionary], item_id: String) -> int:
	for descriptor in descriptors:
		if str(descriptor.get("item_id", "")) == item_id:
			return int(descriptor.get("quantity", 0))
	return 0


static func _has_diagnostic(result: Dictionary, code: String, fragment: String) -> bool:
	for diagnostic in result.get("diagnostics", []):
		if (
			str(diagnostic.get("code", "")) == code
			and str(diagnostic.get("message", "")).contains(fragment)
		):
			return true
	return false


static func _has_fragment(result: Dictionary, fragment: String) -> bool:
	for diagnostic in result.get("diagnostics", []):
		if str(diagnostic).contains(fragment):
			return true
	return false


static func _expect_equal(
	failures: Array[String],
	label: String,
	actual: Variant,
	expected: Variant
) -> void:
	if actual != expected:
		failures.append("%s expected %s, got %s" % [label, str(expected), str(actual)])
