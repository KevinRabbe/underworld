extends RefCounted
class_name UnderworldCaveGeometryResult

var bundle
var chamber_descriptors: Array
var tunnel_descriptors: Array
var reserved_site_descriptors: Array
var geometry_metrics: Dictionary
var fingerprint: String
var provenance


func _init(
	bundle_value,
	chamber_descriptors_value: Array,
	tunnel_descriptors_value: Array,
	metrics_value: Dictionary,
	fingerprint_value: String,
	provenance_value = null
) -> void:
	bundle = bundle_value
	chamber_descriptors = chamber_descriptors_value.duplicate()
	tunnel_descriptors = tunnel_descriptors_value.duplicate()
	reserved_site_descriptors = []
	if bundle_value != null:
		reserved_site_descriptors = bundle_value.special_location_hooks.duplicate()
	geometry_metrics = metrics_value.duplicate(true)
	fingerprint = fingerprint_value
	provenance = provenance_value
