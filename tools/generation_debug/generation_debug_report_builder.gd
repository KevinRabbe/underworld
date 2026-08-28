extends RefCounted
class_name UnderworldGenerationDebugReportBuilder

const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const MacroRegionGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const PrimaryTopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const DebugReport := preload("res://tools/generation_debug/generation_debug_report.gd")


static func build(world_seed: int, region_coord: Vector2i) -> Dictionary:
	var context = WorldGenerationContext.new(world_seed)
	var report = DebugReport.new(context, region_coord, {
		"macro_region_size": MacroRegionGenerator.REGION_SIZE,
		"macro_region_depth": MacroRegionGenerator.REGION_DEPTH,
		"macro_network_candidate_count": MacroRegionGenerator.NETWORK_CANDIDATE_COUNT,
		"macro_special_candidate_count": MacroRegionGenerator.SPECIAL_CANDIDATE_COUNT,
		"topology_child_candidate_count": PrimaryTopologyGenerator.CHILD_CANDIDATE_COUNT,
		"topology_region_margin": PrimaryTopologyGenerator.REGION_MARGIN,
		"topology_boundary_distance": PrimaryTopologyGenerator.BOUNDARY_DISTANCE,
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
		}
	report.record_stage(macro_stage, 0, macro_parameters)
	if not macro_stage.success:
		return _result(report)

	var topology_stage = PrimaryTopologyGenerator.generate(context, macro_stage.data)
	var topology_parameters: Dictionary = {}
	if topology_stage.success and topology_stage.data != null:
		topology_parameters = topology_stage.data.topology_metrics.duplicate(true)
	report.record_stage(topology_stage, 0, topology_parameters)
	return _result(report)


static func _result(report) -> Dictionary:
	return {
		"success": report.is_success(),
		"report": report.to_dictionary(),
		"json": report.to_json(),
		"text": report.to_text(),
	}
