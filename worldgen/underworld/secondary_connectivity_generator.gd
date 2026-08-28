extends RefCounted
class_name UnderworldSecondaryConnectivityGenerator

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const SeedDomains := preload("res://worldgen/random/seed_domains.gd")
const SeedDeriver := preload("res://worldgen/random/seed_deriver.gd")
const StageResult := preload("res://worldgen/pipeline/generation_stage_result.gd")
const RegionDefinition := preload("res://worldgen/graph/underground_region_definition.gd")
const EdgeDefinition := preload("res://worldgen/graph/cave_edge_definition.gd")
const ExternalEdgeReference := preload("res://worldgen/graph/external_edge_reference.gd")
const RegionGraphBundle := preload("res://worldgen/graph/region_graph_bundle.gd")
const GraphCanonicalizer := preload("res://worldgen/validation/graph_canonicalizer.gd")
const GraphValidator := preload("res://worldgen/validation/graph_validator.gd")
const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")
const ConnectivityResult := preload("res://worldgen/underworld/secondary_connectivity_result.gd")

const MIN_LOCAL_LENGTH := 26.0
const MAX_CROSS_REGION_LENGTH := 240.0
const MIN_CROSS_REGION_SCORE := 0.42
const MAX_SECONDARY_DEGREE := 1


