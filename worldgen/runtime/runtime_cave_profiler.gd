extends RefCounted
class_name UnderworldRuntimeCaveProfiler

const Controller := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const Streamer := preload("res://worldgen/runtime/underworld_runtime_streamer.gd")
const Budget := preload("res://worldgen/runtime/runtime_performance_budget.gd")
const WorldId := preload("res://worldgen/identity/world_id.gd")
const Manifest := preload("res://worldgen/versioning/generator_manifest.gd")
const Fixture := preload("res://worldgen/validation/map015_fixture.gd")
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
const MeshBoundary := preload("res://worldgen/geometry/cave_mesh_realization_boundary.gd")
const CollisionBuilder := preload("res://worldgen/runtime/cave_collision_builder.gd")
const CollisionBoundary := preload("res://worldgen/runtime/cave_collision_realization_boundary.gd")
const SurfacePlan := preload("res://worldgen/surface/surface_entrance_chunk_plan.gd")


class Report extends RefCounted:
	var failures: Array[String] = []
	var warnings: Array[String] = []
	var metrics: Dictionary = {}
	var scenarios: Array[Dictionary] = []
	var deterministic_fingerprint: String = ""
	var budget: Dictionary = {}

	func success() -> bool:
		return failures.is_empty()


static func run_map015() -> Report:
	var report := Report.new()
	report.budget = Budget.descriptor()
	var staged: Dictionary = _profile_pipeline(Fixture.SEED, Fixture.REGION, Fixture.ENTRANCE_ID)
	if not bool(staged.get("success", false)):
		for failure in staged.get("failures", []):
			report.failures.append(str(failure))
		return report

	report.deterministic_fingerprint = str(staged.get("deterministic_fingerprint", ""))
	_merge_metrics(report.metrics, staged.get("metrics", {}))

	var controller = Controller.new()
	controller.configure(
		WorldId.from_seed(Fixture.SEED).value(),
		Manifest.foundation_default().manifest_id()
	)
	var bootstrap_started: int = Time.get_ticks_usec()
	var diagnostics: Array[String] = controller.bootstrap_fixture(
		Fixture.SEED,
		Fixture.REGION,
		Fixture.ENTRANCE_ID
	)
	report.metrics["controller_bootstrap_ms"] = _elapsed_ms(bootstrap_started)
	if not diagnostics.is_empty():
		for diagnostic in diagnostics:
			report.failures.append("controller bootstrap: " + str(diagnostic))
	else:
		if str(controller.last_bootstrap_fingerprint) != report.deterministic_fingerprint:
			report.failures.append(
				"profiling changed deterministic bootstrap truth: staged=%s controller=%s" % [
					report.deterministic_fingerprint,
					str(controller.last_bootstrap_fingerprint),
				]
			)
		var controller_route: Dictionary = _profile_controller_route(controller, Fixture.ENTRANCE_ID)
		_merge_metrics(report.metrics, controller_route.get("metrics", {}))
		for scenario in controller_route.get("scenarios", []):
			report.scenarios.append(scenario)
		for failure in controller_route.get("failures", []):
			report.failures.append(str(failure))
	controller.free()

	var streaming: Dictionary = _profile_streaming_policy()
	_merge_metrics(report.metrics, streaming.get("metrics", {}))
	for scenario in streaming.get("scenarios", []):
		report.scenarios.append(scenario)
	for failure in streaming.get("failures", []):
		report.failures.append(str(failure))

	report.warnings = Budget.evaluate(report.metrics)
	return report


