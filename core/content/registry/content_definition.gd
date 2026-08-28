extends Resource

const ContentId := preload("res://core/content/identity/content_id.gd")

@export var content_id: String = ""
@export var definition_family: String = ""
@export var schema_revision: int = 1


func configure(
	p_content_id: String,
	p_definition_family: String,
	p_schema_revision: int = 1
) -> Resource:
	content_id = p_content_id
	definition_family = p_definition_family
	schema_revision = p_schema_revision
	return self


func validate_definition() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(ContentId.validate(content_id))
	for failure in ContentId.validate_family(definition_family):
		failures.append("definition family: %s" % failure)

	if ContentId.is_valid(content_id) and ContentId.is_valid_family(definition_family):
		var content_family: String = ContentId.family_of(content_id)
		if content_family != definition_family:
			failures.append(
				"content id family '%s' does not match definition family '%s': %s" % [
					content_family,
					definition_family,
					content_id,
				]
			)
	if schema_revision < 1:
		failures.append("schema revision must be >= 1 for %s" % content_id)
	return failures


func canonical_descriptor() -> Dictionary:
	return {
		"content_id": content_id,
		"definition_family": definition_family,
		"schema_revision": schema_revision,
	}
