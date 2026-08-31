extends "res://core/content/validation/content_family_validator.gd"

var rule_label: String = "revision"
var minimum_revision: int = 1


func configure_rule(
	p_definition_family: String,
	p_rule_label: String,
	p_minimum_revision: int
) -> RefCounted:
	definition_family = p_definition_family
	rule_label = p_rule_label
	minimum_revision = p_minimum_revision
	return self


func validate_definition(definition, _context: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if int(definition.schema_revision) < minimum_revision:
		failures.append("%s requires schema revision >= %d" % [rule_label, minimum_revision])
	return failures


func canonical_evidence_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_evidence_descriptor()
	descriptor["rule_label"] = rule_label
	descriptor["minimum_revision"] = minimum_revision
	return descriptor
