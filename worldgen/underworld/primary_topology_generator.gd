extends RefCounted
class_name UnderworldPrimaryTopologyGenerator

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const SeedDomains := preload("res://worldgen/random/seed_domains.gd")
const SeedDeriver := preload("res://worldgen/random/seed_deriver.gd")
const StageResult := preload("res://worldgen/pipeline/generation_stage_result.gd")
const DepthProfiles := preload("res://worldgen/profiles/depth_profile_provider.gd")
const RegionDefinition := preload("res://worldgen/graph/underground_region_definition.gd")
const NetworkDefinition := preload("res://worldgen/graph/cave_network_definition.gd")
const NodeDefinition := preload("res://worldgen/graph/cave_node_definition.gd")
const EdgeDefinition := preload("res://worldgen/graph/cave_edge_definition.gd")
const RegionGraphBundle := preload("res://worldgen/graph/region_graph_bundle.gd")
const GraphCanonicalizer := preload("res://worldgen/validation/graph_canonicalizer.gd")
const GraphValidator := preload("res://worldgen/validation/graph_validator.gd")
const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")
const TopologyResult := preload("res://worldgen/underworld/primary_topology_result.gd")

const CHILD_CANDIDATE_COUNT: int = 7
const REGION_MARGIN: float = 24.0
const BOUNDARY_DISTANCE: float = 72.0


static func generate(context, region_plan):
	var failures: Array[String] = []
	if context == null:
		return StageResult.fail("primary_topology", ["WorldGenerationContext is null"])
	if region_plan == null:
		return StageResult.fail("primary_topology", ["MacroRegionPlan is null"])
	failures.append_array(context.validate())
	if not failures.is_empty():
		return StageResult.fail("primary_topology", failures)

	var networks: Array = []
	var nodes: Array = []
	var edges: Array = []
	var network_candidates: Array = []
	var node_candidates: Array = []
	var boundary_candidates: Array = []
	var region_network_ids: Array[String] = []

	for slot in region_plan.network_candidate_slots:
		var network_address = StableAddress.network(region_plan.stable_address, slot)
		var acceptance: float = SeedDeriver.random_unit(
			context.world_seed,
			network_address,
			SeedDomains.get_domain(SeedDomains.UG_NETWORK_EXISTS),
			"accept"
		)
		var accepted: bool = slot == 0 or acceptance < float(
			region_plan.topology_tendencies.get("network_acceptance", 0.55)
		)
		network_candidates.append({
			"address": network_address.canonical_text(),
			"slot": slot,
			"accepted": accepted,
		})
		if not accepted:
			continue

		var generated: Dictionary = _generate_network(
			context,
			region_plan,
			network_address,
			slot
		)
		var network = generated["network"]
		networks.append(network)
		region_network_ids.append(network.stable_id)
		nodes.append_array(generated["nodes"])
		edges.append_array(generated["edges"])
		node_candidates.append_array(generated["node_candidates"])
		boundary_candidates.append_array(generated["boundary_candidates"])

	region_network_ids.sort()
	network_candidates.sort_custom(_metadata_address_less)
	node_candidates.sort_custom(_metadata_address_less)
	boundary_candidates.sort_custom(_metadata_address_less)
	var topology_metrics: Dictionary = {
		"network_candidate_count": region_plan.network_candidate_slots.size(),
		"accepted_network_count": networks.size(),
		"node_count": nodes.size(),
		"primary_edge_count": edges.size(),
		"primary_component_count": networks.size(),
		"boundary_candidate_count": boundary_candidates.size(),
	}
	var region = RegionDefinition.new(
		region_plan.stable_address,
		region_plan.region_coord,
		region_plan.world_anchor,
		region_plan.world_bounds,
		region_plan.profile_bias,
		region_network_ids,
		[],
		[],
		[],
		topology_metrics
	)
	var bundle = RegionGraphBundle.new(region, networks, nodes, edges)
	failures.append_array(GraphValidator.validate_region_bundle(bundle))
	if not failures.is_empty():
		return StageResult.fail("primary_topology", failures)

	var fingerprint_data: Dictionary = {
		"graph": GraphCanonicalizer.region_bundle_data(bundle),
		"network_candidates": network_candidates,
		"node_candidates": node_candidates,
		"boundary_candidates": boundary_candidates,
		"metrics": topology_metrics,
	}
	var fingerprint: String = "topology-" + CanonicalValue.fingerprint(fingerprint_data)
	var result = TopologyResult.new(
		bundle,
		network_candidates,
		node_candidates,
		boundary_candidates,
		topology_metrics,
		fingerprint
	)
	return StageResult.ok("primary_topology", result, fingerprint)


