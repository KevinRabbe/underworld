extends Node3D
class_name UnderworldCaveRuntimeController

const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const Streamer := preload("res://worldgen/runtime/underworld_runtime_streamer.gd")
const Result := preload("res://worldgen/runtime/runtime_cell_result.gd")
const Gate := preload("res://worldgen/runtime/entrance_traversal_gate.gd")
const MeshBoundary := preload("res://worldgen/geometry/cave_mesh_realization_boundary.gd")
const CollisionBoundary := preload("res://worldgen/runtime/cave_collision_realization_boundary.gd")
const VoxelRequest := preload("res://worldgen/geometry/cave_voxel_field_request.gd")
const VoxelMesher := preload("res://worldgen/geometry/cave_voxel_mesher.gd")
const PartitionRequest := preload("res://worldgen/geometry/geometry_cell_partition_request.gd")
const Partitioner := preload("res://worldgen/geometry/geometry_cell_partitioner.gd")
const CollisionBuilder := preload("res://worldgen/runtime/cave_collision_builder.gd")
const SurfacePlan := preload("res://worldgen/surface/surface_entrance_chunk_plan.gd")
const DefinitionService := preload("res://worldgen/runtime/underworld_runtime_cell_definition_service.gd")
const RuntimeExecutor := preload("res://worldgen/runtime/underworld_runtime_cell_executor.gd")

const MAX_OBSERVER_BINDINGS_PER_UPDATE: int = 4
const MAX_EXPENSIVE_CELL_JOBS_PER_UPDATE: int = 1
const MAX_TOTAL_CELL_JOBS_PER_UPDATE: int = 16

signal traversal_gate_changed(entrance_id: String, open: bool)
signal cell_attached(address, tier: String)
signal cave_presence_changed(in_cave: bool)

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
var _player_in_realized_cave: bool = false
var _definition_service
var _runtime_executor
var _observer_binding_failures: Dictionary = {}


func configure(
	world_id_value: String,
	manifest_id_value: String,
	player_value: Node3D = null,
	executor = null
) -> void:
	_unbind_streamer()
	_dispose_all_realizations()
	entrance_plans.clear()
	gates.clear()
	_observer_binding_failures.clear()
	_definition_service = null
	_runtime_executor = null
	world_id = world_id_value
	generator_manifest_id = manifest_id_value
	player = player_value
	_player_in_realized_cave = false
	streamer = Streamer.new(world_id, generator_manifest_id, executor)
	_bind_streamer()


func set_cave_material(material: Material) -> void:
	_material = material


## Compatibility/developer entry point retained for MAP-015 and historical tests.
## The generated-entrance operation below is the production authority.
func bootstrap_fixture(world_seed: int, region: Vector2i, entrance_id: String) -> Array[String]:
	return bootstrap_generated_entrance(world_seed, region, entrance_id)


