extends RefCounted
class_name UnderworldTopologyReproductionProbe

const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const MacroRegionGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const PrimaryTopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")


static func build(world_seed: int, region_coord: Vector2i) -> Dictionary:
	var context = WorldGenerationContext.new(world_seed)
	var macro_result = MacroRegionGenerator.generate(context, region_coord)
	if macro_result == null:
		return {
			"success": false,
			"fingerprint": "",
			"macro_fingerprint": "",
			"diagnostics": ["macro_region stage returned null"],
		}
	if not macro_result.success:
		return {
			"success": false,
			"fingerprint": "",
			"macro_fingerprint": "",
			"diagnostics": macro_result.diagnostics,
		}

	var topology_result = PrimaryTopologyGenerator.generate(context, macro_result.data)
	if topology_result == null:
		return {
			"success": false,
			"fingerprint": "",
			"macro_fingerprint": macro_result.fingerprint,
			"diagnostics": ["primary_topology stage returned null"],
		}
	if not topology_result.success:
		return {
			"success": false,
			"fingerprint": "",
			"macro_fingerprint": macro_result.fingerprint,
			"diagnostics": topology_result.diagnostics,
		}

	return {
		"success": true,
		"fingerprint": topology_result.fingerprint,
		"macro_fingerprint": macro_result.fingerprint,
		"diagnostics": [],
		"metrics": topology_result.data.topology_metrics,
	}
