extends RefCounted

const ContentId := preload("res://core/content/identity/content_id.gd")
const _ROLE_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_."

var source_id: String = ""
var role: String = ""
var target_id: String = ""
var expected_family: String = ""
var required: bool = true


func _init(
	p_source_id: String = "",
	p_role: String = "",
	p_target_id: String = "",
	p_expected_family: String = "",
	p_required: bool = true
) -> void:
	source_id = p_source_id
	role = p_role
	target_id = p_target_id
	expected_family = p_expected_family
	required = p_required


func validate_reference() -> Array[String]:
	var failures: Array[String] = []
	if not source_id.is_empty():
		for failure in ContentId.validate(source_id):
			failures.append("source id: %s" % failure)
	if not _is_valid_role(role):
		failures.append("reference role must be a lowercase semantic role: %s" % role)
	if target_id.is_empty():
		if required:
			failures.append("required reference target is empty")
	else:
		for failure in ContentId.validate(target_id):
			failures.append("target id: %s" % failure)
	if not expected_family.is_empty():
		for failure in ContentId.validate_family(expected_family):
			failures.append("expected family: %s" % failure)
	return failures


static func _is_valid_role(value: String) -> bool:
	if value.is_empty() or value != value.strip_edges():
		return false
	if value.begins_with(".") or value.ends_with(".") or value.contains(".."):
		return false
	for index in range(value.length()):
		if _ROLE_CHARS.find(value.substr(index, 1)) < 0:
			return false
	return true
