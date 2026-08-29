extends "res://core/content/validation/content_family_validator.gd"

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CreatureDefinition := preload("res://gameplay/creatures/definitions/creature_definition.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const LootProfileDefinition := preload("res://gameplay/loot/definitions/loot_profile_definition.gd")

const LOOT_PROFILE_FAMILY := "loot_profile"


func configure_loot_rules() -> RefCounted:
	configure(LOOT_PROFILE_FAMILY)
	return self


func validate_validator() -> Array[String]:
	var failures: Array[String] = super.validate_validator()
	if definition_family != LOOT_PROFILE_FAMILY:
		failures.append("loot family validator must target '%s'" % LOOT_PROFILE_FAMILY)
	failures.sort()
	return failures


func validate_definition(definition, context: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if definition == null:
		return failures
	if not definition is LootProfileDefinition:
		failures.append(
			"loot-profile definition must inherit LootProfileDefinition: %s" % str(definition.content_id)
		)
		return failures

	var content_registry = context.get("content_registry", null)
	if content_registry == null or not content_registry is ContentRegistry:
		return failures

	var creature_resolution: Dictionary = content_registry.resolve(
		definition.source_creature_id,
		LootProfileDefinition.CREATURE_FAMILY
	)
	if creature_resolution.get("diagnostics", []).is_empty():
		var creature = creature_resolution.get("definition", null)
		if creature != null and not creature is CreatureDefinition:
			failures.append(
				"loot source creature target must inherit CreatureDefinition: %s" % definition.source_creature_id
			)

	for entry in definition.reward_entries():
		var item_id: String = str(entry.get("item_id", ""))
		var item_resolution: Dictionary = content_registry.resolve(
			item_id,
			LootProfileDefinition.ITEM_FAMILY
		)
		if not item_resolution.get("diagnostics", []).is_empty():
			continue
		var item = item_resolution.get("definition", null)
		if item != null and not item is ItemDefinition:
			failures.append(
				"loot reward item target must inherit ItemDefinition: %s" % item_id
			)
	failures.sort()
	return failures
