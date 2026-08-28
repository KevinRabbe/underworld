extends RefCounted
class_name UnderworldPrimaryTopologyResult

var bundle
var network_candidate_metadata: Array = []
var node_candidate_metadata: Array = []
var boundary_candidate_metadata: Array = []
var topology_metrics: Dictionary = {}
var fingerprint: String = ""
var provenance


func _init(
	bundle_value,
	network_candidate_metadata_value: Array,
	node_candidate_metadata_value: Array,
	boundary_candidate_metadata_value: Array,
	topology_metrics_value: Dictionary,
	fingerprint_value: String,
	provenance_value = null
) -> void:
	bundle = bundle_value
	network_candidate_metadata = network_candidate_metadata_value.duplicate(true)
	node_candidate_metadata = node_candidate_metadata_value.duplicate(true)
	boundary_candidate_metadata = boundary_candidate_metadata_value.duplicate(true)
	topology_metrics = topology_metrics_value.duplicate(true)
	fingerprint = fingerprint_value
	provenance = provenance_value
