extends "res://gameplay/items/validation/item_rule_extension.gd"

const WeaponDefinition := preload("res://gameplay/items/definitions/weapon_definition.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const SemanticRoleSchemaRegistry := preload("res://core/content/schema/semantic_role_schema_registry.gd")
const AttackCatalog := preload("res://gameplay/combat/attacks/player_attack_catalog.gd")

const WEAPON_ROOT_CATEGORY := "category.item.equipment.weapon"
const DAMAGE_DEALER_CAPABILITY := "capability.damage_dealer"

var _semantic_role_registry


func configure_weapon_rules(semantic_role_registry) -> RefCounted:
	configure("weapon")
	_semantic_role_registry = semantic_role_registry
	return self


func validate_extension() -> Array[String]:
	var failures: Array[String] = super.validate_extension()
	if _semantic_role_registry == null or not _semantic_role_registry is SemanticRoleSchemaRegistry:
		failures.append("weapon rules require a SemanticRoleSchemaRegistry")
	elif not _semantic_role_registry.is_valid():
		failures.append("weapon semantic role registry must be valid")
	failures.sort()
	return failures


func applies_to(definition, _context: Dictionary) -> bool:
	if definition == null:
		return false
	if definition is WeaponDefinition:
		return true
	for category_id in definition.category_ids:
		var value: String = str(category_id)
		if value == WEAPON_ROOT_CATEGORY or value.begins_with(WEAPON_ROOT_CATEGORY + "."):
			return true
	return false


func validate_definition(definition, context: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if not definition is WeaponDefinition:
		failures.append("weapon-category item must inherit WeaponDefinition")
		return failures

	var category_registry = context.get("category_registry", null)
	var has_weapon_category: bool = false
	if category_registry != null and category_registry is CategorySchemaRegistry and category_registry.is_valid():
		if not category_registry.has_schema(WEAPON_ROOT_CATEGORY):
			failures.append("weapon root category schema is not registered: %s" % WEAPON_ROOT_CATEGORY)
		else:
			for category_id in definition.category_ids:
				if (
					category_registry.has_schema(category_id)
					and category_registry.is_category_or_descendant(category_id, WEAPON_ROOT_CATEGORY)
				):
					has_weapon_category = true
					break
	if not has_weapon_category:
		failures.append("weapon must declare a registered category under %s" % WEAPON_ROOT_CATEGORY)

	if not definition.capability_ids.has(DAMAGE_DEALER_CAPABILITY):
		failures.append("weapon requires capability %s" % DAMAGE_DEALER_CAPABILITY)

	if not AttackCatalog.has_profile(definition.light_attack_profile_id):
		failures.append("weapon light attack profile is not registered by the attack-definition boundary: %s" % definition.light_attack_profile_id)

	if _semantic_role_registry != null and _semantic_role_registry is SemanticRoleSchemaRegistry and _semantic_role_registry.is_valid():
		if not _semantic_role_registry.has_animation_role(definition.attack_animation_role):
			failures.append("weapon attack animation role is not registered: %s" % definition.attack_animation_role)
		if not _semantic_role_registry.has_rig_role(definition.grip_rig_role):
			failures.append("weapon grip rig role is not registered: %s" % definition.grip_rig_role)

	failures.sort()
	return failures
