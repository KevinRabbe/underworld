extends RefCounted
class_name UnderworldGeometryCellContribution

const Identity := preload("res://worldgen/graph/definition_identity.gd")
const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")

var stable_address
var stable_id: String
var source_region_id: String
var cell_coord: Vector3i
var world_bounds: AABB
var chamber_descriptor_ids: Array[String]
var tunnel_descriptor_ids: Array[String]
var reserved_site_ids: Array[String]
var fingerprint: String


func _init(
	address,
	source_region_id_value: String,
	cell_coord_value: Vector3i,
	world_bounds_value: AABB,
	chamber_ids_value: Array[String],
	tunnel_ids_value: Array[String],
	reserved_site_ids_value: Array[String]
) -> void:
	stable_address = Identity.copy_address(address)
	stable_id = Identity.id_value(stable_address)
	source_region_id = source_region_id_value
	cell_coord = cell_coord_value
	world_bounds = world_bounds_value
	chamber_descriptor_ids = chamber_ids_value.duplicate()
	tunnel_descriptor_ids = tunnel_ids_value.duplicate()
	reserved_site_ids = reserved_site_ids_value.duplicate()
	chamber_descriptor_ids.sort()
	tunnel_descriptor_ids.sort()
	reserved_site_ids.sort()
	fingerprint = "geometry-cell-" + CanonicalValue.fingerprint(canonical_data())


func canonical_data() -> Dictionary:
	return {
		"stable_address": stable_address.canonical_text(),
		"stable_id": stable_id,
		"source_region_id": source_region_id,
		"cell_coord": cell_coord,
		"world_bounds": world_bounds,
		"chamber_descriptor_ids": chamber_descriptor_ids,
		"tunnel_descriptor_ids": tunnel_descriptor_ids,
		"reserved_site_ids": reserved_site_ids,
	}
