extends RefCounted

const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const Fragment := preload("res://worldgen/geometry/geometry_cell_fragment.gd")
const Plan := preload("res://worldgen/geometry/geometry_cell_plan.gd")
const Config := preload("res://worldgen/geometry/geometry_cell_partition_config.gd")
const Request := preload("res://worldgen/geometry/cave_voxel_field_request.gd")
const Mesher := preload("res://worldgen/geometry/cave_voxel_mesher.gd")
const Boundary := preload("res://worldgen/geometry/cave_mesh_realization_boundary.gd")
const Context := preload("res://worldgen/pipeline/world_generation_context.gd")
const MeshData := preload("res://worldgen/geometry/cave_mesh_data.gd")
const PartitionResult := preload("res://worldgen/geometry/geometry_cell_partition_result.gd")
const Map016AcceptanceTests := preload("res://tests/geometry/test_map016_acceptance_contract.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var plan := _plan(Vector3i(-1, 0, 2), ["chamber", "tunnel"])
	var context := Context.new(7)
	var provenance = context.make_provenance("geometry_cell_partition", "region", "address", ["plan-source"])
	var partition = _partition_result(plan, Config.new(), provenance)
	var result = Mesher.build(Request.new(plan, Config.new(), provenance, 0.0, partition, context))
	_expect(failures, "chamber and tunnel mesh build succeeds", result.success)
	if result.success:
		_expect(failures, "versioned marching-cubes table has 256 cases", Mesher.MARCHING_CUBES_TABLE.size() == 256)
		_expect(failures, "versioned edge table has 256 cases", Mesher.MARCHING_CUBES_EDGE_TABLE.size() == 256)
		var table_valid := true
		for table_case in Mesher.MARCHING_CUBES_TABLE:
			for triangle in table_case:
				if triangle.size() != 3 or triangle[0] < 0 or triangle[0] > 11 or triangle[1] < 0 or triangle[1] > 11 or triangle[2] < 0 or triangle[2] > 11: table_valid = false
		_expect(failures, "marching-cubes cases contain valid edge triples", table_valid)
		_expect(failures, "mesh buffers have triangles", result.data.indices.size() > 0)
		_expect(failures, "mesh uses global signed-distance extraction", result.data.metrics.get("extraction_mode", "") == "global_signed_distance_marching_cubes")
		_expect(failures, "mesh records configured pitch", is_equal_approx(float(result.data.metrics.get("sample_pitch", 0.0)), Config.DEFAULT_VOXEL_PITCH))
		_expect(failures, "mesh indices are valid", _valid_indices(result.data))
		_expect(failures, "mesh normals are unit and finite", _valid_normals(result.data))
		var realized: Dictionary = Boundary.realize_main_thread(result.data)
		_expect(failures, "main-thread realization succeeds", realized.success)
		_expect(failures, "realization preserves source fingerprint", realized.input_fingerprint == result.data.input_fingerprint)
		_expect(failures, "stale realization is rejected", not Boundary.realize_main_thread(result.data, null, "stale").success)
		var repeated = Mesher.build(Request.new(plan, Config.new(), provenance, 0.0, partition, context))
		_expect(failures, "repeated extraction reproduces exact fingerprint", repeated.success and repeated.data.fingerprint == result.data.fingerprint)
		var retimed_metrics: Dictionary = result.data.metrics.duplicate(true)
		retimed_metrics["extraction_ms"] = 999999.0
		retimed_metrics["preparation_ms"] = 888888.0
		var retimed_data = MeshData.new(plan.cell_address, result.data.world_bounds, result.data.vertices, result.data.indices, result.data.normals, result.data.uvs, result.data.source_descriptor_ids, result.data.source_fragment_ids, result.data.input_fingerprint, retimed_metrics)
		_expect(failures, "observational timings do not perturb mesh identity", retimed_data.fingerprint == result.data.fingerprint)
		var changed_vertices: PackedVector3Array = result.data.vertices.duplicate()
		changed_vertices[0] += Vector3(0.25, 0.0, 0.0)
		var changed_data = MeshData.new(plan.cell_address, result.data.world_bounds, changed_vertices, result.data.indices, result.data.normals, result.data.uvs, result.data.source_descriptor_ids, result.data.source_fragment_ids, result.data.input_fingerprint, result.data.metrics)
		_expect(failures, "mesh output identity includes buffer contents", changed_data.output_fingerprint != result.data.output_fingerprint)
	var reversed := _plan(Vector3i(-1, 0, 2), ["tunnel", "chamber"])
	var reversed_partition = _partition_result(reversed, Config.new(), provenance)
	var second = Mesher.build(Request.new(reversed, Config.new(), provenance, 0.0, reversed_partition, context))
	_expect(failures, "reordered fragments build", second.success)
	if second.success:
		_expect(failures, "reordered fragments reproduce buffers", second.data.fingerprint == result.data.fingerprint)
	var malformed := _plan(Vector3i.ZERO, ["chamber"])
	malformed.fragments.append(null)
	var bad = Mesher.build(Request.new(malformed, Config.new(), provenance, 0.0, partition, context))
	_expect(failures, "malformed fragment is rejected", not bad.success)
	var missing_provenance = Mesher.build(Request.new(plan, Config.new(), null, 0.0, partition, context))
	_expect(failures, "missing mesh provenance is rejected", not missing_provenance.success)
	var stale = context.make_provenance("geometry_cell_partition", "region", "address", ["plan-source"])
	stale.stage_id = "other_stage"
	var stale_request = Mesher.build(Request.new(plan, Config.new(), stale, 0.0, partition, context))
	_expect(failures, "stale mutated mesh provenance is rejected", not stale_request.success)
	var unrelated = context.make_provenance("geometry_cell_partition", "other-region", "other-address", ["plan-source"])
	var unrelated_request = Mesher.build(Request.new(plan, Config.new(), unrelated, 0.0, partition, context))
	_expect(failures, "unrelated partition provenance is rejected", not unrelated_request.success)
	var empty_plan := _plan(Vector3i(3, -2, 1), [])
	var empty_partition = _partition_result(empty_plan, Config.new(), provenance)
	var empty = Mesher.build(Request.new(empty_plan, Config.new(), provenance, 0.0, empty_partition, context))
	_expect(failures, "empty cells remain valid mesh results", empty.success)
	if empty.success:
		_expect(failures, "empty cell emits no triangles", empty.data.indices.is_empty())
		_expect(failures, "empty cell bounds derive from address", empty.data.world_bounds == AABB(Vector3(96, -64, 32), Vector3(32, 32, 32)))
	var surface_plan := _surface_plan(Vector3i.ZERO, 0.5)
	var surface_partition = _partition_result(surface_plan, Config.new(), provenance)
	var surface_result = Mesher.build(Request.new(surface_plan, Config.new(), provenance, 0.0, surface_partition, context))
	_expect(failures, "analytic chamber surface builds", surface_result.success and surface_result.data.indices.size() > 0)
	if surface_result.success:
		_expect(failures, "marching-cubes vertices are canonically reused", _unique_positions(surface_result.data.vertices) == surface_result.data.vertices.size())
		var altered_surface_plan := _surface_plan(Vector3i.ZERO, 1.0)
		var altered_surface := Mesher.build(Request.new(altered_surface_plan, Config.new(), provenance, 0.0, _partition_result(altered_surface_plan, Config.new(), provenance), context))
		_expect(failures, "chamber authored parameters affect mesh identity", altered_surface.success and altered_surface.data.fingerprint != surface_result.data.fingerprint)
	var tunnel_plan := _tunnel_plan(Vector3i.ZERO)
	var tunnel_partition = _partition_result(tunnel_plan, Config.new(), provenance)
	var tunnel_result = Mesher.build(Request.new(tunnel_plan, Config.new(), provenance, 0.0, tunnel_partition, context))
	_expect(failures, "elliptical tunnel capsule builds", tunnel_result.success and tunnel_result.data.indices.size() > 0)
	var entrance_plan := _entrance_plan(Vector3i.ZERO)
	var entrance_partition = _partition_result(entrance_plan, Config.new(), provenance)
	var entrance_result = Mesher.build(Request.new(entrance_plan, Config.new(), provenance, 0.0, entrance_partition, context))
	_expect(failures, "oriented entrance descent volume builds", entrance_result.success and entrance_result.data.indices.size() > 0)
	failures.append_array(Map016AcceptanceTests.run())
	return failures


static func _partition_result(plan: Plan, configuration, provenance):
	return PartitionResult.new([plan], configuration.fingerprint, plan.source_geometry_fingerprint, plan.source_finalization_fingerprint, {}, [], provenance)


static func _plan(coordinate: Vector3i, kinds: Array) -> Plan:
	var address := Address.new(coordinate)
	var cell := AABB(Vector3(coordinate) * 32.0, Vector3(32, 32, 32))
	var fragments: Array = []
	for i in range(kinds.size()):
		var kind_offset := 2 if str(kinds[i]) == "chamber" else 10
		var clipped := AABB(cell.position + Vector3(kind_offset, 4, 3), Vector3(10, 8, 12))
		var owner := str(kinds[i]) == "chamber" or (not kinds.has("chamber") and i == 0)
		fragments.append(Fragment.new(
			"gfrag1:test-%s" % kinds[i], "stable:%s" % kinds[i], kinds[i], address,
			cell, clipped, owner, {}, {}, "source:%s" % kinds[i], {}
		))
	return Plan.new(address, fragments, [], [], "geometry", "finalization")


static func _surface_plan(coordinate: Vector3i, floor_bias: float = 0.5) -> Plan:
	var address := Address.new(coordinate)
	var cell := AABB(Vector3(coordinate) * 32.0, Vector3(32, 32, 32))
	var clipped := AABB(Vector3(5, 5, 5), Vector3(22, 22, 22))
	var metadata := {"center": Vector3(16, 16, 16), "dimensions": Vector3(22, 18, 20), "shape_family": "ellipsoid", "rotation_y": 0.0, "floor_bias": floor_bias, "wall_roughness": 0.5}
	var fragment := Fragment.new("gfrag1:surface-chamber", "stable:surface-chamber", "chamber", address, cell, clipped, true, {}, {}, "source:surface-chamber", metadata)
	return Plan.new(address, [fragment], [], [], "geometry", "finalization")


static func _tunnel_plan(coordinate: Vector3i) -> Plan:
	var address := Address.new(coordinate)
	var cell := AABB(Vector3(coordinate) * 32.0, Vector3(32, 32, 32))
	var clipped := AABB(Vector3(3, 12, 3), Vector3(26, 8, 26))
	var metadata := {"control_points": [Vector3(4, 16, 4), Vector3(12, 16, 12), Vector3(20, 14, 20), Vector3(28, 14, 28)], "width": 6.0, "height": 4.0}
	var fragment := Fragment.new("gfrag1:tunnel-surface", "stable:tunnel-surface", "tunnel", address, cell, clipped, true, {}, {}, "source:tunnel-surface", metadata)
	return Plan.new(address, [fragment], [], [], "geometry", "finalization")


static func _entrance_plan(coordinate: Vector3i) -> Plan:
	var address := Address.new(coordinate)
	var cell := AABB(Vector3(coordinate) * 32.0, Vector3(32, 32, 32))
	var clipped := AABB(Vector3(10, 4, 10), Vector3(12, 24, 12))
	var metadata := {"required_opening_bounds": clipped, "surface_world_position": Vector3(16, 20, 16), "orientation": Vector3(1, 0, 0), "underground_anchor": Vector3(16, 4, 16), "clearance_radius": 3.0, "descent_profile": "gradual"}
	var fragment := Fragment.new("gfrag1:entrance-surface", "stable:entrance-surface", "entrance", address, cell, clipped, true, {}, {}, "source:entrance-surface", metadata)
	return Plan.new(address, [fragment], [metadata], [], "geometry", "finalization")


static func _valid_indices(data) -> bool:
	if data.indices.size() % 3 != 0:
		return false
	for index in data.indices:
		if index < 0 or index >= data.vertices.size():
			return false
	return true


static func _valid_normals(data) -> bool:
	for normal in data.normals:
		if not normal.is_finite() or absf(normal.length() - 1.0) > 0.0001:
			return false
	return true


static func _unique_positions(values: PackedVector3Array) -> int:
	var seen := {}
	for value in values:
		seen["%.6f:%.6f:%.6f" % [value.x, value.y, value.z]] = true
	return seen.size()


static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
