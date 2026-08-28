extends RefCounted
class_name UnderworldGenerationDebugReportBuilder

const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const MacroRegionGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const PrimaryTopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const EntranceGenerator := preload("res://worldgen/underworld/entrance_generator.gd")
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
	return _result(report)


static func _result(report) -> Dictionary:
	return {
		"success": report.is_success(),
		"report": report.to_dictionary(),
		"json": report.to_json(),
		"text": report.to_text(),
	}