static func _generate_network(
	context,
	region_plan,
	network_address,
	network_slot: int
) -> Dictionary:
	var network_id: String = StableId.from_address(network_address).value()
	var records: Array = []
	var node_candidates: Array = []
	var root_address = StableAddress.node(network_address)
	var root_position: Vector3 = _root_position(context, region_plan, network_address)
	records.append({
		"address": root_address,
		"position": root_position,
		"parent_index": -1,
		"candidate_slot": -1,
	})

	for candidate_slot in range(CHILD_CANDIDATE_COUNT):
		var node_address = StableAddress.node(network_address, [candidate_slot])
		var parent_index: int = int(SeedDeriver.derive_u32(
			context.world_seed,
			node_address,
			SeedDomains.get_domain(SeedDomains.UG_PRIMARY_EDGE_TOPOLOGY),
			"parent"
		) % records.size())
		var parent_record: Dictionary = records[parent_index]
		var parent_profile: Vector3 = DepthProfiles.sample(
			context,
			region_plan,
			parent_record["position"],
			parent_record["address"]
		)
		var grammar: Dictionary = DepthProfiles.resolve_grammar(
			parent_profile,
			region_plan.topology_tendencies
		)
		var acceptance: float = SeedDeriver.random_unit(
			context.world_seed,
			node_address,
			SeedDomains.get_domain(SeedDomains.UG_NODE_EXISTS),
			"accept"
		)
		var accepted: bool = candidate_slot == 0 or acceptance < float(
			grammar["branch_acceptance"]
		)
		node_candidates.append({
			"address": node_address.canonical_text(),
			"network_slot": network_slot,
			"slot": candidate_slot,
			"accepted": accepted,
		})
		if not accepted:
			continue

		var child_position: Vector3 = _child_position(
			context,
			region_plan,
			node_address,
			parent_record["position"],
			grammar
		)
		records.append({
			"address": node_address,
			"position": child_position,
			"parent_index": parent_index,
			"candidate_slot": candidate_slot,
		})

	var degrees: Array[int] = []
	for _record in records:
		degrees.append(0)
	for record_index in range(1, records.size()):
		var parent_index: int = int(records[record_index]["parent_index"])
		degrees[parent_index] += 1
		degrees[record_index] += 1

	var nodes: Array = []
	var node_ids: Array[String] = []
	for record_index in range(records.size()):
		var record: Dictionary = records[record_index]
		var node_address = record["address"]
		var node_id: String = StableId.from_address(node_address).value()
		var profile: Vector3 = DepthProfiles.sample(
			context,
			region_plan,
			record["position"],
			node_address
		)
		var grammar: Dictionary = DepthProfiles.resolve_grammar(
			profile,
			region_plan.topology_tendencies
		)
		var size_scale: float = float(grammar["chamber_scale"])
		var shape_domain = SeedDomains.get_domain(SeedDomains.UG_NODE_SHAPE)
		var size := Vector3(
			(13.0 + SeedDeriver.random_unit(context.world_seed, node_address, shape_domain, "x") * 15.0) * size_scale,
			(8.0 + SeedDeriver.random_unit(context.world_seed, node_address, shape_domain, "y") * 10.0) * size_scale,
			(13.0 + SeedDeriver.random_unit(context.world_seed, node_address, shape_domain, "z") * 15.0) * size_scale
		)
		var semantic_type: String = _semantic_type(record_index, degrees[record_index])
		var tags: Array[String] = [_dominant_profile_tag(profile)]
		var node = NodeDefinition.new(
			node_address,
			network_id,
			record["position"],
			"ellipsoid",
			size,
			profile,
			semantic_type,
			tags,
			{
				"candidate_slot": record["candidate_slot"],
				"parent_candidate_index": record["parent_index"],
				"degree": degrees[record_index],
			}
		)
		nodes.append(node)
		node_ids.append(node_id)

	var edges: Array = []
	var edge_ids: Array[String] = []
	for record_index in range(1, records.size()):
		var record: Dictionary = records[record_index]
		var parent_index: int = int(record["parent_index"])
		var parent: Dictionary = records[parent_index]
		var edge_slot: int = int(record["candidate_slot"])
		var edge_address = StableAddress.primary_edge(
			network_address,
			parent["address"],
			record["address"],
			edge_slot
		)
		var delta: Vector3 = record["position"] - parent["position"]
		var connection_class: String = (
			"vertical_transition" if absf(delta.y) >= 24.0 else "primary"
		)
		var child_profile: Vector3 = nodes[record_index].profile_blend
		var grammar: Dictionary = DepthProfiles.resolve_grammar(
			child_profile,
			region_plan.topology_tendencies
		)
		var edge = EdgeDefinition.new(
			edge_address,
			StableId.from_address(parent["address"]).value(),
			StableId.from_address(record["address"]).value(),
			region_plan.stable_id,
			connection_class,
			{
				"candidate_slot": edge_slot,
				"length": delta.length(),
				"vertical_delta": delta.y,
			},
			{
				"width": grammar["tunnel_width"],
				"roughness": 0.45 + child_profile.z * 0.30,
			},
			["primary-tree"]
		)
		edges.append(edge)
		edge_ids.append(edge.stable_id)

	node_ids.sort()
	edge_ids.sort()
	var root_id: String = StableId.from_address(root_address).value()
	var network = NetworkDefinition.new(
		network_address,
		region_plan.stable_id,
		root_id,
		node_ids,
		edge_ids,
		[],
		{
			"candidate_slot": network_slot,
			"node_count": nodes.size(),
			"edge_count": edges.size(),
			"cycle_rank": 0,
			"connected_components": 1,
		}
	)

	var boundary_candidates: Array = []
	for node in nodes:
		boundary_candidates.append_array(_boundary_candidates(region_plan, node))
	return {
		"network": network,
		"nodes": nodes,
		"edges": edges,
		"node_candidates": node_candidates,
		"boundary_candidates": boundary_candidates,
	}


