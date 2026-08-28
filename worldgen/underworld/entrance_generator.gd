extends RefCounted
class_name UnderworldEntranceGenerator

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const SeedDomains := preload("res://worldgen/random/seed_domains.gd")
const SeedDeriver := preload("res://worldgen/random/seed_deriver.gd")
const StageResult := preload("res://worldgen/pipeline/generation_stage_result.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const DepthProfiles := preload("res://worldgen/profiles/depth_profile_provider.gd")
const RegionDefinition := preload("res://worldgen/graph/underground_region_definition.gd")
const NetworkDefinition := preload("res://worldgen/graph/cave_network_definition.gd")
const NodeDefinition := preload("res://worldgen/graph/cave_node_definition.gd")
const EdgeDefinition := preload("res://worldgen/graph/cave_edge_definition.gd")
const EntranceDefinition := preload("res://worldgen/graph/entrance_definition.gd")
const SurfaceDescriptor := preload("res://worldgen/graph/surface_entrance_integration_descriptor.gd")
const RegionGraphBundle := preload("res://worldgen/graph/region_graph_bundle.gd")
const GraphCanonicalizer := preload("res://worldgen/validation/graph_canonicalizer.gd")
const GraphValidator := preload("res://worldgen/validation/graph_validator.gd")
const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")
const EntranceResult := preload("res://worldgen/underworld/entrance_generation_result.gd")

const SURFACE_JITTER_RADIUS: float = 42.0


static func generate(context, region_plan, primary_topology, surface_sampler = null):
	var failures: Array[String] = []
	if context == null:
		return StageResult.fail("entrance_generation", ["WorldGenerationContext is null"])
	if region_plan == null:
		return StageResult.fail("entrance_generation", ["MacroRegionPlan is null"])
	if primary_topology == null or primary_topology.bundle == null:
		return StageResult.fail("entrance_generation", ["PrimaryTopologyResult is null"])
	failures.append_array(context.validate())
	if not failures.is_empty():
		return StageResult.fail("entrance_generation", failures)
	if surface_sampler == null:
		surface_sampler = SurfaceSampler.new(context.world_seed)

	var source_bundle = primary_topology.bundle
	var candidates: Array = []
	for slot in region_plan.entrance_candidate_slots:
		candidates.append(_build_candidate(
			context, region_plan, source_bundle.nodes, slot, surface_sampler
		))

	var ranked: Array = candidates.duplicate()
	ranked.sort_custom(_candidate_score_greater)
	var target_count: int = _target_count(context, region_plan)
	var accepted_addresses: Dictionary = {}
	var used_nodes: Dictionary = {}
	var accepted_count: int = 0
	for candidate in ranked:
		if accepted_count >= target_count:
			break
		if float(candidate["surface_viability_score"]) < 0.25:
			continue
		if used_nodes.has(candidate["connected_node_id"]):
			continue
		accepted_addresses[candidate["address"]] = true
		used_nodes[candidate["connected_node_id"]] = true
		accepted_count += 1

	var nodes: Array = source_bundle.nodes.duplicate()
	var edges: Array = source_bundle.edges.duplicate()
	var entrances: Array = []
	var descriptors: Array = []
	var additions_by_network: Dictionary = {}
	var candidate_metadata: Array = []
	for candidate in candidates:
		var accepted: bool = accepted_addresses.has(candidate["address"])
		candidate["accepted"] = accepted
		candidate_metadata.append(_candidate_metadata(candidate))
		if not accepted:
			continue
		var built: Dictionary = _build_entrance(
			context, region_plan, candidate, surface_sampler
		)
		nodes.append(built["anchor_node"])
		edges.append(built["path_edge"])
		entrances.append(built["entrance"])
		descriptors.append(built["descriptor"])
		var network_id: String = str(candidate["connected_network_id"])
		if not additions_by_network.has(network_id):
			additions_by_network[network_id] = {
				"node_ids": [], "edge_ids": [], "entrance_ids": [],
			}
		additions_by_network[network_id]["node_ids"].append(built["anchor_node"].stable_id)
		additions_by_network[network_id]["edge_ids"].append(built["path_edge"].stable_id)
		additions_by_network[network_id]["entrance_ids"].append(built["entrance"].stable_id)

	var networks: Array = []
	for source_network in source_bundle.networks:
		var additions: Dictionary = additions_by_network.get(source_network.stable_id, {
			"node_ids": [], "edge_ids": [], "entrance_ids": [],
		})
		var node_ids: Array = source_network.node_ids.duplicate()
		node_ids.append_array(additions["node_ids"])
		node_ids.sort()
		var entrance_ids: Array = source_network.attached_entrance_ids.duplicate()
		entrance_ids.append_array(additions["entrance_ids"])
		entrance_ids.sort()
		var path_ids: Array = source_network.entrance_path_edge_ids.duplicate()
		path_ids.append_array(additions["edge_ids"])
		path_ids.sort()
		var metrics: Dictionary = source_network.topology_metrics.duplicate(true)
		metrics["entrance_count"] = entrance_ids.size()
		metrics["entrance_path_edge_count"] = path_ids.size()
		networks.append(NetworkDefinition.new(
			source_network.stable_address,
			source_network.owning_region_id,
			source_network.root_node_id,
			node_ids,
			source_network.primary_edge_ids,
			entrance_ids,
			metrics,
			path_ids
		))

	var region_entrance_ids: Array[String] = []
	for entrance in entrances:
		region_entrance_ids.append(entrance.stable_id)
	region_entrance_ids.sort()
	var region_metrics: Dictionary = source_bundle.region_definition.topology_metrics.duplicate(true)
	region_metrics["entrance_candidate_count"] = candidates.size()
	region_metrics["entrance_count"] = entrances.size()
	region_metrics["entrance_path_edge_count"] = entrances.size()
	var source_region = source_bundle.region_definition
	var region = RegionDefinition.new(
		source_region.stable_address,
		source_region.region_coord,
		source_region.world_anchor,
		source_region.world_bounds,
		source_region.profile_bias,
		source_region.network_ids,
		region_entrance_ids,
		source_region.secondary_edge_ids,
		source_region.special_location_hook_ids,
		region_metrics
	)
	var bundle = RegionGraphBundle.new(
		region, networks, nodes, edges, entrances, source_bundle.special_location_hooks
	)
	failures.append_array(GraphValidator.validate_region_bundle(bundle))
	failures.append_array(_validate_descriptors(bundle, descriptors))
	if not failures.is_empty():
		return StageResult.fail("entrance_generation", failures)

	candidate_metadata.sort_custom(_metadata_address_less)
	descriptors.sort_custom(_descriptor_id_less)
	var metrics: Dictionary = {
		"candidate_count": candidates.size(),
		"target_count": target_count,
		"accepted_count": entrances.size(),
		"descriptor_count": descriptors.size(),
	}
	var descriptor_data: Array = []
	for descriptor in descriptors:
		descriptor_data.append(descriptor.canonical_data())
	var fingerprint_data: Dictionary = {
		"graph": GraphCanonicalizer.region_bundle_data(bundle),
		"candidates": candidate_metadata,
		"surface_descriptors": descriptor_data,
		"metrics": metrics,
	}
	var fingerprint: String = "entrances-" + CanonicalValue.fingerprint(fingerprint_data)
	return StageResult.ok(
		"entrance_generation",
		EntranceResult.new(bundle, candidate_metadata, descriptors, metrics, fingerprint),
		fingerprint
	)


static func _build_candidate(context, region_plan, nodes: Array, slot: int, surface_sampler) -> Dictionary:
	var address = StableAddress.entrance(region_plan.stable_address, slot)
	var best: Dictionary = {}
	for node in nodes:
		var domain = SeedDomains.get_domain(SeedDomains.UG_ENTRANCE_SURFACE)
		var x: float = node.world_position.x + lerpf(-SURFACE_JITTER_RADIUS, SURFACE_JITTER_RADIUS,
			SeedDeriver.random_unit(context.world_seed, address, domain, node.stable_id + ":x"))
		var z: float = node.world_position.z + lerpf(-SURFACE_JITTER_RADIUS, SURFACE_JITTER_RADIUS,
			SeedDeriver.random_unit(context.world_seed, address, domain, node.stable_id + ":z"))
		x = clampf(x, region_plan.world_bounds.position.x, region_plan.world_bounds.end.x)
		z = clampf(z, region_plan.world_bounds.position.z, region_plan.world_bounds.end.z)
		var sample = surface_sampler.sample(x, z)
		var degree: float = float(node.generation_metadata.get("degree", 1))
		var topology_score: float = clampf(
			node.profile_blend.x * 0.50
			+ clampf(degree / 4.0, 0.0, 1.0) * 0.20
			+ (0.20 if node.semantic_type == "terminal" else 0.10)
			+ SeedDeriver.random_unit(
				context.world_seed, address,
				SeedDomains.get_domain(SeedDomains.UG_ENTRANCE_SELECTION),
				node.stable_id
			) * 0.10,
			0.0, 1.0
		)
		var surface_score: float = clampf(
			sample.buildability * 0.50
			+ (1.0 - sample.slope) * 0.30
			+ (0.0 if sample.is_submerged() else 0.20),
			0.0, 1.0
		)
		var depth: float = sample.world_position.y - node.world_position.y
		var depth_score: float = clampf(1.0 - absf(depth - 90.0) / 260.0, 0.0, 1.0)
		var total: float = topology_score * 0.45 + surface_score * 0.40 + depth_score * 0.15
		if best.is_empty() or total > float(best["total_score"]):
			best = {
				"address_object": address,
				"address": address.canonical_text(),
				"slot": slot,
				"connected_node": node,
				"connected_node_id": node.stable_id,
				"connected_network_id": node.owning_network_id,
				"surface_sample": sample,
				"topology_usefulness_score": topology_score,
				"surface_viability_score": surface_score,
				"depth_suitability_score": depth_score,
				"surface_relative_depth": depth,
				"total_score": total,
			}
	return best


static func _build_entrance(context, region_plan, candidate: Dictionary, surface_sampler) -> Dictionary:
	var address = candidate["address_object"]
	var node = candidate["connected_node"]
	var sample = candidate["surface_sample"]
	var profile: String = _descent_profile(context, address, candidate)
	var anchor_depth: float = 10.0
	match profile:
		"gradual_cave": anchor_depth = 8.0
		"steep_sinkhole": anchor_depth = 18.0
		"crevice": anchor_depth = 12.0
	var anchor_position: Vector3 = sample.world_position - Vector3.UP * anchor_depth
	var anchor_address = StableAddress.entrance_anchor(address)
	var anchor_profile: Vector3 = DepthProfiles.sample(
		context, region_plan, anchor_position, anchor_address, surface_sampler
	)
	var anchor_node = NodeDefinition.new(
		anchor_address,
		node.owning_network_id,
		anchor_position,
		"entrance_anchor",
		Vector3(10.0, 8.0, 10.0),
		anchor_profile,
		"entrance_anchor",
		["entrance-path"],
		{"entrance_id": StableId.from_address(address).value()}
	)
	var delta: Vector3 = node.world_position - anchor_position
	var path_address = StableAddress.entrance_path(address, node.stable_address)
	var path_edge = EdgeDefinition.new(
		path_address,
		anchor_node.stable_id,
		node.stable_id,
		region_plan.stable_id,
		"entrance_path",
		{
			"entrance_id": StableId.from_address(address).value(),
			"length": delta.length(),
			"vertical_delta": delta.y,
			"descent_profile": profile,
		},
		{"width": 5.0, "roughness": 0.55},
		["entrance-path"]
	)
	var horizontal := Vector3(delta.x, 0.0, delta.z)
	var orientation := horizontal.normalized() if horizontal.length_squared() > 0.0001 else Vector3.FORWARD
	var clearance: float = 7.0 if profile == "steep_sinkhole" else 5.5
	var opening_bounds := AABB(
		sample.world_position - Vector3(clearance, 3.0, clearance),
		Vector3(clearance * 2.0, 8.0, clearance * 2.0)
	)
	var integration: Dictionary = {
		"orientation": orientation,
		"required_opening_bounds": opening_bounds,
		"clearance_radius": clearance,
	}
	var entrance = EntranceDefinition.new(
		address,
		region_plan.stable_id,
		node.owning_network_id,
		node.stable_id,
		sample.world_position,
		anchor_position,
		"natural",
		profile,
		integration,
		{
			"candidate_slot": candidate["slot"],
			"topology_usefulness_score": candidate["topology_usefulness_score"],
			"surface_viability_score": candidate["surface_viability_score"],
			"surface_relative_depth": candidate["surface_relative_depth"],
			"entrance_path_edge_id": path_edge.stable_id,
			"anchor_node_id": anchor_node.stable_id,
		}
	)
	var descriptor = SurfaceDescriptor.new(
		entrance.stable_id,
		region_plan.stable_id,
		sample.world_position,
		orientation,
		opening_bounds,
		clearance,
		node.owning_network_id,
		node.stable_id,
		anchor_position,
		profile
	)
	return {
		"entrance": entrance,
		"anchor_node": anchor_node,
		"path_edge": path_edge,
		"descriptor": descriptor,
	}


static func _target_count(context, region_plan) -> int:
	var roll: float = SeedDeriver.random_unit(
		context.world_seed,
		region_plan.stable_address,
		SeedDomains.get_domain(SeedDomains.UG_ENTRANCE_SELECTION),
		"target-count"
	)
	if roll < 0.08:
		return 0
	if roll < 0.50:
		return 1
	if roll < 0.85:
		return 2
	return 3


static func _descent_profile(context, address, candidate: Dictionary) -> String:
	var roll: float = SeedDeriver.random_unit(
		context.world_seed,
		address,
		SeedDomains.get_domain(SeedDomains.UG_ENTRANCE_PROFILE),
		"descent-profile"
	)
	if float(candidate["surface_relative_depth"]) > 190.0 or roll > 0.76:
		return "steep_sinkhole"
	if float(candidate["surface_viability_score"]) < 0.48 or roll < 0.18:
		return "crevice"
	return "gradual_cave"


static func _candidate_metadata(candidate: Dictionary) -> Dictionary:
	return {
		"address": candidate["address"],
		"slot": candidate["slot"],
		"accepted": candidate["accepted"],
		"connected_node_id": candidate["connected_node_id"],
		"connected_network_id": candidate["connected_network_id"],
		"surface_position": candidate["surface_sample"].world_position,
		"surface_relative_depth": candidate["surface_relative_depth"],
		"topology_usefulness_score": candidate["topology_usefulness_score"],
		"surface_viability_score": candidate["surface_viability_score"],
		"depth_suitability_score": candidate["depth_suitability_score"],
		"total_score": candidate["total_score"],
	}


static func _validate_descriptors(bundle, descriptors: Array) -> Array[String]:
	var failures: Array[String] = []
	var entrance_ids: Dictionary = {}
	for entrance in bundle.entrances:
		entrance_ids[entrance.stable_id] = true
	for descriptor in descriptors:
		if not entrance_ids.has(descriptor.entrance_id):
			failures.append("Surface descriptor references missing entrance: " + descriptor.entrance_id)
		if descriptor.clearance_radius <= 0.0:
			failures.append("Surface descriptor has non-positive clearance: " + descriptor.entrance_id)
		if descriptor.required_opening_bounds.size.x <= 0.0 or descriptor.required_opening_bounds.size.z <= 0.0:
			failures.append("Surface descriptor has invalid opening bounds: " + descriptor.entrance_id)
		if absf(descriptor.orientation.length() - 1.0) > 0.001:
			failures.append("Surface descriptor orientation is not normalized: " + descriptor.entrance_id)
	return failures


static func _candidate_score_greater(a: Dictionary, b: Dictionary) -> bool:
	if float(a["total_score"]) == float(b["total_score"]):
		return str(a["address"]) < str(b["address"])
	return float(a["total_score"]) > float(b["total_score"])


static func _metadata_address_less(a: Dictionary, b: Dictionary) -> bool:
	return str(a["address"]) < str(b["address"])


static func _descriptor_id_less(a, b) -> bool:
	return a.entrance_id < b.entrance_id
