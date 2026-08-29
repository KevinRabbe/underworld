extends "res://core/content/registry/content_definition.gd"

const ATTACK_PROFILE_FAMILY := "attack_profile"
const _SEMANTIC_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_."

@export var attack_style: String = "melee.contact"
@export var parryable: bool = true


func configure_attack_profile(
	p_content_id: String,
	p_attack_style: String = "melee.contact",
	p_parryable: bool = true,
	p_schema_revision: int = 1
) -> Resource:
	configure(p_content_id, ATTACK_PROFILE_FAMILY, p_schema_revision)
	attack_style = p_attack_style
	parryable = p_parryable
	return self


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if definition_family != ATTACK_PROFILE_FAMILY:
		failures.append(
			"creature attack profile family must be '%s': %s" % [
				ATTACK_PROFILE_FAMILY,
				definition_family,
			]
		)
	if not _is_semantic_label(attack_style):
		failures.append("creature attack style must be a lowercase semantic label: %s" % attack_style)
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["attack_style"] = attack_style
	descriptor["parryable"] = parryable
	return descriptor


static func _is_semantic_label(value: String) -> bool:
	if value.is_empty() or value != value.strip_edges():
		return false
	if value.begins_with(".") or value.ends_with(".") or value.contains(".."):
		return false
	for index in range(value.length()):
		if _SEMANTIC_CHARS.find(value.substr(index, 1)) < 0:
			return false
	return true