## Builds the accepted deterministic region definition once, then realizes the
## entrance handoff through the same canonical one-cell definitions used by
## observer streaming. This keeps re-entry identity independent of batch shape.
func bootstrap_generated_entrance(
	world_seed: int,
	region: Vector2i,
	entrance_id: String
) -> Array[String]:
	last_bootstrap_diagnostics.clear()
	_observer_binding_failures.clear()
	_definition_service = DefinitionService.new()
	var definition_failures: Array[String] = _definition_service.configure(world_seed)
	if not definition_failures.is_empty():
		return _bootstrap_fail(definition_failures)

	var region_stage = _definition_service.region_definition(region)
	if not region_stage.success:
		return _bootstrap_fail(region_stage.diagnostics)
	var region_data: Dictionary = region_stage.data
	var entrances = region_data["entrances"]
	var selected = null
	for descriptor in entrances.surface_integration_descriptors:
		if str(descriptor.entrance_id) == entrance_id:
			selected = descriptor
			break
	if selected == null:
		return _bootstrap_fail(["Generated entrance was not found: " + entrance_id])
	last_bootstrap_surface_position = selected.surface_world_position

	var cell_config = _definition_service.cell_config
	var bounds := AABB(
		selected.surface_world_position - Vector3(32, 32, 32),
		Vector3(64, 64, 64)
	)
	var surface_result = SurfacePlan.build(
		bounds,
		[selected],
		Vector2i(16, 16),
		str(region_data["entrance_fingerprint"]),
		cell_config
	)
	if not surface_result.success:
		return _bootstrap_fail(surface_result.diagnostics)
	var handoff = surface_result.data.demand_handoffs[0]

	# Preserve the accepted public bootstrap fingerprint contract. This batch
	# partition exists only as deterministic evidence; runtime cell ownership and
	# re-entry use the canonical one-cell definitions built below.
	var evidence_partition_request := PartitionRequest.new(
		region_data["geometry"],
		region_data["finalized"],
		cell_config,
		handoff.cell_addresses,
		_definition_service.context,
		region_data["expected_geometry_sources"]
	)
	var evidence_partition = Partitioner.generate(evidence_partition_request)
	if not evidence_partition.success:
		return _bootstrap_fail(evidence_partition.diagnostics)

	var definitions: Dictionary = {}
	var source_fingerprints: Dictionary = {}
	var provenance_fingerprints: Dictionary = {}
	for address in handoff.cell_addresses:
		var definition_stage = _definition_service.cell_definition(address)
		if not definition_stage.success:
			return _bootstrap_fail(definition_stage.diagnostics)
		var definition: Dictionary = definition_stage.data
		var key: String = address.canonical_text()
		definitions[key] = definition
		source_fingerprints[key] = str(definition["source_fingerprint"])
		provenance_fingerprints[key] = str(definition["provenance_fingerprint"])

	var registration_failures := register_surface_plan(
		surface_result.data,
		"",
		source_fingerprints,
		provenance_fingerprints
	)
	if not registration_failures.is_empty():
		return _bootstrap_fail(registration_failures)

	for address in handoff.cell_addresses:
		var key: String = address.canonical_text()
		var definition: Dictionary = definitions[key]
		if not _accept_bootstrap_tier(address, "definition", definition):
			return _bootstrap_fail(["Definition readiness failed for " + key])
		if not _accept_bootstrap_tier(address, "fragment_plan", definition["cell_plan"]):
			return _bootstrap_fail(["Fragment-plan readiness failed for " + key])

		var voxel_request := VoxelRequest.new(
			definition["cell_plan"],
			cell_config,
			definition["provenance"],
			0.0,
			definition["partition_result"],
			_definition_service.context
		)
		var mesh_stage = VoxelMesher.build(voxel_request)
		if not mesh_stage.success:
			return _bootstrap_fail(mesh_stage.diagnostics)
		if not _accept_bootstrap_tier(address, "voxel_geometry", mesh_stage.data):
			return _bootstrap_fail(["Voxel readiness failed for " + key])

		var semantic_snapshot: Dictionary = build_cell_semantic_snapshot(
			definition["cell_plan"]
		)
		if not accept_mesh_data(mesh_stage.data, null, semantic_snapshot):
			return _bootstrap_fail(["Mesh realization failed for " + key])

		var collision_stage = CollisionBuilder.prepare(
			mesh_stage.data,
			str(definition["provenance_fingerprint"])
		)
		if not collision_stage.success:
			return _bootstrap_fail(collision_stage.diagnostics)
		var collision_realized: Dictionary = CollisionBoundary.realize_main_thread(
			collision_stage.data,
			mesh_stage.data.output_fingerprint
		)
		if not bool(collision_realized.get("success", false)) or not accept_collision_shape(
			address,
			collision_realized.get("shape", null),
			str(definition["source_fingerprint"]),
			str(definition["provenance_fingerprint"])
		):
			return _bootstrap_fail(["Collision realization failed for " + key])

	if streamer.executor == null:
		_runtime_executor = RuntimeExecutor.new()
		var executor_failures: Array[String] = _runtime_executor.configure(
			streamer,
			_definition_service,
			self
		)
		if not executor_failures.is_empty():
			return _bootstrap_fail(executor_failures)
		streamer.executor = _runtime_executor

	last_bootstrap_fingerprint = "%s:%s:%s" % [
		region_data["entrance_fingerprint"],
		region_data["geometry_fingerprint"],
		evidence_partition.data.fingerprint,
	]
	return []


func _accept_bootstrap_tier(address, tier: String, payload) -> bool:
	var record = streamer.records.get(address.canonical_text(), null)
	if record == null:
		return false
	var result := Result.new(
		address,
		record.generation,
		tier,
		record.source_fingerprint,
		record.provenance_fingerprint,
		payload,
		true,
		[],
		world_id,
		generator_manifest_id
	)
	return streamer.accept_result(result)


func _bootstrap_fail(diagnostics: Array) -> Array[String]:
	for diagnostic in diagnostics:
		last_bootstrap_diagnostics.append(str(diagnostic))
	return last_bootstrap_diagnostics.duplicate()


