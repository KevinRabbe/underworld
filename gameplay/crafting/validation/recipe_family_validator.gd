extends "res://core/content/validation/content_family_validator.gd"

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const RecipeDefinition := preload("res://gameplay/crafting/definitions/recipe_definition.gd")

const RECIPE_FAMILY := "recipe"


func configure_recipe_rules() -> RefCounted:
	configure(RECIPE_FAMILY)
	return self


func validate_validator() -> Array[String]:
	var failures: Array[String] = super.validate_validator()
	if definition_family != RECIPE_FAMILY:
		failures.append("recipe family validator must target '%s'" % RECIPE_FAMILY)
	failures.sort()
	return failures


func applies_to(definition) -> bool:
	return super.applies_to(definition)


func validate_definition(definition, context: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if definition == null:
		return failures
	if not definition is RecipeDefinition:
		failures.append(
			"recipe-family definition must inherit RecipeDefinition: %s" % str(definition.content_id)
		)
		return failures

	var content_registry = context.get("content_registry", null)
	if content_registry == null or not content_registry is ContentRegistry:
		failures.append("recipe validation requires accepted ContentRegistry")
	else:
		for item_id in definition.referenced_item_ids():
			var resolved: Dictionary = content_registry.resolve(item_id, "item")
			if not resolved.get("diagnostics", []).is_empty():
				continue
			var item_definition = resolved.get("definition", null)
			if item_definition == null or not item_definition is ItemDefinition:
				failures.append(
					"recipe item target must inherit accepted ItemDefinition: %s" % item_id
				)

	var capability_registry = context.get("capability_registry", null)
	if (
		capability_registry != null
		and capability_registry is CapabilitySchemaRegistry
		and capability_registry.is_valid()
	):
		for capability_id in definition.required_context_capabilities:
			if not capability_registry.has_schema(capability_id):
				failures.append(
					"recipe requires unknown crafting context capability: %s" % capability_id
				)
	failures.sort()
	return failures
