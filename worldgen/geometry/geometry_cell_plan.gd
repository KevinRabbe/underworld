extends RefCounted
class_name UnderworldGeometryCellPlan

const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")

var cell_address
var fragments: Array
var entrance_opening_metadata: Array
var reserved_site_metadata: Array
var source_geometry_fingerprint: String
var source_finalization_fingerprint: String
var metrics: Dictionary
var diagnostics: Array[String]
var fingerprint: String


func _init(
	cell_address_value,
	fragments_value: Array,
	entrance_metadata_value: Array,
	reserved_metadata_value: Array,
	geometry_fingerprint_value: String,
	finalization_fingerprint_value: String,
	metrics_value: Dictionary = {},
	diagnostics_value: Array[String] = []
) -> void:
	cell_address = cell_address_value
	fragments = fragments_value.duplicate()
	entrance_opening_metadata = entrance_metadata_value.duplicate(true)
	reserved_site_metadata = reserved_metadata_value.duplicate(true)
	source_geometry_fingerprint = geometry_fingerprint_value
	source_finalization_fingerprint = finalization_fingerprint_value
	metrics = metrics_value.duplicate(true)
	diagnostics = diagnostics_value.duplicate()
	var data := canonical_data()
	fingerprint = "gcell-plan1:" + CanonicalValue.fingerprint(data)


func canonical_data() -> Dictionary:
	var fragment_data: Array = []
	for fragment in fragments:
		fragment_data.append(fragment.canonical_data())
	fragment_data.sort_custom(func(a, b): return str(a.get("fragment_id", "")) < str(b.get("fragment_id", "")))
	var sorted_entrances := entrance_opening_metadata.duplicate(true)
	sorted_entrances.sort_custom(func(a, b): return str(a.get("entrance_id", "")) < str(b.get("entrance_id", "")))
	var sorted_sites := reserved_site_metadata.duplicate(true)
	sorted_sites.sort_custom(func(a, b): return str(a.get("site_id", "")) < str(b.get("site_id", "")))
	return {
		"cell_address": cell_address.canonical_text(),
		"fragments": fragment_data,
		"entrance_opening_metadata": sorted_entrances,
		"reserved_site_metadata": sorted_sites,
		"source_geometry_fingerprint": source_geometry_fingerprint,
		"source_finalization_fingerprint": source_finalization_fingerprint,
		"metrics": metrics,
	}

