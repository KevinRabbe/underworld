extends RefCounted

const WeaponDefinitionScript := preload("res://gameplay/items/weapons/definitions/weapon_definition.gd")
const WeaponAttackSetDefinitionScript := preload("res://gameplay/items/weapons/definitions/weapon_attack_set_definition.gd")
const PlayerAttackDefinitionScript := preload("res://gameplay/combat/attacks/player_attack_definition.gd")

var _attack_definitions_by_id: Dictionary = {}
var _diagnostics: Array[String] = []


func configure_attack_definitions(definitions: Array = []) -> RefCounted:
	_attack_definitions_by_id.clear()
	_diagnostics.clear()
	for candidate in definitions:
		if candidate == null or not candidate is PlayerAttackDefinitionScript:
			_diagnostics.append("weapon attack resolver expects UnderworldPlayerAttackDefinition entries")
			continue
		if not candidate.is_valid():
			_diagnostics.append("invalid gameplay-owned attack definition: %s" % str(candidate.attack_id))
			continue
		var attack_id: String = str(candidate.attack_id)
		if _attack_definitions_by_id.has(attack_id):
			_diagnostics.append("duplicate gameplay-owned attack id: %s" % attack_id)
			continue
		_attack_definitions_by_id[attack_id] = candidate
	_diagnostics.sort()
	return self


func diagnostics() -> Array[String]:
	var result: Array[String] = []
	result.append_array(_diagnostics)
	return result


func is_valid() -> bool:
	return _diagnostics.is_empty()


func resolve_primary_attack(weapon, attack_set) -> Dictionary:
	var failures: Array[String] = []
	if weapon == null or not weapon is WeaponDefinitionScript:
		return {
			"attack_definition": null,
			"attack_id": "",
			"technique_role": "",
			"diagnostics": ["expected WeaponDefinition"],
		}
	if attack_set == null or not attack_set is WeaponAttackSetDefinitionScript:
		return {
			"attack_definition": null,
			"attack_id": "",
			"technique_role": weapon.primary_technique_role,
			"diagnostics": ["expected WeaponAttackSetDefinition"],
		}
	if not is_valid():
		failures.append_array(_diagnostics)
	if str(weapon.attack_set_id) != str(attack_set.content_id):
		failures.append("weapon attack-set id does not match supplied attack set: %s != %s" % [
			weapon.attack_set_id,
			attack_set.content_id,
		])

	var attack_id: StringName = attack_set.attack_id_for(weapon.primary_technique_role)
	if attack_id.is_empty():
		failures.append("weapon attack set has no binding for technique role: %s" % weapon.primary_technique_role)
	var attack_definition = _attack_definitions_by_id.get(str(attack_id), null)
	if attack_definition == null and not attack_id.is_empty():
		failures.append("gameplay-owned attack definition is not registered: %s" % str(attack_id))

	failures.sort()
	return {
		"attack_definition": attack_definition if failures.is_empty() else null,
		"attack_id": str(attack_id),
		"technique_role": weapon.primary_technique_role,
		"diagnostics": failures,
	}