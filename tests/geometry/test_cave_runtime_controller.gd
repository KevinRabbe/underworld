extends RefCounted

const Controller := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const CaveMeshData := preload("res://worldgen/geometry/cave_mesh_data.gd")
const PlanData := preload("res://worldgen/surface/surface_entrance_chunk_plan_data.gd")
const Demand := preload("res://worldgen/surface/entrance_runtime_demand.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	var controller := Controller.new()
	controller.configure("world:test", "manifest:test")
	var plan := PlanData.new()
	plan.fingerprint = "surface-plan:test"
	var cells := [Address.new(Vector3i(0, -1, 0)), Address.new(Vector3i(1, -1, 0))]
	plan.demand_handoffs = [Demand.new("entrance:test", cells, "prov:test")]
	plan.underground_cells = cells
	failures.append_array(controller.register_surface_plan(plan, "prov:test"))
	_expect(failures, "registers one entrance gate", controller.gates.has("entrance:test"))
	_expect(failures, "pins all handoff cells", controller.streamer.records.size() == 2)
	controller.update_player_position(Vector3(0.5, -31.5, 0.5))
	var first_count: int = controller.streamer.records[cells[0].canonical_text()].demand_count("collision")
	controller.update_player_position(Vector3(0.5, -31.5, 0.5))
	_expect(failures, "repeated entrance pinning is idempotent", controller.streamer.records[cells[0].canonical_text()].demand_count("collision") == first_count)
	_expect(failures, "gate remains closed before collision", not controller.gate_is_open("entrance:test"))
	var address = cells[0]
	var record = controller.streamer.records[address.canonical_text()]
	var shape := _shape()
	_expect(failures, "collision attaches through main-thread boundary", controller.accept_collision_shape(address, shape, record.source_fingerprint, record.provenance_fingerprint))
	_expect(failures, "gate remains closed until every destination cell is ready", not controller.gate_is_open("entrance:test"))
	var second_record = controller.streamer.records[cells[1].canonical_text()]
	var second_shape := _shape()
	_expect(failures, "second collision attaches", controller.accept_collision_shape(cells[1], second_shape, second_record.source_fingerprint, second_record.provenance_fingerprint))
	_expect(failures, "gate opens after all collision cells are ready", controller.gate_is_open("entrance:test"))
	controller.free()

	_test_tier_retirement_and_replacement(failures)
	_test_bounded_observer_nodes(failures)
	return failures


static func _test_tier_retirement_and_replacement(failures: Array[String]) -> void:
	var controller := Controller.new()
	controller.configure("world:lifecycle", "manifest:lifecycle")
	var address := Address.new(Vector3i(2, -1, 3))
	var key: String = address.canonical_text()
	var record = controller.streamer.set_demand(address, "source:a", ["definition", "fragment_plan", "voxel_geometry", "render", "collision"], "source:lifecycle", "provenance:lifecycle")
	var mesh_data = _mesh_data(address, "mesh:lifecycle")
	_expect(failures, "initial render realization accepted", controller.accept_mesh_data(mesh_data))
	_expect(failures, "initial collision realization accepted", controller.accept_collision_shape(address, _shape(), record.source_fingerprint, record.provenance_fingerprint))
	_expect(failures, "one tracked live render collision pair", controller.render_nodes.size() == 1 and controller.collision_nodes.size() == 1 and controller.get_child_count() == 2 and record.readiness["render"] and record.readiness["collision"])

	var first_render = controller.render_nodes[key]
	var first_collision = controller.collision_nodes[key]
	controller.streamer.demand_cell(address, "source:b", ["render"])
	controller.streamer.release_demand(address, "source:a", ["render"])
	_expect(failures, "one source cannot retire another render lease", record.demand_count("render") == 1 and record.readiness["render"] and controller.render_nodes.get(key) == first_render)
	controller.streamer.release_demand(address, "source:b", ["render"])
	_expect(failures, "render tier retirement clears readiness handle and node", record.demand_count("render") == 0 and not record.readiness["render"] and record.runtime_handle == null and not controller.render_nodes.has(key) and first_render.get_parent() == null)
	_expect(failures, "collision remains independently realized", record.readiness["collision"] and controller.collision_nodes.get(key) == first_collision)

	var queued_before: int = controller.streamer.queued_count
	controller.streamer.demand_cell(address, "source:a", ["render"])
	var renewed_generation: int = record.generation
	_expect(failures, "renewed render queues once", record.queued.get("render", false) and controller.streamer.queued_count == queued_before + 1)
	controller.streamer.set_demand(address, "source:a", ["definition", "fragment_plan", "voxel_geometry", "render", "collision"])
	_expect(failures, "idempotent demand refresh does not double queue render", controller.streamer.queued_count == queued_before + 1 and record.generation == renewed_generation)
	_expect(failures, "renewed render realizes", controller.accept_mesh_data(mesh_data) and record.readiness["render"])
	var renewed_render = controller.render_nodes[key]
	_expect(failures, "second accepted render replaces rather than orphans", controller.accept_mesh_data(mesh_data) and controller.render_nodes.size() == 1 and controller.get_child_count() == 2 and renewed_render.get_parent() == null)

	controller.streamer.release_demand(address, "source:a", ["collision"])
	_expect(failures, "collision retirement removes physics body and handle", record.demand_count("collision") == 0 and not record.readiness["collision"] and record.collision_handle == null and not controller.collision_nodes.has(key) and first_collision.get_parent() == null)

	controller.streamer.release_demand(address, "source:a")
	_expect(failures, "whole demand release removes remaining render", controller.render_nodes.is_empty() and controller.collision_nodes.is_empty() and controller.get_child_count() == 0 and record.state == "release_pending")
	var released_before: int = controller.streamer.released_count
	_expect(failures, "whole cell release succeeds", controller.streamer.release_cell(address) and record.state == "dormant")
	var generation_after_release: int = record.generation
	_expect(failures, "repeated whole cell release is idempotent", controller.streamer.release_cell(address) and record.generation == generation_after_release and controller.streamer.released_count == released_before + 1)

	record = controller.streamer.set_demand(address, "source:c", ["render", "collision"], "source:reconfigure", "provenance:reconfigure")
	var reconfigure_mesh = _mesh_data(address, "mesh:reconfigure")
	_expect(failures, "pre-reconfigure render realizes", controller.accept_mesh_data(reconfigure_mesh))
	_expect(failures, "pre-reconfigure collision realizes", controller.accept_collision_shape(address, _shape(), record.source_fingerprint, record.provenance_fingerprint))
	var old_generation: int = record.generation
	controller.streamer.reconfigure("world:lifecycle:new", "manifest:lifecycle:new")
	_expect(failures, "reconfigure retires all live realization nodes", controller.render_nodes.is_empty() and controller.collision_nodes.is_empty() and controller.get_child_count() == 0 and not record.readiness["render"] and not record.readiness["collision"])
	var stale_shape := _shape()
	var stale_result = preload("res://worldgen/runtime/runtime_cell_result.gd").new(address, old_generation, "collision", record.source_fingerprint, record.provenance_fingerprint, stale_shape, true, [], "world:lifecycle", "manifest:lifecycle")
	_expect(failures, "pre-reconfigure async result stays stale", not controller.streamer.accept_result(stale_result))
	controller.free()


static func _test_bounded_observer_nodes(failures: Array[String]) -> void:
	var controller := Controller.new()
	controller.configure("world:window", "manifest:window")
	controller.streamer.definition_activate_radius = 0
	controller.streamer.definition_release_radius = 0
	controller.streamer.geometry_activate_radius = 0
	controller.streamer.geometry_release_radius = 0
	controller.streamer.render_activate_radius = 0
	controller.streamer.render_release_radius = 0
	controller.streamer.collision_activate_radius = 0
	controller.streamer.collision_release_radius = 0
	for x in range(4):
		var position := Vector3(float(x * 32) + 0.5, 0.5, 0.5)
		controller.update_player_position(position)
		var address := Address.new(Vector3i(x, 0, 0))
		var record = controller.streamer.records[address.canonical_text()]
		var tiers: Array = record.demands.get("player", {}).keys()
		controller.streamer.set_demand(address, "player", tiers, "source:window:%d" % x, "provenance:window:%d" % x)
		_expect(failures, "bounded observer render realizes step %d" % x, controller.accept_mesh_data(_mesh_data(address, "mesh:window:%d" % x)))
		_expect(failures, "bounded observer live render count step %d" % x, controller.render_nodes.size() == 1 and controller.get_child_count() == 1)
	controller.free()


static func _mesh_data(address, input_fingerprint: String):
	return CaveMeshData.new(
		address,
		AABB(Vector3(address.coordinate) * 32.0, Vector3(32, 32, 32)),
		PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD]),
		PackedInt32Array([0, 1, 2]),
		PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP]),
		PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.UP]),
		[],
		[],
		input_fingerprint
	)


static func _shape() -> ConcavePolygonShape3D:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD]))
	return shape


static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
