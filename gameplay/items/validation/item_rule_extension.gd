extends RefCounted

var rule_id: String = ""


func configure(p_rule_id: String) -> RefCounted:
	rule_id = p_rule_id
	return self


func validate_extension() -> Array[String]:
	var failures: Array[String] = []
	if rule_id.is_empty() or rule_id != rule_id.strip_edges():
		failures.append("item rule extension id must be non-empty and trimmed")
	return failures


func applies_to(_definition, _context: Dictionary) -> bool:
	return false


func validate_definition(_definition, _context: Dictionary) -> Array[String]:
	return []
