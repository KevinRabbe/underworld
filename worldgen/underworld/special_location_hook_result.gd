extends RefCounted
class_name UnderworldSpecialLocationHookResult

var bundle
var candidate_metadata: Array
var hook_metrics: Dictionary
var fingerprint: String


func _init(
	bundle_value,
	candidate_metadata_value: Array,
	metrics_value: Dictionary,
	fingerprint_value: String
) -> void:
	bundle = bundle_value
	candidate_metadata = candidate_metadata_value.duplicate(true)
	hook_metrics = metrics_value.duplicate(true)
	fingerprint = fingerprint_value
