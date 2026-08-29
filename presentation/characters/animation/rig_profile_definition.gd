extends "res://core/content/registry/content_definition.gd"

const SemanticRoleSchemaRegistry := preload("res://core/content/schema/semantic_role_schema_registry.gd")

const DEFINITION_FAMILY := "rig_profile"
const _LOWER := "abcdefghijklmnopqrstuvwxyz"
const _TOKEN_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_"
const BINDING_KIND_BONE := "bone"
const BINDING_KIND_SOCKET := "socket"

@export var rig_family: String = "humanoid"
@export var role_bindings: Dictionary = {}
@export var scale_multiplier: float = 1.0


func configure_rig_profile(
	p_content_id: String,
	p_rig_family: String = "humanoid",
	p_schema_revision: int = 1
) -> Resource:
	configure(p_content_id, DEFINITION_FAMILY, p_schema_revision)
	rig_family = p_rig_family
	return self


func set_role_binding(role_id: String, kind: String, target: String) -> Resource:
	role_bindings[role_id] = {"kind": kind, "target": target}
	return self


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if definition_family != DEFINITION_FAMILY:
		failures.append("rig profile definition family must be '%s': %s" % [DEFINITION_FAMILY, definition_family])
	if not _is_ascii_token(rig_family):
		failures.append("rig family must be one lowercase ASCII semantic token: %s" % rig_family)
	if scale_multiplier <= 0.0:
		failures.append("rig profile scale multiplier must be > 0 for %s" % content_id)
	if role_bindings.is_empty():
		failures.append("rig profile must define at least one semantic rig-role binding: %s" % content_id)

	for raw_role_id in role_bindings.keys():
		var role_id: String = str(raw_role_id)
		for failure in SchemaId.validate_rig_role(role_id):
			failures.append("rig binding role: %s" % failure)
		var binding = role_bindings[raw_role_id]
		if not binding is Dictionary:
			failures.append("rig role binding must be a Dictionary: %s" % role_id)
			continue
		var kind: String = str(binding.get("kind", ""))
		var target: String = str(binding.get("target", ""))
		if kind != BINDING_KIND_BONE and kind != BINDING_KIND_SOCKET:
			failures.append("rig role binding kind must be 'bone' or 'socket': %s -> %s" % [role_id, kind])
		if target.is_empty() or target != target.strip_edges():
			failures.append("rig role concrete target must be a non-empty trimmed presentation binding: %s" % role_id)

	failures.sort()
	return failures


func validate_semantic_contract(role_registry) -> Array[String]:
	var failures: Array[String] = []
	if role_registry == null or not role_registry is SemanticRoleSchemaRegistry:
		return ["expected SemanticRoleSchemaRegistry"]
	if not role_registry.is_valid():
		for failure in role_registry.diagnostics():
			failures.append("semantic role registry: %s" % failure)
		failures.sort()
		return failures
	for raw_role_id in role_bindings.keys():
		var role_id: String = str(raw_role_id)
		if SchemaId.is_valid_rig_role(role_id) and not role_registry.has_rig_role(role_id):
			failures.append("unknown rig role schema id: %s" % role_id)
	failures.sort()
	return failures


func binding_for_role(role_id: String) -> Dictionary:
	if not role_bindings.has(role_id):
		return {}
	var binding = role_bindings[role_id]
	if not binding is Dictionary:
		return {}
	return {
		"kind": str(binding.get("kind", "")),
		"target": str(binding.get("target", "")),
	}


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["rig_family"] = rig_family
	descriptor["scale_multiplier"] = scale_multiplier
	var ordered_bindings: Array[String] = []
	for raw_role_id in role_bindings.keys():
		var role_id: String = str(raw_role_id)
		var binding = role_bindings[raw_role_id]
		if not binding is Dictionary:
			ordered_bindings.append("%s=<invalid>" % role_id)
			continue
		ordered_bindings.append("%s=%s:%s" % [
			role_id,
			str(binding.get("kind", "")),
			str(binding.get("target", "")),
		])
	ordered_bindings.sort()
	descriptor["role_bindings"] = ordered_bindings
	return descriptor


static func _is_ascii_token(token: String) -> bool:
	if token.is_empty():
		return false
	if _LOWER.find(token.substr(0, 1)) < 0:
		return false
	for index in range(token.length()):
		if _TOKEN_CHARS.find(token.substr(index, 1)) < 0:
			return false
	return true
