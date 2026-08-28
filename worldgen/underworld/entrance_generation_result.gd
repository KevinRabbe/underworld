extends RefCounted
class_name UnderworldEntranceGenerationResult

var bundle
var entrance_candidate_metadata: Array
var surface_integration_descriptors: Array
var entrance_metrics: Dictionary
var fingerprint: String


func _init(
	bundle_value,
	candidate_metadata_value: Array,
	descriptors_value: Array,
	metrics_value: Dictionary,
	fingerprint_value: String
) -> void:
	bundle = bundle_value
	entrance_candidate_metadata = candidate_metadata_value.duplicate(true)
	surface_integration_descriptors = descriptors_value.duplicate()
	entrance_metrics = metrics_value.duplicate(true)
	fingerprint = fingerprint_value
