extends "res://core/content/registry/content_definition.gd"

const ContentId := preload("res://core/content/identity/content_id.gd")
const ContentReference := preload("res://core/content/references/content_reference.gd")
const SchemaId := preload("res://core/content/schema/schema_id.gd")
const SemanticRoleSchemaRegistry := preload("res://core/content/schema/semantic_role_schema_registry.gd")

const DEFINITION_FAMILY := "animation_set"
const RIG_PROFILE_FAMILY := "rig_profile"
const ROOT_MOTION_DISABLED := "disabled"
const ROOT_MOTION_VISUAL_ONLY := "visual_only"

@export var rig_profile_id: String = ""
@export var root_motion_policy: String = ROOT_MOTION_DISABLED
@export var role_bindings: Dictionary = {}
@export var fallback_roles: Dictionary = {}
@export var required_role_ids: Array[String] = []
@export var required_rig_role_ids: Array[String] = []


func configure_animation_set(
	p_content_id: String,
	p_rig_profile_id: String,
	p_schema_revision: int = 1
) -> Resource:
	configure(p_content_id, DEFINITION_FAMILY, p_schema_revision)
	rig_profile_id = p_rig_profile_id
	return self


func set_role_binding(role_id: String, binding: String) -> Resource:
	role_bindings[role_id] = binding
	return self


func set_fallback_role(role_id: String, fallback_role_id: String) -> Resource:
	fallback_roles[role_id] = fallback_role_id
	return self


func configure_required_roles(animation_roles: Array = [], rig_roles: Array = []) -> Resource:
	required_role_ids.clear()
	for role_id in animation_roles:
		required_role_ids.append(str(role_id))
	required_rig_role_ids.clear()
	for role_id in rig_roles:
		required_rig_role_ids.append(str(role_id))
	return self


func validation_references() -> Array:
	return [ContentReference.new(
		content_id,
		"rig_profile.compatibility",
		rig_profile_id,
		RIG_PROFILE_FAMILY,
		true
	)]


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if definition_family != DEFINITION_FAMILY:
		failures.append("animation set definition family must be '%s': %s" % [DEFINITION_FAMILY, definition_family])

	var rig_failures: Array[String] = ContentId.validate(rig_profile_id)
	for failure in rig_failures:
		failures.append("rig profile id: %s" % failure)
	if ContentId.is_valid(rig_profile_id) and ContentId.family_of(rig_profile_id) != RIG_PROFILE_FAMILY:
		failures.append("rig profile id must use '%s.' content family: %s" % [RIG_PROFILE_FAMILY, rig_profile_id])

	if root_motion_policy != ROOT_MOTION_DISABLED and root_motion_policy != ROOT_MOTION_VISUAL_ONLY:
		failures.append("unsupported root-motion policy '%s' for %s" % [root_motion_policy, content_id])

	var bound_roles: Array[String] = []
	for raw_role_id in role_bindings.keys():
		var role_id: String = str(raw_role_id)
		bound_roles.append(role_id)
		for failure in SchemaId.validate_animation_role(role_id):
			failures.append("animation binding role: %s" % failure)
		var binding: String = str(role_bindings[raw_role_id])
		if binding.is_empty() or binding != binding.strip_edges():
			failures.append("animation binding must be a non-empty trimmed presentation binding: %s" % role_id)

	var fallback_sources: Array[String] = []
	for raw_role_id in fallback_roles.keys():
		var role_id: String = str(raw_role_id)
		fallback_sources.append(role_id)
		for failure in SchemaId.validate_animation_role(role_id):
			failures.append("fallback source role: %s" % failure)
		var fallback_role_id: String = str(fallback_roles[raw_role_id])
		for failure in SchemaId.validate_animation_role(fallback_role_id):
			failures.append("fallback target role: %s" % failure)
		if role_id == fallback_role_id and not role_id.is_empty():
			failures.append("animation fallback role cannot reference itself: %s" % role_id)
		if role_bindings.has(role_id):
			failures.append("animation role has both concrete binding and fallback: %s" % role_id)

	_validate_unique_animation_roles(required_role_ids, "required animation role", failures)
	_validate_unique_rig_roles(required_rig_role_ids, "required rig role", failures)
	_validate_fallback_cycles(failures)

	for role_id in required_role_ids:
		if not role_bindings.has(role_id) and not fallback_roles.has(role_id):
			failures.append("required animation role has no binding or fallback: %s" % role_id)

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
		if SchemaId.is_valid_animation_role(role_id) and not role_registry.has_animation_role(role_id):
			failures.append("unknown animation role schema id: %s" % role_id)
	for raw_role_id in fallback_roles.keys():
		var role_id: String = str(raw_role_id)
		var fallback_role_id: String = str(fallback_roles[raw_role_id])
		if SchemaId.is_valid_animation_role(role_id) and not role_registry.has_animation_role(role_id):
			failures.append("unknown animation fallback source schema id: %s" % role_id)
		if SchemaId.is_valid_animation_role(fallback_role_id) and not role_registry.has_animation_role(fallback_role_id):
			failures.append("unknown animation fallback target schema id: %s" % fallback_role_id)
	for role_id in required_role_ids:
		if SchemaId.is_valid_animation_role(role_id) and not role_registry.has_animation_role(role_id):
			failures.append("unknown required animation role schema id: %s" % role_id)
	for role_id in required_rig_role_ids:
		if SchemaId.is_valid_rig_role(role_id) and not role_registry.has_rig_role(role_id):
			failures.append("unknown required rig role schema id: %s" % role_id)
	failures.sort()
	return failures


