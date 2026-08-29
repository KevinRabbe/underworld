extends "res://gameplay/items/definitions/item_definition.gd"

const ContentIdContract := preload("res://core/content/identity/content_id.gd")
const SchemaIdContract := preload("res://core/content/schema/schema_id.gd")
const ContentReferenceContract := preload("res://core/content/references/content_reference.gd")

const ATTACK_SET_FAMILY := "attack_set"
const ARCHETYPE_FAMILY := "archetype"
const ANIMATION_SET_FAMILY := "animation_set"
const RIG_PROFILE_FAMILY := "rig_profile"

const _SEMANTIC_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_."

@export var attack_set_id: String = ""
@export var archetype_id: String = ""
@export var animation_set_id: String = ""
@export var rig_profile_id: String = ""
@export var primary_technique_role: String = "weapon_technique.light.primary"
@export var attack_animation_role: String = "animation_role.action.attack.light_01"
@export var grip_rig_role: String = "rig_role.socket.hand.right"


func configure_weapon(
	p_content_id: String,
	p_attack_set_id: String,
	p_archetype_id: String,
	p_animation_set_id: String,
	p_rig_profile_id: String,
	p_primary_technique_role: String = "weapon_technique.light.primary",
	p_attack_animation_role: String = "animation_role.action.attack.light_01",
	p_grip_rig_role: String = "rig_role.socket.hand.right",
	p_unit_weight: float = 0.0,
	p_schema_revision: int = 1
) -> Resource:
	configure_item(p_content_id, 1, p_unit_weight, p_schema_revision)
	attack_set_id = p_attack_set_id
	archetype_id = p_archetype_id
	animation_set_id = p_animation_set_id
	rig_profile_id = p_rig_profile_id
	primary_technique_role = p_primary_technique_role
	attack_animation_role = p_attack_animation_role
	grip_rig_role = p_grip_rig_role
	return self


func validation_references() -> Array:
	var result: Array = super.validation_references()
	result.append(ContentReferenceContract.new(
		content_id,
		"weapon.attack_set",
		attack_set_id,
		ATTACK_SET_FAMILY,
		true
	))
	result.append(ContentReferenceContract.new(
		content_id,
		"presentation.archetype",
		archetype_id,
		ARCHETYPE_FAMILY,
		true
	))
	result.append(ContentReferenceContract.new(
		content_id,
		"presentation.animation_set",
		animation_set_id,
		ANIMATION_SET_FAMILY,
		true
	))
	result.append(ContentReferenceContract.new(
		content_id,
		"presentation.rig_profile",
		rig_profile_id,
		RIG_PROFILE_FAMILY,
		true
	))
	return result


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if stack_limit != 1:
		failures.append("weapon stack limit must be exactly 1 for %s" % content_id)
	_validate_content_target("attack set", attack_set_id, ATTACK_SET_FAMILY, failures)
	_validate_content_target("archetype", archetype_id, ARCHETYPE_FAMILY, failures)
	_validate_content_target("animation set", animation_set_id, ANIMATION_SET_FAMILY, failures)
	_validate_content_target("rig profile", rig_profile_id, RIG_PROFILE_FAMILY, failures)
	for failure in validate_technique_role(primary_technique_role):
		failures.append("primary technique role: %s" % failure)
	for failure in SchemaIdContract.validate_animation_role(attack_animation_role):
		failures.append("attack animation role: %s" % failure)
	for failure in SchemaIdContract.validate_rig_role(grip_rig_role):
		failures.append("grip rig role: %s" % failure)
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["attack_set_id"] = attack_set_id
	descriptor["archetype_id"] = archetype_id
	descriptor["animation_set_id"] = animation_set_id
	descriptor["rig_profile_id"] = rig_profile_id
	descriptor["primary_technique_role"] = primary_technique_role
	descriptor["attack_animation_role"] = attack_animation_role
	descriptor["grip_rig_role"] = grip_rig_role
	return descriptor


static func validate_technique_role(value: String) -> Array[String]:
	var failures: Array[String] = []
	if value.is_empty() or value != value.strip_edges():
		failures.append("weapon technique role must be non-empty and trimmed: %s" % value)
		return failures
	if not value.begins_with("weapon_technique."):
		failures.append("weapon technique role must use 'weapon_technique.' namespace: %s" % value)
	if value.begins_with(".") or value.ends_with(".") or value.contains(".."):
		failures.append("weapon technique role contains empty semantic token: %s" % value)
		return failures
	for index in range(value.length()):
		if _SEMANTIC_CHARS.find(value.substr(index, 1)) < 0:
			failures.append("weapon technique role contains invalid character: %s" % value)
			break
	return failures


static func _validate_content_target(
	label: String,
	target_id: String,
	expected_family: String,
	failures: Array[String]
) -> void:
	for failure in ContentIdContract.validate(target_id):
		failures.append("%s id: %s" % [label, failure])
	if (
		ContentIdContract.is_valid(target_id)
		and ContentIdContract.family_of(target_id) != expected_family
	):
		failures.append("%s id must use '%s.' content family: %s" % [
			label,
			expected_family,
			target_id,
		])