extends RefCounted
class_name ProductionCaveTransitionProfiler

const ExistingProfiler := preload("res://worldgen/runtime/runtime_cave_profiler.gd")
const Controller := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const RouteSelector := preload("res://worldgen/surface/natural_entrance_route_selector.gd")
const SurfaceWorld := preload("res://world/runtime/streaming/surface_chunk_streamer.gd")
const WorldSettings := preload("res://world/runtime/config/world_settings.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const WorldId := preload("res://worldgen/identity/world_id.gd")
const Manifest := preload("res://worldgen/versioning/generator_manifest.gd")


static func run(world_seed: int = 12345) -> Dictionary:
	var failures: Array[String] = []
	var metrics: Dictionary = {}
	var scenarios: Array[Dictionary] = []

	var settings = WorldSettings.new()
	settings.world_seed = world_seed
	var preferred_start := Vector3(
		float(settings.chunk_size) * 0.5,
		0.0,
		float(settings.chunk_size) * 0.5
	)

	var route_started: int = Time.get_ticks_usec()
	var selection: Dictionary = RouteSelector.select(world_seed, preferred_start)
	metrics["route_selection_ms"] = _elapsed_ms(route_started)
	if not bool(selection.get("success", false)):
		for diagnostic in selection.get("diagnostics", []):
			failures.append("route selection: " + str(diagnostic))
		return _report(false, failures, metrics, scenarios, {})
	var route_variant: Variant = selection.get("route", null)
	if not route_variant is Dictionary:
		failures.append("route selection did not return a route Dictionary")
		return _report(false, failures, metrics, scenarios, {})
	var route: Dictionary = route_variant
	var region_variant: Variant = route.get("region_coord", null)
	var entrance_id: String = str(route.get("entrance_id", ""))
	var spawn_variant: Variant = route.get("recommended_spawn_xz", null)
	if not region_variant is Vector2i or entrance_id.is_empty() or not spawn_variant is Vector3:
		failures.append("selected production route is missing generated identity or spawn")
		return _report(false, failures, metrics, scenarios, route)
	var region: Vector2i = region_variant
	var spawn_xz: Vector3 = spawn_variant

	var surface = SurfaceWorld.new()
	var delta_store = WorldDeltaStore.new()
	if not surface.bind_world_delta_store(delta_store):
		failures.append("surface profiler could not bind WorldDeltaStore")
		surface.free()
		return _report(false, failures, metrics, scenarios, route)
	surface.configure(settings)
	var surface_started: int = Time.get_ticks_usec()
	surface.generate_initial(spawn_xz)
	metrics["surface_initial_sync_ms"] = _elapsed_ms(surface_started)
	metrics["surface_reported_generation_ms"] = float(surface.last_generation_ms)
	metrics["surface_reported_chunk_build_ms"] = float(surface.last_chunk_build_ms)
	metrics["surface_initial_chunk_count"] = int(surface.chunks.size())
	var surface_height: float = surface.get_height_at_world(spawn_xz.x, spawn_xz.z)
	var approach_position := Vector3(spawn_xz.x, surface_height + 3.0, spawn_xz.z)

	var staged: Dictionary = ExistingProfiler._profile_pipeline(world_seed, region, entrance_id)
	if not bool(staged.get("success", false)):
		for diagnostic in staged.get("failures", []):
			failures.append("staged production route: " + str(diagnostic))
		surface.free()
		return _report(false, failures, metrics, scenarios, route)
	var staged_metrics: Dictionary = staged.get("metrics", {})
	var staged_keys: Array = staged_metrics.keys()
	staged_keys.sort()
	for key in staged_keys:
		metrics["staged_" + str(key)] = staged_metrics[key]

	var controller = Controller.new()
	controller.configure(
		WorldId.from_seed(world_seed).value(),
		Manifest.foundation_default().manifest_id()
	)
	var bootstrap_started: int = Time.get_ticks_usec()
	var bootstrap_diagnostics: Array[String] = controller.bootstrap_generated_entrance(
		world_seed,
		region,
		entrance_id
	)
	var bootstrap_ms: float = _elapsed_ms(bootstrap_started)
	metrics["cold_controller_bootstrap_ms"] = bootstrap_ms
	metrics["blocking_frame_hitch_ms"] = bootstrap_ms
	metrics["bootstrap_executor_queue_wait_ms"] = 0.0
	metrics["bootstrap_executor_job_count"] = 0
	if not bootstrap_diagnostics.is_empty():
		for diagnostic in bootstrap_diagnostics:
			failures.append("production controller bootstrap: " + str(diagnostic))
		controller.free()
		surface.free()
		return _report(false, failures, metrics, scenarios, route)

	var handoff = controller.entrance_plans.get(entrance_id, null)
	if handoff == null:
		failures.append("production controller did not register selected entrance handoff")
	else:
		metrics["entrance_required_cell_count"] = int(handoff.cell_addresses.size())
	metrics["realized_render_cell_count"] = int(controller.render_nodes.size())
	metrics["realized_collision_cell_count"] = int(controller.collision_nodes.size())
	metrics["streamer_record_count"] = int(controller.streamer.records.size())
	metrics["streamer_active_owner_count"] = int(controller.streamer.active_owner_count())
	var surface_ms: float = maxf(float(metrics.get("surface_initial_sync_ms", 0.0)), 0.001)
	metrics["cold_cave_to_surface_ratio"] = bootstrap_ms / surface_ms

	var approach_started: int = Time.get_ticks_usec()
	controller.update_player_position(approach_position)
	var approach_ms: float = _elapsed_ms(approach_started)
	var gate_open: bool = controller.gate_is_open(entrance_id)
	metrics["approach_observer_update_ms"] = approach_ms
	metrics["approach_gate_open"] = gate_open
	if not gate_open:
		failures.append("production entrance gate is not open after cold bootstrap at approach")

	var warm_max_ms: float = 0.0
	var warm_total_ms: float = 0.0
	var warm_samples: int = 0
	if handoff != null and not handoff.cell_addresses.is_empty():
		var cell_size: Vector3 = controller.streamer.cell_size
		var first_address = handoff.cell_addresses[0]
		var cave_position: Vector3 = Vector3(first_address.coordinate) * cell_size + cell_size * 0.5
		for sample in [
			{"name": "warm_cave_entry", "position": cave_position},
			{"name": "warm_surface_return", "position": approach_position},
			{"name": "warm_cave_reentry", "position": cave_position},
		]:
			var sample_started: int = Time.get_ticks_usec()
			controller.update_player_position(sample["position"])
			var sample_ms: float = _elapsed_ms(sample_started)
			warm_max_ms = maxf(warm_max_ms, sample_ms)
			warm_total_ms += sample_ms
			warm_samples += 1
			scenarios.append({
				"name": sample["name"],
				"observer_update_ms": sample_ms,
				"gate_open": controller.gate_is_open(entrance_id),
				"render_cells": controller.render_nodes.size(),
				"collision_cells": controller.collision_nodes.size(),
			})
	metrics["warm_reentry_observer_max_ms"] = warm_max_ms
	metrics["warm_reentry_observer_total_ms"] = warm_total_ms
	metrics["warm_reentry_sample_count"] = warm_samples

	controller.free()
	surface.free()
	return _report(failures.is_empty(), failures, metrics, scenarios, route)


static func _report(
	success: bool,
	failures: Array[String],
	metrics: Dictionary,
	scenarios: Array[Dictionary],
	route: Dictionary
) -> Dictionary:
	return {
		"success": success,
		"failures": failures.duplicate(),
		"metrics": metrics.duplicate(true),
		"scenarios": scenarios.duplicate(true),
		"route": route.duplicate(true),
		"measurement_semantics": {
			"cold_controller_bootstrap": "production bootstrap_generated_entrance synchronous wall time",
			"blocking_frame_hitch": "same synchronous bootstrap wall time because current production startup does not yield or enqueue bootstrap jobs",
			"bootstrap_executor_queue_wait": "zero by construction on current production bootstrap path; VoxelMesher/CollisionBuilder execute directly",
			"surface_initial_sync": "SurfaceChunkStreamer.generate_initial center-chunk synchronous wall time",
			"warm_reentry": "observer/gate bookkeeping after all cold bootstrap cells are already realized",
		},
	}


static func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0
