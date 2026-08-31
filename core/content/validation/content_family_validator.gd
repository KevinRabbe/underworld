extends RefCounted

const ContentId := preload("res://core/content/identity/content_id.gd")

const EVIDENCE_REVISION := 1

var definition_family: String = ""


func configure(p_definition_family: String) -> RefCounted:
	definition_family = p_definition_family
	return self


func validate_validator() -> Array[String]:
	var failures: Array[String] = []
	for failure in ContentId.validate_family(definition_family):
		failures.append("validator family: %s" % failure)
	return failures


func applies_to(definition) -> bool:
	return definition != null and str(definition.definition_family) == definition_family


func validate_definition(_definition, _context: Dictionary) -> Array[String]:
	return []


# CONTENT-006 extension point. Subclasses with validation-relevant
# configuration append only semantic configuration here; runtime instance
# identity and discovery order are deliberately excluded.
func canonical_evidence_descriptor() -> Dictionary:
	var script_path: String = ""
	var script = get_script()
	if script != null:
		script_path = str(script.resource_path)
	return {
		"definition_family": definition_family,
		"evidence_revision": EVIDENCE_REVISION,
		"validator_script": script_path,
	}
