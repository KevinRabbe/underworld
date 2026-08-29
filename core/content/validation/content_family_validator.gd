extends RefCounted

const ContentId := preload("res://core/content/identity/content_id.gd")

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
