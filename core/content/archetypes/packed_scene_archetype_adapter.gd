extends "res://core/content/archetypes/archetype_realization_adapter.gd"


func _init() -> void:
	configure("packed.scene")


func realize(definition) -> Dictionary:
	var failures: Array[String] = validate_realization(definition)
	if not failures.is_empty():
		return {
			"instance": null,
			"diagnostics": failures,
		}

	var scene: PackedScene = definition.composition.packed_scene()
	if scene == null:
		return {
			"instance": null,
			"diagnostics": ["archetype resource binding is not a PackedScene"],
		}

	var instance: Node = scene.instantiate()
	if instance == null:
		return {
			"instance": null,
			"diagnostics": ["PackedScene failed to instantiate for archetype: %s" % definition.content_id],
		}

	for role in definition.composition.required_roles:
		var group_name: String = ArchetypeComposition.role_group_name(role)
		if not _tree_has_group(instance, group_name):
			failures.append(
				"realized archetype '%s' is missing required role '%s'" % [
					definition.content_id,
					role,
				]
			)

	if not failures.is_empty():
		failures.sort()
		instance.free()
		return {
			"instance": null,
			"diagnostics": failures,
		}

	return {
		"instance": instance,
		"diagnostics": [],
	}


static func _tree_has_group(node: Node, group_name: String) -> bool:
	if node.is_in_group(group_name):
		return true
	for child in node.get_children():
		if child is Node and _tree_has_group(child, group_name):
			return true
	return false
