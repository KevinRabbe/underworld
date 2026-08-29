extends "res://core/content/validation/content_family_validator.gd"

const ResourceDefinition := preload("res://gameplay/resources/definitions/resource_definition.gd")
const ResourceYieldEntry := preload("res://gameplay/resources/definitions/resource_yield_entry.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")

const RESOURCE_ROOT_CATEGORY := "category.world_resource"

var required_category_id: String = ""
var required_capability_ids: Array[String] = []


func configure_resource_rules(
	p_definition_family: String,
	p_required_category_id: String,
	p_required_capability_ids: Array = []
) -> RefCounted:
	configure(p_definition_family)
	required_category_id = p_required_category_id
	required_capability_ids.clear()
	for capability_id in p_required_capability_ids:
		required_capability_ids.append(str(capability_id))
	return self


func validate_validator() -> Array[String]:
	var failures: Array[String] = super.validate_validator()
	if required_category_id.is_empty():
		failures.append("resource family validator requires a category root")
	for capability_id in required_capability_ids:
		if capability_id.is_empty():
			failures.append("resource family validator capability id must not be empty")
	failures.sort()
	return failures


func validate_definition(definition, context: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if definition == null:
		return failures
	if not definition is ResourceDefinition:
		failures.append("resource-family definition must inherit ResourceDefinition: %s" % str(definition.content_id))
		return failures

	var category_registry = context.get("category_registry", null)
	if (
		category_registry != null
		and category_registry is CategorySchemaRegistry
		and category_registry.is_valid()
	):
		if not category_registry.has_schema(RESOURCE_ROOT_CATEGORY):
			failures.append("resource root category schema is not registered: %s" % RESOURCE_ROOT_CATEGORY)
		elif not category_registry.has_schema(required_category_id):
			failures.append("required resource category schema is not registered: %s" % required_category_id)
		elif definition.category_ids.is_empty():
			failures.append("resource '%s' must declare a category under %s" % [definition.content_id, required_category_id])
		else:
			var matched_required_category: bool = false
			for category_id in definition.category_ids:
				if not category_registry.has_schema(category_id):
					continue
				if not category_registry.is_category_or_descendant(category_id, RESOURCE_ROOT_CATEGORY):
					failures.append("resource '%s' declares category outside %s: %s" % [
						definition.content_id,
						RESOURCE_ROOT_CATEGORY,
						category_id,
					])
				if category_registry.is_category_or_descendant(category_id, required_category_id):
					matched_required_category = true
			if not matched_required_category:
				failures.append("resource '%s' must declare category under %s" % [definition.content_id, required_category_id])

	for capability_id in required_capability_ids:
		if not definition.capability_ids.has(capability_id):
			failures.append("resource '%s' requires capability: %s" % [definition.content_id, capability_id])

	var content_registry = context.get("content_registry", null)
	if content_registry != null:
		for entry in definition.yield_entries:
			if entry == null or not entry is ResourceYieldEntry:
				continue
			var resolved: Dictionary = content_registry.resolve(entry.item_content_id, "item")
			if not resolved.get("diagnostics", []).is_empty():
				continue
			var target = resolved.get("definition", null)
			if target == null or not target is ItemDefinition:
				failures.append("resource yield target must inherit ItemDefinition: %s" % entry.item_content_id)

	failures.sort()
	return failures
