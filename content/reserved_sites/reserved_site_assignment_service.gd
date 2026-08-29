extends RefCounted
class_name ReservedSiteAssignmentService

const Definition := preload("res://content/reserved_sites/reserved_site_content_definition.gd")
const Assignment := preload("res://content/reserved_sites/reserved_site_assignment.gd")

const CONTRACT_REVISION: int = 1


static func assign(hooks: Array, definitions: Array, rulebook_revision: int = 1) -> Dictionary:
	var failures: Array[String] = []
	if rulebook_revision <= 0:
		failures.append("Reserved-site rulebook_revision must be positive")

	var normalized_definitions: Array = []
	var definition_ids: Dictionary = {}
	for definition in definitions:
		if definition == null or not (definition is Definition):
			failures.append("Reserved-site assignment received a non-definition value")
			continue
		var definition_failures: Array[String] = definition.validate_definition()
		var label: String = str(definition.content_id)
		if label.is_empty():
			label = "<unidentified-definition>"
		for failure in definition_failures:
			failures.append("%s: %s" % [label, failure])
		if definition_ids.has(definition.content_id):
			failures.append("Duplicate reserved-site content_id: %s" % definition.content_id)
		else:
			definition_ids[definition.content_id] = true
		normalized_definitions.append(definition)
	normalized_definitions.sort_custom(_definition_less)

	var normalized_hooks: Array = []
	var hook_ids: Dictionary = {}
	for hook in hooks:
		if hook == null:
			failures.append("Reserved-site assignment received a null hook")
			continue
		var site_id: String = str(hook.get("stable_id"))
		if site_id.is_empty() or not site_id.begins_with("sid1:"):
			failures.append("Reserved-site hook requires a procedural sid1 StableId")
			continue
		if typeof(hook.get("reserved_bounds")) != TYPE_AABB:
			failures.append("Reserved-site hook %s requires AABB reserved_bounds" % site_id)
			continue
		if hook_ids.has(site_id):
			failures.append("Duplicate reserved-site hook StableId: %s" % site_id)
			continue
		hook_ids[site_id] = true
		normalized_hooks.append(hook)
	normalized_hooks.sort_custom(_hook_less)

	if not failures.is_empty():
		return _failure(failures, rulebook_revision)

	var assignments: Array = []
	for hook in normalized_hooks:
		var eligible: Array = []
		for definition in normalized_definitions:
			if definition.matches_hook(hook):
				eligible.append(definition)
		if eligible.is_empty():
			failures.append(
				"No eligible reserved-site content for %s (%s)" % [
					str(hook.get("stable_id")),
					str(hook.get("semantic_category")),
				]
			)
			continue
		var selected = _select_definition(hook, eligible, rulebook_revision)
		if selected == null:
			failures.append("Reserved-site selection failed for %s" % str(hook.get("stable_id")))
			continue
		var fingerprint := _assignment_fingerprint(hook, selected, rulebook_revision)
		assignments.append(Assignment.new(
			str(hook.get("stable_id")),
			hook.get("reserved_bounds"),
			selected.content_id,
			selected.category_ids,
			rulebook_revision,
			selected.schema_revision,
			fingerprint,
			selected.metadata
		))

	if not failures.is_empty():
		return _failure(failures, rulebook_revision)
	return {
		"success": true,
		"assignments": assignments,
		"diagnostics": [],
		"rulebook_revision": rulebook_revision,
		"contract_revision": CONTRACT_REVISION,
	}


static func _select_definition(hook, eligible: Array, rulebook_revision: int):
	eligible.sort_custom(_definition_less)
	var total_weight := 0
	var manifest_parts: Array[String] = []
	for definition in eligible:
		total_weight += definition.selection_weight
		manifest_parts.append("%s@%d#%d" % [
			definition.content_id,
			definition.schema_revision,
			definition.selection_weight,
		])
	if total_weight <= 0:
		return null
	var selection_key := "reserved-site-assignment-v%d|rules=%d|site=%s|hook=%s|defs=%s" % [
		CONTRACT_REVISION,
		rulebook_revision,
		str(hook.get("stable_id")),
		str(hook.get("semantic_category")),
		_join_strings(manifest_parts, ","),
	]
	var roll := _hex_prefix_value(selection_key.sha256_text(), 8) % total_weight
	var cursor := 0
	for definition in eligible:
		cursor += definition.selection_weight
		if roll < cursor:
			return definition
	return eligible[eligible.size() - 1]


static func _assignment_fingerprint(hook, definition, rulebook_revision: int) -> String:
	var categories: Array[String] = []
	categories.append_array(definition.category_ids)
	categories.sort()
	var payload := "reserved-site-assignment-v%d|rules=%d|site=%s|content=%s|schema=%d|categories=%s" % [
		CONTRACT_REVISION,
		rulebook_revision,
		str(hook.get("stable_id")),
		definition.content_id,
		definition.schema_revision,
		_join_strings(categories, ","),
	]
	return "rsa1:" + payload.sha256_text()


static func _failure(failures: Array[String], rulebook_revision: int) -> Dictionary:
	return {
		"success": false,
		"assignments": [],
		"diagnostics": failures,
		"rulebook_revision": rulebook_revision,
		"contract_revision": CONTRACT_REVISION,
	}


static func _definition_less(a, b) -> bool:
	return str(a.content_id) < str(b.content_id)


static func _hook_less(a, b) -> bool:
	return str(a.get("stable_id")) < str(b.get("stable_id"))


static func _join_strings(values: Array[String], separator: String) -> String:
	var result := ""
	for index in range(values.size()):
		if index > 0:
			result += separator
		result += values[index]
	return result


static func _hex_prefix_value(value: String, digits: int) -> int:
	var result := 0
	var count := mini(digits, value.length())
	for index in range(count):
		var codepoint := value.unicode_at(index)
		var digit := 0
		if codepoint >= 48 and codepoint <= 57:
			digit = codepoint - 48
		elif codepoint >= 97 and codepoint <= 102:
			digit = codepoint - 87
		else:
			continue
		result = result * 16 + digit
	return result
