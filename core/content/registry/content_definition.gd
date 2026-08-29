extends Resource

const ContentId := preload("res://core/content/identity/content_id.gd")
const SchemaId := preload("res://core/content/schema/schema_id.gd")

@export var content_id: String = ""
@export var definition_family: String = ""
@export var schema_revision: int = 1
@export var category_ids: Array[String] = []
@export var capability_ids: Array[String] = []


func configure(
	p_content_id: String,
	p_definition_family: String,
	p_schema_revision: int = 1
) -> Resource:
	content_id = p_content_id
	definition_family = p_definition_family
	schema_revision = p_schema_revision
	return self


func configure_schema_declarations(
	p_category_ids: Array = [],
	p_capability_ids: Array = []
) -> Resource:
	category_ids.clear()
	capability_ids.clear()
	for category_id in p_category_ids:
		category_ids.append(str(category_id))
	for capability_id in p_capability_ids:
		capability_ids.append(str(capability_id))
	return self


# Generic authoring-validation extension point. Content families that own typed
# semantic references may override this without making ContentRegistry or the
# validation pipeline aware of that family.
func validation_references() -> Array:
	return []


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

	_validate_schema_declaration_list(category_ids, true, failures)
	_validate_schema_declaration_list(capability_ids, false, failures)
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var ordered_categories: Array[String] = []
	ordered_categories.append_array(category_ids)
	ordered_categories.sort()
	var ordered_capabilities: Array[String] = []
	ordered_capabilities.append_array(capability_ids)
	ordered_capabilities.sort()
	return {
		"content_id": content_id,
		"definition_family": definition_family,
		"schema_revision": schema_revision,
		"category_ids": ordered_categories,
		"capability_ids": ordered_capabilities,
	}


static func _validate_schema_declaration_list(
	ids: Array[String],
	is_category: bool,
	failures: Array[String]
) -> void:
	var seen: Dictionary = {}
	var label: String = "category" if is_category else "capability"
	for schema_id in ids:
		var schema_failures: Array[String] = (
			SchemaId.validate_category(schema_id)
			if is_category
			else SchemaId.validate_capability(schema_id)
		)
		for failure in schema_failures:
			failures.append("declared %s: %s" % [label, failure])
		if seen.has(schema_id):
			failures.append("duplicate declared %s schema id: %s" % [label, schema_id])
		seen[schema_id] = true
