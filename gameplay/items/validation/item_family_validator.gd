extends "res://core/content/validation/content_family_validator.gd"

const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemRuleExtension := preload("res://gameplay/items/validation/item_rule_extension.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")

const ITEM_FAMILY := "item"
const ITEM_ROOT_CATEGORY := "category.item"

var _rule_extensions: Array = []


func configure_item_rules(rule_extensions: Array = []) -> RefCounted:
	configure(ITEM_FAMILY)
	_rule_extensions.clear()
	_rule_extensions.append_array(rule_extensions)
	return self


func validate_validator() -> Array[String]:
	var failures: Array[String] = super.validate_validator()
	if definition_family != ITEM_FAMILY:
		failures.append("item family validator must target '%s'" % ITEM_FAMILY)
	for extension in _rule_extensions:
		if extension == null or not extension is ItemRuleExtension:
			failures.append("item rule extension must inherit ItemRuleExtension")
			continue
		for failure in extension.validate_extension():
			failures.append("item rule extension '%s': %s" % [extension.rule_id, failure])
	failures.sort()
	return failures


func applies_to(definition) -> bool:
	return super.applies_to(definition)


func validate_definition(definition, context: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if definition == null:
		return failures
	if not definition is ItemDefinition:
		failures.append(
			"item-family definition must inherit ItemDefinition: %s" % str(definition.content_id)
		)
		return failures

	var category_registry = context.get("category_registry", null)
	if (
		category_registry != null
		and category_registry is CategorySchemaRegistry
		and category_registry.is_valid()
	):
		if not category_registry.has_schema(ITEM_ROOT_CATEGORY):
			failures.append("item root category schema is not registered: %s" % ITEM_ROOT_CATEGORY)
		elif definition.category_ids.is_empty():
			failures.append("item '%s' must declare a category under %s" % [
				definition.content_id,
				ITEM_ROOT_CATEGORY,
			])
		else:
			for category_id in definition.category_ids:
				if not category_registry.has_schema(category_id):
					continue
				if not category_registry.is_category_or_descendant(category_id, ITEM_ROOT_CATEGORY):
					failures.append(
						"item '%s' declares category outside %s: %s" % [
							definition.content_id,
							ITEM_ROOT_CATEGORY,
							category_id,
						]
					)

	for extension in _rule_extensions:
		if extension == null or not extension is ItemRuleExtension:
			continue
		if not extension.applies_to(definition, context):
			continue
		for failure in extension.validate_definition(definition, context):
			failures.append("rule '%s': %s" % [extension.rule_id, failure])

	failures.sort()
	return failures