static func _profile_pipeline(world_seed: int, region: Vector2i, entrance_id: String) -> Dictionary:
	var metrics: Dictionary = {}
	var generation_started: int = Time.get_ticks_usec()
	var context = WorldContext.new(world_seed)
	var sampler = SurfaceSampler.new(world_seed)
	var macro = MacroGenerator.generate(context, region)
	if not macro.success:
		return _pipeline_fail("macro", macro.diagnostics)
	var topology = TopologyGenerator.generate(context, macro.data, sampler)
	if not topology.success:
		return _pipeline_fail("topology", topology.diagnostics)
	var entrances = EntranceGenerator.generate(context, macro.data, topology.data, sampler)
	if not entrances.success:
		return _pipeline_fail("entrances", entrances.diagnostics)

	var selected = null
	for descriptor in entrances.data.surface_integration_descriptors:
		if str(descriptor.entrance_id) == entrance_id:
			selected = descriptor
			break
	if selected == null:
		return _pipeline_fail("entrances", ["Fixture entrance was not found: " + entrance_id])

	var neighbor_views: Array = []
	for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var neighbor_macro = MacroGenerator.generate(context, region + offset)
		if not neighbor_macro.success:
			return _pipeline_fail("neighbor-macro", neighbor_macro.diagnostics)
		var neighbor_topology = TopologyGenerator.generate(context, neighbor_macro.data, sampler)
		if not neighbor_topology.success:
			return _pipeline_fail("neighbor-topology", neighbor_topology.diagnostics)
		neighbor_views.append({
			"region_plan": neighbor_macro.data,
			"primary_topology": neighbor_topology.data,
		})

	var connectivity = ConnectivityGenerator.generate(
		context,
		macro.data,
		topology.data,
		entrances.data,
		neighbor_views
	)
	if not connectivity.success:
		return _pipeline_fail("connectivity", connectivity.diagnostics)
	var hooks = HookGenerator.generate(context, macro.data, connectivity.data)
	if not hooks.success:
		return _pipeline_fail("hooks", hooks.diagnostics)
	var finalized = RegionFinalizer.generate(context, macro.data, entrances.data, connectivity.data, hooks.data)
	if not finalized.success:
		return _pipeline_fail("finalization", finalized.diagnostics)
	var geometry = GeometryGenerator.generate(context, macro.data, finalized.data, neighbor_views)
	if not geometry.success:
		return _pipeline_fail("geometry", geometry.diagnostics)
	metrics["deterministic_generation_ms"] = _elapsed_ms(generation_started)

	var partition_started: int = Time.get_ticks_usec()
	var cell_config = PartitionConfig.new()
	var bounds := AABB(selected.surface_world_position - Vector3(32, 32, 32), Vector3(64, 64, 64))
	var surface_result = SurfacePlan.build(
		bounds,
		[selected],
		Vector2i(16, 16),
		entrances.fingerprint,
		cell_config
	)
	if not surface_result.success:
		return _pipeline_fail("surface-plan", surface_result.diagnostics)
	if surface_result.data.demand_handoffs.is_empty():
		return _pipeline_fail("surface-plan", ["Fixture produced no runtime demand handoff"])
	var handoff = surface_result.data.demand_handoffs[0]
	var expected_geometry_sources = GeometryGenerator.expected_provenance_sources(
		macro.data,
		finalized.data,
		neighbor_views
	)
	var partition_request = PartitionRequest.new(
		geometry.data,
		finalized.data,
		cell_config,
		handoff.cell_addresses,
		context,
		expected_geometry_sources
	)
	var partition = Partitioner.generate(partition_request)
	if not partition.success:
		return _pipeline_fail("partition", partition.diagnostics)
	metrics["surface_partition_ms"] = _elapsed_ms(partition_started)

	var extraction_total_ms: float = 0.0
	var extraction_max_ms: float = 0.0
	var mesh_realization_total_ms: float = 0.0
	var mesh_realization_max_ms: float = 0.0
	var collision_prepare_total_ms: float = 0.0
	var collision_prepare_max_ms: float = 0.0
	var collision_realization_total_ms: float = 0.0
	var collision_realization_max_ms: float = 0.0
	var mesh_memory_total: int = 0
	var mesh_memory_max: int = 0
	var vertex_total: int = 0
	var triangle_total: int = 0
	var sample_total: int = 0
	var cube_total: int = 0
	var provenance = partition.provenance

	for plan in partition.data.plans:
		var mesh_started: int = Time.get_ticks_usec()
		var voxel_request = VoxelRequest.new(plan, cell_config, provenance, 0.0, partition.data, context)
		var mesh_stage = VoxelMesher.build(voxel_request)
		var mesh_wall_ms: float = _elapsed_ms(mesh_started)
		if not mesh_stage.success:
			return _pipeline_fail("mesh", mesh_stage.diagnostics)
		var mesh_data = mesh_stage.data
		var extraction_ms: float = float(mesh_data.metrics.get("extraction_ms", mesh_wall_ms))
		extraction_total_ms += extraction_ms
		extraction_max_ms = maxf(extraction_max_ms, extraction_ms)
		var memory_bytes: int = int(mesh_data.metrics.get("memory_bytes", 0))
		mesh_memory_total += memory_bytes
		mesh_memory_max = maxi(mesh_memory_max, memory_bytes)
		vertex_total += int(mesh_data.metrics.get("vertex_count", mesh_data.vertices.size()))
		triangle_total += int(mesh_data.metrics.get("triangle_count", mesh_data.indices.size() / 3))
		sample_total += int(mesh_data.metrics.get("sample_count", 0))
		cube_total += int(mesh_data.metrics.get("cube_count", 0))

		var render_started: int = Time.get_ticks_usec()
		var realized: Dictionary = MeshBoundary.realize_main_thread(
			mesh_data,
			null,
			mesh_data.input_fingerprint
		)
		var render_ms: float = _elapsed_ms(render_started)
		if not bool(realized.get("success", false)):
			return _pipeline_fail("mesh-realization", realized.get("diagnostics", []))
		mesh_realization_total_ms += render_ms
		mesh_realization_max_ms = maxf(mesh_realization_max_ms, render_ms)

		var collision_prepare_started: int = Time.get_ticks_usec()
		var collision_stage = CollisionBuilder.prepare(
			mesh_data,
			provenance.fingerprint if provenance != null else ""
		)
		var collision_prepare_ms: float = _elapsed_ms(collision_prepare_started)
		if not collision_stage.success:
			return _pipeline_fail("collision-preparation", collision_stage.diagnostics)
		collision_prepare_total_ms += collision_prepare_ms
		collision_prepare_max_ms = maxf(collision_prepare_max_ms, collision_prepare_ms)

		var collision_realization_started: int = Time.get_ticks_usec()
		var collision_realized: Dictionary = CollisionBoundary.realize_main_thread(
			collision_stage.data,
			mesh_data.output_fingerprint
		)
		var collision_realization_ms: float = _elapsed_ms(collision_realization_started)
		if not bool(collision_realized.get("success", false)):
			return _pipeline_fail("collision-realization", collision_realized.get("diagnostics", []))
		collision_realization_total_ms += collision_realization_ms
		collision_realization_max_ms = maxf(collision_realization_max_ms, collision_realization_ms)

	metrics["profiled_cell_count"] = partition.data.plans.size()
	metrics["mesh_extraction_total_ms"] = extraction_total_ms
	metrics["mesh_extraction_cell_max_ms"] = extraction_max_ms
	metrics["mesh_realization_total_ms"] = mesh_realization_total_ms
	metrics["mesh_realization_cell_max_ms"] = mesh_realization_max_ms
	metrics["collision_prepare_total_ms"] = collision_prepare_total_ms
	metrics["collision_prepare_cell_max_ms"] = collision_prepare_max_ms
	metrics["collision_realization_total_ms"] = collision_realization_total_ms
	metrics["collision_realization_cell_max_ms"] = collision_realization_max_ms
	metrics["mesh_memory_total_bytes"] = mesh_memory_total
	metrics["mesh_memory_cell_max_bytes"] = mesh_memory_max
	metrics["vertex_total"] = vertex_total
	metrics["triangle_total"] = triangle_total
	metrics["sample_total"] = sample_total
	metrics["cube_total"] = cube_total
	metrics["staged_processing_total_ms"] = extraction_total_ms + collision_prepare_total_ms
	metrics["main_thread_realization_total_ms"] = mesh_realization_total_ms + collision_realization_total_ms

	var deterministic_fingerprint: String = (
		str(entrances.fingerprint)
		+ ":"
		+ str(geometry.fingerprint)
		+ ":"
		+ str(partition.data.fingerprint)
	)
	return {
		"success": true,
		"failures": [],
		"metrics": metrics,
		"deterministic_fingerprint": deterministic_fingerprint,
	}


