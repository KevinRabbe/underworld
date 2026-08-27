extends RefCounted
class_name UnderworldCaveGeometryResult

const CellPartitioner := preload("res://worldgen/geometry/geometry_cell_partitioner.gd")
const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")

var bundle
var chamber_descriptors: Array
var tunnel_descriptors: Array
var reserved_site_descriptors: Array
var cell_contributions: Array
var cell_partition_fingerprint: String
var geometry_metrics: Dictionary
var fingerprint: String


func _init(
	bundle_value,
	chamber_descriptors_value: Array,
	tunnel_descriptors_value: Array,
	metrics_value: Dictionary,
	fingerprint_value: String
) -> void:
	bundle = bundle_value
	chamber_descriptors = chamber_descriptors_value.duplicate()
	tunnel_descriptors = tunnel_descriptors_value.duplicate()
	reserved_site_descriptors = []
	if bundle_value != null:
		reserved_site_descriptors = bundle_value.special_location_hooks.duplicate()
	cell_contributions = CellPartitioner.build(
		bundle_value,
		chamber_descriptors,
		tunnel_descriptors,
		reserved_site_descriptors
	)
	var cell_data: Array = []
	for contribution in cell_contributions:
		cell_data.append(contribution.canonical_data())
	cell_partition_fingerprint = "geometry-cells-" + CanonicalValue.fingerprint(cell_data)
	geometry_metrics = metrics_value.duplicate(true)
	fingerprint = fingerprint_value
