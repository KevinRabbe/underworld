extends RefCounted
class_name UnderworldSpecialLocationHookGenerator

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const SeedDomains := preload("res://worldgen/random/seed_domains.gd")
const SeedDeriver := preload("res://worldgen/random/seed_deriver.gd")
const StageResult := preload("res://worldgen/pipeline/generation_stage_result.gd")
const RegionDefinition := preload("res://worldgen/graph/underground_region_definition.gd")
const HookDefinition := preload("res://worldgen/graph/special_location_hook_definition.gd")
const RegionGraphBundle := preload("res://worldgen/graph/region_graph_bundle.gd")
const GraphCanonicalizer := preload("res://worldgen/validation/graph_canonicalizer.gd")
const GraphValidator := preload("res://worldgen/validation/graph_validator.gd")
const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")
const HookResult := preload("res://worldgen/underworld/special_location_hook_result.gd")

const MAX_RESERVED_HOOKS: int = 2


static func generate(context, region_plan, connectivity_result):
	if context == null:
		return StageResult.fail("special_location_hooks", ["WorldGenerationContext is null"])
	if region_plan == null:
		return StageResult.fail("special_location_hooks", ["MacroRegionPlan is null"])
	if connectivity_result == null or connectivity_result.bundle == null:
		return StageResult.fail("special_location_hooks", ["SecondaryConnectivityResult is null"])
	var failures: Array[String] = context.validate()
	if not failures.is_empty():
		return StageResult.fail("special_location_hooks", failures)
	var source = connectivity_result.bundle
	if source.region_definition.stable_id != region_plan.stable_id:
		return StageResult.fail("special_location_hooks", ["Hook inputs refer to different regions"])
	var source_fingerprint: String = GraphCanonicalizer.region_bundle_fingerprint(source)
	var domain = SeedDomains.get_domain(SeedDomains.UG_SPECIAL_EXISTS)
	if domain == null:
		return StageResult.fail("special_location_hooks", ["Missing ug.special.exists seed domain"])

	var eligible_nodes: Array = []
	for node in source.nodes:
		if node != null and node.semantic_type != "entrance_anchor":
			eligible_nodes.append(node)
	eligible_nodes.sort_custom(_stable_less)

	var candidates: Array = []
	for slot in region_plan.special_candidate_slots:
		if eligible_nodes.is_empty():
			break
		candidates.append(_candidate(context, region_plan, eligible_nodes, int(slot), domain))
	candidates.sort_custom(_score_greater)

	var accepted: Array = []
	var used_nodes: Dictionary = {}
	var occupied_bounds: Array = []
	for existing_hook in source.special_location_hooks:
		if existing_hook != null:
			occupied_bounds.append(existing_hook.reserved_bounds)
	for candidate in candidates:
		if accepted.size() >= MAX_RESERVED_HOOKS:
			break
		if float(candidate["roll"]) >= float(candidate["probability"]):
			continue
		var node_id: String = str(candidate["anchor_node_id"])
		if used_nodes.has(node_id):
			continue
		var bounds: AABB = candidate["reserved_bounds"]
		if _intersects_any(bounds, occupied_bounds):
			continue
		candidate["accepted"] = true
		accepted.append(candidate)
		used_nodes[node_id] = true
		occupied_bounds.append(bounds)

	var hooks: Array = source.special_location_hooks.duplicate()
	var hook_ids: Array[String] = source.region_definition.special_location_hook_ids.duplicate()
	for candidate in accepted:
		var hook = HookDefinition.new(
			candidate["address_object"],
			region_plan.stable_id,
			candidate["anchor_node_id"],
			"",
			candidate["world_anchor"],
			"reserved_site",
			candidate["reserved_bounds"],
			candidate["profile_blend"],
			{
				"candidate_slot": candidate["slot"],
				"selection_score": candidate["score"],
				"acceptance_probability": candidate["probability"],
			}
		)
		hooks.append(hook)
		hook_ids.append(hook.stable_id)
	hook_ids.sort()
	hooks.sort_custom(_stable_less)

	var old_region = source.region_definition
	var region_metrics: Dictionary = old_region.topology_metrics.duplicate(true)
	region_metrics["special_location_hook_count"] = hook_ids.size()
	region_metrics["reserved_special_site_count"] = accepted.size()
	var region = RegionDefinition.new(
		old_region.stable_address,
		old_region.region_coord,
		old_region.world_anchor,
		old_region.world_bounds,
		old_region.profile_bias,
		old_region.network_ids,
		old_region.entrance_ids,
		old_region.secondary_edge_ids,
		hook_ids,
		region_metrics
	)
	var bundle = RegionGraphBundle.new(
		region,
		source.networks,
		source.nodes,
		source.edges,
		source.entrances,
		hooks
	)
	failures.append_array(GraphValidator.validate_region_bundle(bundle))
	if GraphCanonicalizer.region_bundle_fingerprint(source) != source_fingerprint:
		failures.append("Special-location hook generation mutated its source graph")
	if not failures.is_empty():
		return StageResult.fail("special_location_hooks", failures)

	var metadata: Array = []
	for candidate in candidates:
		metadata.append(_metadata(candidate))
	metadata.sort_custom(_address_less)
	var metrics: Dictionary = {
		"candidate_count": candidates.size(),
		"accepted_count": accepted.size(),
		"total_hook_count": hooks.size(),
	}
	var fingerprint: String = "hooks-" + CanonicalValue.fingerprint({
		"source_connectivity_fingerprint": connectivity_result.fingerprint,
		"graph": GraphCanonicalizer.region_bundle_data(bundle),
		"candidates": metadata,
		"metrics": metrics,
	})
	return StageResult.ok(
		"special_location_hooks",
		HookResult.new(bundle, metadata, metrics, fingerprint),
		fingerprint
	)


