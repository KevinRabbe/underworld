extends RefCounted
class_name UnderworldWorldDefinitionService

const StableAddressScript := preload("res://worldgen/identity/stable_address.gd")
const StableIdScript := preload("res://worldgen/identity/stable_id.gd")

var generation_context
var _region_bundles_by_id: Dictionary = {}


func configure(context) -> Array[String]:
	generation_context = context
	_region_bundles_by_id.clear()
	if generation_context == null:
		return ["WorldDefinitionService requires WorldGenerationContext"]
	return generation_context.validate()


func has_region(region_address) -> bool:
	var region_id: String = _region_id_from_address(region_address)
	return not region_id.is_empty() and _region_bundles_by_id.has(region_id)


func get_region_if_ready(region_address):
	var region_id: String = _region_id_from_address(region_address)
	if region_id.is_empty():
		return null
	return _region_bundles_by_id.get(region_id)


func store_finalized_region(region_bundle) -> Array[String]:
	var failures: Array[String] = []
	if generation_context == null:
		return ["WorldDefinitionService is not configured"]
	if region_bundle == null or region_bundle.region_definition == null:
		return ["WorldDefinitionService cannot store an empty region bundle"]

	var region = region_bundle.region_definition
	if region.stable_address == null:
		return ["WorldDefinitionService region has no StableAddress"]
	var expected_id = StableIdScript.from_address(region.stable_address)
	if expected_id == null or expected_id.value() != region.stable_id:
		failures.append("WorldDefinitionService region StableId/address mismatch")
	if not failures.is_empty():
		return failures

	_region_bundles_by_id[region.stable_id] = region_bundle
	return failures


func evict_region(region_address) -> bool:
	var region_id: String = _region_id_from_address(region_address)
	if region_id.is_empty() or not _region_bundles_by_id.has(region_id):
		return false
	_region_bundles_by_id.erase(region_id)
	return true


func cached_region_count() -> int:
	return _region_bundles_by_id.size()


func make_region_request(region_x: int, region_z: int, priority: int = 0) -> Dictionary:
	var region_address = StableAddressScript.underground_region(region_x, region_z)
	return {
		"world_id": generation_context.world_id if generation_context != null else "",
		"generator_manifest_id": (
			generation_context.generator_manifest_id if generation_context != null else ""
		),
		"region_address": region_address.canonical_text(),
		"region_id": StableIdScript.from_address(region_address).value(),
		"priority": priority,
	}


static func _region_id_from_address(region_address) -> String:
	if region_address == null:
		return ""
	var stable_id = StableIdScript.from_address(region_address)
	if stable_id == null:
		return ""
	return stable_id.value()
