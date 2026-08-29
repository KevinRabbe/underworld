extends "res://core/content/registry/content_definition.gd"

const ArchetypeComposition := preload("res://core/content/archetypes/archetype_composition.gd")
const ContentReference := preload("res://core/content/references/content_reference.gd")

@export var composition: Resource
var _semantic_references: Array = []


func configure_archetype(
	p_content_id: String,
	p_definition_family: String,
	p_composition: Resource,
	p_schema_revision: int = 1
) -> Resource:
	configure(p_content_id, p_definition_family, p_schema_revision)
	composition = p_composition
	return self


func configure_semantic_references(references: Array = []) -> Resource:
	_semantic_references.clear()
	_semantic_references.append_array(references)
	return self


func validation_references() -> Array:
	var result: Array = []
	result.append_array(_semantic_references)
	return result


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if composition == null:
		failures.append("archetype composition is required for %s" % content_id)
	elif not composition is ArchetypeComposition:
		failures.append("archetype composition must be an ArchetypeComposition Resource for %s" % content_id)
	else:
		for failure in composition.validate_contract():
			failures.append("archetype composition: %s" % failure)
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	if composition != null and composition is ArchetypeComposition:
		descriptor["archetype_composition"] = composition.canonical_descriptor()
	else:
		descriptor["archetype_composition"] = null

	var references: Array[String] = []
	for candidate in _semantic_references:
		if candidate == null or not candidate is ContentReference:
			references.append("<invalid-reference>")
			continue
		references.append("%s|%s|%s|%s|%s" % [
			str(candidate.source_id),
			str(candidate.role),
			str(candidate.target_id),
			str(candidate.expected_family),
			str(candidate.required),
		])
	references.sort()
	descriptor["semantic_references"] = references
	return descriptor
