extends RefCounted

const ArchetypeDefinition := preload("res://core/content/archetypes/archetype_definition.gd")
const ArchetypeComposition := preload("res://core/content/archetypes/archetype_composition.gd")
const _SEMANTIC_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_."

var adapter_id: String = ""


func configure(p_adapter_id: String) -> RefCounted:
	adapter_id = p_adapter_id
	return self


func validate_adapter() -> Array[String]:
	var failures: Array[String] = []
	if not _is_semantic_label(adapter_id):
		failures.append("realization adapter id must be a lowercase semantic label: %s" % adapter_id)
	return failures


func accepts(definition) -> bool:
	return (
		definition != null
		and definition is ArchetypeDefinition
		and definition.composition != null
		and definition.composition is ArchetypeComposition
		and str(definition.composition.realization_adapter_id) == adapter_id
	)


func validate_resource_binding(_resource_binding: Resource) -> Array[String]:
	# Adapter-specific Resource type/shape validation belongs here rather than in
	# ArchetypeComposition. The common composition contract only requires that a
	# replaceable Resource binding exists.
	return []


func validate_realization(definition) -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(validate_adapter())
	if definition == null or not definition is ArchetypeDefinition:
		failures.append("expected ArchetypeDefinition")
		failures.sort()
		return failures
	if definition.composition == null or not definition.composition is ArchetypeComposition:
		failures.append("archetype definition has no valid composition")
		failures.sort()
		return failures
	for failure in definition.composition.validate_contract():
		failures.append("composition: %s" % failure)
	if str(definition.composition.realization_adapter_id) != adapter_id:
		failures.append(
			"archetype requests realization adapter '%s', adapter is '%s'" % [
				definition.composition.realization_adapter_id,
				adapter_id,
			]
		)
	if definition.composition.resource_binding != null:
		for failure in validate_resource_binding(definition.composition.resource_binding):
			failures.append("resource binding: %s" % failure)
	failures.sort()
	return failures


func realize(definition) -> Dictionary:
	var failures: Array[String] = validate_realization(definition)
	if failures.is_empty():
		failures.append("realization adapter '%s' does not implement realize()" % adapter_id)
	return {
		"instance": null,
		"diagnostics": failures,
	}


static func _is_semantic_label(value: String) -> bool:
	if value.is_empty() or value != value.strip_edges():
		return false
	if value.begins_with(".") or value.ends_with(".") or value.contains(".."):
		return false
	for index in range(value.length()):
		if _SEMANTIC_CHARS.find(value.substr(index, 1)) < 0:
			return false
	return true
