extends RefCounted
class_name UnderworldRuntimeCellResult

var cell_address
var generation: int
var tier: String
var source_fingerprint: String
var provenance_fingerprint: String
var world_id: String
var generator_manifest_id: String
var payload
var success: bool
var diagnostics: Array[String]


func _init(address_value, generation_value: int, tier_value: String, source_value: String = "", provenance_value: String = "", payload_value = null, success_value: bool = true, diagnostics_value: Array[String] = [], world_value: String = "", manifest_value: String = "") -> void:
	cell_address = address_value
	generation = generation_value
	tier = tier_value
	source_fingerprint = source_value
	provenance_fingerprint = provenance_value
	world_id = world_value
	generator_manifest_id = manifest_value
	payload = payload_value
	success = success_value
	diagnostics = diagnostics_value.duplicate()
