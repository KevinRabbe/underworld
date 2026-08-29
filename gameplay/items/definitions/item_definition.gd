extends "res://core/content/registry/content_definition.gd"

const ContentReference := preload("res://core/content/references/content_reference.gd")
const FiniteNumber := preload("res://core/content/validation/finite_number.gd")

const ITEM_FAMILY := "item"

@export var stack_limit: int = 1
@export var unit_weight: float = 0.0
var _semantic_references: Array = []


func configure_item(
	p_content_id: String,
	p_stack_limit: int = 1,
	p_unit_weight: float = 0.0,
	p_schema_revision: int = 1
) -> Resource:
	configure(p_content_id, ITEM_FAMILY, p_schema_revision)
	stack_limit = p_stack_limit
	unit_weight = p_unit_weight
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
	if definition_family != ITEM_FAMILY:
		failures.append(
			"item definition family must be '%s': %s" % [ITEM_FAMILY, definition_family]
		)
	if stack_limit < 1:
		failures.append("item stack limit must be >= 1 for %s" % content_id)
	if not FiniteNumber.is_finite_number(unit_weight):
		failures.append("item unit_weight must be finite for %s" % content_id)
	elif unit_weight < 0.0:
		failures.append("item unit weight must be >= 0 for %s" % content_id)
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["stack_limit"] = stack_limit
	descriptor["unit_weight"] = unit_weight

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
