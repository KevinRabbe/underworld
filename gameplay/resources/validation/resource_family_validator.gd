extends "res://core/content/validation/content_family_validator.gd"

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ResourceDefinition := preload("res://gameplay/resources/definitions/resource_definition.gd")
const ResourceYieldRule := preload("res://gameplay/resources/definitions/resource_yield_rule.gd")
const ResourceRuleExtension := preload("res://gameplay/resources/validation/resource_rule_extension.gd")

const RESOURCE_FAMILY := "resource"
const RESOURCE_ROOT_CATEGORY := "category.resource"

var _rule_extensions: Array = []


func configure_resource_rules(rule_extensions: Array = []) -> RefCounted:
	configure(RESOURCE_FAMILY)
	_rule_extensions.clear()
	_rule_extensions.append_array(rule_extensions)
	return self


func validate_validator() -> Array[String]:
	var failures: Array[String] = super.validate_validator()
	if definition_family != RESOURCE_FAMILY:
		failures.append("resource family validator must target '%s'" % RESOURCE_FAMILY)
	for extension in _rule_extensions:
		if extension == null or not extension is ResourceRuleExtension:
			failures.append("resource rule extension must inherit ResourceRuleExtension")
			continue
		for failure in extension.validate_extension():
			failures.append("resource rule extension '%s': %s" % [extension.rule_id, failure])
	failures.sort()
	return failures


func applies_to(definition) -> bool:
	return super.applies_to(definition)


func validate_definition(definition, context: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if definition == null:
		return failures
	if not definition is ResourceDefinition:
		failures.append(
			"resource-family definition must inherit ResourceDefinition: %s" % str(definition.content_id)
		)
		return failures

	var category_registry = context.get("category_registry", null)
	if (
		category_registry != null
		and category_registry is CategorySchemaRegistry
		and category_registry.is_valid()
	):
		if not category_registry.has_schema(RESOURCE_ROOT_CATEGORY):
			failures.append(
				"resource root category schema is not registered: %s" % RESOURCE_ROOT_CATEGORY
			)
		elif definition.category_ids.is_empty():
			failures.append("resource '%s' must declare a category under %s" % [
				definition.content_id,
				RESOURCE_ROOT_CATEGORY,
			])
		else:
			for category_id in definition.category_ids:
				if not category_registry.has_schema(category_id):
					continue
				if not category_registry.is_category_or_descendant(
					category_id,
					RESOURCE_ROOT_CATEGORY
				):
					failures.append(
						"resource '%s' declares category outside %s: %s" % [
							definition.content_id,
							RESOURCE_ROOT_CATEGORY,
							category_id,
						]
					)

	var content_registry = context.get("content_registry", null)
	if content_registry != null and content_registry is ContentRegistry:
		for candidate in definition.yield_rules():
			if candidate == null or not candidate is ResourceYieldRule:
				continue
			var reference = candidate.validation_reference()
			if reference == null or str(reference.expected_family) != "item":
				continue
			var resolved: Dictionary = content_registry.resolve(reference.target_id, "item")
			if not resolved.get("diagnostics", []).is_empty():
				continue
			var target = resolved.get("definition", null)
			if target == null or not target is ItemDefinition:
				failures.append(
					"resource yield target must inherit accepted ItemDefinition: %s" % reference.target_id
				)

	for extension in _rule_extensions:
		if extension == null or not extension is ResourceRuleExtension:
			continue
		if not extension.applies_to(definition, context):
			continue
		for failure in extension.validate_definition(definition, context):
			failures.append("rule '%s': %s" % [extension.rule_id, failure])

	failures.sort()
	return failures
