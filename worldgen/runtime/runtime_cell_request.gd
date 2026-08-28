extends RefCounted
class_name UnderworldRuntimeCellRequest

var cell_address
var generation: int
var requested_tiers: Array[String]
var source_fingerprint: String
var provenance_fingerprint: String
var world_id: String
var generator_manifest_id: String


func _init(address_value, generation_value: int, tiers_value: Array = [], source_value: String = "", provenance_value: String = "", world_value: String = "", manifest_value: String = "") -> void:
	cell_address = address_value
	generation = generation_value
	requested_tiers = []
	for tier in tiers_value:
		requested_tiers.append(str(tier))
	requested_tiers.sort()
	source_fingerprint = source_value
	provenance_fingerprint = provenance_value
	world_id = world_value
	generator_manifest_id = manifest_value


func canonical_data() -> Dictionary:
	return {
		"cell": cell_address.canonical_text() if cell_address != null else "",
		"generation": generation,
		"requested_tiers": requested_tiers,
		"source_fingerprint": source_fingerprint,
		"provenance_fingerprint": provenance_fingerprint,
		"world_id": world_id,
		"generator_manifest_id": generator_manifest_id,
	}