static func _profile_controller_route(controller, entrance_id: String) -> Dictionary:
	var failures: Array[String] = []
	var scenarios: Array[Dictionary] = []
	var positions: Array[Dictionary] = []
	positions.append({
		"name": "surface_approach",
		"position": controller.last_bootstrap_surface_position + Vector3.UP * 3.0,
	})
	var required_cells: Array = controller.entrance_plans[entrance_id].cell_addresses
	var cell_size: Vector3 = controller.streamer.cell_size
	for index in range(required_cells.size()):
		var address = required_cells[index]
		positions.append({
			"name": "cave_cell_%02d" % index,
			"position": Vector3(address.coordinate) * cell_size + cell_size * 0.5,
		})
	positions.append({
		"name": "surface_return",
		"position": controller.last_bootstrap_surface_position + Vector3.UP * 3.0,
	})

	var observer_max_ms: float = 0.0
	var peak_active_owner_count: int = 0
	var peak_record_count: int = 0
	for entry in positions:
		var started: int = Time.get_ticks_usec()
		controller.update_player_position(entry["position"])
		var elapsed_ms: float = _elapsed_ms(started)
		observer_max_ms = maxf(observer_max_ms, elapsed_ms)
		var gate_open: bool = bool(controller.gate_is_open(entrance_id))
		if not gate_open:
			failures.append("controller route closed entrance gate at " + str(entry["name"]))
		var active_owner_count: int = int(controller.streamer.active_owner_count())
		peak_active_owner_count = maxi(peak_active_owner_count, active_owner_count)
		peak_record_count = maxi(peak_record_count, int(controller.streamer.records.size()))
		scenarios.append({
			"family": "controller_demand_route",
			"name": entry["name"],
			"position": entry["position"],
			"observer_update_ms": elapsed_ms,
			"gate_open": gate_open,
			"active_owner_count": active_owner_count,
			"record_count": controller.streamer.records.size(),
			"render_nodes": controller.render_nodes.size(),
			"collision_nodes": controller.collision_nodes.size(),
		})

	return {
		"failures": failures,
		"scenarios": scenarios,
		"metrics": {
			"controller_route_observer_update_max_ms": observer_max_ms,
			"controller_route_peak_active_owner_count": peak_active_owner_count,
			"controller_route_peak_record_count": peak_record_count,
			"realized_render_nodes": controller.render_nodes.size(),
			"realized_collision_nodes": controller.collision_nodes.size(),
			"controller_stale_result_count": controller.streamer.stale_result_count,
		},
	}