static func generate(context, region_plan, primary_topology, entrance_result, neighbor_views: Array = []):
	if context == null:
		return StageResult.fail("secondary_connectivity", ["WorldGenerationContext is null"])
	if region_plan == null:
		return StageResult.fail("secondary_connectivity", ["MacroRegionPlan is null"])
	if primary_topology == null or primary_topology.bundle == null:
		return StageResult.fail("secondary_connectivity", ["PrimaryTopologyResult is null"])
	if entrance_result == null or entrance_result.bundle == null:
		return StageResult.fail("secondary_connectivity", ["EntranceGenerationResult is null"])
	var failures: Array[String] = context.validate()
	if not failures.is_empty():
		return StageResult.fail("secondary_connectivity", failures)
	failures.append_array(context.validate_provenance(
		region_plan.provenance, "macro_region", region_plan.stable_id
	))
	failures.append_array(context.validate_provenance(
		primary_topology.provenance, "primary_topology", region_plan.stable_id,
		[region_plan.provenance.fingerprint]
	))
	failures.append_array(context.validate_provenance(
		entrance_result.provenance, "entrance_selection", region_plan.stable_id,
		[region_plan.provenance.fingerprint, primary_topology.provenance.fingerprint]
	))
	for view in neighbor_views:
		if not (view is Dictionary):
			continue
		var neighbor_plan = view.get("region_plan")
		var neighbor_topology = view.get("primary_topology")
		if neighbor_plan != null and neighbor_plan.provenance != null:
			failures.append_array(context.validate_provenance(
				neighbor_plan.provenance, "macro_region", neighbor_plan.stable_id
			))
		if neighbor_topology != null and neighbor_plan != null and neighbor_topology.provenance != null:
			failures.append_array(context.validate_provenance(
				neighbor_topology.provenance, "primary_topology", neighbor_plan.stable_id,
				[neighbor_plan.provenance.fingerprint]
			))
	if not failures.is_empty():
		return StageResult.fail("secondary_connectivity", failures)

	var source = entrance_result.bundle
	if source.region_definition.stable_id != region_plan.stable_id:
		return StageResult.fail("secondary_connectivity", ["Connectivity inputs refer to different regions"])

	var cave_nodes: Array = _cave_nodes(source.nodes)
	var local_candidates: Array = _local_candidates(context, region_plan, source, cave_nodes)
	var accepted_local: Array = _accept_local(region_plan, source, cave_nodes, local_candidates)

	var cross_candidates: Array = []
	var accepted_owned_cross: Array = []
	var external_refs: Array = []
	for view in _normalized_neighbors(region_plan, neighbor_views):
		var cross: Dictionary = _cross_candidates(context, region_plan, primary_topology, view)
		cross_candidates.append_array(cross["candidates"])
		var accepted = cross["accepted"]
		if accepted == null:
			continue
		if bool(accepted["owned"]):
			accepted_owned_cross.append(accepted)
		else:
			external_refs.append(_external_ref(region_plan, accepted))

	var new_edges: Array = []
	for candidate in accepted_local:
		new_edges.append(_edge(context, candidate))
	for candidate in accepted_owned_cross:
		new_edges.append(_edge(context, candidate))

	var secondary_ids: Array[String] = source.region_definition.secondary_edge_ids.duplicate()
	for edge in new_edges:
		secondary_ids.append(edge.stable_id)
	secondary_ids.sort()
	var edges: Array = source.edges.duplicate()
	edges.append_array(new_edges)

	var counts: Dictionary = _counts(accepted_local, accepted_owned_cross, external_refs)
	var region_metrics: Dictionary = source.region_definition.topology_metrics.duplicate(true)
	region_metrics["secondary_edge_count"] = secondary_ids.size()
	region_metrics["secondary_local_loop_count"] = counts["loops"]
	region_metrics["secondary_cross_network_count"] = counts["network_joins"]
	region_metrics["secondary_owned_cross_region_count"] = counts["owned_cross_region"]
	region_metrics["secondary_external_cross_region_count"] = counts["external_cross_region"]

	var old_region = source.region_definition
	var region = RegionDefinition.new(
		old_region.stable_address,
		old_region.region_coord,
		old_region.world_anchor,
		old_region.world_bounds,
		old_region.profile_bias,
		old_region.network_ids,
		old_region.entrance_ids,
		secondary_ids,
		old_region.special_location_hook_ids,
		region_metrics
	)
	var bundle = RegionGraphBundle.new(
		region, source.networks, source.nodes, edges, source.entrances, source.special_location_hooks
	)
	failures.append_array(GraphValidator.validate_region_bundle(bundle))
	failures.append_array(_validate(bundle, source, new_edges, external_refs))
	if not failures.is_empty():
		return StageResult.fail("secondary_connectivity", failures)

	var metadata: Array = []
	for candidate in local_candidates:
		metadata.append(_metadata(candidate))
	for candidate in cross_candidates:
		metadata.append(_metadata(candidate))
	metadata.sort_custom(_address_less)
	external_refs.sort_custom(_external_less)

	var reference_data: Array = []
	for reference in external_refs:
		reference_data.append(reference.canonical_data())
	var metrics := {
		"local_candidate_count": local_candidates.size(),
		"cross_region_candidate_count": cross_candidates.size(),
		"accepted_local_count": accepted_local.size(),
		"accepted_owned_cross_region_count": accepted_owned_cross.size(),
		"external_cross_region_reference_count": external_refs.size(),
		"local_loop_count": counts["loops"],
		"cross_network_count": counts["network_joins"],
	}
	var fingerprint := "connectivity-" + CanonicalValue.fingerprint({
		"graph": GraphCanonicalizer.region_bundle_data(bundle),
		"candidates": metadata,
		"external_edge_references": reference_data,
		"metrics": metrics,
	})
	var provenance = context.make_provenance(
		"secondary_connectivity",
		region.stable_id,
		region.stable_address.canonical_text(),
		_neighbor_source_fingerprints(region_plan, primary_topology, entrance_result, neighbor_views)
	)
	return StageResult.ok(
		"secondary_connectivity",
		ConnectivityResult.new(bundle, metadata, external_refs, metrics, fingerprint, provenance),
		fingerprint,
		provenance
	)


static func _neighbor_source_fingerprints(region_plan, primary_topology, entrance_result, neighbor_views: Array) -> Array[String]:
	var sources: Array[String] = [
		region_plan.provenance.fingerprint,
		primary_topology.provenance.fingerprint,
		entrance_result.provenance.fingerprint,
	]
	for view in _normalized_neighbors(region_plan, neighbor_views):
		if not (view is Dictionary):
			continue
		var neighbor_plan = view.get("region_plan")
		var neighbor_topology = view.get("primary_topology")
		if neighbor_plan != null and neighbor_plan.provenance != null:
			sources.append(neighbor_plan.provenance.fingerprint)
		if neighbor_topology != null and neighbor_topology.provenance != null:
			sources.append(neighbor_topology.provenance.fingerprint)
	sources.sort()
	return sources


