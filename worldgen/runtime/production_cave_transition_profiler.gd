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
const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")

const OUTSIDE_PROBE_MAX_UPDATES: int = 6


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
	metrics["bootstrap_executor_present_after_bootstrap"] = controller.streamer.executor != null
	metrics["bootstrap_executor_live_queue_depth_after_bootstrap"] = _executor_queue_depth(controller.streamer.executor)
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
	metrics["cold_time_to_gate_ready_ms"] = bootstrap_ms + approach_ms
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
				"family": "warm_handoff",
				"name": sample["name"],
				"observer_update_ms": sample_ms,
				"gate_open": controller.gate_is_open(entrance_id),
				"render_cells": controller.render_nodes.size(),
				"collision_cells": controller.collision_nodes.size(),
			})
	metrics["warm_reentry_observer_max_ms"] = warm_max_ms
	metrics["warm_reentry_observer_total_ms"] = warm_total_ms
	metrics["warm_reentry_sample_count"] = warm_samples

	var outside_probe: Dictionary = _profile_outside_handoff(
		controller,
		handoff,
		approach_position
	)
	var outside_metrics: Dictionary = outside_probe.get("metrics", {})
	var outside_keys: Array = outside_metrics.keys()
	outside_keys.sort()
	for key in outside_keys:
		metrics[str(key)] = outside_metrics[key]
	var outside_scenarios_variant: Variant = outside_probe.get("scenarios", [])
	if outside_scenarios_variant is Array:
		for scenario in outside_scenarios_variant:
			if scenario is Dictionary:
				scenarios.append(scenario)
	var outside_hitch_ms: float = float(metrics.get("outside_probe_update_max_ms", 0.0))
	metrics["worst_transition_hitch_ms"] = maxf(bootstrap_ms, outside_hitch_ms)

	controller.free()
	surface.free()
	return _report(failures.is_empty(), failures, metrics, scenarios, route)


