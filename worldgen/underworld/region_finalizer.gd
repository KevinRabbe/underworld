extends RefCounted
class_name UnderworldRegionFinalizer

const StageResult := preload("res://worldgen/pipeline/generation_stage_result.gd")
const GraphCanonicalizer := preload("res://worldgen/validation/graph_canonicalizer.gd")
const GraphValidator := preload("res://worldgen/validation/graph_validator.gd")
const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")
const FinalizationResult := preload("res://worldgen/underworld/region_finalization_result.gd")


static func generate(
	context,
	region_plan,
	entrance_result,
	connectivity_result,
	hook_result
):
	if context == null:
		return StageResult.fail("region_finalization", ["WorldGenerationContext is null"])
	if region_plan == null:
		return StageResult.fail("region_finalization", ["MacroRegionPlan is null"])
	if entrance_result == null or entrance_result.bundle == null:
		return StageResult.fail("region_finalization", ["EntranceGenerationResult is null"])
	if connectivity_result == null or connectivity_result.bundle == null:
		return StageResult.fail("region_finalization", ["SecondaryConnectivityResult is null"])
	if hook_result == null or hook_result.bundle == null:
		return StageResult.fail("region_finalization", ["SpecialLocationHookResult is null"])
	var failures: Array[String] = context.validate()
	if not failures.is_empty():
		return StageResult.fail("region_finalization", failures)

	var bundle = hook_result.bundle
	var region_id: String = bundle.region_definition.stable_id
	if region_id != region_plan.stable_id:
		failures.append("Finalization inputs refer to different regions")
	if entrance_result.bundle.region_definition.stable_id != region_id:
		failures.append("Entrance result belongs to another region")
	if connectivity_result.bundle.region_definition.stable_id != region_id:
		failures.append("Connectivity result belongs to another region")
	failures.append_array(GraphValidator.validate_region_bundle(bundle))

	var external_refs: Array = connectivity_result.external_edge_references.duplicate()
	external_refs.sort_custom(_external_less)
	var surface_descriptors: Array = entrance_result.surface_integration_descriptors.duplicate()
	surface_descriptors.sort_custom(_surface_less)
	failures.append_array(_validate_external_refs(region_id, external_refs))
	failures.append_array(_validate_surface_descriptors(bundle, region_id, surface_descriptors))
	if not failures.is_empty():
		return StageResult.fail("region_finalization", failures)

	var reference_data: Array = []
	for reference in external_refs:
		reference_data.append(reference.canonical_data())
	var surface_data: Array = []
	for descriptor in surface_descriptors:
		surface_data.append(descriptor.canonical_data())
	var metrics: Dictionary = {
		"network_count": bundle.networks.size(),
		"node_count": bundle.nodes.size(),
		"edge_count": bundle.edges.size(),
		"entrance_count": bundle.entrances.size(),
		"special_location_hook_count": bundle.special_location_hooks.size(),
		"external_edge_reference_count": external_refs.size(),
		"surface_integration_descriptor_count": surface_descriptors.size(),
	}
	var fingerprint: String = "finalized-region-" + CanonicalValue.fingerprint({
		"entrance_fingerprint": entrance_result.fingerprint,
		"connectivity_fingerprint": connectivity_result.fingerprint,
		"hook_fingerprint": hook_result.fingerprint,
		"graph": GraphCanonicalizer.region_bundle_data(bundle),
		"external_edge_references": reference_data,
		"surface_integration_descriptors": surface_data,
		"metrics": metrics,
	})
	return StageResult.ok(
		"region_finalization",
		FinalizationResult.new(bundle, external_refs, surface_descriptors, metrics, fingerprint),
		fingerprint
	)


static func _validate_external_refs(region_id: String, references: Array) -> Array[String]:
	var failures: Array[String] = []
	var ids: Dictionary = {}
	for reference in references:
		if reference == null:
			failures.append("Finalization contains null external edge reference")
			continue
		if reference.local_region_id != region_id:
			failures.append("External edge reference has wrong local region: " + reference.edge_stable_id)
		if reference.owner_region_id == region_id:
			failures.append("External edge reference is locally owned: " + reference.edge_stable_id)
		if ids.has(reference.edge_stable_id):
			failures.append("Duplicate external edge reference: " + reference.edge_stable_id)
		ids[reference.edge_stable_id] = true
	return failures


static func _validate_surface_descriptors(bundle, region_id: String, descriptors: Array) -> Array[String]:
	var failures: Array[String] = []
	var entrance_ids: Dictionary = {}
	for entrance in bundle.entrances:
		if entrance != null:
			entrance_ids[entrance.stable_id] = true
	var seen: Dictionary = {}
	for descriptor in descriptors:
		if descriptor == null:
			failures.append("Finalization contains null surface integration descriptor")
			continue
		if descriptor.owning_region_id != region_id:
			failures.append("Surface integration descriptor has wrong region: " + descriptor.entrance_id)
		if not entrance_ids.has(descriptor.entrance_id):
			failures.append("Surface integration descriptor references missing entrance: " + descriptor.entrance_id)
		if seen.has(descriptor.entrance_id):
			failures.append("Duplicate surface integration descriptor: " + descriptor.entrance_id)
		seen[descriptor.entrance_id] = true
	return failures


static func _external_less(a, b) -> bool:
	return str(a.edge_stable_id) < str(b.edge_stable_id)


static func _surface_less(a, b) -> bool:
	return str(a.entrance_id) < str(b.entrance_id)
