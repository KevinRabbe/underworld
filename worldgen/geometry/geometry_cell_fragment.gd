extends RefCounted
class_name UnderworldGeometryCellFragment

const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")

var fragment_id: String
var source_descriptor_id: String
var source_kind: String
var cell_address
var cell_bounds: AABB
var clipped_source_bounds: AABB
var is_owner: bool
var continuation_mask: Dictionary
var neighboring_cell_addresses: Dictionary
var source_fingerprint: String
var metadata: Dictionary


func _init(
	fragment_id_value: String,
	source_descriptor_id_value: String,
	source_kind_value: String,
	cell_address_value,
	cell_bounds_value: AABB,
	clipped_source_bounds_value: AABB,
	is_owner_value: bool,
	continuation_mask_value: Dictionary,
	neighboring_cell_addresses_value: Dictionary,
	source_fingerprint_value: String,
	metadata_value: Dictionary = {}
) -> void:
	fragment_id = fragment_id_value
	source_descriptor_id = source_descriptor_id_value
	source_kind = source_kind_value
	cell_address = cell_address_value
	cell_bounds = cell_bounds_value
	clipped_source_bounds = clipped_source_bounds_value
	is_owner = is_owner_value
	continuation_mask = continuation_mask_value.duplicate(true)
	neighboring_cell_addresses = neighboring_cell_addresses_value.duplicate(true)
	source_fingerprint = source_fingerprint_value
	metadata = metadata_value.duplicate(true)


func canonical_data() -> Dictionary:
	return {
		"fragment_id": fragment_id,
		"source_descriptor_id": source_descriptor_id,
		"source_kind": source_kind,
		"cell_address": cell_address.canonical_text(),
		"cell_bounds": cell_bounds,
		"clipped_source_bounds": clipped_source_bounds,
		"is_owner": is_owner,
		"continuation_mask": continuation_mask,
		"neighboring_cell_addresses": _canonical_neighbors(),
		"source_fingerprint": source_fingerprint,
		"metadata": metadata,
	}


func fingerprint() -> String:
	return "gfrag1:" + CanonicalValue.fingerprint(canonical_data())


func _canonical_neighbors() -> Dictionary:
	var result: Dictionary = {}
	for key in neighboring_cell_addresses.keys():
		var address = neighboring_cell_addresses[key]
		result[str(key)] = address.canonical_text() if address != null else ""
	return result

