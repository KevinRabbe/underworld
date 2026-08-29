extends "res://core/content/archetypes/archetype_realization_adapter.gd"


func _init() -> void:
	configure("test.tagged")


func validate_resource_binding(resource_binding: Resource) -> Array[String]:
	var failures: Array[String] = []
	if resource_binding != null and not resource_binding is Curve:
		failures.append(
			"expected Curve resource binding, got %s" % resource_binding.get_class()
		)
	return failures


func realize(definition) -> Dictionary:
	var failures: Array[String] = validate_realization(definition)
	if not failures.is_empty():
		return {"instance": null, "diagnostics": failures}

	var binding = definition.composition.resource_binding
	if binding == null or not binding is Curve:
		return {"instance": null, "diagnostics": ["tagged adapter requires Curve resource binding"]}

	var instance := Node.new()
	instance.set_meta("test_adapter", adapter_id)
	instance.set_meta("archetype_content_id", str(definition.content_id))
	instance.set_meta("test_binding_point_count", binding.get_point_count())
	for role in definition.composition.required_roles:
		instance.add_to_group(ArchetypeComposition.role_group_name(role))
	return {"instance": instance, "diagnostics": []}
