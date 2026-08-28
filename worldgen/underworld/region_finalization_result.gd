extends RefCounted
class_name UnderworldRegionFinalizationResult

var bundle
var external_edge_references: Array
var surface_integration_descriptors: Array
var finalization_metrics: Dictionary
var fingerprint: String


func _init(
	bundle_value,
	external_edge_references_value: Array,
	surface_integration_descriptors_value: Array,
	metrics_value: Dictionary,
	fingerprint_value: String
) -> void:
	bundle = bundle_value
	external_edge_references = external_edge_references_value.duplicate()
	surface_integration_descriptors = surface_integration_descriptors_value.duplicate()
	finalization_metrics = metrics_value.duplicate(true)
	fingerprint = fingerprint_value
