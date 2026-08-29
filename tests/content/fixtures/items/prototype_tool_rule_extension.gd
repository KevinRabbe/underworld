extends "res://gameplay/items/validation/item_rule_extension.gd"

const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")

const TOOL_CATEGORY := "category.item.equipment.tool"
const HARVEST_TOOL_CAPABILITY := "capability.harvest_tool"


func _init() -> void:
	configure("prototype.tool")


func applies_to(definition, context: Dictionary) -> bool:
	var category_registry = context.get("category_registry", null)
	return (
		category_registry != null
		and category_registry is CategorySchemaRegistry
		and category_registry.is_valid()
		and category_registry.matches_required_categories(
			definition.category_ids,
			[TOOL_CATEGORY],
			true
		)
	)


func validate_definition(definition, context: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var capability_registry = context.get("capability_registry", null)
	if (
		capability_registry == null
		or not capability_registry is CapabilitySchemaRegistry
		or not capability_registry.is_valid()
	):
		return failures
	if not capability_registry.provides_capability(
		definition.capability_ids,
		HARVEST_TOOL_CAPABILITY
	):
		failures.append(
			"tool category requires capability: %s" % HARVEST_TOOL_CAPABILITY
		)
	return failures
