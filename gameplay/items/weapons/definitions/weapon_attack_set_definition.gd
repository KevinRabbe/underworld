extends "res://core/content/registry/content_definition.gd"

const WeaponDefinitionScript := preload("res://gameplay/items/weapons/definitions/weapon_definition.gd")

const ATTACK_SET_FAMILY := "attack_set"

@export var technique_attack_ids: Dictionary = {}


func configure_attack_set(
	p_content_id: String,
	p_bindings: Dictionary = {},
	p_schema_revision: int = 1
) -> Resource:
	configure(p_content_id, ATTACK_SET_FAMILY, p_schema_revision)
	technique_attack_ids.clear()
	for raw_role in p_bindings.keys():
		technique_attack_ids[str(raw_role)] = str(p_bindings[raw_role])
	return self


func set_attack_binding(technique_role: String, attack_id: StringName) -> Resource:
	technique_attack_ids[technique_role] = str(attack_id)
	return self


func has_technique(technique_role: String) -> bool:
	return technique_attack_ids.has(technique_role)


func attack_id_for(technique_role: String) -> StringName:
	if not technique_attack_ids.has(technique_role):
		return &""
	return StringName(str(technique_attack_ids[technique_role]))


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if definition_family != ATTACK_SET_FAMILY:
		failures.append("weapon attack-set definition family must be '%s': %s" % [
			ATTACK_SET_FAMILY,
			definition_family,
		])
	if technique_attack_ids.is_empty():
		failures.append("weapon attack set must declare at least one technique binding: %s" % content_id)
	for raw_role in technique_attack_ids.keys():
		var technique_role: String = str(raw_role)
		for failure in WeaponDefinitionScript.validate_technique_role(technique_role):
			failures.append("attack-set technique role: %s" % failure)
		var attack_id: String = str(technique_attack_ids[raw_role])
		if attack_id.is_empty() or attack_id != attack_id.strip_edges():
			failures.append("attack id must be non-empty and trimmed for technique %s" % technique_role)
			continue
		if not _is_semantic_attack_id(attack_id):
			failures.append("attack id must be a lowercase semantic attack token: %s" % attack_id)
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	var bindings: Array[String] = []
	for raw_role in technique_attack_ids.keys():
		bindings.append("%s=%s" % [str(raw_role), str(technique_attack_ids[raw_role])])
	bindings.sort()
	descriptor["technique_attack_ids"] = bindings
	return descriptor


static func _is_semantic_attack_id(value: String) -> bool:
	if value.is_empty():
		return false
	var allowed := "abcdefghijklmnopqrstuvwxyz0123456789_."
	if allowed.find(value.substr(0, 1)) < 0 or "abcdefghijklmnopqrstuvwxyz".find(value.substr(0, 1)) < 0:
		return false
	if value.begins_with(".") or value.ends_with(".") or value.contains(".."):
		return false
	for index in range(value.length()):
		if allowed.find(value.substr(index, 1)) < 0:
			return false
	return true