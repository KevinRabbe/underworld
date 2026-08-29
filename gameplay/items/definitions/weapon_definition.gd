extends "res://gameplay/items/definitions/item_definition.gd"

const ATTACK_PROFILE_FAMILY := "attack_profile"

@export var light_attack_profile_id: String = ""
@export var attack_animation_role: String = "animation_role.action.attack.light_01"
@export var grip_rig_role: String = "rig_role.socket.hand.right"
@export var presentation_archetype_id: String = ""
@export var grip_style: String = "one_handed"


func configure_weapon(
	p_content_id: String,
	p_light_attack_profile_id: String,
	p_presentation_archetype_id: String,
	p_attack_animation_role: String = "animation_role.action.attack.light_01",
	p_grip_rig_role: String = "rig_role.socket.hand.right",
	p_grip_style: String = "one_handed",
	p_unit_weight: float = 0.0,
	p_schema_revision: int = 1
) -> Resource:
	configure_item(p_content_id, 1, p_unit_weight, p_schema_revision)
	light_attack_profile_id = p_light_attack_profile_id
	presentation_archetype_id = p_presentation_archetype_id
	attack_animation_role = p_attack_animation_role
	grip_rig_role = p_grip_rig_role
	grip_style = p_grip_style
	return self


func validation_references() -> Array:
	var result: Array = super.validation_references()
	if not presentation_archetype_id.is_empty():
		result.append(ContentReference.new(
			content_id,
			"presentation.archetype",
			presentation_archetype_id,
			"archetype",
			true
		))
	return result


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if not _is_attack_profile_id(light_attack_profile_id):
		failures.append("weapon light attack profile must be a semantic attack_profile.* id: %s" % light_attack_profile_id)
	if (
		not SchemaId.is_valid_animation_role(attack_animation_role)
		or not attack_animation_role.begins_with("animation_role.action.attack.")
	):
		failures.append("weapon attack animation role must be an animation_role.action.attack.* id: %s" % attack_animation_role)
	if (
		not SchemaId.is_valid_rig_role(grip_rig_role)
		or not grip_rig_role.begins_with("rig_role.socket.")
	):
		failures.append("weapon grip rig role must be a rig_role.socket.* id: %s" % grip_rig_role)
	if presentation_archetype_id.is_empty() or not ContentId.is_valid(presentation_archetype_id):
		failures.append("weapon presentation archetype must be a semantic ContentId: %s" % presentation_archetype_id)
	if grip_style.is_empty() or grip_style != grip_style.strip_edges():
		failures.append("weapon grip style must be non-empty and trimmed")
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["light_attack_profile_id"] = light_attack_profile_id
	descriptor["attack_animation_role"] = attack_animation_role
	descriptor["grip_rig_role"] = grip_rig_role
	descriptor["presentation_archetype_id"] = presentation_archetype_id
	descriptor["grip_style"] = grip_style
	return descriptor


static func _is_attack_profile_id(value: String) -> bool:
	return ContentId.is_valid(value) and ContentId.family_of(value) == ATTACK_PROFILE_FAMILY
