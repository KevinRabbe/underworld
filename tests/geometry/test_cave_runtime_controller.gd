extends RefCounted

const Controller := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
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
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD]))
	_expect(failures, "collision attaches through main-thread boundary", controller.accept_collision_shape(address, shape, record.source_fingerprint, record.provenance_fingerprint))
	_expect(failures, "gate remains closed until every destination cell is ready", not controller.gate_is_open("entrance:test"))
	var second_record = controller.streamer.records[cells[1].canonical_text()]
	var second_shape := ConcavePolygonShape3D.new()
	second_shape.set_faces(PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD]))
	_expect(failures, "second collision attaches", controller.accept_collision_shape(cells[1], second_shape, second_record.source_fingerprint, second_record.provenance_fingerprint))
	_expect(failures, "gate opens after all collision cells are ready", controller.gate_is_open("entrance:test"))
	controller.free()
	return failures

static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