static func _candidate(context, region_plan, nodes: Array, slot: int, domain) -> Dictionary:
	var address = StableAddress.special_location(region_plan.stable_address, "reserved_site", slot)
	var best: Dictionary = {}
	for node in nodes:
		var degree: float = float(node.generation_metadata.get("degree", 1))
		var profile: Vector3 = node.profile_blend
		var topology_score: float = clampf(
			clampf(degree / 4.0, 0.0, 1.0) * 0.24
			+ (0.18 if node.semantic_type == "terminal" else 0.08)
			+ profile.y * 0.20
			+ profile.z * 0.30
			+ SeedDeriver.random_unit(
				context.world_seed, address, domain, node.stable_id + ":selection"
			) * 0.18,
			0.0,
			1.0
		)
		if best.is_empty() or topology_score > float(best["score"]):
			var scale: float = lerpf(
				1.45,
				2.35,
				SeedDeriver.random_unit(context.world_seed, address, domain, node.stable_id + ":scale")
			)
			var size := Vector3(
				maxf(node.approximate_size.x * scale, 18.0),
				maxf(node.approximate_size.y * lerpf(1.25, 1.85, profile.y + profile.z), 12.0),
				maxf(node.approximate_size.z * scale, 18.0)
			)
			var bounds := AABB(node.world_position - size * 0.5, size)
			var probability: float = clampf(
				0.16 + profile.y * 0.13 + profile.z * 0.17 + topology_score * 0.08,
				0.12,
				0.42
			)
			best = {
				"address_object": address,
				"address": address.canonical_text(),
				"slot": slot,
				"anchor_node_id": node.stable_id,
				"world_anchor": node.world_position,
				"reserved_bounds": bounds,
				"profile_blend": profile,
				"score": topology_score,
				"probability": probability,
				"roll": SeedDeriver.random_unit(
					context.world_seed, address, domain, node.stable_id + ":accept"
				),
				"accepted": false,
			}
	return best


static func _metadata(candidate: Dictionary) -> Dictionary:
	return {
		"address": candidate["address"],
		"candidate_slot": candidate["slot"],
		"anchor_node_id": candidate["anchor_node_id"],
		"world_anchor": candidate["world_anchor"],
		"reserved_bounds": candidate["reserved_bounds"],
		"profile_blend": candidate["profile_blend"],
		"selection_score": candidate["score"],
		"acceptance_probability": candidate["probability"],
		"acceptance_roll": candidate["roll"],
		"accepted": candidate["accepted"],
	}


static func _intersects_any(bounds: AABB, occupied: Array) -> bool:
	for other in occupied:
		if bounds.intersects(other):
			return true
	return false


static func _score_greater(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(float(a["score"]), float(b["score"])):
		return float(a["score"]) > float(b["score"])
	return str(a["address"]) < str(b["address"])


static func _address_less(a: Dictionary, b: Dictionary) -> bool:
	return str(a["address"]) < str(b["address"])


static func _stable_less(a, b) -> bool:
	return str(a.stable_id) < str(b.stable_id)
