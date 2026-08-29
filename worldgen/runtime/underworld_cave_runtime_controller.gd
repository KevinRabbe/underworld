extends Node3D
class_name UnderworldCaveRuntimeController

const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const Streamer := preload("res://worldgen/runtime/underworld_runtime_streamer.gd")
const Result := preload("res://worldgen/runtime/runtime_cell_result.gd")
const Gate := preload("res://worldgen/runtime/entrance_traversal_gate.gd")
const MeshBoundary := preload("res://worldgen/geometry/cave_mesh_realization_boundary.gd")
const CollisionBoundary := preload("res://worldgen/runtime/cave_collision_realization_boundary.gd")
const WorldContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const MacroGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const TopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const EntranceGenerator := preload("res://worldgen/underworld/entrance_generator.gd")
const ConnectivityGenerator := preload("res://worldgen/underworld/secondary_connectivity_generator.gd")
const HookGenerator := preload("res://worldgen/underworld/special_location_hook_generator.gd")
const RegionFinalizer := preload("res://worldgen/underworld/region_finalizer.gd")
const GeometryGenerator := preload("res://worldgen/underworld/cave_geometry_generator.gd")
const PartitionConfig := preload("res://worldgen/geometry/geometry_cell_partition_config.gd")
const PartitionRequest := preload("res://worldgen/geometry/geometry_cell_partition_request.gd")
const Partitioner := preload("res://worldgen/geometry/geometry_cell_partitioner.gd")
const VoxelRequest := preload("res://worldgen/geometry/cave_voxel_field_request.gd")
const VoxelMesher := preload("res://worldgen/geometry/cave_voxel_mesher.gd")
const CollisionBuilder := preload("res://worldgen/runtime/cave_collision_builder.gd")
const SurfacePlan := preload("res://worldgen/surface/surface_entrance_chunk_plan.gd")

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
var last_bootstrap_fingerprint: String = ""
var last_bootstrap_diagnostics: Array[String] = []
var last_bootstrap_surface_position: Vector3 = Vector3.ZERO

func configure(world_id_value: String, manifest_id_value: String, player_value: Node3D = null, executor = null) -> void:
	world_id = world_id_value
	generator_manifest_id = manifest_id_value
	player = player_value
	streamer = Streamer.new(world_id, generator_manifest_id, executor)

func set_cave_material(material: Material) -> void:
	_material = material

