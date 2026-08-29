extends RefCounted

const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")

const SLOT_PREFIX := "equipment_slot."

var slot_key: String = ""
var required_category_roots: Array[String] = []
var required_capabilities: Array[String] = []


func configure(
	p_slot_key: String,
	p_required_category_roots: Array = [],
	p_required_capabilities: Array = []
) -> RefCounted:
	slot_key = p_slot_key.strip_edges()
	required_category_roots.clear()
	required_capabilities.clear()
	for value in p_required_category_roots:
		required_category_roots.append(str(value).strip_edges())
	for value in p_required_capabilities:
		required_capabilities.append(str(value).strip_edges())
	required_category_roots.sort()
	required_capabilities.sort()
	return self


func validate_rule() -> Array[String]:
	var failures: Array[String] = []
	if slot_key.is_empty() or not slot_key.begins_with(SLOT_PREFIX):
		failures.append("equipment slot key must use '%s' namespace: %s" % [SLOT_PREFIX, slot_key])
	_validate_semantic_list(required_category_roots, "category.", "category root", failures)
	_validate_semantic_list(required_capabilities, "capability.", "capability", failures)
	failures.sort()
	return failures


func compatibility_failures(definition) -> Array[String]:
	var failures: Array[String] = validate_rule()
	if definition == null or not definition is ItemDefinition:
		failures.append("equipment slot requires ItemDefinition")
		failures.sort()
		return failures
	for failure in definition.validate_definition():
		failures.append("item definition: %s" % failure)
	for required_capability in required_capabilities:
		if not definition.capability_ids.has(required_capability):
			failures.append(
				"equipment slot %s requires capability %s" % [slot_key, required_capability]
			)
	for required_root in required_category_roots:
		var matched := false
		for category_id in definition.category_ids:
			if _category_matches_root(str(category_id), required_root):
				matched = true
				break
		if not matched:
			failures.append(
				"equipment slot %s requires category root %s" % [slot_key, required_root]
			)
	failures.sort()
	return failures


func accepts(definition) -> bool:
	return compatibility_failures(definition).is_empty()


func canonical_descriptor() -> Dictionary:
	return {
		"slot_key": slot_key,
		"required_category_roots": required_category_roots.duplicate(),
		"required_capabilities": required_capabilities.duplicate(),
	}


static func _category_matches_root(category_id: String, root: String) -> bool:
	return category_id == root or category_id.begins_with(root + ".")


static func _validate_semantic_list(
	values: Array[String],
	prefix: String,
	label: String,
	failures: Array[String]
) -> void:
	var seen: Dictionary = {}
	for value in values:
		if value.is_empty() or value != value.strip_edges() or not value.begins_with(prefix):
			failures.append("equipment slot %s must use '%s' namespace: %s" % [label, prefix, value])
		if seen.has(value):
			failures.append("duplicate equipment slot %s: %s" % [label, value])
		seen[value] = true
