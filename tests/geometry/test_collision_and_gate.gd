extends RefCounted

const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const MeshData := preload("res://worldgen/geometry/cave_mesh_data.gd")
const CollisionBuilder := preload("res://worldgen/runtime/cave_collision_builder.gd")
const Boundary := preload("res://worldgen/runtime/cave_collision_realization_boundary.gd")
const Streamer := preload("res://worldgen/runtime/underworld_runtime_streamer.gd")
const Result := preload("res://worldgen/runtime/runtime_cell_result.gd")
const Gate := preload("res://worldgen/runtime/entrance_traversal_gate.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var empty_gate := Gate.new("empty", [])
	var empty_streamer := Streamer.new("world", "manifest")
	_expect(failures, "empty gate fails closed", not empty_gate.update(empty_streamer) and not empty_gate.diagnostics.is_empty())
	var address := Address.new(Vector3i(-1, 0, -2))
	var vertices := PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0)])
	var indices := PackedInt32Array([0, 1, 2])
	var normals := PackedVector3Array([Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1)])
	var uvs := PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.UP])
	var mesh := MeshData.new(address, AABB(Vector3.ZERO, Vector3.ONE), vertices, indices, normals, uvs, ["source"], ["fragment"], "plan", {"triangle_count": 1})
	var prepared = CollisionBuilder.prepare(mesh, "prov")
	_expect(failures, "collision preparation succeeds", prepared.success)
	var realized: Dictionary = {}
	if prepared.success:
		realized = Boundary.realize_main_thread(prepared.data, mesh.output_fingerprint)
		_expect(failures, "collision realization succeeds", realized.success)
		_expect(failures, "stale collision source rejected", not Boundary.realize_main_thread(prepared.data, "stale").success)
	var streamer := Streamer.new("world", "manifest")
	streamer.demand_cell(address, "entrance:test", ["collision"], "plan", "prov")
	var gate := Gate.new("entrance:test", [address])
	_expect(failures, "gate closed before collision", not gate.update(streamer))
	var result := Result.new(address, streamer.records[address.canonical_text()].generation, "collision", "plan", "prov", realized.get("shape") if prepared.success else null, true, [], "world", "manifest")
	_expect(failures, "collision result accepted", streamer.accept_result(result))
	_expect(failures, "gate opens when collision ready", gate.update(streamer))
	var invalid := Result.new(address, streamer.records[address.canonical_text()].generation, "collision", "plan", "prov", null, true, [], "world", "manifest")
	streamer.release_demand(address, "entrance:test")
	streamer.demand_cell(address, "entrance:test", ["collision"], "plan", "prov")
	_expect(failures, "null collision payload is rejected", not streamer.accept_result(invalid))
	streamer.release_demand(address, "entrance:test")
	gate.update(streamer)
	_expect(failures, "gate closes before release", not gate.is_open())
	return failures


static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