func register_surface_plan(
	plan,
	provenance_fingerprint: String = "",
	cell_source_fingerprints: Dictionary = {},
	cell_provenance_fingerprints: Dictionary = {}
) -> Array[String]:
	var failures: Array[String] = []
	if plan == null or plan.demand_handoffs.is_empty():
		failures.append("Surface entrance plan must provide demand handoffs")
		return failures
	for handoff in plan.demand_handoffs:
		if handoff == null or handoff.cell_addresses.is_empty():
			failures.append("Entrance handoff has no destination cells")
			continue
		entrance_plans[handoff.entrance_id] = handoff
		gates[handoff.entrance_id] = Gate.new(
			handoff.entrance_id,
			handoff.cell_addresses
		)
		for address in handoff.cell_addresses:
			var key: String = address.canonical_text()
			var source_fingerprint: String = str(
				cell_source_fingerprints.get(key, plan.fingerprint)
			)
			var cell_provenance: String = str(
				cell_provenance_fingerprints.get(key, provenance_fingerprint)
			)
			streamer.pin_entrance(
				address,
				handoff.entrance_id,
				["definition", "fragment_plan", "voxel_geometry", "render", "collision"],
				source_fingerprint,
				cell_provenance
			)
	return failures


func update_player_position(position: Vector3) -> void:
	if streamer == null:
		return
	var production_streaming_active: bool = (
		_definition_service == null or _observer_streaming_active(position)
	)
	if production_streaming_active:
		streamer.update_observer(position, "player")
		if _definition_service != null:
			_bind_unbound_observer_cells(position)
	else:
		_release_observer_source("player")

	for entrance_id in gates.keys():
		var handoff = entrance_plans[entrance_id]
		var near: bool = false
		for address in handoff.cell_addresses:
			var bounds: AABB = AABB(
				Vector3(address.coordinate) * streamer.cell_size,
				streamer.cell_size
			)
			if bounds.grow(streamer.cell_size.x).has_point(position):
				near = true
				break
		for address in handoff.cell_addresses:
			if near:
				# Bootstrap establishes canonical per-cell identity. Refresh only
				# desired tiers here; never relabel a live cell on approach.
				streamer.set_demand(
					address,
					"entrance:" + entrance_id,
					["definition", "fragment_plan", "voxel_geometry", "render", "collision"]
				)
			else:
				streamer.release_entrance(address, entrance_id)

	if _runtime_executor != null:
		_runtime_executor.set_observer_position(position)
		_runtime_executor.pump(
			MAX_EXPENSIVE_CELL_JOBS_PER_UPDATE,
			MAX_TOTAL_CELL_JOBS_PER_UPDATE
		)
		_runtime_executor.prune_runtime_cache()
	_prune_definition_cache()
	_update_cave_presence(position)
	_update_gates()


func _bind_unbound_observer_cells(position: Vector3) -> void:
	var candidates: Array[Dictionary] = []
	for record in streamer.records.values():
		if record == null or not record.demands.has("player"):
			continue
		if not record.source_fingerprint.is_empty() and not record.provenance_fingerprint.is_empty():
			continue
		if not _address_is_underworld(record.cell_address):
			continue
		var key: String = record.cell_address.canonical_text()
		if _observer_binding_failures.has(key):
			continue
		var center: Vector3 = (
			Vector3(record.cell_address.coordinate) * streamer.cell_size
			+ streamer.cell_size * 0.5
		)
		candidates.append({
			"record": record,
			"distance": center.distance_squared_to(position),
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["distance"]), float(b["distance"])):
			return float(a["distance"]) < float(b["distance"])
		return a["record"].key < b["record"].key
	)

	var bound: int = 0
	for candidate in candidates:
		if bound >= MAX_OBSERVER_BINDINGS_PER_UPDATE:
			break
		var record = candidate["record"]
		var definition_stage = _definition_service.cell_definition(record.cell_address)
		if not definition_stage.success:
			var diagnostics: Array[String] = []
			for diagnostic in definition_stage.diagnostics:
				diagnostics.append(str(diagnostic))
			_observer_binding_failures[record.key] = diagnostics
			push_error(
				"Observer cave cell binding failed for %s: %s" % [
					record.key,
					diagnostics,
				]
			)
			continue
		var definition: Dictionary = definition_stage.data
		var player_lease: Dictionary = record.demands.get("player", {})
		var tiers: Array = player_lease.keys()
		if tiers.is_empty():
			continue
		streamer.set_demand(
			record.cell_address,
			"player",
			tiers,
			str(definition["source_fingerprint"]),
			str(definition["provenance_fingerprint"])
		)
		bound += 1