static func _local_candidates(context, region_plan, bundle, nodes: Array) -> Array:
	var result: Array = []
	var existing := _pair_set(bundle.edges)
	for i in range(nodes.size()):
		for j in range(i + 1, nodes.size()):
			var a = nodes[i]
			var b = nodes[j]
			if existing.has(_pair(a.stable_id, b.stable_id)):
				continue
			var same_network: bool = a.owning_network_id == b.owning_network_id
			var hops: int = -1
			if same_network:
				hops = _primary_hops(bundle, a.owning_network_id, a.stable_id, b.stable_id)
				if hops < 3:
					continue
			var delta: Vector3 = b.world_position - a.world_position
			var length: float = delta.length()
			if length < MIN_LOCAL_LENGTH:
				continue
			var profile: Vector3 = (a.profile_blend + b.profile_blend) * 0.5
			var max_length: float = profile.x * 92.0 + profile.y * 152.0 + profile.z * 178.0
			if length > max_length:
				continue
			var connection_class: String = (
				"secondary_loop" if same_network else "cross_network_connection"
			)
			var address = StableAddress.secondary_connector(
				region_plan.stable_address,
				a.stable_address,
				b.stable_address,
				connection_class,
				0
			)
			var topology: float = (
				clampf(float(hops - 2) / 5.0, 0.0, 1.0) if same_network else 1.0
			)
			var length_score := clampf(
				1.0 - (length - MIN_LOCAL_LENGTH) / maxf(max_length - MIN_LOCAL_LENGTH, 1.0),
				0.0, 1.0
			)
			var vertical_ratio := clampf(absf(delta.y) / maxf(length, 1.0), 0.0, 1.0)
			var entrance_value := _entrance_value(bundle, a.owning_network_id, b.owning_network_id)
			var random_value := SeedDeriver.random_unit(
				context.world_seed, address,
				SeedDomains.get_domain(SeedDomains.UG_SECONDARY_EXISTS), "score"
			)
			var score := clampf(
				length_score * 0.36 + topology * 0.30
					+ (1.0 - absf(vertical_ratio - 0.28)) * 0.10
					+ entrance_value * 0.14 + random_value * 0.10,
				0.0, 1.0
			)
			var tendency := profile.x * 0.050 + profile.y * 0.165 + profile.z * 0.095
			if not same_network:
				tendency *= 1.12
			var probability := clampf(tendency * (0.55 + score * 0.70), 0.0, 0.36)
			result.append(_candidate(
				context, address, connection_class, a, b, region_plan.stable_id, "",
				length, delta.y, hops, profile, score, probability, true
			))
	result.sort_custom(_score_greater)
	return result


static func _accept_local(region_plan, bundle, nodes: Array, candidates: Array) -> Array:
	var profile := _average_profile(nodes, region_plan.profile_bias)
	var density := profile.x * 0.045 + profile.y * 0.095 + profile.z * 0.070
	var budget := clampi(
		int(round(float(nodes.size()) * density)),
		0,
		mini(5, maxi(bundle.networks.size(), 1) + 1)
	)
	var accepted: Array = []
	var degree: Dictionary = {}
	var network_pairs: Dictionary = {}
	for candidate in candidates:
		if accepted.size() >= budget:
			break
		if float(candidate["score"]) < 0.43:
			continue
		if float(candidate["roll"]) >= float(candidate["probability"]):
			continue
		var a_id: String = candidate["a_id"]
		var b_id: String = candidate["b_id"]
		if int(degree.get(a_id, 0)) >= MAX_SECONDARY_DEGREE:
			continue
		if int(degree.get(b_id, 0)) >= MAX_SECONDARY_DEGREE:
			continue
		var key: String = str(candidate["class"]) + "\n" + _pair(
			candidate["a_network"], candidate["b_network"]
		)
		if network_pairs.has(key):
			continue
		candidate["accepted"] = true
		accepted.append(candidate)
		degree[a_id] = int(degree.get(a_id, 0)) + 1
		degree[b_id] = int(degree.get(b_id, 0)) + 1
		network_pairs[key] = true
	return accepted


