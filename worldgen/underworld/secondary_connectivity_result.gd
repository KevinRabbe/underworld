extends RefCounted
class_name UnderworldSecondaryConnectivityResult

var bundle
var candidate_metadata: Array
var external_edge_references: Array
var connectivity_metrics: Dictionary
var fingerprint: String


func _init(
	bundle_value,
	candidate_metadata_value: Array,
	external_edge_references_value: Array,
	metrics_value: Dictionary,
	fingerprint_value: String
) -> void:
	bundle = bundle_value
	candidate_metadata = candidate_metadata_value.duplicate(true)
	external_edge_references = external_edge_references_value.duplicate(true)
	connectivity_metrics = metrics_value.duplicate(true)
	fingerprint = fingerprint_value
