extends RefCounted
class_name ReservedSiteAssignment

## Pure overlay record joining procedural site identity with authored semantic content.
## It is not a replacement StableId and does not own runtime realization.

var site_stable_id: String
var site_bounds: AABB
var content_id: String
var categories: Array[String] = []
var rulebook_revision: int
var content_schema_revision: int
var assignment_fingerprint: String
var definition_metadata: Dictionary


func _init(
	site_stable_id_value: String,
	site_bounds_value: AABB,
	content_id_value: String,
	categories_value: Array,
	rulebook_revision_value: int,
	content_schema_revision_value: int,
	assignment_fingerprint_value: String,
	definition_metadata_value: Dictionary = {}
) -> void:
	site_stable_id = site_stable_id_value
	site_bounds = site_bounds_value
	content_id = content_id_value
	for value in categories_value:
		categories.append(str(value))
	categories.sort()
	rulebook_revision = rulebook_revision_value
	content_schema_revision = content_schema_revision_value
	assignment_fingerprint = assignment_fingerprint_value
	definition_metadata = definition_metadata_value.duplicate(true)


func canonical_data() -> Dictionary:
	return {
		"site_stable_id": site_stable_id,
		"site_bounds": site_bounds,
		"content_id": content_id,
		"categories": categories.duplicate(),
		"rulebook_revision": rulebook_revision,
		"content_schema_revision": content_schema_revision,
		"assignment_fingerprint": assignment_fingerprint,
		"definition_metadata": definition_metadata.duplicate(true),
	}