static func _profile_outside_handoff(controller, handoff, approach_position: Vector3) -> Dictionary:
	var metrics: Dictionary = {
		"outside_probe_available": false,
		"outside_probe_ready": false,
		"outside_probe_update_sample_count": 0,
		"outside_probe_update_total_ms": 0.0,
		"outside_probe_update_max_ms": 0.0,
		"outside_probe_time_to_ready_ms": 0.0,
	}
	var scenarios: Array[Dictionary] = []
	if controller == null or controller.streamer == null or handoff == null:
		return {"metrics": metrics, "scenarios": scenarios}
	if handoff.cell_addresses.is_empty():
		return {"metrics": metrics, "scenarios": scenarios}

	var target = _select_outside_handoff_address(handoff)
	if target == null:
		return {"metrics": metrics, "scenarios": scenarios}
	var target_key: String = target.canonical_text()
	var cell_size: Vector3 = controller.streamer.cell_size
	var target_position: Vector3 = Vector3(target.coordinate) * cell_size + cell_size * 0.5
	var executor = controller.streamer.executor
	var stale_before: int = int(controller.streamer.stale_result_count)
	var queued_cumulative_before: int = int(controller.streamer.queued_count)
	var render_nodes_before: int = int(controller.render_nodes.size())
	var collision_nodes_before: int = int(controller.collision_nodes.size())
	metrics["outside_probe_available"] = true
	metrics["outside_probe_address"] = target_key
	metrics["outside_probe_position"] = target_position
	metrics["outside_probe_executor_present"] = executor != null
	metrics["outside_probe_executor_live_queue_depth_before"] = _executor_queue_depth(executor)
	metrics["outside_probe_streamer_queued_count_cumulative_before"] = queued_cumulative_before
	metrics["outside_probe_stale_result_count_before"] = stale_before
	metrics["outside_probe_render_nodes_before"] = render_nodes_before
	metrics["outside_probe_collision_nodes_before"] = collision_nodes_before

	var ready: bool = false
	var update_total_ms: float = 0.0
	var update_max_ms: float = 0.0
	var sample_count: int = 0
	var source_bound: bool = false
	var provenance_bound: bool = false
	var render_ready: bool = false
	var collision_ready: bool = false
	for sample_index in range(OUTSIDE_PROBE_MAX_UPDATES):
		var queue_before: int = _executor_queue_depth(executor)
		var sample_started: int = Time.get_ticks_usec()
		controller.update_player_position(target_position)
		var sample_ms: float = _elapsed_ms(sample_started)
		var queue_after: int = _executor_queue_depth(controller.streamer.executor)
		executor = controller.streamer.executor
		update_total_ms += sample_ms
		update_max_ms = maxf(update_max_ms, sample_ms)
		sample_count += 1
		var record = controller.streamer.records.get(target_key, null)
		source_bound = record != null and not str(record.source_fingerprint).is_empty()
		provenance_bound = record != null and not str(record.provenance_fingerprint).is_empty()
		render_ready = record != null and bool(record.readiness.get("render", false)) and controller.render_nodes.has(target_key)
		collision_ready = (
			record != null
			and bool(record.readiness.get("collision", false))
			and record.collision_handle != null
			and controller.collision_nodes.has(target_key)
		)
		ready = render_ready and collision_ready
		scenarios.append({
			"family": "outside_handoff_streaming",
			"name": "outside_handoff_update_%02d" % sample_index,
			"address": target_key,
			"observer_update_ms": sample_ms,
			"executor_live_queue_before": queue_before,
			"executor_live_queue_after": queue_after,
			"source_bound": source_bound,
			"provenance_bound": provenance_bound,
			"render_ready": render_ready,
			"collision_ready": collision_ready,
			"render_cells": controller.render_nodes.size(),
			"collision_cells": controller.collision_nodes.size(),
			"stale_result_count": controller.streamer.stale_result_count,
		})
		if ready:
			break

	metrics["outside_probe_ready"] = ready
	metrics["outside_probe_source_bound"] = source_bound
	metrics["outside_probe_provenance_bound"] = provenance_bound
	metrics["outside_probe_render_ready"] = render_ready
	metrics["outside_probe_collision_ready"] = collision_ready
	metrics["outside_probe_update_sample_count"] = sample_count
	metrics["outside_probe_update_total_ms"] = update_total_ms
	metrics["outside_probe_update_max_ms"] = update_max_ms
	metrics["outside_probe_time_to_ready_ms"] = update_total_ms if ready else 0.0
	metrics["outside_probe_executor_live_queue_depth_after"] = _executor_queue_depth(executor)
	metrics["outside_probe_streamer_queued_count_cumulative_after"] = int(controller.streamer.queued_count)
	metrics["outside_probe_streamer_queued_count_cumulative_delta"] = int(controller.streamer.queued_count) - queued_cumulative_before
	metrics["outside_probe_stale_result_count_after"] = int(controller.streamer.stale_result_count)
	metrics["outside_probe_stale_result_count_delta"] = int(controller.streamer.stale_result_count) - stale_before
	metrics["outside_probe_render_nodes_after"] = int(controller.render_nodes.size())
	metrics["outside_probe_collision_nodes_after"] = int(controller.collision_nodes.size())
	metrics["outside_probe_render_node_delta"] = int(controller.render_nodes.size()) - render_nodes_before
	metrics["outside_probe_collision_node_delta"] = int(controller.collision_nodes.size()) - collision_nodes_before

	if ready:
		var warm_render_count_before: int = int(controller.render_nodes.size())
		var warm_collision_count_before: int = int(controller.collision_nodes.size())
		var return_started: int = Time.get_ticks_usec()
		controller.update_player_position(approach_position)
		var surface_return_ms: float = _elapsed_ms(return_started)
		var reentry_started: int = Time.get_ticks_usec()
		controller.update_player_position(target_position)
		var reentry_ms: float = _elapsed_ms(reentry_started)
		metrics["outside_probe_warm_surface_return_ms"] = surface_return_ms
		metrics["outside_probe_warm_reentry_ms"] = reentry_ms
		metrics["outside_probe_warm_hitch_max_ms"] = maxf(surface_return_ms, reentry_ms)
		metrics["outside_probe_warm_render_node_delta"] = int(controller.render_nodes.size()) - warm_render_count_before
		metrics["outside_probe_warm_collision_node_delta"] = int(controller.collision_nodes.size()) - warm_collision_count_before
		scenarios.append({
			"family": "outside_handoff_streaming",
			"name": "outside_handoff_warm_surface_return",
			"observer_update_ms": surface_return_ms,
			"render_cells": controller.render_nodes.size(),
			"collision_cells": controller.collision_nodes.size(),
		})
		scenarios.append({
			"family": "outside_handoff_streaming",
			"name": "outside_handoff_warm_reentry",
			"address": target_key,
			"observer_update_ms": reentry_ms,
			"render_ready": _target_render_ready(controller, target_key),
			"collision_ready": _target_collision_ready(controller, target_key),
			"render_cells": controller.render_nodes.size(),
			"collision_cells": controller.collision_nodes.size(),
			"stale_result_count": controller.streamer.stale_result_count,
		})

	return {"metrics": metrics, "scenarios": scenarios}