func resolve_role_binding(role_id: String) -> Dictionary:
	var failures: Array[String] = []
	for failure in SchemaId.validate_animation_role(role_id):
		failures.append(str(failure))
	if not failures.is_empty():
		return {"binding": "", "resolved_role_id": "", "diagnostics": failures}

	var current: String = role_id
	var visited: Dictionary = {}
	while true:
		if visited.has(current):
			failures.append("animation fallback cycle while resolving: %s" % role_id)
			break
		visited[current] = true
		if role_bindings.has(current):
			return {
				"binding": str(role_bindings[current]),
				"resolved_role_id": current,
				"diagnostics": failures,
			}
		if not fallback_roles.has(current):
			failures.append("animation role has no binding or fallback: %s" % current)
			break
		current = str(fallback_roles[current])

	return {"binding": "", "resolved_role_id": "", "diagnostics": failures}


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["rig_profile_id"] = rig_profile_id
	descriptor["root_motion_policy"] = root_motion_policy
	descriptor["role_bindings"] = _ordered_mapping_descriptor(role_bindings)
	descriptor["fallback_roles"] = _ordered_mapping_descriptor(fallback_roles)
	var ordered_roles: Array[String] = []
	ordered_roles.append_array(required_role_ids)
	ordered_roles.sort()
	descriptor["required_role_ids"] = ordered_roles
	var ordered_rig_roles: Array[String] = []
	ordered_rig_roles.append_array(required_rig_role_ids)
	ordered_rig_roles.sort()
	descriptor["required_rig_role_ids"] = ordered_rig_roles
	return descriptor


static func _ordered_mapping_descriptor(mapping: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for raw_key in mapping.keys():
		result.append("%s=%s" % [str(raw_key), str(mapping[raw_key])])
	result.sort()
	return result


static func _validate_unique_animation_roles(
	roles: Array[String],
	label: String,
	failures: Array[String]
) -> void:
	var seen: Dictionary = {}
	for role_id in roles:
		for failure in SchemaId.validate_animation_role(role_id):
			failures.append("%s: %s" % [label, failure])
		if seen.has(role_id):
			failures.append("duplicate %s: %s" % [label, role_id])
		seen[role_id] = true


static func _validate_unique_rig_roles(
	roles: Array[String],
	label: String,
	failures: Array[String]
) -> void:
	var seen: Dictionary = {}
	for role_id in roles:
		for failure in SchemaId.validate_rig_role(role_id):
			failures.append("%s: %s" % [label, failure])
		if seen.has(role_id):
			failures.append("duplicate %s: %s" % [label, role_id])
		seen[role_id] = true


func _validate_fallback_cycles(failures: Array[String]) -> void:
	var ordered_sources: Array[String] = []
	for raw_role_id in fallback_roles.keys():
		ordered_sources.append(str(raw_role_id))
	ordered_sources.sort()
	for source_role in ordered_sources:
		var current: String = source_role
		var visited: Dictionary = {}
		while fallback_roles.has(current):
			if visited.has(current):
				failures.append("animation fallback cycle: %s" % source_role)
				break
			visited[current] = true
			current = str(fallback_roles[current])
