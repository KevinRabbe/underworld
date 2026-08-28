extends Node3D
class_name UnderworldCaveRuntimeController

const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const Streamer := preload("res://worldgen/runtime/underworld_runtime_streamer.gd")
const Result := preload("res://worldgen/runtime/runtime_cell_result.gd")
const Gate := preload("res://worldgen/runtime/entrance_traversal_gate.gd")
const MeshBoundary := preload("res://worldgen/geometry/cave_mesh_realization_boundary.gd")
const CollisionBoundary := preload("res://worldgen/runtime/cave_collision_realization_boundary.gd")

signal traversal_gate_changed(entrance_id: String, open: bool)
signal cell_attached(address, tier: String)

var streamer
var world_id: String = ""
var generator_manifest_id: String = ""
var player: Node3D
var entrance_plans: Dictionary = {}
var gates: Dictionary = {}
var render_nodes: Dictionary = {}
var collision_nodes: Dictionary = {}
var _material: Material

func configure(world_id_value: String, manifest_id_value: String, player_value: Node3D = null, executor = null) -> void:
	world_id = world_id_value
	generator_manifest_id = manifest_id_value
	player = player_value
	streamer = Streamer.new(world_id, generator_manifest_id, executor)

func set_cave_material(material: Material) -> void:
	_material = material

func register_surface_plan(plan, provenance_fingerprint: String = "") -> Array[String]:
	var failures: Array[String] = []
	if plan == null or plan.demand_handoffs.is_empty():
		failures.append("Surface entrance plan must provide demand handoffs")
		return failures
	for handoff in plan.demand_handoffs:
		if handoff == null or handoff.cell_addresses.is_empty():
			failures.append("Entrance handoff has no destination cells")
			continue
		entrance_plans[handoff.entrance_id] = handoff
		gates[handoff.entrance_id] = Gate.new(handoff.entrance_id, handoff.cell_addresses)
		for address in handoff.cell_addresses:
			streamer.pin_entrance(address, handoff.entrance_id, ["definition", "fragment_plan", "voxel_geometry", "render", "collision"], plan.fingerprint, provenance_fingerprint)
	return failures

func update_player_position(position: Vector3) -> void:
	if streamer == null:
		return
	streamer.update_observer(position, "player")
	for entrance_id in gates.keys():
		var handoff = entrance_plans[entrance_id]
		var near := false
		for address in handoff.cell_addresses:
			var bounds := AABB(Vector3(address.coordinate) * streamer.cell_size, streamer.cell_size)
			if bounds.grow(streamer.cell_size.x).has_point(position):
				near = true
				break
		for address in handoff.cell_addresses:
			if near:
				streamer.set_demand(address, "entrance:" + entrance_id, ["definition", "fragment_plan", "voxel_geometry", "render", "collision"], handoff.fingerprint, "")
			else:
				streamer.release_entrance(address, entrance_id)
		_update_gates()

func accept_mesh_data(mesh_data, material = null) -> bool:
	if streamer == null or mesh_data == null:
		return false
	var realized: Dictionary = MeshBoundary.realize_main_thread(mesh_data, material if material != null else _material, mesh_data.input_fingerprint)
	if not realized.success:
		return false
	var result := Result.new(mesh_data.cell_address, streamer.records[mesh_data.cell_address.canonical_text()].generation, "render", streamer.records[mesh_data.cell_address.canonical_text()].source_fingerprint, streamer.records[mesh_data.cell_address.canonical_text()].provenance_fingerprint, realized.handle, true, [], world_id, generator_manifest_id)
	if not streamer.accept_result(result):
		return false
	var node := MeshInstance3D.new()
	node.name = "CaveCell_" + mesh_data.cell_address.canonical_text().replace(":", "_")
	node.mesh = realized.mesh
	node.set_meta("cell_address", mesh_data.cell_address.canonical_text())
	node.set_meta("source_fingerprint", mesh_data.output_fingerprint)
	add_child(node)
	render_nodes[mesh_data.cell_address.canonical_text()] = node
	streamer.records[mesh_data.cell_address.canonical_text()].runtime_handle = realized.handle
	cell_attached.emit(mesh_data.cell_address, "render")
	return true

func accept_collision_shape(address, shape, source_fingerprint: String, provenance_fingerprint: String) -> bool:
	if streamer == null or shape == null:
		return false
	var record = streamer.records.get(address.canonical_text())
	if record == null:
		return false
	var result := Result.new(address, record.generation, "collision", source_fingerprint, provenance_fingerprint, shape, true, [], world_id, generator_manifest_id)
	if not streamer.accept_result(result):
		return false
	var body := StaticBody3D.new()
	body.name = "CaveCollision_" + address.canonical_text().replace(":", "_")
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.set_meta("cell_address", address.canonical_text())
	body.set_meta("source_fingerprint", source_fingerprint)
	add_child(body)
	collision_nodes[address.canonical_text()] = body
	cell_attached.emit(address, "collision")
	_update_gates()
	return true

func gate_is_open(entrance_id: String) -> bool:
	return gates.has(entrance_id) and gates[entrance_id].is_open()

func _update_gates() -> void:
	for entrance_id in gates.keys():
		var gate: Gate = gates[entrance_id]
		var was_open := gate.is_open()
		var now_open := gate.update(streamer)
		if was_open != now_open:
			traversal_gate_changed.emit(entrance_id, now_open)