static func _cross_candidates(context, region_plan, primary_topology, view: Dictionary) -> Dictionary:
	var neighbor_plan = view["region_plan"]
	var neighbor_topology = view["primary_topology"]
	var sides := _shared_sides(region_plan.region_coord, neighbor_plan.region_coord)
	var local_nodes := _node_index(primary_topology.bundle.nodes)
	var remote_nodes := _node_index(neighbor_topology.bundle.nodes)
	var owner_address = StableAddress.canonical_owner(region_plan.stable_address, neighbor_plan.stable_address)
	var owner_id: String = str(StableId.from_address(owner_address).value())
	var result: Array = []

	for local_meta in primary_topology.boundary_candidate_metadata:
		if str(local_meta.get("side", "")) != sides[0]:
			continue
		var local_id := str(local_meta.get("node_id", ""))
		if not local_nodes.has(local_id):
			continue
		for remote_meta in neighbor_topology.boundary_candidate_metadata:
			if str(remote_meta.get("side", "")) != sides[1]:
				continue
			var remote_id := str(remote_meta.get("node_id", ""))
			if not remote_nodes.has(remote_id):
				continue
			var a = local_nodes[local_id]
			var b = remote_nodes[remote_id]
			var delta: Vector3 = b.world_position - a.world_position
			var length := delta.length()
			if length > MAX_CROSS_REGION_LENGTH:
				continue
			var address = StableAddress.secondary_connector(
				owner_address, a.stable_address, b.stable_address, "cross_region_connection", 0
			)
			var profile: Vector3 = (a.profile_blend + b.profile_blend) * 0.5
			var vertical_ratio := clampf(absf(delta.y) / maxf(length, 1.0), 0.0, 1.0)
			var random_value := SeedDeriver.random_unit(
				context.world_seed, address,
				SeedDomains.get_domain(SeedDomains.UG_SECONDARY_EXISTS), "cross-score"
			)
			var score := clampf(
				(1.0 - length / MAX_CROSS_REGION_LENGTH) * 0.50
					+ (1.0 - clampf(vertical_ratio * 0.65, 0.0, 0.65)) * 0.20
					+ profile.y * 0.12 + profile.z * 0.08 + random_value * 0.10,
				0.0, 1.0
			)
			var probability := clampf(0.035 + profile.y * 0.075 + profile.z * 0.035, 0.035, 0.145)
			result.append(_candidate(
				context, address, "cross_region_connection", a, b, owner_id,
				neighbor_plan.stable_id, length, delta.y, -1, profile, score, probability,
				owner_id == region_plan.stable_id
			))

	result.sort_custom(_score_greater)
	var accepted = null
	if not result.is_empty():
		var best: Dictionary = result[0]
		if float(best["score"]) >= MIN_CROSS_REGION_SCORE and float(best["roll"]) < float(best["probability"]):
			best["accepted"] = true
			accepted = best
	return {"candidates": result, "accepted": accepted}


static func _candidate(
	context,
	address,
	connection_class: String,
	a,
	b,
	owner_id: String,
	remote_region_id: String,
	length: float,
	vertical_delta: float,
	hops: int,
	profile: Vector3,
	score: float,
	probability: float,
	owned: bool
) -> Dictionary:
	return {
		"address_object": address,
		"address": address.canonical_text(),
		"class": connection_class,
		"a_id": a.stable_id,
		"b_id": b.stable_id,
		"a_network": a.owning_network_id,
		"b_network": b.owning_network_id,
		"owner_region_id": owner_id,
		"remote_region_id": remote_region_id,
		"length": length,
		"vertical_delta": vertical_delta,
		"hops": hops,
		"profile": profile,
		"score": score,
		"probability": probability,
		"roll": SeedDeriver.random_unit(
			context.world_seed, address,
			SeedDomains.get_domain(SeedDomains.UG_SECONDARY_EXISTS),
			"cross-accept" if connection_class == "cross_region_connection" else "accept"
		),
		"accepted": false,
		"owned": owned,
	}


static func _edge(context, candidate: Dictionary):
	var profile: Vector3 = candidate["profile"]
	var length: float = candidate["length"]
	var vertical_ratio := absf(float(candidate["vertical_delta"])) / maxf(length, 1.0)
	var style := "shaft" if vertical_ratio >= 0.52 else (
		"steep_tunnel" if vertical_ratio >= 0.30 else (
			"fracture" if profile.z >= 0.55 else "tunnel"
		)
	)
	var shape_domain = SeedDomains.get_domain(SeedDomains.UG_SECONDARY_SHAPE)
	var width_scale := lerpf(
		0.86, 1.16,
		SeedDeriver.random_unit(context.world_seed, candidate["address_object"], shape_domain, "width")
	)
	var roughness_random := SeedDeriver.random_unit(
		context.world_seed, candidate["address_object"], shape_domain, "roughness"
	)
	var tags: Array[String] = ["secondary"]
	if candidate["class"] == "secondary_loop":
		tags.append("loop")
	elif candidate["class"] == "cross_network_connection":
		tags.append("network-join")
	else:
		tags.append("cross-region")
	return EdgeDefinition.new(
		candidate["address_object"],
		candidate["a_id"],
		candidate["b_id"],
		candidate["owner_region_id"],
		candidate["class"],
		{
			"candidate_slot": 0,
			"length": length,
			"vertical_delta": candidate["vertical_delta"],
			"score": candidate["score"],
			"acceptance_probability": candidate["probability"],
			"source_network_id": candidate["a_network"],
			"target_network_id": candidate["b_network"],
			"remote_region_id": candidate["remote_region_id"],
			"hop_distance_before_connection": candidate["hops"],
		},
		{
			"connector_style": style,
			"width": (profile.x * 3.8 + profile.y * 5.8 + profile.z * 7.2) * width_scale,
			"roughness": 0.40 + profile.z * 0.22 + profile.y * 0.08 + roughness_random * 0.10,
			"verticality": vertical_ratio,
		},
		tags
	)


