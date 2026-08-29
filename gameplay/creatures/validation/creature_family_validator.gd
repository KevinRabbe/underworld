extends "res://core/content/validation/content_family_validator.gd"

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CreatureDefinition := preload("res://gameplay/creatures/definitions/creature_definition.gd")
const CreatureAttackProfileDefinition := preload("res://gameplay/creatures/definitions/creature_attack_profile_definition.gd")
const ArchetypeDefinition := preload("res://core/content/archetypes/archetype_definition.gd")
const AnimationSetDefinition := preload("res://presentation/characters/animation/animation_set_definition.gd")
const RigProfileDefinition := preload("res://presentation/characters/animation/rig_profile_definition.gd")

const CREATURE_FAMILY := "creature"
const CREATURE_ROOT_CATEGORY := "category.creature"
const ENEMY_CATEGORY := "category.creature.enemy"
const MOVEMENT_CAPABILITY := "capability.movement"
const SENSING_CAPABILITY := "capability.sensing"
const MELEE_CAPABILITY := "capability.combat.melee"


func configure_creature_rules() -> RefCounted:
	configure(CREATURE_FAMILY)
	return self


func validate_validator() -> Array[String]:
	var failures: Array[String] = super.validate_validator()
	if definition_family != CREATURE_FAMILY:
		failures.append("creature family validator must target '%s'" % CREATURE_FAMILY)
	failures.sort()
	return failures


func applies_to(definition) -> bool:
	return super.applies_to(definition)


func validate_definition(definition, context: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if definition == null:
		return failures
	if not definition is CreatureDefinition:
		failures.append(
			"creature-family definition must inherit CreatureDefinition: %s" % str(definition.content_id)
		)
		return failures

	_validate_categories_and_capabilities(definition, context, failures)
	_validate_semantic_targets(definition, context, failures)
	failures.sort()
	return failures


func _validate_categories_and_capabilities(
	definition,
	context: Dictionary,
	failures: Array[String]
) -> void:
	var category_registry = context.get("category_registry", null)
	if (
		category_registry != null
		and category_registry is CategorySchemaRegistry
		and category_registry.is_valid()
	):
		if not category_registry.has_schema(CREATURE_ROOT_CATEGORY):
			failures.append(
				"creature root category schema is not registered: %s" % CREATURE_ROOT_CATEGORY
			)
		elif definition.category_ids.is_empty():
			failures.append("creature '%s' must declare a category under %s" % [
				definition.content_id,
				CREATURE_ROOT_CATEGORY,
			])
		else:
			for category_id in definition.category_ids:
				if not category_registry.has_schema(category_id):
					continue
				if not category_registry.is_category_or_descendant(
					category_id,
					CREATURE_ROOT_CATEGORY
				):
					failures.append(
						"creature '%s' declares category outside %s: %s" % [
							definition.content_id,
							CREATURE_ROOT_CATEGORY,
							category_id,
						]
					)

	if ENEMY_CATEGORY in definition.category_ids:
		for required_capability in [
			MOVEMENT_CAPABILITY,
			SENSING_CAPABILITY,
			MELEE_CAPABILITY,
		]:
			if required_capability not in definition.capability_ids:
				failures.append(
					"enemy creature '%s' requires capability: %s" % [
						definition.content_id,
						required_capability,
					]
				)


func _validate_semantic_targets(
	definition,
	context: Dictionary,
	failures: Array[String]
) -> void:
	var content_registry = context.get("content_registry", null)
	if content_registry == null or not content_registry is ContentRegistry:
		return

	var attack_profile = _resolve_definition(
		content_registry,
		definition.attack_profile_id,
		CreatureDefinition.ATTACK_PROFILE_FAMILY
	)
	if attack_profile != null and not attack_profile is CreatureAttackProfileDefinition:
		failures.append(
			"creature attack profile target must inherit CreatureAttackProfileDefinition: %s" % definition.attack_profile_id
		)

	var archetype = _resolve_definition(
		content_registry,
		definition.archetype_id,
		CreatureDefinition.ARCHETYPE_FAMILY
	)
	if archetype != null and not archetype is ArchetypeDefinition:
		failures.append(
			"creature archetype target must inherit accepted ArchetypeDefinition: %s" % definition.archetype_id
		)

	var animation_set = _resolve_definition(
		content_registry,
		definition.animation_set_id,
		CreatureDefinition.ANIMATION_SET_FAMILY
	)
	if animation_set != null:
		if not animation_set is AnimationSetDefinition:
			failures.append(
				"creature animation-set target must inherit AnimationSetDefinition: %s" % definition.animation_set_id
			)
		else:
			if str(animation_set.rig_profile_id) != str(definition.rig_profile_id):
				failures.append(
					"creature animation-set rig profile does not match creature rig profile: %s -> %s" % [
						definition.animation_set_id,
						definition.rig_profile_id,
					]
				)
			for role_id in definition.required_animation_role_ids:
				var resolution: Dictionary = animation_set.resolve_role_binding(role_id)
				if not resolution.get("diagnostics", []).is_empty():
					failures.append(
						"creature animation set does not satisfy required role %s: %s" % [
							role_id,
							resolution.get("diagnostics", []),
						]
					)

	var rig_profile = _resolve_definition(
		content_registry,
		definition.rig_profile_id,
		CreatureDefinition.RIG_PROFILE_FAMILY
	)
	if rig_profile != null:
		if not rig_profile is RigProfileDefinition:
			failures.append(
				"creature rig-profile target must inherit RigProfileDefinition: %s" % definition.rig_profile_id
			)
		else:
			for role_id in definition.required_rig_role_ids:
				if rig_profile.binding_for_role(role_id).is_empty():
					failures.append(
						"creature rig profile does not satisfy required role: %s" % role_id
					)


static func _resolve_definition(content_registry, content_id: String, family: String):
	var resolved: Dictionary = content_registry.resolve(content_id, family)
	if not resolved.get("diagnostics", []).is_empty():
		return null
	return resolved.get("definition", null)
