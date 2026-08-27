extends RefCounted
class_name UnderworldCaveGeometryResult

var bundle
var chamber_descriptors: Array
var tunnel_descriptors: Array
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
	geometry_metrics = metrics_value.duplicate(true)
	fingerprint = fingerprint_value