static func _root_position(context, region_plan, network_address) -> Vector3:
	var domain = SeedDomains.get_domain(SeedDomains.UG_NODE_POSITION)
	var bounds: AABB = region_plan.world_bounds
	return Vector3(
		lerpf(
			bounds.position.x + REGION_MARGIN,
			bounds.end.x - REGION_MARGIN,
			SeedDeriver.random_unit(context.world_seed, network_address, domain, "root-x")
		),
		lerpf(
			bounds.position.y + REGION_MARGIN,
			bounds.end.y - 32.0,
			SeedDeriver.random_unit(context.world_seed, network_address, domain, "root-y")
		),
		lerpf(
			bounds.position.z + REGION_MARGIN,
			bounds.end.z - REGION_MARGIN,
			SeedDeriver.random_unit(context.world_seed, network_address, domain, "root-z")
		)
	)


static func _child_position(
	context,
	region_plan,
	node_address,
	parent_position: Vector3,
	grammar: Dictionary
) -> Vector3:
	var domain = SeedDomains.get_domain(SeedDomains.UG_NODE_POSITION)
	var angle: float = SeedDeriver.random_unit(
		context.world_seed, node_address, domain, "azimuth"
	) * TAU
	var length: float = float(grammar["tunnel_length"]) * lerpf(
		0.72,
		1.28,
		SeedDeriver.random_unit(context.world_seed, node_address, domain, "length")
	)
	var vertical: float = lerpf(
		-42.0,
		28.0,
		SeedDeriver.random_unit(context.world_seed, node_address, domain, "vertical")
	) * float(grammar["verticality"])
	var proposed := parent_position + Vector3(cos(angle) * length, vertical, sin(angle) * length)
	var bounds: AABB = region_plan.world_bounds
	return Vector3(
		clampf(proposed.x, bounds.position.x + REGION_MARGIN, bounds.end.x - REGION_MARGIN),
		clampf(proposed.y, bounds.position.y + REGION_MARGIN, bounds.end.y - REGION_MARGIN),
		clampf(proposed.z, bounds.position.z + REGION_MARGIN, bounds.end.z - REGION_MARGIN)
	)


static func _boundary_candidates(region_plan, node) -> Array:
	var result: Array = []
	var bounds: AABB = region_plan.world_bounds
	var distances: Dictionary = {
		"west": node.world_position.x - bounds.position.x,
		"east": bounds.end.x - node.world_position.x,
		"north": node.world_position.z - bounds.position.z,
		"south": bounds.end.z - node.world_position.z,
	}
	var sides: Array = distances.keys()
	sides.sort()
	for side_variant in sides:
		var side: String = str(side_variant)
		var distance: float = float(distances[side])
		if distance > BOUNDARY_DISTANCE:
			continue
		var candidate_address = StableAddress.generated_child(
			node.stable_address,
			"boundary-" + side,
			0
		)
		result.append({
			"address": candidate_address.canonical_text(),
			"node_id": node.stable_id,
			"side": side,
			"distance": distance,
		})
	return result


static func _semantic_type(record_index: int, degree: int) -> String:
	if record_index == 0:
		return "chamber"
	if degree <= 1:
		return "terminal"
	if degree >= 3:
		return "junction"
	return "chamber"


static func _dominant_profile_tag(profile: Vector3) -> String:
	if profile.x >= profile.y and profile.x >= profile.z:
		return "profile-shallow"
	if profile.y >= profile.z:
		return "profile-mid"
	return "profile-deep"


static func _metadata_address_less(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("address", "")) < str(b.get("address", ""))
