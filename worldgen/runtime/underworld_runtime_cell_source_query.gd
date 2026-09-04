extends RefCounted
class_name UnderworldRuntimeCellSourceQuery

const CaveRuntimeController := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const CellAddress := preload("res://worldgen/geometry/geometry_cell_address.gd")

const DEFAULT_REQUIRED_TIER := "render"


## Narrow read-only boundary over #372 runtime internals. Callers receive detached
## value snapshots only; demand, execution, cache, readiness and eviction remain
## owned by UnderworldCaveRuntimeController/UnderworldRuntimeStreamer.
static func current_snapshot(
	controller,
	address,
	required_tier: String = DEFAULT_REQUIRED_TIER
) -> Dictionary:
	if controller == null or not controller is CaveRuntimeController:
		return {}
	if address == null or not address is CellAddress:
		return {}
	if not _valid_tier(required_tier):
		return {}
	if controller.streamer == null or controller._definition_service == null:
		return {}

	var key: String = address.canonical_text()
	var record = controller.streamer.records.get(key, null)
	if not _record_is_current(record, required_tier):
		return {}

	var generation: int = int(record.generation)
	var source_fingerprint: String = str(record.source_fingerprint)
	var provenance_fingerprint: String = str(record.provenance_fingerprint)
	if source_fingerprint.is_empty() or provenance_fingerprint.is_empty():
		return {}

	var definition_stage = controller._definition_service.cell_definition(address)
	if definition_stage == null or not bool(definition_stage.success):
		return {}
	var definition_variant = definition_stage.data
	if not definition_variant is Dictionary:
		return {}
	var definition: Dictionary = definition_variant
	if str(definition.get("source_fingerprint", "")) != source_fingerprint:
		return {}
	if str(definition.get("provenance_fingerprint", "")) != provenance_fingerprint:
		return {}
	var region_variant = definition.get("region", null)
	if not region_variant is Vector2i:
		return {}
	var cell_plan = definition.get("cell_plan", null)
	if cell_plan == null:
		return {}

	var owner_sites: Array[Dictionary] = []
	for fragment in cell_plan.fragments:
		if fragment == null or str(fragment.source_kind) != "reserved_site" or not bool(fragment.is_owner):
			continue
		var metadata_variant = fragment.metadata
		if not metadata_variant is Dictionary:
			continue
		owner_sites.append({
			"fragment_id": str(fragment.fragment_id),
			"source_descriptor_id": str(fragment.source_descriptor_id),
			"source_kind": "reserved_site",
			"cell_bounds": fragment.cell_bounds,
			"clipped_source_bounds": fragment.clipped_source_bounds,
			"is_owner": true,
			"source_fingerprint": str(fragment.source_fingerprint),
			"metadata": metadata_variant.duplicate(true),
		})
	owner_sites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_source: String = str(a.get("source_descriptor_id", ""))
		var b_source: String = str(b.get("source_descriptor_id", ""))
		if a_source != b_source:
			return a_source < b_source
		return str(a.get("fragment_id", "")) < str(b.get("fragment_id", ""))
	)

	# Definition access can synchronously touch caches. Re-read the current record
	# before publishing so release/reconfigure/identity changes fail closed.
	var current = controller.streamer.records.get(key, null)
	if not _record_matches(
		current,
		required_tier,
		generation,
		source_fingerprint,
		provenance_fingerprint
	):
		return {}

	return {
		"cell_address": key,
		"cell_coordinate": address.coordinate,
		"generation": generation,
		"source_fingerprint": source_fingerprint,
		"provenance_fingerprint": provenance_fingerprint,
		"region_coord": region_variant,
		"owner_reserved_sites": owner_sites.duplicate(true),
	}.duplicate(true)


static func current_snapshots(
	controller,
	required_tier: String = DEFAULT_REQUIRED_TIER
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if controller == null or not controller is CaveRuntimeController:
		return result
	if controller.streamer == null or not _valid_tier(required_tier):
		return result
	for address in controller.streamer.current_record_addresses():
		var snapshot: Dictionary = current_snapshot(controller, address, required_tier)
		if not snapshot.is_empty():
			result.append(snapshot)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("cell_address", "")) < str(b.get("cell_address", ""))
	)
	return result


static func snapshot_is_current(
	controller,
	snapshot: Dictionary,
	required_tier: String = DEFAULT_REQUIRED_TIER
) -> bool:
	if controller == null or not controller is CaveRuntimeController:
		return false
	if controller.streamer == null or snapshot.is_empty() or not _valid_tier(required_tier):
		return false
	var key_variant = snapshot.get("cell_address", null)
	var generation_variant = snapshot.get("generation", null)
	var source_variant = snapshot.get("source_fingerprint", null)
	var provenance_variant = snapshot.get("provenance_fingerprint", null)
	if not key_variant is String or typeof(generation_variant) != TYPE_INT:
		return false
	if not source_variant is String or not provenance_variant is String:
		return false
	var record = controller.streamer.records.get(key_variant, null)
	return _record_matches(
		record,
		required_tier,
		int(generation_variant),
		source_variant,
		provenance_variant
	)


static func tier_is_current_for_snapshot(
	controller,
	snapshot: Dictionary,
	required_tier: String
) -> bool:
	return snapshot_is_current(controller, snapshot, required_tier)


static func _record_is_current(record, required_tier: String) -> bool:
	return (
		record != null
		and not bool(record.release_pending)
		and not record.demands.is_empty()
		and bool(record.readiness.get(required_tier, false))
		and record.demand_count(required_tier) > 0
	)


static func _record_matches(
	record,
	required_tier: String,
	generation: int,
	source_fingerprint: String,
	provenance_fingerprint: String
) -> bool:
	return (
		_record_is_current(record, required_tier)
		and int(record.generation) == generation
		and str(record.source_fingerprint) == source_fingerprint
		and str(record.provenance_fingerprint) == provenance_fingerprint
	)


static func _valid_tier(value: String) -> bool:
	return not value.is_empty() and value == value.strip_edges()
