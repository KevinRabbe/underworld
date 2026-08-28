extends RefCounted
class_name UnderworldRuntimeCellRecord

var cell_address
var key: String
var generation: int = 0
var demands: Dictionary = {}
var readiness: Dictionary = {
	"definition": false,
	"fragment_plan": false,
	"voxel_geometry": false,
	"render": false,
	"collision": false,
	"simulation": false,
}
var queued: Dictionary = {}
var source_fingerprint: String = ""
var provenance_fingerprint: String = ""
var runtime_handle = null
var state: String = "dormant"
var diagnostics: Array[String] = []
var release_pending: bool = false


func _init(address_value = null) -> void:
	cell_address = address_value
	key = address_value.canonical_text() if address_value != null else ""


func demand_count(tier: String) -> int:
	var total := 0
	for source in demands.values():
		total += int(source.get(tier, 0))
	return total


func demanded_tiers() -> Array[String]:
	var result: Array[String] = []
	for tier in readiness.keys():
		if demand_count(str(tier)) > 0:
			result.append(str(tier))
	result.sort()
	return result
