extends RefCounted

const WeaponDefinition := preload("res://gameplay/items/definitions/weapon_definition.gd")
const AttackCatalog := preload("res://gameplay/combat/attacks/player_attack_catalog.gd")


static func resolve_light_attack(definition):
	if definition == null or not definition is WeaponDefinition:
		return null
	if not definition.validate_definition().is_empty():
		return null
	return AttackCatalog.for_profile(definition.light_attack_profile_id)


static func presentation_binding(definition) -> Dictionary:
	if definition == null or not definition is WeaponDefinition:
		return {}
	if not definition.validate_definition().is_empty():
		return {}
	return {
		"content_id": definition.content_id,
		"archetype_id": definition.presentation_archetype_id,
		"animation_role": definition.attack_animation_role,
		"grip_rig_role": definition.grip_rig_role,
		"grip_style": definition.grip_style,
	}
