extends RefCounted

const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const MacroRegionGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const PrimaryTopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const EntranceGenerator := preload("res://worldgen/underworld/entrance_generator.gd")
const ConnectivityGenerator := preload("res://worldgen/underworld/secondary_connectivity_generator.gd")
const HookGenerator := preload("res://worldgen/underworld/special_location_hook_generator.gd")
const RegionFinalizer := preload("res://worldgen/underworld/region_finalizer.gd")
const GeometryGenerator := preload("res://worldgen/underworld/cave_geometry_generator.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_determinism_and_coverage(failures)
	_test_neighbor_order_independence(failures)
	_test_negative_region(failures)
	return failures


static func _test_determinism_and_coverage(failures: Array[String]) -> void:
	var first: Dictionary = _build(778899, Vector2i.ZERO, false)
	if not bool(first.get("success", false)):
		failures.append("geometry fixture failed: %s" % first.get("diagnostics", []))
		return
	var second: Dictionary = _build(778899, Vector2i.ZERO, false)
	_expect_true(failures, "repeated geometry fixture succeeds", bool(second.get("success", false)))
	if not bool(second.get("success", false)):
		return
	_expect_equal(
		failures,
		"special-location reservation is deterministic",
		first["hooks"].fingerprint,
		second["hooks"].fingerprint
	)
	_expect_equal(
		failures,
		"region finalization is deterministic",
		first["finalized"].fingerprint,
		second["finalized"].fingerprint
	)
	_expect_equal(
		failures,
		"cave geometry is deterministic",
		first["geometry"].fingerprint,
		second["geometry"].fingerprint
	)
	var geometry = first["geometry"]
	var finalized = first["finalized"]
	_expect_equal(
		failures,
		"one chamber descriptor exists per finalized graph node",
		geometry.chamber_descriptors.size(),
		finalized.bundle.nodes.size()
	)
	_expect_equal(
		failures,
		"one tunnel descriptor exists per finalized owned graph edge",
		geometry.tunnel_descriptors.size(),
		finalized.bundle.edges.size()
	)
	_expect_true(
		failures,
		"reserved special-site count stays bounded",
		finalized.bundle.special_location_hooks.size() <= 2
	)
	_expect_equal(
		failures,
		"region special hook ids match reserved hook definitions",
		finalized.bundle.region_definition.special_location_hook_ids.size(),
		finalized.bundle.special_location_hooks.size()
	)
	var chamber_nodes: Dictionary = {}
	for chamber in geometry.chamber_descriptors:
		_expect_true(failures, "chamber dimensions stay positive", (
			chamber.dimensions.x > 0.0
			and chamber.dimensions.y > 0.0
			and chamber.dimensions.z > 0.0
		))
		_expect_true(failures, "chamber source node is unique", not chamber_nodes.has(chamber.source_node_id))
		chamber_nodes[chamber.source_node_id] = true
	var tunnel_edges: Dictionary = {}
	var node_index: Dictionary = _all_node_index(first)
	for tunnel in geometry.tunnel_descriptors:
		_expect_true(failures, "tunnel source edge is unique", not tunnel_edges.has(tunnel.source_edge_id))
		tunnel_edges[tunnel.source_edge_id] = true
		_expect_equal(failures, "tunnel has four control points", tunnel.control_points.size(), 4)
		_expect_true(failures, "tunnel width is positive", tunnel.width > 0.0)
		_expect_true(failures, "tunnel height is positive", tunnel.height > 0.0)
		if tunnel.control_points.size() == 4:
			_expect_true(failures, "tunnel endpoint A resolves", node_index.has(tunnel.endpoint_a_node_id))
			_expect_true(failures, "tunnel endpoint B resolves", node_index.has(tunnel.endpoint_b_node_id))
			if node_index.has(tunnel.endpoint_a_node_id):
				_expect_true(
					failures,
					"tunnel begins at endpoint A",
					tunnel.control_points[0].distance_to(
						node_index[tunnel.endpoint_a_node_id].world_position
					) <= 0.001
				)
			if node_index.has(tunnel.endpoint_b_node_id):
				_expect_true(
					failures,
					"tunnel ends at endpoint B",
					tunnel.control_points[3].distance_to(
						node_index[tunnel.endpoint_b_node_id].world_position
					) <= 0.001
				)
	for reference in finalized.external_edge_references:
		_expect_true(
			failures,
			"non-owner cross-region reference does not duplicate tunnel geometry",
			not tunnel_edges.has(reference.edge_stable_id)
		)


static func _test_neighbor_order_independence(failures: Array[String]) -> void:
	var forward: Dictionary = _build(24681357, Vector2i(2, -3), false)
	var reversed: Dictionary = _build(24681357, Vector2i(2, -3), true)
	if not bool(forward.get("success", false)) or not bool(reversed.get("success", false)):
		failures.append("geometry neighbor-order fixture failed")
		return
	_expect_equal(
		failures,
		"neighbor scheduling order cannot change finalized region",
		forward["finalized"].fingerprint,
		reversed["finalized"].fingerprint
	)
	_expect_equal(
		failures,
		"neighbor scheduling order cannot change geometry",
		forward["geometry"].fingerprint,
		reversed["geometry"].fingerprint
	)


static func _test_negative_region(failures: Array[String]) -> void:
	var built: Dictionary = _build(-998877, Vector2i(-5, -4), true)
	_expect_true(
		failures,
		"negative-coordinate cave geometry succeeds",
		bool(built.get("success", false))
	)
	if not bool(built.get("success", false)):
		return
	for hook in built["finalized"].bundle.special_location_hooks:
		_expect_true(failures, "negative-region hook has stable id", not hook.stable_id.is_empty())
	for chamber in built["geometry"].chamber_descriptors:
		_expect_true(failures, "negative-region chamber has stable id", not chamber.stable_id.is_empty())
	for tunnel in built["geometry"].tunnel_descriptors:
		_expect_true(failures, "negative-region tunnel has stable id", not tunnel.stable_id.is_empty())


static func _build(seed: int, coord: Vector2i, reverse_neighbors: bool) -> Dictionary:
	var context = WorldGenerationContext.new(seed)
	var sampler = SurfaceSampler.new(seed)
	var macro_stage = MacroRegionGenerator.generate(context, coord)
	if not macro_stage.success:
		return _failure("macro_region", macro_stage.diagnostics)
	var topology_stage = PrimaryTopologyGenerator.generate(context, macro_stage.data, sampler)
	if not topology_stage.success:
		return _failure("primary_topology", topology_stage.diagnostics)
	var entrance_stage = EntranceGenerator.generate(
		context, macro_stage.data, topology_stage.data, sampler
	)
	if not entrance_stage.success:
		return _failure("entrance_generation", entrance_stage.diagnostics)
	var neighbor_views: Array = []
	for offset in [
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(0, -1),
		Vector2i(0, 1),
	]:
		var neighbor_macro = MacroRegionGenerator.generate(context, coord + offset)
		if not neighbor_macro.success:
			return _failure("neighbor_macro_region", neighbor_macro.diagnostics)
		var neighbor_topology = PrimaryTopologyGenerator.generate(
			context, neighbor_macro.data, sampler
		)
		if not neighbor_topology.success:
			return _failure("neighbor_primary_topology", neighbor_topology.diagnostics)
		neighbor_views.append({
			"region_plan": neighbor_macro.data,
			"primary_topology": neighbor_topology.data,
		})
	if reverse_neighbors:
		neighbor_views.reverse()
	var connectivity_stage = ConnectivityGenerator.generate(
		context,
		macro_stage.data,
		topology_stage.data,
		entrance_stage.data,
		neighbor_views
	)
	if not connectivity_stage.success:
		return _failure("secondary_connectivity", connectivity_stage.diagnostics)
	var hook_stage = HookGenerator.generate(
		context,
		macro_stage.data,
		connectivity_stage.data
	)
	if not hook_stage.success:
		return _failure("special_location_hooks", hook_stage.diagnostics)
	var finalization_stage = RegionFinalizer.generate(
		context,
		macro_stage.data,
		entrance_stage.data,
		connectivity_stage.data,
		hook_stage.data
	)
	if not finalization_stage.success:
		return _failure("region_finalization", finalization_stage.diagnostics)
	var geometry_stage = GeometryGenerator.generate(
		context,
		macro_stage.data,
		finalization_stage.data,
		neighbor_views
	)
	if not geometry_stage.success:
		return _failure("cave_geometry", geometry_stage.diagnostics)
	return {
		"success": true,
		"context": context,
		"macro": macro_stage.data,
		"topology": topology_stage.data,
		"entrances": entrance_stage.data,
		"neighbor_views": neighbor_views,
		"connectivity": connectivity_stage.data,
		"hooks": hook_stage.data,
		"finalized": finalization_stage.data,
		"geometry": geometry_stage.data,
		"diagnostics": [],
	}


static func _all_node_index(built: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for node in built["finalized"].bundle.nodes:
		result[node.stable_id] = node
	for view in built["neighbor_views"]:
		for node in view["primary_topology"].bundle.nodes:
			if not result.has(node.stable_id):
				result[node.stable_id] = node
	return result


static func _failure(stage: String, diagnostics: Array) -> Dictionary:
	return {
		"success": false,
		"stage": stage,
		"diagnostics": diagnostics,
	}


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s expected=%s actual=%s" % [label, expected, actual])