static func _external_ref(region_plan, candidate: Dictionary):
	return ExternalEdgeReference.new(
		candidate["address_object"],
		candidate["owner_region_id"],
		region_plan.stable_id,
		candidate["remote_region_id"],
		candidate["a_id"],
		candidate["b_id"],
		"cross_region_connection"
	)


static func _metadata(candidate: Dictionary) -> Dictionary:
	return {
		"address": candidate["address"],
		"connection_class": candidate["class"],
		"node_a_id": candidate["a_id"],
		"node_b_id": candidate["b_id"],
		"node_a_network_id": candidate["a_network"],
		"node_b_network_id": candidate["b_network"],
		"owner_region_id": candidate["owner_region_id"],
		"remote_region_id": candidate["remote_region_id"],
		"distance": candidate["length"],
		"vertical_delta": candidate["vertical_delta"],
		"hop_distance": candidate["hops"],
		"score": candidate["score"],
		"acceptance_probability": candidate["probability"],
		"acceptance_roll": candidate["roll"],
		"accepted": candidate["accepted"],
		"owned_by_current_region": candidate["owned"],
	}


static func _primary_hops(bundle, network_id: String, start_id: String, target_id: String) -> int:
	var adjacency: Dictionary = {}
	for node in bundle.nodes:
		if node.owning_network_id == network_id and node.semantic_type != "entrance_anchor":
			adjacency[node.stable_id] = []
	for edge in bundle.edges:
		if edge.connection_class != "primary" and edge.connection_class != "vertical_transition":
			continue
		if adjacency.has(edge.endpoint_a_node_id) and adjacency.has(edge.endpoint_b_node_id):
			adjacency[edge.endpoint_a_node_id].append(edge.endpoint_b_node_id)
			adjacency[edge.endpoint_b_node_id].append(edge.endpoint_a_node_id)
	if not adjacency.has(start_id) or not adjacency.has(target_id):
		return -1
	var reached := {start_id: 0}
	var pending: Array[String] = [start_id]
	while not pending.is_empty():
		var current: String = pending.pop_front()
		for next_variant in adjacency[current]:
			var next_id := str(next_variant)
			if reached.has(next_id):
				continue
			if next_id == target_id:
				return int(reached[current]) + 1
			reached[next_id] = int(reached[current]) + 1
			pending.append(next_id)
	return -1


static func _entrance_value(bundle, a_id: String, b_id: String) -> float:
	var counts: Dictionary = {}
	for network in bundle.networks:
		counts[network.stable_id] = network.attached_entrance_ids.size()
	var a_count := int(counts.get(a_id, 0))
	var b_count := int(counts.get(b_id, 0))
	if a_id == b_id:
		return clampf(float(a_count) / 2.0, 0.0, 1.0)
	if a_count > 0 and b_count > 0:
		return 1.0
	if a_count > 0 or b_count > 0:
		return 0.82
	return 0.35


static func _normalized_neighbors(region_plan, views: Array) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for value in views:
		if not (value is Dictionary):
			continue
		var plan = value.get("region_plan")
		var topology = value.get("primary_topology")
		if plan == null or topology == null or topology.bundle == null:
			continue
		if plan.stable_id == region_plan.stable_id:
			continue
		if _shared_sides(region_plan.region_coord, plan.region_coord).is_empty():
			continue
		if seen.has(plan.stable_id):
			continue
		seen[plan.stable_id] = true
		result.append(value)
	result.sort_custom(_neighbor_less)
	return result