func _observer_streaming_active(position: Vector3) -> bool:
	if position.y < 0.0:
		return true
	for handoff in entrance_plans.values():
		if handoff == null:
			continue
		for address in handoff.cell_addresses:
			var bounds: AABB = AABB(
				Vector3(address.coordinate) * streamer.cell_size,
				streamer.cell_size
			)
			if bounds.grow(streamer.cell_size.x).has_point(position):
				return true
	return false


func _release_observer_source(source: String) -> void:
	for record in streamer.records.values():
		if record == null or not record.demands.has(source):
			continue
		streamer.release_demand(record.cell_address, source)
		if record.demands.is_empty():
			streamer.release_cell(record.cell_address)


func _prune_definition_cache() -> void:
	if _definition_service == null:
		return
	var active_addresses: Array = []
	for record in streamer.records.values():
		if record == null or record.demands.is_empty():
			continue
		if not _address_is_underworld(record.cell_address):
			continue
		active_addresses.append(record.cell_address)
	_definition_service.prune_to_addresses(active_addresses)


func _address_is_underworld(address) -> bool:
	if address == null:
		return false
	var minimum_y: float = float(address.coordinate.y) * float(streamer.cell_size.y)
	var maximum_y: float = minimum_y + float(streamer.cell_size.y)
	return minimum_y < 0.0 and maximum_y > -384.0


func _update_cave_presence(position: Vector3) -> void:
	if not _is_finite_vector3(position):
		return
	var in_cave: bool = false
	for candidate in render_nodes.values():
		if candidate == null or not candidate is Node or not is_instance_valid(candidate):
			continue
		if not candidate.has_meta("cell_semantic_snapshot"):
			continue
		var snapshot_variant = candidate.get_meta("cell_semantic_snapshot")
		if not snapshot_variant is Dictionary:
			continue
		var bounds_variant = snapshot_variant.get("world_bounds", null)
		if bounds_variant is AABB:
			var bounds: AABB = bounds_variant
			if (
				bounds.size.x > 0.0
				and bounds.size.y > 0.0
				and bounds.size.z > 0.0
				and bounds.has_point(position)
			):
				in_cave = true
				break
	if in_cave == _player_in_realized_cave:
		return
	_player_in_realized_cave = in_cave
	cave_presence_changed.emit(in_cave)


func player_is_in_realized_cave() -> bool:
	return _player_in_realized_cave


static func _is_finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x)
		and not is_inf(value.x)
		and not is_nan(value.y)
		and not is_inf(value.y)
		and not is_nan(value.z)
		and not is_inf(value.z)
	)


## Builds the compact renderer-facing semantic snapshot consumed by replaceable
## presentation. It contains value types only and deliberately excludes StableIds,
## source/provenance fingerprints, fragment objects and other generation authority.
static func build_cell_semantic_snapshot(source_cell_plan) -> Dictionary:
	if source_cell_plan == null:
		var empty_snapshot: Dictionary = {}
		empty_snapshot.make_read_only()
		return empty_snapshot

	var source_kinds: Array[String] = []
	var tags: Array[String] = []
	var world_bounds := AABB()
	var has_bounds: bool = false
	for fragment in source_cell_plan.fragments:
		if fragment == null:
			continue
		var source_kind: String = str(fragment.source_kind)
		if not source_kind.is_empty() and not source_kinds.has(source_kind):
			source_kinds.append(source_kind)
		if not has_bounds:
			world_bounds = fragment.cell_bounds
			has_bounds = true
		var raw_tags = fragment.metadata.get("tags", [])
		if raw_tags is Array:
			for raw_tag in raw_tags:
				var tag: String = str(raw_tag)
				if not tag.is_empty() and not tags.has(tag):
					tags.append(tag)

	source_kinds.sort()
	tags.sort()
	source_kinds.make_read_only()
	tags.make_read_only()
	var snapshot: Dictionary = {
		"source_kinds": source_kinds,
		"has_entrance": not source_cell_plan.entrance_opening_metadata.is_empty(),
		"has_reserved_site": not source_cell_plan.reserved_site_metadata.is_empty(),
		"tags": tags,
		"world_bounds": world_bounds if has_bounds else AABB(),
	}
	snapshot.make_read_only()
	return snapshot


