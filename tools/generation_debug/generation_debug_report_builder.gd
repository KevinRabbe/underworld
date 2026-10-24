extends RefCounted
class_name UnderworldGenerationDebugReportBuilder

const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const StageResult := preload("res://worldgen/pipeline/generation_stage_result.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const MacroRegionGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const PrimaryTopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const EntranceGenerator := preload("res://worldgen/underworld/entrance_generator.gd")
const ConnectivityGenerator := preload("res://worldgen/underworld/secondary_connectivity_generator.gd")
const DebugReport := preload("res://tools/generation_debug/generation_debug_report.gd")


static func build(world_seed: int, region_coord: Vector2i) -> Dictionary:
	var context = WorldGenerationContext.new(world_seed)
	var surface_sampler = SurfaceSampler.new(world_seed)
	var report = DebugReport.new(context, region_coord, {
		"macro_region_size": MacroRegionGenerator.REGION_SIZE,
		"macro_region_depth": MacroRegionGenerator.REGION_DEPTH,
		"macro_network_candidate_count": MacroRegionGenerator.NETWORK_CANDIDATE_COUNT,
		"macro_special_candidate_count": MacroRegionGenerator.SPECIAL_CANDIDATE_COUNT,
		"macro_entrance_candidate_count": MacroRegionGenerator.ENTRANCE_CANDIDATE_COUNT,
		"topology_child_candidate_count": PrimaryTopologyGenerator.CHILD_CANDIDATE_COUNT,
		"topology_region_margin": PrimaryTopologyGenerator.REGION_MARGIN,
		"topology_boundary_distance": PrimaryTopologyGenerator.BOUNDARY_DISTANCE,
		"entrance_surface_jitter_radius": EntranceGenerator.SURFACE_JITTER_RADIUS,
		"connectivity_min_local_length": ConnectivityGenerator.MIN_LOCAL_LENGTH,
		"connectivity_max_cross_region_length": ConnectivityGenerator.MAX_CROSS_REGION_LENGTH,
		"connectivity_min_cross_region_score": ConnectivityGenerator.MIN_CROSS_REGION_SCORE,
		"connectivity_max_secondary_degree": ConnectivityGenerator.MAX_SECONDARY_DEGREE,
	})

	var macro_stage = MacroRegionGenerator.generate(context, region_coord)
	var macro_parameters: Dictionary = {}
	if macro_stage.success and macro_stage.data != null:
		var plan = macro_stage.data
		macro_parameters = {
			"profile_bias": [plan.profile_bias.x, plan.profile_bias.y, plan.profile_bias.z],
			"topology_tendencies": plan.topology_tendencies.duplicate(true),
			"network_candidate_slots": plan.network_candidate_slots.duplicate(),
			"special_candidate_slots": plan.special_candidate_slots.duplicate(),
			"entrance_candidate_slots": plan.entrance_candidate_slots.duplicate(),
		}
	report.record_stage(macro_stage, 0, macro_parameters)
	if not macro_stage.success:
		return _result(report)

	var topology_stage = PrimaryTopologyGenerator.generate(
		context,
		macro_stage.data,
		surface_sampler
	)
	var topology_parameters: Dictionary = {}
	if topology_stage.success and topology_stage.data != null:
		topology_parameters = topology_stage.data.topology_metrics.duplicate(true)
	report.record_stage(topology_stage, 0, topology_parameters)
	if not topology_stage.success:
		return _result(report)

	var entrance_stage = EntranceGenerator.generate(
		context,
		macro_stage.data,
		topology_stage.data,
		surface_sampler
	)
	var entrance_parameters: Dictionary = {}
	if entrance_stage.success and entrance_stage.data != null:
		entrance_parameters = entrance_stage.data.entrance_metrics.duplicate(true)
	report.record_stage(entrance_stage, 0, entrance_parameters)
	if not entrance_stage.success:
		return _result(report)

	var neighbor_build: Dictionary = _build_neighbor_views(
		context,
		surface_sampler,
		region_coord
	)
	var connectivity_parameters: Dictionary = {
		"neighbor_view_count": neighbor_build.get("views", []).size(),
		"neighbor_region_coords": neighbor_build.get("coords", []).duplicate(true),
	}
	if not bool(neighbor_build.get("success", false)):
		var connectivity_failure = StageResult.fail(
			"secondary_connectivity",
			neighbor_build.get("diagnostics", [])
		)
		report.record_stage(connectivity_failure, 0, connectivity_parameters)
		return _result(report)

	var connectivity_stage = ConnectivityGenerator.generate(
		context,
		macro_stage.data,
		topology_stage.data,
		entrance_stage.data,
		neighbor_build["views"]
	)
	if connectivity_stage.success and connectivity_stage.data != null:
		var metrics: Dictionary = connectivity_stage.data.connectivity_metrics.duplicate(true)
		for key in metrics.keys():
			connectivity_parameters[key] = metrics[key]
	report.record_stage(connectivity_stage, 0, connectivity_parameters)
	return _result(report)


static func _build_neighbor_views(context, surface_sampler, region_coord: Vector2i) -> Dictionary:
	var views: Array = []
	var coords: Array = []
	for offset in [
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(0, -1),
		Vector2i(0, 1),
	]:
		var coord: Vector2i = region_coord + offset
		var macro_stage = MacroRegionGenerator.generate(context, coord)
		if not macro_stage.success:
			return _neighbor_failure(
				views,
				coords,
				coord,
				"macro_region",
				macro_stage.diagnostics
			)
		var topology_stage = PrimaryTopologyGenerator.generate(
			context,
			macro_stage.data,
			surface_sampler
		)
		if not topology_stage.success:
			return _neighbor_failure(
				views,
				coords,
				coord,
				"primary_topology",
				topology_stage.diagnostics
			)
		views.append({
			"region_plan": macro_stage.data,
			"primary_topology": topology_stage.data,
		})
		coords.append([coord.x, coord.y])
	return {
		"success": true,
		"views": views,
		"coords": coords,
		"diagnostics": [],
	}


static func _neighbor_failure(
	views: Array,
	coords: Array,
	coord: Vector2i,
	stage_name: String,
	diagnostics: Array
) -> Dictionary:
	var failures: Array[String] = []
	for diagnostic in diagnostics:
		failures.append(
			"neighbor=(%d,%d) stage=%s: %s" % [
				coord.x,
				coord.y,
				stage_name,
				str(diagnostic),
			]
		)
	return {
		"success": false,
		"views": views,
		"coords": coords,
		"diagnostics": failures,
	}


static func _result(report) -> Dictionary:
	return {
		"success": report.is_success(),
		"report": report.to_dictionary(),
		"json": report.to_json(),
		"text": report.to_text(),
	}
