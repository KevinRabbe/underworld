extends "res://core/content/registry/content_definition.gd"

const ContentId := preload("res://core/content/identity/content_id.gd")
const ContentReference := preload("res://core/content/references/content_reference.gd")
const SchemaId := preload("res://core/content/schema/schema_id.gd")

const CREATURE_FAMILY := "creature"
const ATTACK_PROFILE_FAMILY := "attack_profile"
const ARCHETYPE_FAMILY := "archetype"
const ANIMATION_SET_FAMILY := "animation_set"
const RIG_PROFILE_FAMILY := "rig_profile"

const ROLE_ATTACK_PROFILE := "combat.attack_profile"
const ROLE_ARCHETYPE := "presentation.archetype"
const ROLE_ANIMATION_SET := "presentation.animation_set"
const ROLE_RIG_PROFILE := "presentation.rig_profile"

@export var display_name: String = "Creature"
@export var max_health: int = 1
@export var move_speed: float = 1.0
@export var detection_range: float = 1.0
@export var attack_range: float = 1.0
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.0
@export var attack_windup: float = 0.1

@export var attack_profile_id: String = ""
@export var archetype_id: String = ""
@export var animation_set_id: String = ""
@export var rig_profile_id: String = ""
@export var required_animation_role_ids: Array[String] = []
@export var required_rig_role_ids: Array[String] = []


func configure_creature(
	p_content_id: String,
	p_display_name: String,
	p_max_health: int,
	p_move_speed: float,
	p_detection_range: float,
	p_attack_range: float,
	p_attack_damage: int,
	p_attack_cooldown: float,
	p_attack_windup: float,
	p_schema_revision: int = 1
) -> Resource:
	configure(p_content_id, CREATURE_FAMILY, p_schema_revision)
	display_name = p_display_name
	max_health = p_max_health
	move_speed = p_move_speed
	detection_range = p_detection_range
	attack_range = p_attack_range
	attack_damage = p_attack_damage
	attack_cooldown = p_attack_cooldown
	attack_windup = p_attack_windup
	return self


func configure_semantic_bindings(
	p_attack_profile_id: String,
	p_archetype_id: String,
	p_animation_set_id: String,
	p_rig_profile_id: String,
	p_required_animation_roles: Array = [],
	p_required_rig_roles: Array = []
) -> Resource:
	attack_profile_id = p_attack_profile_id
	archetype_id = p_archetype_id
	animation_set_id = p_animation_set_id
	rig_profile_id = p_rig_profile_id
	required_animation_role_ids.clear()
	for role_id in p_required_animation_roles:
		required_animation_role_ids.append(str(role_id))
	required_rig_role_ids.clear()
	for role_id in p_required_rig_roles:
		required_rig_role_ids.append(str(role_id))
	return self


func runtime_stats() -> Dictionary:
	return {
		"health": max_health,
		"move_speed": move_speed,
		"detection_range": detection_range,
		"attack_range": attack_range,
		"attack_damage": attack_damage,
		"attack_cooldown": attack_cooldown,
		"attack_windup": attack_windup,
	}


func validation_references() -> Array:
	return [
		ContentReference.new(
			content_id,
			ROLE_ATTACK_PROFILE,
			attack_profile_id,
			ATTACK_PROFILE_FAMILY,
			true
		),
		ContentReference.new(
			content_id,
			ROLE_ARCHETYPE,
			archetype_id,
			ARCHETYPE_FAMILY,
			true
		),
		ContentReference.new(
			content_id,
			ROLE_ANIMATION_SET,
			animation_set_id,
			ANIMATION_SET_FAMILY,
			true
		),
		ContentReference.new(
			content_id,
			ROLE_RIG_PROFILE,
			rig_profile_id,
			RIG_PROFILE_FAMILY,
			true
		),
	]


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if definition_family != CREATURE_FAMILY:
		failures.append(
			"creature definition family must be '%s': %s" % [CREATURE_FAMILY, definition_family]
		)
	if display_name.is_empty() or display_name != display_name.strip_edges():
		failures.append("creature display name must be non-empty and trimmed for %s" % content_id)
	if max_health <= 0:
		failures.append("creature max health must be > 0 for %s" % content_id)
	if move_speed <= 0.0:
		failures.append("creature move speed must be > 0 for %s" % content_id)
	if detection_range <= 0.0:
		failures.append("creature detection range must be > 0 for %s" % content_id)
	if attack_range <= 0.0:
		failures.append("creature attack range must be > 0 for %s" % content_id)
	if attack_damage <= 0:
		failures.append("creature attack damage must be > 0 for %s" % content_id)
	if attack_cooldown <= 0.0:
		failures.append("creature attack cooldown must be > 0 for %s" % content_id)
	if attack_windup <= 0.0:
		failures.append("creature attack windup must be > 0 for %s" % content_id)

	for reference in validation_references():
		if reference == null or not reference is ContentReference:
			failures.append("creature semantic reference must inherit ContentReference")
			continue
		for failure in reference.validate_reference():
			failures.append("creature semantic reference '%s': %s" % [reference.role, failure])
		if (
			ContentId.is_valid(reference.target_id)
			and not reference.expected_family.is_empty()
			and ContentId.family_of(reference.target_id) != reference.expected_family
		):
			failures.append(
				"creature semantic reference '%s' must target '%s' family: %s" % [
					reference.role,
					reference.expected_family,
					reference.target_id,
				]
			)

	_validate_animation_roles(required_animation_role_ids, failures)
	_validate_rig_roles(required_rig_role_ids, failures)
	if required_animation_role_ids.is_empty():
		failures.append("creature must require at least one semantic animation role: %s" % content_id)
	if required_rig_role_ids.is_empty():
		failures.append("creature must require at least one semantic rig role: %s" % content_id)
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["display_name"] = display_name
	descriptor["max_health"] = max_health
	descriptor["move_speed"] = move_speed
	descriptor["detection_range"] = detection_range
	descriptor["attack_range"] = attack_range
	descriptor["attack_damage"] = attack_damage
	descriptor["attack_cooldown"] = attack_cooldown
	descriptor["attack_windup"] = attack_windup
	descriptor["attack_profile_id"] = attack_profile_id
	descriptor["archetype_id"] = archetype_id
	descriptor["animation_set_id"] = animation_set_id
	descriptor["rig_profile_id"] = rig_profile_id

	var animation_roles: Array[String] = []
	animation_roles.append_array(required_animation_role_ids)
	animation_roles.sort()
	descriptor["required_animation_role_ids"] = animation_roles
	var rig_roles: Array[String] = []
	rig_roles.append_array(required_rig_role_ids)
	rig_roles.sort()
	descriptor["required_rig_role_ids"] = rig_roles
	return descriptor


static func _validate_animation_roles(roles: Array[String], failures: Array[String]) -> void:
	var seen: Dictionary = {}
	for role_id in roles:
		for failure in SchemaId.validate_animation_role(role_id):
			failures.append("creature required animation role: %s" % failure)
		if seen.has(role_id):
			failures.append("duplicate creature required animation role: %s" % role_id)
		seen[role_id] = true


static func _validate_rig_roles(roles: Array[String], failures: Array[String]) -> void:
	var seen: Dictionary = {}
	for role_id in roles:
		for failure in SchemaId.validate_rig_role(role_id):
			failures.append("creature required rig role: %s" % failure)
		if seen.has(role_id):
			failures.append("duplicate creature required rig role: %s" % role_id)
		seen[role_id] = true