func accept_mesh_data(
	mesh_data,
	material = null,
	cell_semantic_snapshot: Dictionary = {}
) -> bool:
	if streamer == null or mesh_data == null:
		return false
	var key: String = mesh_data.cell_address.canonical_text()
	var record = streamer.records.get(key)
	if record == null:
		return false
	var realized: Dictionary = MeshBoundary.realize_main_thread(
		mesh_data,
		material if material != null else _material,
		mesh_data.input_fingerprint
	)
	if not realized.success:
		return false
	var result := Result.new(
		mesh_data.cell_address,
		record.generation,
		"render",
		record.source_fingerprint,
		record.provenance_fingerprint,
		realized.handle,
		true,
		[],
		world_id,
		generator_manifest_id
	)
	if not streamer.accept_result(result):
		return false

	_dispose_tracked_node(render_nodes, key)
	var node := MeshInstance3D.new()
	node.name = "CaveCell_" + key.replace(":", "_")
	node.mesh = realized.mesh
	node.set_meta("cell_address", key)
	node.set_meta("source_fingerprint", mesh_data.output_fingerprint)
	if not cell_semantic_snapshot.is_empty():
		var stored_snapshot: Dictionary = cell_semantic_snapshot.duplicate(true)
		var stored_kinds = stored_snapshot.get("source_kinds", [])
		if stored_kinds is Array:
			stored_kinds.make_read_only()
		var stored_tags = stored_snapshot.get("tags", [])
		if stored_tags is Array:
			stored_tags.make_read_only()
		stored_snapshot.make_read_only()
		node.set_meta("cell_semantic_snapshot", stored_snapshot)
	add_child(node)
	render_nodes[key] = node
	record.runtime_handle = realized.handle
	cell_attached.emit(mesh_data.cell_address, "render")
	return true


func accept_collision_shape(
	address,
	shape,
	source_fingerprint: String,
	provenance_fingerprint: String
) -> bool:
	if streamer == null or shape == null:
		return false
	var key: String = address.canonical_text()
	var record = streamer.records.get(key)
	if record == null:
		return false
	var result := Result.new(
		address,
		record.generation,
		"collision",
		source_fingerprint,
		provenance_fingerprint,
		shape,
		true,
		[],
		world_id,
		generator_manifest_id
	)
	if not streamer.accept_result(result):
		return false

	_dispose_tracked_node(collision_nodes, key)
	var body := StaticBody3D.new()
	body.name = "CaveCollision_" + key.replace(":", "_")
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.set_meta("cell_address", key)
	body.set_meta("source_fingerprint", source_fingerprint)
	add_child(body)
	collision_nodes[key] = body
	cell_attached.emit(address, "collision")
	_update_gates()
	return true


func gate_is_open(entrance_id: String) -> bool:
	return gates.has(entrance_id) and gates[entrance_id].is_open()


func _bind_streamer() -> void:
	if streamer == null:
		return
	var callback := Callable(self, "_on_streamer_tier_retired")
	if streamer.has_signal("tier_retired") and not streamer.is_connected(
		"tier_retired",
		callback
	):
		streamer.connect("tier_retired", callback)


func _unbind_streamer() -> void:
	if streamer == null or not is_instance_valid(streamer):
		return
	var callback := Callable(self, "_on_streamer_tier_retired")
	if streamer.has_signal("tier_retired") and streamer.is_connected(
		"tier_retired",
		callback
	):
		streamer.disconnect("tier_retired", callback)


func _on_streamer_tier_retired(address, tier: String) -> void:
	var key: String = (
		address.canonical_text()
		if address != null and address.has_method("canonical_text")
		else str(address)
	)
	if tier == "render":
		_dispose_tracked_node(render_nodes, key)
	elif tier == "collision":
		_dispose_tracked_node(collision_nodes, key)
		_update_gates()


func _dispose_tracked_node(nodes: Dictionary, key: String) -> void:
	if not nodes.has(key):
		return
	var node = nodes.get(key)
	nodes.erase(key)
	if node == null or not is_instance_valid(node):
		return
	var parent = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	if not node.is_queued_for_deletion():
		node.queue_free()


func _dispose_all_realizations() -> void:
	for key in render_nodes.keys().duplicate():
		_dispose_tracked_node(render_nodes, str(key))
	for key in collision_nodes.keys().duplicate():
		_dispose_tracked_node(collision_nodes, str(key))


func _update_gates() -> void:
	if streamer == null:
		return
	for entrance_id in gates.keys():
		var gate: Gate = gates[entrance_id]
		var was_open: bool = gate.is_open()
		var now_open: bool = gate.update(streamer)
		if was_open != now_open:
			traversal_gate_changed.emit(entrance_id, now_open)
