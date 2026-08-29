extends Resource

const SchemaId := preload("res://core/content/schema/schema_id.gd")
const _SEMANTIC_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_."

@export var realization_adapter_id: String = ""
@export var resource_binding: Resource
@export var required_roles: Array[String] = []
@export var required_capability_ids: Array[String] = []


func configure(
	p_realization_adapter_id: String,
	p_resource_binding: Resource,
	p_required_roles: Array = [],
	p_required_capability_ids: Array = []
) -> Resource:
	realization_adapter_id = p_realization_adapter_id
	resource_binding = p_resource_binding
	required_roles.clear()
	required_capability_ids.clear()
	for role in p_required_roles:
		required_roles.append(str(role))
	for capability_id in p_required_capability_ids:
		required_capability_ids.append(str(capability_id))
	return self


func validate_contract() -> Array[String]:
	var failures: Array[String] = []
	if not _is_semantic_label(realization_adapter_id):
		failures.append(
			"realization adapter id must be a lowercase semantic label: %s" % realization_adapter_id
		)

	# The shared composition contract owns only the presence of a replaceable
	# Resource binding. Concrete binding type belongs to the selected realization
	# adapter (PackedScene, animation resource, generated composition descriptor,
	# etc.) so the generic archetype boundary does not secretly encode one
	# adapter's storage format.
	if resource_binding == null:
		failures.append("realization resource binding is required")

	var seen_roles: Dictionary = {}
	for role in required_roles:
		if not _is_semantic_label(role):
			failures.append("required realization role must be a lowercase semantic role: %s" % role)
		if seen_roles.has(role):
			failures.append("duplicate required realization role: %s" % role)
		seen_roles[role] = true

	var seen_capabilities: Dictionary = {}
	for capability_id in required_capability_ids:
		for failure in SchemaId.validate_capability(capability_id):
			failures.append("required realization capability: %s" % failure)
		if seen_capabilities.has(capability_id):
			failures.append("duplicate required realization capability: %s" % capability_id)
		seen_capabilities[capability_id] = true

	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var ordered_roles: Array[String] = []
	ordered_roles.append_array(required_roles)
	ordered_roles.sort()
	var ordered_capabilities: Array[String] = []
	ordered_capabilities.append_array(required_capability_ids)
	ordered_capabilities.sort()
	var binding_path: String = ""
	var binding_type: String = ""
	if resource_binding != null:
		binding_path = str(resource_binding.resource_path)
		binding_type = str(resource_binding.get_class())
	return {
		"realization_adapter_id": realization_adapter_id,
		"resource_binding_path": binding_path,
		"resource_binding_type": binding_type,
		"required_roles": ordered_roles,
		"required_capability_ids": ordered_capabilities,
	}


static func role_group_name(role: String) -> String:
	return "archetype_role:%s" % role


static func _is_semantic_label(value: String) -> bool:
	if value.is_empty() or value != value.strip_edges():
		return false
	if value.begins_with(".") or value.ends_with(".") or value.contains(".."):
		return false
	for index in range(value.length()):
		if _SEMANTIC_CHARS.find(value.substr(index, 1)) < 0:
			return false
	return true
