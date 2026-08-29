extends "res://core/content/archetypes/archetype_realization_adapter.gd"


func _init() -> void:
	configure("test.tagged")


func realize(definition) -> Dictionary:
	var failures: Array[String] = validate_realization(definition)
	if not failures.is_empty():
		return {"instance": null, "diagnostics": failures}

	var instance := Node.new()
	instance.set_meta("test_adapter", adapter_id)
	instance.set_meta("archetype_content_id", str(definition.content_id))
	for role in definition.composition.required_roles:
		instance.add_to_group(ArchetypeComposition.role_group_name(role))
	return {"instance": instance, "diagnostics": []}
