extends RefCounted

const Descriptor := preload("res://worldgen/graph/surface_entrance_integration_descriptor.gd")
const Plan := preload("res://worldgen/surface/surface_entrance_chunk_plan.gd")
const Demand := preload("res://worldgen/surface/entrance_runtime_demand.gd")
const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const Config := preload("res://worldgen/geometry/geometry_cell_partition_config.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var descriptor := Descriptor.new(
		"entrance:test", "region:test", Vector3(-2, 8, -2), Vector3(0, -1, 0),
		AABB(Vector3(-6, 0, -6), Vector3(8, 4, 8)), 1.0, "network:test", "node:test",
		Vector3(-2, -8, -2), "gradual"
	)
	var chunk_a := AABB(Vector3(-16, 0, -16), Vector3(16, 32, 16))
	var chunk_b := AABB(Vector3(0, 0, -16), Vector3(16, 32, 16))
	var first = Plan.build(chunk_a, [descriptor], Vector2i(8, 8), "prov:test")
	var reordered = Plan.build(chunk_a, [descriptor], Vector2i(8, 8), "prov:test")
	_expect(failures, "single chunk entrance plan succeeds", first.success)
	if first.success:
		_expect(failures, "opening mask is non-empty", true in first.data.opening_mask)
		_expect(failures, "immediate underground cells are identified", first.data.underground_cells.size() > 0)
		_expect(failures, "plan reproduces after reload", first.fingerprint == reordered.fingerprint)
	var cross_a = Plan.build(chunk_b, [descriptor], Vector2i(8, 8), "prov:test")
	_expect(failures, "boundary chunk plan succeeds", cross_a.success)
	if cross_a.success:
		var reverse = Plan.build(chunk_b, [descriptor], Vector2i(8, 8), "prov:test")
		_expect(failures, "boundary plan is order independent", cross_a.fingerprint == reverse.fingerprint)
		_expect(failures, "boundary chunks share identical immediate demand", first.success and not first.data.demand_handoffs.is_empty() and not cross_a.data.demand_handoffs.is_empty() and cross_a.data.demand_handoffs[0].fingerprint == first.data.demand_handoffs[0].fingerprint)
	var demand_a := Demand.new("entrance:test", [Address.new(Vector3i(0, 0, 0))], "prov:test")
	var demand_b := Demand.new("entrance:test", [Address.new(Vector3i(1, 0, 0))], "prov:test")
	var demand_reordered := Demand.new("entrance:test", [Address.new(Vector3i(0, 0, 0))], "prov:test")
	_expect(failures, "demand identity includes cell addresses", demand_a.fingerprint != demand_b.fingerprint)
	_expect(failures, "demand order is canonical", demand_a.fingerprint == demand_reordered.fingerprint)
	var non_default := Config.new(Vector3(16, 16, 16), 0.5, 32, 1)
	var configured = Plan.build(chunk_a, [descriptor], Vector2i(8, 8), "prov:test", non_default)
	_expect(failures, "non-default partition policy maps handoff", configured.success and configured.data.underground_cells.size() >= first.data.underground_cells.size())
	var boundary_descriptor := Descriptor.new("entrance:boundary", "region:test", Vector3(31, 8, 31), Vector3(0, -1, 0), AABB(Vector3(30, 0, 30), Vector3(2, 2, 2)), 0.0, "network:test", "node:test", Vector3(31, -8, 31), "steep")
	var boundary_configured = Plan.build(AABB(Vector3(0, 0, 0), Vector3(32, 32, 32)), [boundary_descriptor], Vector2i(8, 8), "prov:test", non_default)
	var has_configured_neighbor := false
	if boundary_configured.success:
		for cell in boundary_configured.data.underground_cells:
			if cell.coordinate.x == 1 or cell.coordinate.z == 1:
				has_configured_neighbor = true
				break
	_expect(failures, "non-default cell mapping crosses configured boundary", has_configured_neighbor)
	# Opening wholly inside a single terrain quad must still omit that quad.
	var small := Descriptor.new("entrance:small", "region:test", Vector3(8, 8, 8), Vector3(0, -1, 0), AABB(Vector3(7.8, 0, 7.8), Vector3(0.4, 4, 0.4)), 0.1, "network:test", "node:test", Vector3(8, -8, 8), "gradual")
	var small_plan = Plan.build(AABB(Vector3(0, 0, 0), Vector3(16, 32, 16)), [small], Vector2i(4, 4), "prov:test")
	_expect(failures, "interstitial opening omits intersecting terrain triangles", small_plan.success and small_plan.data.omitted_triangle_indices.size() > 0)
	_expect(failures, "surface triangles outside opening remain", small_plan.success and small_plan.data.omitted_triangle_indices.size() < 4 * 4 * 6)
	return failures


static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
