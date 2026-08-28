extends RefCounted
class_name UnderworldCaveGeometryGenerator

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const SeedDomains := preload("res://worldgen/random/seed_domains.gd")
const SeedDeriver := preload("res://worldgen/random/seed_deriver.gd")
const StageResult := preload("res://worldgen/pipeline/generation_stage_result.gd")
const GraphCanonicalizer := preload("res://worldgen/validation/graph_canonicalizer.gd")
const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")
const ChamberDescriptor := preload("res://worldgen/geometry/chamber_geometry_descriptor.gd")
const TunnelDescriptor := preload("res://worldgen/geometry/tunnel_geometry_descriptor.gd")
const FinalizationResult := preload("res://worldgen/underworld/region_finalization_result.gd")
const GeometryResult := preload("res://worldgen/underworld/cave_geometry_result.gd")

const MIN_CHAMBER_XZ: float = 6.0
const MIN_CHAMBER_Y: float = 5.0
const MIN_TUNNEL_WIDTH: float = 2.8
const MAX_TUNNEL_WIDTH: float = 18.0
const MIN_TUNNEL_HEIGHT: float = 3.0
const MAX_TUNNEL_HEIGHT: float = 22.0


static func generate(context, region_plan, finalization_result, neighbor_views: Array = []):
	if context == null:
		return StageResult.fail("cave_geometry", ["WorldGenerationContext is null"])
	if region_plan == null:
		return StageResult.fail("cave_geometry", ["MacroRegionPlan is null"])
	if finalization_result == null or not (finalization_result is FinalizationResult):
		return StageResult.fail(
			"cave_geometry",
			["Cave geometry requires RegionFinalizationResult"]
		)
	if finalization_result.bundle == null:
		return StageResult.fail("cave_geometry", ["RegionFinalizationResult has no bundle"])
	var failures: Array[String] = context.validate()
	if not failures.is_empty():
		return StageResult.fail("cave_geometry", failures)
	failures.append_array(context.validate_provenance(
		region_plan.provenance, "macro_region", region_plan.stable_id
	))
	failures.append_array(context.validate_provenance(
		finalization_result.provenance, "region_finalization", region_plan.stable_id
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
		return StageResult.fail("cave_geometry", failures)

	var source = finalization_result.bundle
	if source.region_definition.stable_id != region_plan.stable_id:
		return StageResult.fail("cave_geometry", ["Geometry inputs refer to different regions"])
	var source_fingerprint_before: String = GraphCanonicalizer.region_bundle_fingerprint(source)
	var domain = SeedDomains.get_domain(SeedDomains.UG_GEOMETRY_SHAPE)
	if domain == null:
		return StageResult.fail("cave_geometry", ["Missing ug.geometry.shape seed domain"])

	var local_nodes: Array = source.nodes.duplicate()
	local_nodes.sort_custom(_stable_less)
	var edges: Array = source.edges.duplicate()
	edges.sort_custom(_stable_less)
	var all_nodes: Dictionary = _node_index(source.nodes, neighbor_views)

	var chambers: Array = []
	for node in local_nodes:
		if node == null:
			failures.append("Geometry source contains null node")
			continue
		chambers.append(_build_chamber(context, region_plan, node, domain))

	var tunnels: Array = []
	for edge in edges:
		if edge == null:
			failures.append("Geometry source contains null edge")
			continue
		if not all_nodes.has(edge.endpoint_a_node_id):
			failures.append(
				"Geometry cannot resolve endpoint A for edge %s: %s" % [
					edge.stable_id, edge.endpoint_a_node_id,
				]
			)
			continue
		if not all_nodes.has(edge.endpoint_b_node_id):
			failures.append(
				"Geometry cannot resolve endpoint B for edge %s: %s" % [
					edge.stable_id, edge.endpoint_b_node_id,
				]
			)
			continue
		tunnels.append(_build_tunnel(
			context,
			region_plan,
			edge,
			all_nodes[edge.endpoint_a_node_id],
			all_nodes[edge.endpoint_b_node_id],
			domain
		))

	failures.append_array(_validate(region_plan, source, local_nodes, edges, chambers, tunnels, all_nodes))
	var source_fingerprint_after: String = GraphCanonicalizer.region_bundle_fingerprint(source)
	if source_fingerprint_after != source_fingerprint_before:
		failures.append("Cave geometry generation mutated its source graph")
	if not failures.is_empty():
		return StageResult.fail("cave_geometry", failures)

	chambers.sort_custom(_stable_less)
	tunnels.sort_custom(_stable_less)
	var chamber_data: Array = []
	for descriptor in chambers:
		chamber_data.append(descriptor.canonical_data())
	var tunnel_data: Array = []
	for descriptor in tunnels:
		tunnel_data.append(descriptor.canonical_data())
	var metrics: Dictionary = _metrics(chambers, tunnels)
	var fingerprint: String = "geometry-" + CanonicalValue.fingerprint({
		"source_finalization_fingerprint": finalization_result.fingerprint,
		"source_graph": GraphCanonicalizer.region_bundle_data(source),
		"chambers": chamber_data,
		"tunnels": tunnel_data,
		"metrics": metrics,
	})
	var provenance = context.make_provenance(
		"geometry_description",
		region_plan.stable_id,
		region_plan.stable_address.canonical_text(),
		_neighbor_source_fingerprints(region_plan, finalization_result, neighbor_views)
	)
	return StageResult.ok(
		"cave_geometry",
		GeometryResult.new(source, chambers, tunnels, metrics, fingerprint, provenance),
		fingerprint,
		provenance
	)


static func _neighbor_source_fingerprints(region_plan, finalization_result, neighbor_views: Array) -> Array[String]:
	var sources: Array[String] = [
		region_plan.provenance.fingerprint,
		finalization_result.provenance.fingerprint,
	]
	for view in neighbor_views:
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


static func _build_chamber(context, region_plan, node, domain):
	var address = StableAddress.generated_child(node.stable_address, "chamber-geometry", 0)
	var base: Vector3 = node.approximate_size
	var x_scale: float = lerpf(0.86, 1.24, _rand(context, address, domain, "size-x"))
	var y_scale: float = lerpf(0.82, 1.18, _rand(context, address, domain, "size-y"))
	var z_scale: float = lerpf(0.86, 1.24, _rand(context, address, domain, "size-z"))
	var dimensions := Vector3(
		maxf(base.x * x_scale, MIN_CHAMBER_XZ),
		maxf(base.y * y_scale, MIN_CHAMBER_Y),
		maxf(base.z * z_scale, MIN_CHAMBER_XZ)
	)
	var rotation_y: float = _rand(context, address, domain, "rotation-y") * TAU
	var floor_bias: float = lerpf(0.38, 0.56, _rand(context, address, domain, "floor-bias"))
	var ceiling_arch: float = clampf(
		0.42
		+ node.profile_blend.y * 0.18
		+ node.profile_blend.z * 0.16
		+ _rand(context, address, domain, "ceiling-arch") * 0.18,
		0.0,
		1.0
	)
	var wall_roughness: float = clampf(
		0.24
		+ node.profile_blend.z * 0.34
		+ node.profile_blend.y * 0.10
		+ _rand(context, address, domain, "wall-roughness") * 0.22,
		0.0,
		1.0
	)
	var asymmetry := Vector3(
		lerpf(0.82, 1.18, _rand(context, address, domain, "asymmetry-x")),
		lerpf(0.90, 1.10, _rand(context, address, domain, "asymmetry-y")),
		lerpf(0.82, 1.18, _rand(context, address, domain, "asymmetry-z"))
	)
	var shape_family: String = _chamber_shape(node)
	var tags: Array[String] = node.tags.duplicate()
	_append_tag(tags, "geometry")
	_append_tag(tags, "chamber")
	_append_tag(tags, shape_family)
	return ChamberDescriptor.new(
		address,
		node.stable_id,
		region_plan.stable_id,
		node.owning_network_id,
		node.world_position,
		dimensions,
		rotation_y,
		shape_family,
		floor_bias,
		ceiling_arch,
		wall_roughness,
		asymmetry,
		node.profile_blend,
		node.semantic_type,
		tags
	)


static func _build_tunnel(context, region_plan, edge, a, b, domain):
	var address = StableAddress.generated_child(edge.stable_address, "tunnel-geometry", 0)
	var delta: Vector3 = b.world_position - a.world_position
	var length: float = maxf(delta.length(), 0.001)
	var vertical_ratio: float = clampf(absf(delta.y) / length, 0.0, 1.0)
	var profile: Vector3 = (a.profile_blend + b.profile_blend) * 0.5
	var style: String = _tunnel_style(edge, vertical_ratio, profile)
	var slope_class: String = _slope_class(vertical_ratio)
	var fallback_width: float = _fallback_width(a, b, profile)
	var width: float = clampf(
		float(edge.geometry_tendencies.get("width", fallback_width))
		* lerpf(0.92, 1.08, _rand(context, address, domain, "width")),
		MIN_TUNNEL_WIDTH,
		MAX_TUNNEL_WIDTH
	)
	var height_factor: float = 1.02 + profile.y * 0.20 + profile.z * 0.12
	if slope_class == "shaft":
		height_factor += 0.22
	var height: float = clampf(
		float(edge.geometry_tendencies.get("height", width * height_factor))
		* lerpf(0.94, 1.08, _rand(context, address, domain, "height")),
		MIN_TUNNEL_HEIGHT,
		MAX_TUNNEL_HEIGHT
	)
	var roughness: float = clampf(
		float(edge.geometry_tendencies.get(
			"roughness",
			0.34 + profile.y * 0.10 + profile.z * 0.22
		)) + (_rand(context, address, domain, "roughness") - 0.5) * 0.12,
		0.12,
		0.92
	)
	var clearance_margin: float = 1.0 + profile.y * 0.8 + profile.z * 1.1
	clearance_margin += _rand(context, address, domain, "clearance") * 0.8
	var control_points: Array = _control_points(
		context, address, domain, edge.connection_class, a.world_position, b.world_position, vertical_ratio
	)
	var tags: Array[String] = edge.tags.duplicate()
	_append_tag(tags, "geometry")
	_append_tag(tags, "tunnel")
	_append_tag(tags, style)
	return TunnelDescriptor.new(
		address,
		edge.stable_id,
		region_plan.stable_id,
		edge.endpoint_a_node_id,
		edge.endpoint_b_node_id,
		edge.connection_class,
		control_points,
		width,
		height,
		clearance_margin,
		roughness,
		style,
		slope_class,
		profile,
		tags
	)


static func _control_points(
	context,
	address,
	domain,
	connection_class: String,
	start: Vector3,
	finish: Vector3,
	vertical_ratio: float
) -> Array:
	var delta: Vector3 = finish - start
	var length: float = maxf(delta.length(), 0.001)
	var horizontal := Vector3(delta.x, 0.0, delta.z)
	var perpendicular: Vector3
	if horizontal.length_squared() > 0.0001:
		var direction: Vector3 = horizontal.normalized()
		perpendicular = Vector3(-direction.z, 0.0, direction.x)
	else:
		perpendicular = (
			Vector3.RIGHT
			if _rand(context, address, domain, "vertical-axis") < 0.5
			else Vector3.FORWARD
		)
	var bend_scale: float = 0.11
	match connection_class:
		"entrance_path": bend_scale = 0.055
		"cross_region_connection": bend_scale = 0.075
		"secondary_loop", "cross_network_connection": bend_scale = 0.13
	var vertical_damping: float = lerpf(1.0, 0.28, vertical_ratio)
	var bend: float = minf(length * bend_scale, 28.0)
	bend *= lerpf(0.35, 1.0, _rand(context, address, domain, "bend-amplitude"))
	bend *= vertical_damping
	if _rand(context, address, domain, "bend-sign") < 0.5:
		bend *= -1.0
	var vertical_wiggle: float = minf(length * 0.035, 7.0) * (1.0 - vertical_ratio)
	var wiggle_a: float = (_rand(context, address, domain, "vertical-a") - 0.5) * 2.0 * vertical_wiggle
	var wiggle_b: float = (_rand(context, address, domain, "vertical-b") - 0.5) * 2.0 * vertical_wiggle
	return [
		start,
		start + delta * 0.33 + perpendicular * bend + Vector3.UP * wiggle_a,
		start + delta * 0.67 - perpendicular * bend * 0.55 + Vector3.UP * wiggle_b,
		finish,
	]


static func _chamber_shape(node) -> String:
	if node.semantic_type == "entrance_anchor":
		return "entrance_vestibule"
	if node.semantic_type == "terminal":
		return "alcove"
	var degree: int = int(node.generation_metadata.get("degree", 1))
	if degree >= 3:
		return "junction_vault"
	if node.profile_blend.z >= node.profile_blend.x and node.profile_blend.z >= node.profile_blend.y:
		return "fracture_vault"
	if node.profile_blend.y >= node.profile_blend.x:
		return "gallery"
	return "low_oval"


static func _tunnel_style(edge, vertical_ratio: float, profile: Vector3) -> String:
	var explicit_style: String = str(edge.geometry_tendencies.get("connector_style", ""))
	if not explicit_style.is_empty():
		return explicit_style
	if edge.connection_class == "entrance_path":
		match str(edge.topology_parameters.get("descent_profile", "")):
			"steep_sinkhole": return "shaft"
			"crevice": return "fracture"
	if vertical_ratio >= 0.55:
		return "shaft"
	if vertical_ratio >= 0.30:
		return "steep_tunnel"
	if profile.z >= 0.55:
		return "fracture"
	return "tunnel"


static func _slope_class(vertical_ratio: float) -> String:
	if vertical_ratio >= 0.55:
		return "shaft"
	if vertical_ratio >= 0.30:
		return "steep"
	if vertical_ratio >= 0.14:
		return "sloped"
	return "gentle"


static func _fallback_width(a, b, profile: Vector3) -> float:
	var a_width: float = minf(a.approximate_size.x, a.approximate_size.z)
	var b_width: float = minf(b.approximate_size.x, b.approximate_size.z)
	var chamber_width: float = minf(a_width, b_width)
	return chamber_width * (0.34 + profile.y * 0.08 + profile.z * 0.12)


static func _node_index(local_nodes: Array, neighbor_views: Array) -> Dictionary:
	var result: Dictionary = {}
	for node in local_nodes:
		if node != null:
			result[node.stable_id] = node
	for value in neighbor_views:
		if not (value is Dictionary):
			continue
		var topology = value.get("primary_topology")
		if topology == null or topology.bundle == null:
			continue
		for node in topology.bundle.nodes:
			if node != null and not result.has(node.stable_id):
				result[node.stable_id] = node
	return result


static func _validate(
	region_plan,
	source,
	local_nodes: Array,
	edges: Array,
	chambers: Array,
	tunnels: Array,
	all_nodes: Dictionary
) -> Array[String]:
	var failures: Array[String] = []
	if chambers.size() != local_nodes.size():
		failures.append("Geometry chamber count does not match source node count")
	if tunnels.size() != edges.size():
		failures.append("Geometry tunnel count does not match source owned edge count")
	var ids: Dictionary = {}
	var local_node_ids: Dictionary = {}
	for node in local_nodes:
		if node != null:
			local_node_ids[node.stable_id] = true
	for chamber in chambers:
		if ids.has(chamber.stable_id):
			failures.append("Duplicate geometry StableId: " + chamber.stable_id)
		ids[chamber.stable_id] = true
		if not local_node_ids.has(chamber.source_node_id):
			failures.append("Chamber references non-local node: " + chamber.source_node_id)
		if chamber.owning_region_id != region_plan.stable_id:
			failures.append("Chamber has wrong owning region: " + chamber.stable_id)
		if chamber.dimensions.x <= 0.0 or chamber.dimensions.y <= 0.0 or chamber.dimensions.z <= 0.0:
			failures.append("Chamber has non-positive dimensions: " + chamber.stable_id)
	for tunnel in tunnels:
		if ids.has(tunnel.stable_id):
			failures.append("Duplicate geometry StableId: " + tunnel.stable_id)
		ids[tunnel.stable_id] = true
		if tunnel.owning_region_id != region_plan.stable_id:
			failures.append("Tunnel has wrong owning region: " + tunnel.stable_id)
		if tunnel.width <= 0.0 or tunnel.height <= 0.0 or tunnel.clearance_margin <= 0.0:
			failures.append("Tunnel has invalid clearance dimensions: " + tunnel.stable_id)
		if tunnel.control_points.size() != 4:
			failures.append("Tunnel must have exactly four centerline points: " + tunnel.stable_id)
			continue
		if not all_nodes.has(tunnel.endpoint_a_node_id) or not all_nodes.has(tunnel.endpoint_b_node_id):
			failures.append("Tunnel endpoint lookup failed: " + tunnel.stable_id)
			continue
		var a = all_nodes[tunnel.endpoint_a_node_id]
		var b = all_nodes[tunnel.endpoint_b_node_id]
		if tunnel.control_points[0].distance_to(a.world_position) > 0.001:
			failures.append("Tunnel start does not match endpoint A: " + tunnel.stable_id)
		if tunnel.control_points[3].distance_to(b.world_position) > 0.001:
			failures.append("Tunnel end does not match endpoint B: " + tunnel.stable_id)
		if tunnel.connection_class == "cross_region_connection":
			var source_edge = _edge_by_id(source.edges, tunnel.source_edge_id)
			if source_edge == null or source_edge.owning_region_id != region_plan.stable_id:
				failures.append("Cross-region tunnel is not canonically owned: " + tunnel.stable_id)
	return failures


static func _metrics(chambers: Array, tunnels: Array) -> Dictionary:
	var styles: Dictionary = {}
	var classes: Dictionary = {}
	for tunnel in tunnels:
		styles[tunnel.path_style] = int(styles.get(tunnel.path_style, 0)) + 1
		classes[tunnel.connection_class] = int(classes.get(tunnel.connection_class, 0)) + 1
	return {
		"chamber_count": chambers.size(),
		"tunnel_count": tunnels.size(),
		"tunnel_styles": styles,
		"connection_classes": classes,
	}


static func _edge_by_id(edges: Array, edge_id: String):
	for edge in edges:
		if edge != null and edge.stable_id == edge_id:
			return edge
	return null


static func _rand(context, address, domain, purpose: String) -> float:
	return SeedDeriver.random_unit(context.world_seed, address, domain, purpose)


static func _append_tag(tags: Array[String], value: String) -> void:
	if not tags.has(value):
		tags.append(value)


static func _stable_less(a, b) -> bool:
	return str(a.stable_id) < str(b.stable_id)
