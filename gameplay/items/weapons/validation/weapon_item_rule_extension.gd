extends "res://gameplay/items/validation/item_rule_extension.gd"

const ItemDefinitionScript := preload("res://gameplay/items/definitions/item_definition.gd")
const WeaponDefinitionScript := preload("res://gameplay/items/weapons/definitions/weapon_definition.gd")
const WeaponAttackSetDefinitionScript := preload("res://gameplay/items/weapons/definitions/weapon_attack_set_definition.gd")
const CategorySchemaRegistryScript := preload("res://core/content/schema/category_schema_registry.gd")
const SemanticRoleSchemaRegistryScript := preload("res://core/content/schema/semantic_role_schema_registry.gd")
const ContentRegistryScript := preload("res://core/content/registry/content_registry.gd")
const ArchetypeDefinitionScript := preload("res://core/content/archetypes/archetype_definition.gd")

const WEAPON_ROOT_CATEGORY := "category.item.equipment.weapon"
const EQUIPABLE_CAPABILITY := "capability.equipable"
const DAMAGE_DEALER_CAPABILITY := "capability.damage_dealer"
const ALLOWED_GRIP_ROLES: Array[String] = [
	"rig_role.socket.hand.left",
	"rig_role.socket.hand.right",
]

var _role_registry


func configure_weapon_rules(role_registry) -> RefCounted:
	configure("weapon")
	_role_registry = role_registry
	return self


func validate_extension() -> Array[String]:
	var failures: Array[String] = super.validate_extension()
	if _role_registry == null or not _role_registry is SemanticRoleSchemaRegistryScript:
		failures.append("weapon rule extension requires SemanticRoleSchemaRegistry")
	elif not _role_registry.is_valid():
		for failure in _role_registry.diagnostics():
			failures.append("weapon semantic role registry: %s" % failure)
	failures.sort()
	return failures


func applies_to(definition, context: Dictionary) -> bool:
	if definition != null and definition is WeaponDefinitionScript:
		return true
	if definition == null or not definition is ItemDefinitionScript:
		return false
	var category_registry = context.get("category_registry", null)
	if (
		category_registry != null
		and category_registry is CategorySchemaRegistryScript
		and category_registry.is_valid()
	):
		for category_id in definition.category_ids:
			if (
				category_registry.has_schema(category_id)
				and category_registry.is_category_or_descendant(
					category_id,
					WEAPON_ROOT_CATEGORY
				)
			):
				return true
	return definition.category_ids.has(WEAPON_ROOT_CATEGORY)


func validate_definition(definition, context: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if definition == null:
		return failures
	if not definition is WeaponDefinitionScript:
		failures.append(
			"weapon-category item must inherit WeaponDefinition: %s" % str(definition.content_id)
		)
		return failures

	_validate_category(definition, context, failures)
	if not definition.capability_ids.has(EQUIPABLE_CAPABILITY):
		failures.append("weapon requires capability: %s" % EQUIPABLE_CAPABILITY)
	if not definition.capability_ids.has(DAMAGE_DEALER_CAPABILITY):
		failures.append("weapon requires capability: %s" % DAMAGE_DEALER_CAPABILITY)
	_validate_semantic_roles(definition, failures)
	_validate_reference_targets(definition, context, failures)
	failures.sort()
	return failures


func _validate_category(definition, context: Dictionary, failures: Array[String]) -> void:
	var category_registry = context.get("category_registry", null)
	if (
		category_registry == null
		or not category_registry is CategorySchemaRegistryScript
		or not category_registry.is_valid()
	):
		return
	if not category_registry.has_schema(WEAPON_ROOT_CATEGORY):
		failures.append("weapon root category schema is not registered: %s" % WEAPON_ROOT_CATEGORY)
		return
	var has_weapon_category := false
	for category_id in definition.category_ids:
		if not category_registry.has_schema(category_id):
			continue
		if category_registry.is_category_or_descendant(category_id, WEAPON_ROOT_CATEGORY):
			has_weapon_category = true
	if not has_weapon_category:
		failures.append("weapon must declare a category under %s" % WEAPON_ROOT_CATEGORY)


func _validate_semantic_roles(definition, failures: Array[String]) -> void:
	if (
		_role_registry == null
		or not _role_registry is SemanticRoleSchemaRegistryScript
		or not _role_registry.is_valid()
	):
		return
	if not _role_registry.has_animation_role(definition.attack_animation_role):
		failures.append("unknown weapon attack animation role: %s" % definition.attack_animation_role)
	if not _role_registry.has_rig_role(definition.grip_rig_role):
		failures.append("unknown weapon grip rig role: %s" % definition.grip_rig_role)
	elif not ALLOWED_GRIP_ROLES.has(definition.grip_rig_role):
		failures.append("weapon grip rig role must be a hand socket: %s" % definition.grip_rig_role)


func _validate_reference_targets(
	definition,
	context: Dictionary,
	failures: Array[String]
) -> void:
	var content_registry = context.get("content_registry", null)
	if content_registry == null or not content_registry is ContentRegistryScript:
		return

	var attack_set = _resolved_definition(
		content_registry,
		definition.attack_set_id,
		WeaponDefinitionScript.ATTACK_SET_FAMILY
	)
	if attack_set != null:
		if not attack_set is WeaponAttackSetDefinitionScript:
			failures.append(
				"weapon attack-set target must inherit WeaponAttackSetDefinition: %s" % definition.attack_set_id
			)
		elif not attack_set.has_technique(definition.primary_technique_role):
			failures.append("weapon attack set does not provide primary technique role: %s" % definition.primary_technique_role)

	var archetype = _resolved_definition(
		content_registry,
		definition.archetype_id,
		WeaponDefinitionScript.ARCHETYPE_FAMILY
	)
	if archetype != null and not archetype is ArchetypeDefinitionScript:
		failures.append("weapon archetype target must inherit ArchetypeDefinition: %s" % definition.archetype_id)


static func _resolved_definition(content_registry, content_id: String, family: String):
	var resolved: Dictionary = content_registry.resolve(content_id, family)
	if not resolved.get("diagnostics", []).is_empty():
		return null
	return resolved.get("definition", null)