extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const ArchetypeComposition := preload("res://core/content/archetypes/archetype_composition.gd")
const ArchetypeDefinition := preload("res://core/content/archetypes/archetype_definition.gd")
const ArchetypeFamilyValidator := preload("res://core/content/archetypes/archetype_family_validator.gd")
const ArchetypeRealizer := preload("res://core/content/archetypes/archetype_realizer.gd")
const PackedSceneArchetypeAdapter := preload("res://core/content/archetypes/packed_scene_archetype_adapter.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemFamilyValidator := preload("res://gameplay/items/validation/item_family_validator.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const RecipeItemAmount := preload("res://gameplay/crafting/definitions/recipe_item_amount.gd")
const RecipeDefinition := preload("res://gameplay/crafting/definitions/recipe_definition.gd")
const RecipeFamilyValidator := preload("res://gameplay/crafting/validation/recipe_family_validator.gd")
const CraftingContext := preload("res://gameplay/crafting/runtime/crafting_context.gd")
const CraftingService := preload("res://gameplay/crafting/runtime/crafting_service.gd")

const ARCHETYPE_SCENE := "res://tests/content/fixtures/archetypes/variant_alpha.tscn"
const SPAWNABLE := "capability.realization.spawnable"
const ITEM_ROOT := "category.item"
const ITEM_RESOURCE := "category.item.resource"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_archetype_realizer_rejects_stale_snapshot(failures)
	_test_crafting_rechecks_stale_snapshot_before_mutation(failures)
	return failures


static func _test_archetype_realizer_rejects_stale_snapshot(failures: Array[String]) -> void:
	var categories = CategorySchemaRegistry.new()
	assert(categories.index_schemas([]).is_empty())
	var capabilities = CapabilitySchemaRegistry.new()
	assert(capabilities.index_schemas([
		CapabilitySchema.new().configure(SPAWNABLE),
	]).is_empty())
	var composition = ArchetypeComposition.new().configure(
		"packed.scene",
		ResourceLoader.load(ARCHETYPE_SCENE),
		["root"],
		[SPAWNABLE]
	)
	var archetype = ArchetypeDefinition.new().configure_archetype(
		"archetype.test.snapshot_consumer",
		"archetype",
		composition,
		1
	)
	archetype.configure_schema_declarations([], [SPAWNABLE])
	var validator = ArchetypeFamilyValidator.new().configure("archetype")
	var validation: Dictionary = ContentValidationPipeline.new().validate_all(
		[archetype],
		categories,
		capabilities,
		[validator]
	)
	if not bool(validation.get("success", false)):
		failures.append("archetype consumer snapshot setup failed validation: %s" % [validation.get("diagnostics", [])])
		return
	var registry = ContentRegistry.new()
	if not registry.index_definitions([archetype]).is_empty():
		failures.append("archetype consumer snapshot registry setup failed")
		return
	var realizer = ArchetypeRealizer.new()
	if not realizer.register_adapter(PackedSceneArchetypeAdapter.new()).is_empty():
		failures.append("archetype consumer snapshot could not register PackedScene adapter")
		return

	var matching: Dictionary = realizer.realize(registry, validation, archetype.content_id)
	if not bool(matching.get("success", false)):
		failures.append("matching CONTENT-006 evidence did not permit archetype realization: %s" % [matching.get("diagnostics", [])])
	else:
		_free_instance(matching)

	archetype.schema_revision = 2
	if not registry.index_definitions([archetype]).is_empty():
		failures.append("archetype consumer snapshot could not reindex canonical mutation")
		return
	var stale: Dictionary = realizer.realize(registry, validation, archetype.content_id)
	if bool(stale.get("success", false)):
		failures.append("stale CONTENT-006 archetype evidence still allowed realization")
		_free_instance(stale)
	if stale.get("instance", null) != null:
		failures.append("stale CONTENT-006 archetype evidence reached realization adapter")
	if not _contains_fragment(stale.get("diagnostics", []), "snapshot mismatch"):
		failures.append("stale archetype rejection did not identify CONTENT-006 snapshot mismatch")


static func _test_crafting_rechecks_stale_snapshot_before_mutation(failures: Array[String]) -> void:
	var categories = CategorySchemaRegistry.new()
	assert(categories.index_schemas([
		CategorySchema.new().configure(ITEM_ROOT),
		CategorySchema.new().configure(ITEM_RESOURCE, [ITEM_ROOT]),
	]).is_empty())
	var capabilities = CapabilitySchemaRegistry.new()
	assert(capabilities.index_schemas([]).is_empty())
	var ingredient = ItemDefinition.new().configure_item(
		"item.resource.snapshot_input",
		64,
		0.1,
		1
	)
	ingredient.configure_schema_declarations([ITEM_RESOURCE], [])
	var output = ItemDefinition.new().configure_item(
		"item.resource.snapshot_output",
		64,
		0.1,
		1
	)
	output.configure_schema_declarations([ITEM_RESOURCE], [])
	var ingredient_amount = RecipeItemAmount.new().configure(ingredient.content_id, 1)
	var recipe = RecipeDefinition.new().configure_recipe(
		"recipe.test.snapshot_consumer",
		[ingredient_amount],
		[RecipeItemAmount.new().configure(output.content_id, 1)]
	)
	var definitions: Array = [recipe, ingredient, output]
	var validation: Dictionary = ContentValidationPipeline.new().validate_all(
		definitions,
		categories,
		capabilities,
		[
			ItemFamilyValidator.new().configure_item_rules([]),
			RecipeFamilyValidator.new().configure_recipe_rules(),
		]
	)
	if not bool(validation.get("success", false)):
		failures.append("crafting consumer snapshot setup failed validation: %s" % [validation.get("diagnostics", [])])
		return
	var registry = ContentRegistry.new()
	var registry_failures: Array[String] = registry.index_definitions(definitions)
	if not registry_failures.is_empty():
		failures.append("crafting consumer snapshot registry setup failed: %s" % [registry_failures])
		return
	var inventory = ItemContainerState.new().configure(3, 10.0)
	inventory.add_stack(ingredient, 1)
	var service = CraftingService.new().configure(registry, validation)
	var matching: Dictionary = service.build_plan(
		recipe.content_id,
		CraftingContext.new(),
		inventory
	)
	if not bool(matching.get("success", false)):
		failures.append("matching CONTENT-006 evidence did not permit crafting plan: %s" % [matching.get("diagnostics", [])])
		return

	var before: String = inventory.canonical_json()
	ingredient_amount.quantity = 2
	registry_failures = registry.index_definitions(definitions)
	if not registry_failures.is_empty():
		failures.append("crafting consumer snapshot could not reindex canonical recipe mutation: %s" % [registry_failures])
		return
	var stale: Dictionary = service.craft(
		recipe.content_id,
		CraftingContext.new(),
		inventory
	)
	if bool(stale.get("success", false)):
		failures.append("stale CONTENT-006 crafting evidence unexpectedly committed")
	if not _contains_fragment(stale.get("diagnostics", []), "snapshot mismatch"):
		failures.append("stale crafting rejection did not identify CONTENT-006 snapshot mismatch")
	if str(stale.get("transaction_fingerprint", "")) != "":
		failures.append("stale crafting evidence emitted a transaction fingerprint")
	if int(stale.get("operation_count", 0)) != 0:
		failures.append("stale crafting evidence emitted inventory operations")
	if not stale.get("events", []).is_empty():
		failures.append("stale crafting evidence emitted inventory events")
	if inventory.canonical_json() != before:
		failures.append("stale crafting evidence mutated inventory before rejection")


static func _contains_fragment(values: Array, fragment: String) -> bool:
	for value in values:
		if str(value).contains(fragment):
			return true
	return false


static func _free_instance(result: Dictionary) -> void:
	var instance = result.get("instance", null)
	if instance != null and instance is Node and is_instance_valid(instance):
		instance.free()
