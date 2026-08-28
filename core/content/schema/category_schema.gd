extends Resource

const SchemaId := preload("res://core/content/schema/schema_id.gd")

@export var schema_id: String = ""
@export var schema_revision: int = 1
@export var parent_ids: Array[String] = []


func configure(
	p_schema_id: String,
	p_parent_ids: Array = [],
	p_schema_revision: int = 1
) -> Resource:
	schema_id = p_schema_id
	schema_revision = p_schema_revision
	parent_ids.clear()
	for parent_id in p_parent_ids:
		parent_ids.append(str(parent_id))
	return self


func validate_schema() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(SchemaId.validate_category(schema_id))
	if schema_revision < 1:
		failures.append("category schema revision must be >= 1 for %s" % schema_id)

	var seen: Dictionary = {}
	for parent_id in parent_ids:
		for failure in SchemaId.validate_category(parent_id):
			failures.append("category parent: %s" % failure)
		if seen.has(parent_id):
			failures.append("duplicate category parent reference: %s -> %s" % [schema_id, parent_id])
		seen[parent_id] = true
		if parent_id == schema_id and not schema_id.is_empty():
			failures.append("category cannot directly parent itself: %s" % schema_id)
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var ordered_parents: Array[String] = []
	ordered_parents.append_array(parent_ids)
	ordered_parents.sort()
	return {
		"schema_id": schema_id,
		"schema_revision": schema_revision,
		"parent_ids": ordered_parents,
	}
