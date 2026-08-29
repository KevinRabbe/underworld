extends "res://core/content/registry/content_definition.gd"

var references: Array = []


func configure_references(p_references: Array = []) -> Resource:
	references.clear()
	references.append_array(p_references)
	return self


func validation_references() -> Array:
	return references.duplicate()
