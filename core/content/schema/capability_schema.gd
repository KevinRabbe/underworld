extends Resource

const SchemaId := preload("res://core/content/schema/schema_id.gd")

@export var schema_id: String = ""
@export var schema_revision: int = 1
@export var composed_capability_ids: Array[String] = []


func configure(
	p_schema_id: String,
	p_composed_capability_ids: Array = [],
	p_schema_revision: int = 1
) -> Resource:
	schema_id = p_schema_id
	schema_revision = p_schema_revision
	composed_capability_ids.clear()
	for capability_id in p_composed_capability_ids:
		composed_capability_ids.append(str(capability_id))
	return self


func validate_schema() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(SchemaId.validate_capability(schema_id))
	if schema_revision < 1:
		failures.append("capability schema revision must be >= 1 for %s" % schema_id)

	var seen: Dictionary = {}
	for capability_id in composed_capability_ids:
		for failure in SchemaId.validate_capability(capability_id):
			failures.append("composed capability: %s" % failure)
		if seen.has(capability_id):
			failures.append("duplicate capability composition reference: %s -> %s" % [schema_id, capability_id])
		seen[capability_id] = true
		if capability_id == schema_id and not schema_id.is_empty():
			failures.append("capability cannot directly compose itself: %s" % schema_id)
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var ordered_composition: Array[String] = []
	ordered_composition.append_array(composed_capability_ids)
	ordered_composition.sort()
	return {
		"schema_id": schema_id,
		"schema_revision": schema_revision,
		"composed_capability_ids": ordered_composition,
	}