static func _shared_sides(a: Vector2i, b: Vector2i) -> Array[String]:
	var delta := b - a
	if delta == Vector2i(1, 0):
		return ["east", "west"]
	if delta == Vector2i(-1, 0):
		return ["west", "east"]
	if delta == Vector2i(0, 1):
		return ["south", "north"]
	if delta == Vector2i(0, -1):
		return ["north", "south"]
	return []


static func _validate(bundle, source, new_edges: Array, refs: Array) -> Array[String]:
	var failures: Array[String] = []
	var source_ids: Dictionary = {}
	for edge in source.edges:
		source_ids[edge.stable_id] = true
	var pairs: Dictionary = {}
	var degree: Dictionary = {}
	for edge in bundle.edges:
		var pair := _pair(edge.endpoint_a_node_id, edge.endpoint_b_node_id)
		if pairs.has(pair):
			failures.append("Secondary connectivity introduced duplicate edge endpoints: " + pair)
		pairs[pair] = edge.stable_id
	for edge in new_edges:
		if source_ids.has(edge.stable_id):
			failures.append("Secondary connectivity reused an existing StableId: " + edge.stable_id)
		if float(edge.topology_parameters.get("length", 0.0)) <= 0.0:
			failures.append("Secondary edge has non-positive length: " + edge.stable_id)
		if edge.connection_class != "cross_region_connection":
			degree[edge.endpoint_a_node_id] = int(degree.get(edge.endpoint_a_node_id, 0)) + 1
			degree[edge.endpoint_b_node_id] = int(degree.get(edge.endpoint_b_node_id, 0)) + 1
	for node_id in degree:
		if int(degree[node_id]) > MAX_SECONDARY_DEGREE:
			failures.append("Secondary node degree cap exceeded: " + str(node_id))
	var ref_ids: Dictionary = {}
	for reference in refs:
		if reference == null or reference.edge_stable_id.is_empty():
			failures.append("Invalid external secondary reference")
			continue
		if ref_ids.has(reference.edge_stable_id):
			failures.append("Duplicate external secondary reference: " + reference.edge_stable_id)
		ref_ids[reference.edge_stable_id] = true
		if reference.owner_region_id == bundle.region_definition.stable_id:
			failures.append("External reference is locally owned: " + reference.edge_stable_id)
	return failures


static func _cave_nodes(nodes: Array) -> Array:
	var result: Array = []
	for node in nodes:
		if node != null and node.semantic_type != "entrance_anchor":
			result.append(node)
	result.sort_custom(_node_less)
	return result


static func _pair_set(edges: Array) -> Dictionary:
	var result: Dictionary = {}
	for edge in edges:
		result[_pair(edge.endpoint_a_node_id, edge.endpoint_b_node_id)] = true
	return result


static func _node_index(nodes: Array) -> Dictionary:
	var result: Dictionary = {}
	for node in nodes:
		if node != null:
			result[node.stable_id] = node
	return result


static func _average_profile(nodes: Array, fallback: Vector3) -> Vector3:
	if nodes.is_empty():
		return fallback
	var value := Vector3.ZERO
	for node in nodes:
		value += node.profile_blend
	return value / float(nodes.size())


static func _counts(local: Array, owned_cross: Array, external: Array) -> Dictionary:
	var loops := 0
	var joins := 0
	for candidate in local:
		if candidate["class"] == "secondary_loop":
			loops += 1
		elif candidate["class"] == "cross_network_connection":
			joins += 1
	return {
		"loops": loops,
		"network_joins": joins,
		"owned_cross_region": owned_cross.size(),
		"external_cross_region": external.size(),
	}


static func _pair(a_value, b_value) -> String:
	var a := str(a_value)
	var b := str(b_value)
	return a + "\n" + b if a <= b else b + "\n" + a


static func _score_greater(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(float(a["score"]), float(b["score"])):
		return float(a["score"]) > float(b["score"])
	return str(a["address"]) < str(b["address"])


static func _address_less(a: Dictionary, b: Dictionary) -> bool:
	return str(a["address"]) < str(b["address"])


static func _node_less(a, b) -> bool:
	return str(a.stable_id) < str(b.stable_id)


static func _neighbor_less(a: Dictionary, b: Dictionary) -> bool:
	return str(a["region_plan"].stable_id) < str(b["region_plan"].stable_id)


static func _external_less(a, b) -> bool:
	return str(a.edge_stable_id) < str(b.edge_stable_id)