static func _select_outside_handoff_address(handoff):
	var handoff_keys: Dictionary = {}
	var addresses: Array = handoff.cell_addresses.duplicate()
	addresses.sort_custom(func(a, b): return a.canonical_text() < b.canonical_text())
	for address in addresses:
		handoff_keys[address.canonical_text()] = true
	var offsets: Array[Vector3i] = [
		Vector3i(0, -1, 0),
		Vector3i(1, 0, 0),
		Vector3i(0, 0, 1),
		Vector3i(-1, 0, 0),
		Vector3i(0, 0, -1),
		Vector3i(1, -1, 0),
		Vector3i(0, -1, 1),
		Vector3i(-1, -1, 0),
		Vector3i(0, -1, -1),
	]
	for address in addresses:
		for offset in offsets:
			var coordinate: Vector3i = address.coordinate + offset
			if coordinate.y >= 0:
				continue
			var candidate = Address.new(coordinate)
			if not handoff_keys.has(candidate.canonical_text()):
				return candidate
	return null


static func _target_render_ready(controller, target_key: String) -> bool:
	var record = controller.streamer.records.get(target_key, null)
	return record != null and bool(record.readiness.get("render", false)) and controller.render_nodes.has(target_key)


static func _target_collision_ready(controller, target_key: String) -> bool:
	var record = controller.streamer.records.get(target_key, null)
	return (
		record != null
		and bool(record.readiness.get("collision", false))
		and record.collision_handle != null
		and controller.collision_nodes.has(target_key)
	)


static func _executor_queue_depth(executor) -> int:
	if executor == null or not executor.has_method("queued_job_count"):
		return -1
	return int(executor.call("queued_job_count"))


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
		"budget_state": "pending post-streaming production measurement",
		"measurement_semantics": {
			"cold_controller_bootstrap": "production bootstrap_generated_entrance synchronous wall time",
			"blocking_frame_hitch": "cold synchronous bootstrap wall time on the currently accepted production route",
			"bootstrap_executor_queue_wait": "zero on the accepted baseline bootstrap path because VoxelMesher/CollisionBuilder execute directly; executor presence is reported separately when a later production seam supplies one",
			"surface_initial_sync": "SurfaceChunkStreamer.generate_initial center-chunk synchronous wall time",
			"warm_reentry": "observer/gate bookkeeping after cold entrance handoff cells are realized",
			"outside_handoff_streaming": "repeated synchronous wall-time samples around one deterministic underworld cell outside the initial entrance handoff; each update is a player-visible hitch candidate",
			"executor_live_queue_depth": "live queued_job_count() when the production executor exposes it; -1 means no compatible executor is present",
			"streamer_queued_count_cumulative": "historical submission telemetry from UnderworldRuntimeStreamer; never interpreted as live queue depth",
		},
	}


static func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0
