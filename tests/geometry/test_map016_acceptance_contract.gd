extends RefCounted

const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const Fragment := preload("res://worldgen/geometry/geometry_cell_fragment.gd")
const Plan := preload("res://worldgen/geometry/geometry_cell_plan.gd")
const Config := preload("res://worldgen/geometry/geometry_cell_partition_config.gd")
const Request := preload("res://worldgen/geometry/cave_voxel_field_request.gd")
const Mesher := preload("res://worldgen/geometry/cave_voxel_mesher.gd")
const Context := preload("res://worldgen/pipeline/world_generation_context.gd")
const PartitionResult := preload("res://worldgen/geometry/geometry_cell_partition_result.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var config := Config.new(Vector3(8, 8, 8), 1.0, 8, 1)
	var context := Context.new(160016)
	var provenance = context.make_provenance("geometry_cell_partition", "map016", "proof", ["preserved"])
	_seam(Vector3i(0, 0, 0), Vector3i(1, 0, 0), 8.0, Vector3(2, 4, 4), Vector3(14, 4, 4), "positive", config, context, provenance, failures)
	_seam(Vector3i(-2, 0, 0), Vector3i(-1, 0, 0), -8.0, Vector3(-14, 4, 4), Vector3(-2, 4, 4), "negative", config, context, provenance, failures)
	_parameter_sensitivity(config, context, provenance, failures)
	_continuity(config, context, provenance, failures)
	_no_isosurface(config, context, provenance, failures)
	return failures


static func _seam(left: Vector3i, right: Vector3i, shared_x: float, start: Vector3, finish: Vector3, label: String, config, context, provenance, failures: Array[String]) -> void:
	var metadata := {"control_points": [start, finish], "width": 4.0, "height": 4.0, "roughness": 0.0}
	var first = _build(_source_plan(left, "tunnel", metadata, config), config, context, provenance)
	var second = _build(_source_plan(right, "tunnel", metadata, config), config, context, provenance)
	_expect(failures, "%s adjacent cells build" % label, first.success and second.success)
	if not first.success or not second.success:
		return
	var a := _face_vertices(first.data.vertices, shared_x)
	var b := _face_vertices(second.data.vertices, shared_x)
	_expect(failures, "%s seam has shared-face vertices" % label, not a.is_empty())
	_expect(failures, "%s adjacent seam equivalence" % label, a == b)


static func _parameter_sensitivity(config, context, provenance, failures: Array[String]) -> void:
	var tunnel_a = _build(_source_plan(Vector3i.ZERO, "tunnel", {"control_points": [Vector3(1,4,4), Vector3(7,4,4)], "width": 2.0, "height": 2.0, "roughness": 0.0}, config), config, context, provenance)
	var tunnel_b = _build(_source_plan(Vector3i.ZERO, "tunnel", {"control_points": [Vector3(1,4,4), Vector3(7,4,4)], "width": 5.0, "height": 4.0, "roughness": 0.0}, config), config, context, provenance)
	_expect(failures, "tunnel variants are non-empty", _nonempty(tunnel_a) and _nonempty(tunnel_b))
	if tunnel_a.success and tunnel_b.success:
		_expect(failures, "tunnel parameters change geometry buffers", _buffers_differ(tunnel_a.data, tunnel_b.data))
	var entrance_a = _build(_entrance_plan(1.0, config), config, context, provenance)
	var entrance_b = _build(_entrance_plan(2.5, config), config, context, provenance)
	_expect(failures, "entrance variants are non-empty", _nonempty(entrance_a) and _nonempty(entrance_b))
	if entrance_a.success and entrance_b.success:
		_expect(failures, "entrance parameters change geometry buffers", _buffers_differ(entrance_a.data, entrance_b.data))


static func _continuity(config, context, provenance, failures: Array[String]) -> void:
	var address := Address.new(Vector3i.ZERO)
	var cell := AABB(Vector3.ZERO, config.cell_size)
	var chamber := Fragment.new("gfrag1:union-chamber", "stable:union-chamber", "chamber", address, cell, cell, true, {}, {}, "source:union-chamber", {"center": Vector3(2.5,4,4), "dimensions": Vector3(5,5,5), "shape_family": "ellipsoid", "floor_bias": 0.5, "wall_roughness": 0.0})
	var tunnel := Fragment.new("gfrag1:union-tunnel", "stable:union-tunnel", "tunnel", address, cell, cell, false, {}, {}, "source:union-tunnel", {"control_points": [Vector3(2.5,4,4), Vector3(7,4,4)], "width": 2.5, "height": 2.5, "roughness": 0.0})
	var union_plan := Plan.new(address, [chamber, tunnel], [], [], "map016-geometry", "map016-finalization")
	var union = _build(union_plan, config, context, provenance)
	_expect(failures, "chamber+tunnel union builds", _nonempty(union))
	var union_open := true
	for x in [2.5, 3.5, 4.5, 5.5, 6.5]:
		if Mesher._field(Vector3(float(x), 4, 4), union_plan.fragments, 0.0) >= 0.0:
			union_open = false
	_expect(failures, "chamber+tunnel union has continuous void path", union_open)

	var entrance_plan := _entrance_plan(1.5, config)
	var entrance = _build(entrance_plan, config, context, provenance)
	_expect(failures, "entrance continuity fixture builds", _nonempty(entrance))
	var metadata: Dictionary = entrance_plan.entrance_opening_metadata[0]
	var surface: Vector3 = metadata["surface_world_position"]
	var underground: Vector3 = metadata["underground_anchor"]
	var opening: AABB = metadata["required_opening_bounds"]
	var continuous := Mesher._field(opening.get_center(), entrance_plan.fragments, 0.0) < 0.0
	for t in [0.0, 0.25, 0.5, 0.75, 1.0]:
		continuous = continuous and Mesher._field(surface.lerp(underground, float(t)), entrance_plan.fragments, 0.0) < 0.0
	_expect(failures, "entrance opening and descent remain continuous", continuous)


static func _no_isosurface(config, context, provenance, failures: Array[String]) -> void:
	var address := Address.new(Vector3i.ZERO)
	var cell := AABB(Vector3.ZERO, config.cell_size)
	var fragment := Fragment.new("gfrag1:no-isosurface", "stable:no-isosurface", "chamber", address, cell, cell, true, {}, {}, "source:no-isosurface", {"center": cell.get_center(), "dimensions": Vector3(100,100,100), "shape_family": "ellipsoid", "floor_bias": 0.5, "wall_roughness": 0.0})
	var result = _build(Plan.new(address, [fragment], [], [], "map016-geometry", "map016-finalization"), config, context, provenance)
	_expect(failures, "non-empty no-isosurface fragment succeeds", result.success)
	if not result.success:
		return
	_expect(failures, "non-empty no-isosurface fragment emits empty MC buffers", result.data.vertices.is_empty() and result.data.indices.is_empty())
	_expect(failures, "no hidden fallback extraction mode", str(result.data.metrics.get("extraction_mode", "")) == "global_signed_distance_marching_cubes")
	_expect(failures, "no-isosurface result still records one source fragment", int(result.data.metrics.get("fragment_count", 0)) == 1)


static func _source_plan(coordinate: Vector3i, kind: String, metadata: Dictionary, config) -> Plan:
	var address := Address.new(coordinate)
	var cell := AABB(Vector3(coordinate) * config.cell_size.x, config.cell_size)
	var fragment := Fragment.new("gfrag1:%s:%s" % [kind, address.canonical_text()], "stable:map016-%s" % kind, kind, address, cell, cell, true, {}, {}, "source:map016-%s" % kind, metadata)
	return Plan.new(address, [fragment], [], [], "map016-geometry", "map016-finalization")


static func _entrance_plan(radius: float, config) -> Plan:
	var address := Address.new(Vector3i.ZERO)
	var cell := AABB(Vector3.ZERO, config.cell_size)
	var opening := AABB(Vector3(3,5,3), Vector3(2,3,2))
	var metadata := {"required_opening_bounds": opening, "surface_world_position": Vector3(4,7,4), "orientation": Vector3(1,0,0), "underground_anchor": Vector3(4,1,4), "clearance_radius": radius, "clearance_margin": 0.0, "descent_profile": "steep"}
	var fragment := Fragment.new("gfrag1:entrance", "stable:map016-entrance", "entrance", address, cell, cell, true, {}, {}, "source:map016-entrance", metadata)
	return Plan.new(address, [fragment], [metadata], [], "map016-geometry", "map016-finalization")


static func _build(plan: Plan, config, context, provenance):
	var partition := PartitionResult.new([plan], config.fingerprint, plan.source_geometry_fingerprint, plan.source_finalization_fingerprint, {}, [], provenance)
	return Mesher.build(Request.new(plan, config, provenance, 0.0, partition, context))


static func _face_vertices(vertices: PackedVector3Array, x: float) -> Array[String]:
	var seen := {}
	for vertex in vertices:
		if absf(vertex.x - x) <= 0.00001:
			seen["%.6f:%.6f:%.6f" % [vertex.x, vertex.y, vertex.z]] = true
	var result: Array[String] = []
	for key in seen.keys():
		result.append(str(key))
	result.sort()
	return result


static func _buffers_differ(a, b) -> bool:
	if a.vertices.size() != b.vertices.size() or a.indices.size() != b.indices.size():
		return true
	for i in range(a.vertices.size()):
		if not a.vertices[i].is_equal_approx(b.vertices[i]):
			return true
	for i in range(a.indices.size()):
		if a.indices[i] != b.indices[i]:
			return true
	return false


static func _nonempty(result) -> bool:
	return result.success and not result.data.indices.is_empty()


static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