static func _profile_streaming_policy() -> Dictionary:
	var failures: Array[String] = []
	var scenarios: Array[Dictionary] = []
	var streamer = Streamer.new("world:perf001", "manifest:perf001")
	var route: Array[Dictionary] = [
		{"name": "surface_approach", "position": Vector3(0.25, 0.25, 0.25)},
		{"name": "entrance_transition", "position": Vector3(32.25, -0.25, 0.25)},
		{"name": "cave_shallow", "position": Vector3(32.25, -32.25, 0.25)},
		{"name": "cave_mid", "position": Vector3(64.25, -64.25, 32.25)},
		{"name": "cave_deep", "position": Vector3(96.25, -96.25, 64.25)},
		{"name": "negative_coordinate", "position": Vector3(-32.25, -64.25, -32.25)},
		{"name": "surface_return", "position": Vector3(0.25, 0.25, 0.25)},
	]
	var observer_max_ms: float = 0.0
	var peak_geometry: int = 0
	var peak_render: int = 0
	var peak_collision: int = 0
	var peak_active: int = 0
	var peak_records: int = 0

	for entry in route:
		var started: int = Time.get_ticks_usec()
		streamer.update_observer(entry["position"], "perf-route")
		var elapsed_ms: float = _elapsed_ms(started)
		observer_max_ms = maxf(observer_max_ms, elapsed_ms)
		_release_unowned_cells(streamer)
		var snapshot: Dictionary = _streamer_snapshot(streamer)
		peak_geometry = maxi(peak_geometry, int(snapshot["geometry_cells"]))
		peak_render = maxi(peak_render, int(snapshot["render_cells"]))
		peak_collision = maxi(peak_collision, int(snapshot["collision_cells"]))
		peak_active = maxi(peak_active, int(snapshot["active_owner_count"]))
		peak_records = maxi(peak_records, int(snapshot["record_count"]))
		scenarios.append({
			"family": "streaming_policy_demand_only",
			"name": entry["name"],
			"position": entry["position"],
			"observer_cell": streamer.observer_cell(entry["position"]),
			"observer_update_ms": elapsed_ms,
			"residency": snapshot,
		})

	if streamer.observer_cell(Vector3(-32.25, -64.25, -32.25)) != Vector3i(-2, -3, -2):
		failures.append("negative-coordinate observer addressing changed during profiling")
	return {
		"failures": failures,
		"scenarios": scenarios,
		"metrics": {
			"observer_update_max_ms": observer_max_ms,
			"resident_geometry_cells": peak_geometry,
			"resident_render_cells": peak_render,
			"resident_collision_cells": peak_collision,
			"streaming_peak_active_owner_count": peak_active,
			"streaming_peak_record_count": peak_records,
			"streaming_released_cells": streamer.released_count,
			"streaming_stale_result_count": streamer.stale_result_count,
		},
	}


