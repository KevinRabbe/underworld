extends RefCounted

const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const MacroRegionGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const PrimaryTopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const EntranceGenerator := preload("res://worldgen/underworld/entrance_generator.gd")
const ConnectivityGenerator := preload("res://worldgen/underworld/secondary_connectivity_generator.gd")
const GraphValidator := preload("res://worldgen/validation/graph_validator.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_local_determinism_and_immutability(failures)
	_test_neighbor_order_independence(failures)
	_test_bounded_distribution(failures)
	_test_cross_region_canonical_ownership(failures)
	_test_negative_region(failures)
	return failures


static func _test_local_determinism_and_immutability(failures: Array[String]) -> void:
	var built: Dictionary = _build(778899, Vector2i.ZERO, false)
	if not bool(built.get("success", false)):
		failures.append("connectivity fixture failed: %s" % built.get("diagnostics", []))
		return
	var repeated: Dictionary = _build(778899, Vector2i.ZERO, false)
	_expect_true(failures, "repeated connectivity fixture succeeds", bool(repeated.get("success", false)))
	if not bool(repeated.get("success", false)):
		return
	_expect_equal(
		failures,
		"secondary connectivity is deterministic",
		built["result"].fingerprint,
		repeated["result"].fingerprint
	)
	_expect_true(
		failures,
		"entrance-stage input remains immutable",
		built["entrances"].bundle.region_definition.secondary_edge_ids.is_empty()
	)
	for graph_failure in GraphValidator.validate_region_bundle(built["result"].bundle):
		failures.append("secondary graph invalid: " + graph_failure)
	for edge_id in built["result"].bundle.region_definition.secondary_edge_ids:
		var edge = _edge_by_id(built["result"].bundle.edges, edge_id)
		_expect_true(failures, "secondary edge id resolves", edge != null)
		if edge == null:
			continue
		_expect_true(
			failures,
			"secondary edge has expected class",
			edge.connection_class == "secondary_loop"
			or edge.connection_class == "cross_network_connection"
			or edge.connection_class == "cross_region_connection"
		)


static func _test_neighbor_order_independence(failures: Array[String]) -> void:
	var built: Dictionary = _build(24681357, Vector2i(2, -3), true)
	if not bool(built.get("success", false)):
		failures.append("neighbor-order fixture failed: %s" % built.get("diagnostics", []))
		return
	var reversed_neighbors: Array = built["neighbor_views"].duplicate()
	reversed_neighbors.reverse()
	var rerun = ConnectivityGenerator.generate(
		built["context"],
		built["macro"],
		built["topology"],
		built["entrances"],
		reversed_neighbors
	)
	_expect_true(failures, "reversed-neighbor connectivity succeeds", rerun.success)
	if rerun.success:
		_expect_equal(
			failures,
			"neighbor scheduling order cannot change connectivity",
			built["result"].fingerprint,
			rerun.data.fingerprint
		)


static func _test_bounded_distribution(failures: Array[String]) -> void:
	var accepted_total: int = 0
	var regions_with_secondary: int = 0
	var max_owned: int = 0
	for seed in range(1, 49):
		var built: Dictionary = _build(seed, Vector2i(1, -1), false)
		if not bool(built.get("success", false)):
			failures.append(
				"connectivity distribution fixture failed seed=%d: %s" % [
					seed, built.get("diagnostics", []),
				]
			)
			continue
		var result = built["result"]
		var count: int = result.bundle.region_definition.secondary_edge_ids.size()
		accepted_total += count
		if count > 0:
			regions_with_secondary += 1
		max_owned = maxi(max_owned, count)
		_expect_true(failures, "local secondary pass stays bounded", count <= 5)
		var degrees: Dictionary = {}
		for edge_id in result.bundle.region_definition.secondary_edge_ids:
			var edge = _edge_by_id(result.bundle.edges, edge_id)
			if edge == null or edge.connection_class == "cross_region_connection":
				continue
			degrees[edge.endpoint_a_node_id] = int(degrees.get(edge.endpoint_a_node_id, 0)) + 1
			degrees[edge.endpoint_b_node_id] = int(degrees.get(edge.endpoint_b_node_id, 0)) + 1
		for node_id in degrees.keys():
			_expect_true(
				failures,
				"secondary degree cap prevents spaghetti",
				int(degrees[node_id]) <= 1
			)
	_expect_true(
		failures,
		"secondary connectivity remains selective across seeds",
		regions_with_secondary < 48
	)
	_expect_true(
		failures,
		"secondary connectivity appears across the seed campaign",
		accepted_total > 0
	)
	_expect_true(failures, "bounded campaign maximum", max_owned <= 5)


static func _test_cross_region_canonical_ownership(failures: Array[String]) -> void:
	var coord_a := Vector2i(0, 0)
	var coord_b := Vector2i(1, 0)
	var found: bool = false
	for seed in range(1, 193):
		var pair: Dictionary = _build_pair(seed, coord_a, coord_b)
		if not bool(pair.get("success", false)):
			failures.append(
				"cross-region fixture failed seed=%d: %s" % [
					seed, pair.get("diagnostics", []),
				]
			)
			return
		var ids_a: Array[String] = _cross_region_ids(pair["result_a"])
		var ids_b: Array[String] = _cross_region_ids(pair["result_b"])
		if ids_a.is_empty() and ids_b.is_empty():
			continue
		found = true
		_expect_equal(
			failures,
			"both sides agree on cross-region connector identity",
			ids_a,
			ids_b
		)
		var owned_a: int = _owned_cross_region_count(pair["result_a"])
		var owned_b: int = _owned_cross_region_count(pair["result_b"])
		var external_a: int = pair["result_a"].external_edge_references.size()
		var external_b: int = pair["result_b"].external_edge_references.size()
		_expect_equal(
			failures,
			"cross-region connector has exactly one canonical owner",
			owned_a + owned_b,
			1
		)
		_expect_equal(
			failures,
			"non-owner receives exactly one external reference",
			external_a + external_b,
			1
		)
		break
	_expect_true(
		failures,
		"cross-region campaign produces at least one rare connector",
		found
	)


static func _test_negative_region(failures: Array[String]) -> void:
	var built: Dictionary = _build(-998877, Vector2i(-5, -4), true)
	_expect_true(
		failures,
		"negative-coordinate connectivity succeeds",
		bool(built.get("success", false))
	)
	if not bool(built.get("success", false)):
		return
	for reference in built["result"].external_edge_references:
		_expect_true(
			failures,
			"negative-region external reference keeps canonical owner",
			reference != null and not reference.owner_region_id.is_empty()
		)


static func _build(seed: int, coord: Vector2i, with_neighbors: bool) -> Dictionary:
	var context = WorldGenerationContext.new(seed)
	var sampler = SurfaceSampler.new(seed)
	var base: Dictionary = _build_region(context, sampler, coord, true)
	if not bool(base.get("success", false)):
		return base
	var neighbor_views: Array = []
	if with_neighbors:
		for offset in [
			Vector2i(-1, 0),
			Vector2i(1, 0),
			Vector2i(0, -1),
			Vector2i(0, 1),
		]:
			var neighbor: Dictionary = _build_region(context, sampler, coord + offset, false)
			if not bool(neighbor.get("success", false)):
				return neighbor
			neighbor_views.append({
				"region_plan": neighbor["macro"],
				"primary_topology": neighbor["topology"],
			})
	var connectivity = ConnectivityGenerator.generate(
		context,
		base["macro"],
		base["topology"],
		base["entrances"],
		neighbor_views
	)
	if not connectivity.success:
		return {
			"success": false,
			"stage": "secondary_connectivity",
			"diagnostics": connectivity.diagnostics,
		}
	return {
		"success": true,
		"context": context,
		"macro": base["macro"],
		"topology": base["topology"],
		"entrances": base["entrances"],
		"neighbor_views": neighbor_views,
		"result": connectivity.data,
		"diagnostics": [],
	}


static func _build_pair(seed: int, coord_a: Vector2i, coord_b: Vector2i) -> Dictionary:
	var context = WorldGenerationContext.new(seed)
	var sampler = SurfaceSampler.new(seed)
	var a: Dictionary = _build_region(context, sampler, coord_a, true)
	if not bool(a.get("success", false)):
		return a
	var b: Dictionary = _build_region(context, sampler, coord_b, true)
	if not bool(b.get("success", false)):
		return b
	var result_a = ConnectivityGenerator.generate(
		context,
		a["macro"],
		a["topology"],
		a["entrances"],
		[{"region_plan": b["macro"], "primary_topology": b["topology"]}]
	)
	if not result_a.success:
		return {"success": false, "diagnostics": result_a.diagnostics}
	var result_b = ConnectivityGenerator.generate(
		context,
		b["macro"],
		b["topology"],
		b["entrances"],
		[{"region_plan": a["macro"], "primary_topology": a["topology"]}]
	)
	if not result_b.success:
		return {"success": false, "diagnostics": result_b.diagnostics}
	return {
		"success": true,
		"result_a": result_a.data,
		"result_b": result_b.data,
		"diagnostics": [],
	}


static func _build_region(context, sampler, coord: Vector2i, include_entrances: bool) -> Dictionary:
	var macro_stage = MacroRegionGenerator.generate(context, coord)
	if not macro_stage.success:
		return {
			"success": false,
			"stage": "macro_region",
			"diagnostics": macro_stage.diagnostics,
		}
	var topology_stage = PrimaryTopologyGenerator.generate(context, macro_stage.data, sampler)
	if not topology_stage.success:
		return {
			"success": false,
			"stage": "primary_topology",
			"diagnostics": topology_stage.diagnostics,
		}
	if not include_entrances:
		return {
			"success": true,
			"macro": macro_stage.data,
			"topology": topology_stage.data,
			"diagnostics": [],
		}
	var entrance_stage = EntranceGenerator.generate(
		context,
		macro_stage.data,
		topology_stage.data,
		sampler
	)
	if not entrance_stage.success:
		return {
			"success": false,
			"stage": "entrance_generation",
			"diagnostics": entrance_stage.diagnostics,
		}
	return {
		"success": true,
		"macro": macro_stage.data,
		"topology": topology_stage.data,
		"entrances": entrance_stage.data,
		"diagnostics": [],
	}


static func _cross_region_ids(result) -> Array[String]:
	var ids: Array[String] = []
	for edge_id in result.bundle.region_definition.secondary_edge_ids:
		var edge = _edge_by_id(result.bundle.edges, edge_id)
		if edge != null and edge.connection_class == "cross_region_connection":
			ids.append(edge.stable_id)
	for reference in result.external_edge_references:
		ids.append(str(reference.edge_stable_id))
	ids.sort()
	return ids


static func _owned_cross_region_count(result) -> int:
	var count: int = 0
	for edge_id in result.bundle.region_definition.secondary_edge_ids:
		var edge = _edge_by_id(result.bundle.edges, edge_id)
		if edge != null and edge.connection_class == "cross_region_connection":
			count += 1
	return count


static func _edge_by_id(edges: Array, edge_id: String):
	for edge in edges:
		if edge != null and edge.stable_id == edge_id:
			return edge
	return null


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s expected=%s actual=%s" % [label, expected, actual])
