extends RefCounted

const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const Fragment := preload("res://worldgen/geometry/geometry_cell_fragment.gd")
const Plan := preload("res://worldgen/geometry/geometry_cell_plan.gd")
const Config := preload("res://worldgen/geometry/geometry_cell_partition_config.gd")
const Request := preload("res://worldgen/geometry/cave_voxel_field_request.gd")
const Mesher := preload("res://worldgen/geometry/cave_voxel_mesher.gd")
const Boundary := preload("res://worldgen/geometry/cave_mesh_realization_boundary.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var plan := _plan(Vector3i(-1, 0, 2), ["chamber", "tunnel"])
	var result = Mesher.build(Request.new(plan, Config.new()))
	_expect(failures, "chamber and tunnel mesh build succeeds", result.success)
	if result.success:
		_expect(failures, "mesh buffers have triangles", result.data.indices.size() > 0)
		_expect(failures, "mesh indices are valid", _valid_indices(result.data))
		_expect(failures, "mesh normals are unit and finite", _valid_normals(result.data))
		var realized: Dictionary = Boundary.realize_main_thread(result.data)
		_expect(failures, "main-thread realization succeeds", realized.success)
		_expect(failures, "realization preserves source fingerprint", realized.input_fingerprint == plan.fingerprint)
		_expect(failures, "stale realization is rejected", not Boundary.realize_main_thread(result.data, null, "stale").success)
	var reversed := _plan(Vector3i(-1, 0, 2), ["tunnel", "chamber"])
	var second = Mesher.build(Request.new(reversed, Config.new()))
	_expect(failures, "reordered fragments build", second.success)
	if second.success:
		_expect(failures, "reordered fragments reproduce buffers", second.data.fingerprint == result.data.fingerprint)
	var malformed := _plan(Vector3i.ZERO, ["chamber"])
	malformed.fragments.append(null)
	var bad = Mesher.build(Request.new(malformed, Config.new()))
	_expect(failures, "malformed fragment is rejected", not bad.success)
	return failures


static func _plan(coordinate: Vector3i, kinds: Array) -> Plan:
	var address := Address.new(coordinate)
	var cell := AABB(Vector3(coordinate) * 32.0, Vector3(32, 32, 32))
	var fragments: Array = []
	for i in range(kinds.size()):
		var clipped := AABB(cell.position + Vector3(2 + i * 8, 4, 3), Vector3(10, 8, 12))
		fragments.append(Fragment.new(
			"gfrag1:test-%s" % kinds[i], "stable:%s" % kinds[i], kinds[i], address,
			cell, clipped, i == 0, {}, {}, "source:%s" % kinds[i], {}
		))
	return Plan.new(address, fragments, [], [], "geometry", "finalization")


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


static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