## Builds the deterministic data pipeline for one region and realizes the selected
## entrance cells. Call this during a loading phase; all scene/resource creation
## remains inside the main-thread realization methods below.
func bootstrap_fixture(world_seed: int, region: Vector2i, entrance_id: String) -> Array[String]:
	last_bootstrap_diagnostics.clear()
	var context := WorldContext.new(world_seed)
	var sampler := SurfaceSampler.new(world_seed)
	var macro = MacroGenerator.generate(context, region)
	if not macro.success: return _bootstrap_fail(macro.diagnostics)
	var topology = TopologyGenerator.generate(context, macro.data, sampler)
	if not topology.success: return _bootstrap_fail(topology.diagnostics)
	var entrances = EntranceGenerator.generate(context, macro.data, topology.data, sampler)
	if not entrances.success: return _bootstrap_fail(entrances.diagnostics)
	var selected = null
	for descriptor in entrances.data.surface_integration_descriptors:
		if str(descriptor.entrance_id) == entrance_id: selected = descriptor; break
	if selected == null: return _bootstrap_fail(["Fixture entrance was not found: " + entrance_id])
	last_bootstrap_surface_position = selected.surface_world_position
	var neighbor_views: Array = []
	for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var neighbor_macro = MacroGenerator.generate(context, region + offset)
		if not neighbor_macro.success: return _bootstrap_fail(neighbor_macro.diagnostics)
		var neighbor_topology = TopologyGenerator.generate(context, neighbor_macro.data, sampler)
		if not neighbor_topology.success: return _bootstrap_fail(neighbor_topology.diagnostics)
		neighbor_views.append({"region_plan": neighbor_macro.data, "primary_topology": neighbor_topology.data})
	var connectivity = ConnectivityGenerator.generate(context, macro.data, topology.data, entrances.data, neighbor_views)
	if not connectivity.success: return _bootstrap_fail(connectivity.diagnostics)
	var hooks = HookGenerator.generate(context, macro.data, connectivity.data)
	if not hooks.success: return _bootstrap_fail(hooks.diagnostics)
	var finalized = RegionFinalizer.generate(context, macro.data, entrances.data, connectivity.data, hooks.data)
	if not finalized.success: return _bootstrap_fail(finalized.diagnostics)
	var geometry = GeometryGenerator.generate(context, macro.data, finalized.data, neighbor_views)
	if not geometry.success: return _bootstrap_fail(geometry.diagnostics)
	var cell_config := PartitionConfig.new()
	var bounds := AABB(selected.surface_world_position - Vector3(32, 32, 32), Vector3(64, 64, 64))
	var surface_result = SurfacePlan.build(bounds, [selected], Vector2i(16, 16), entrances.fingerprint, cell_config)
	if not surface_result.success: return _bootstrap_fail(surface_result.diagnostics)
	var handoff = surface_result.data.demand_handoffs[0]
	var expected_geometry_sources := GeometryGenerator.expected_provenance_sources(macro.data, finalized.data, neighbor_views)
	var partition_request := PartitionRequest.new(geometry.data, finalized.data, cell_config, handoff.cell_addresses, context, expected_geometry_sources)
	var partition = Partitioner.generate(partition_request)
	if not partition.success: return _bootstrap_fail(partition.diagnostics)
	var provenance = partition.provenance
	var registration_failures := register_surface_plan(surface_result.data, provenance.fingerprint if provenance != null else "")
	if not registration_failures.is_empty(): return _bootstrap_fail(registration_failures)
	for plan in partition.data.plans:
		var voxel_request := VoxelRequest.new(plan, cell_config, provenance, 0.0, partition.data, context)
		var mesh_stage = VoxelMesher.build(voxel_request)
		if not mesh_stage.success: return _bootstrap_fail(mesh_stage.diagnostics)
		if not accept_mesh_data(mesh_stage.data, null, plan): return _bootstrap_fail(["Mesh realization failed for " + plan.cell_address.canonical_text()])
		var collision_stage = CollisionBuilder.prepare(mesh_stage.data, provenance.fingerprint if provenance != null else "")
		if not collision_stage.success: return _bootstrap_fail(collision_stage.diagnostics)
		var collision_realized: Dictionary = CollisionBoundary.realize_main_thread(collision_stage.data, mesh_stage.data.output_fingerprint)
		if not collision_realized.success or not accept_collision_shape(plan.cell_address, collision_realized.shape, streamer.records[plan.cell_address.canonical_text()].source_fingerprint, streamer.records[plan.cell_address.canonical_text()].provenance_fingerprint):
			return _bootstrap_fail(["Collision realization failed for " + plan.cell_address.canonical_text()])
	last_bootstrap_fingerprint = entrances.fingerprint + ":" + geometry.fingerprint + ":" + partition.data.fingerprint
	return []

func _bootstrap_fail(diagnostics: Array) -> Array[String]:
	for diagnostic in diagnostics: last_bootstrap_diagnostics.append(str(diagnostic))
	return last_bootstrap_diagnostics.duplicate()

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
				# The entrance pin established the accepted surface-plan/partition
				# identity. Refresh only desired tiers here; never relabel a live
				# cell with the handoff fingerprint and invalidate its generation.
				streamer.set_demand(address, "entrance:" + entrance_id, ["definition", "fragment_plan", "voxel_geometry", "render", "collision"])
			else:
				streamer.release_entrance(address, entrance_id)
		_update_gates()

func accept_mesh_data(mesh_data, material = null, source_cell_plan = null) -> bool:
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
	if source_cell_plan != null:
		# Transient renderer context only. The plan already owns authoritative
		# identity/fingerprints; attaching the reference here does not alter them.
		node.set_meta("source_cell_plan", source_cell_plan)
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