static func _streamer_snapshot(streamer) -> Dictionary:
	var definition_cells: int = 0
	var geometry_cells: int = 0
	var render_cells: int = 0
	var collision_cells: int = 0
	var simulation_cells: int = 0
	for record in streamer.records.values():
		if record.demand_count("definition") > 0:
			definition_cells += 1
		if record.demand_count("voxel_geometry") > 0:
			geometry_cells += 1
		if record.demand_count("render") > 0:
			render_cells += 1
		if record.demand_count("collision") > 0:
			collision_cells += 1
		if record.demand_count("simulation") > 0:
			simulation_cells += 1
	return {
		"definition_cells": definition_cells,
		"geometry_cells": geometry_cells,
		"render_cells": render_cells,
		"collision_cells": collision_cells,
		"simulation_cells": simulation_cells,
		"active_owner_count": streamer.active_owner_count(),
		"record_count": streamer.records.size(),
		"queued_count": streamer.queued_count,
		"released_count": streamer.released_count,
	}


static func _release_unowned_cells(streamer) -> void:
	for record in streamer.records.values():
		if record.demands.is_empty() and record.state == "release_pending":
			streamer.release_cell(record.cell_address)


static func _pipeline_fail(stage: String, diagnostics: Array) -> Dictionary:
	var failures: Array[String] = []
	for diagnostic in diagnostics:
		failures.append(stage + ": " + str(diagnostic))
	return {
		"success": false,
		"failures": failures,
		"metrics": {},
		"deterministic_fingerprint": "",
	}


static func _merge_metrics(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[key] = source[key]


static func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0
