extends Resource

const SchemaId := preload("res://core/content/schema/schema_id.gd")

@export var schema_id: String = ""
@export var schema_revision: int = 1


func configure(p_schema_id: String, p_schema_revision: int = 1) -> Resource:
	schema_id = p_schema_id
	schema_revision = p_schema_revision
	return self


func validate_schema() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(SchemaId.validate_semantic_role(schema_id))
	if schema_revision < 1:
		failures.append("semantic role schema revision must be >= 1 for %s" % schema_id)
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	return {
		"schema_id": schema_id,
		"schema_revision": schema_revision,
	}
