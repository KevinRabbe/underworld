extends "res://core/content/registry/content_definition.gd"

const ContentReference := preload("res://core/content/references/content_reference.gd")
const FiniteNumber := preload("res://core/content/validation/finite_number.gd")
const ResourceYieldRule := preload("res://gameplay/resources/definitions/resource_yield_rule.gd")

const RESOURCE_FAMILY := "resource"

@export var capacity_units: float = 1.0
var _yield_rules: Array = []
var _semantic_references: Array = []


func configure_resource(
	p_content_id: String,
	p_capacity_units: float = 1.0,
	p_schema_revision: int = 1
) -> Resource:
	configure(p_content_id, RESOURCE_FAMILY, p_schema_revision)
	capacity_units = p_capacity_units
	return self


func configure_yield_rules(rules: Array = []) -> Resource:
	_yield_rules.clear()
	_yield_rules.append_array(rules)
	return self


func configure_semantic_references(references: Array = []) -> Resource:
	_semantic_references.clear()
	_semantic_references.append_array(references)
	return self


func yield_rules() -> Array:
	var result: Array = []
	result.append_array(_yield_rules)
	return result


func validation_references() -> Array:
	var result: Array = []
	for candidate in _yield_rules:
		if candidate != null and candidate is ResourceYieldRule:
			result.append(candidate.validation_reference())
	for candidate in _semantic_references:
		result.append(candidate)
	return result


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if definition_family != RESOURCE_FAMILY:
		failures.append(
			"resource definition family must be '%s': %s" % [
				RESOURCE_FAMILY,
				definition_family,
			]
		)
	if not FiniteNumber.is_finite_number(capacity_units):
		failures.append("resource capacity_units must be finite for %s" % content_id)
	elif capacity_units <= 0.0:
		failures.append("resource capacity units must be > 0 for %s" % content_id)
	if _yield_rules.is_empty():
		failures.append("resource must declare at least one typed item yield: %s" % content_id)
	for candidate in _yield_rules:
		if candidate == null or not candidate is ResourceYieldRule:
			failures.append("resource yield rule must inherit ResourceYieldRule")
			continue
		for failure in candidate.validate_rule():
			failures.append("resource yield: %s" % failure)
		var reference = candidate.validation_reference()
		if reference != null and reference is ContentReference:
			if not reference.source_id.is_empty() and reference.source_id != content_id:
				failures.append(
					"resource yield source id '%s' does not match definition '%s'" % [
						reference.source_id,
						content_id,
					]
				)
	for candidate in _semantic_references:
		if candidate == null or not candidate is ContentReference:
			failures.append("resource semantic reference must inherit ContentReference")
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["capacity_units"] = capacity_units

	var yields: Array[Dictionary] = []
	for candidate in _yield_rules:
		if candidate == null or not candidate is ResourceYieldRule:
			yields.append({"reference": "<invalid-yield-rule>"})
			continue
		yields.append(candidate.canonical_descriptor())
	yields.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return JSON.stringify(a) < JSON.stringify(b)
	)
	descriptor["yield_rules"] = yields

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
