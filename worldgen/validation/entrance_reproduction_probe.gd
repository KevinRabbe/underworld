extends RefCounted
class_name UnderworldEntranceReproductionProbe

const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const MacroRegionGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const PrimaryTopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const EntranceGenerator := preload("res://worldgen/underworld/entrance_generator.gd")


static func build(world_seed: int, region_coord: Vector2i) -> Dictionary:
	var context = WorldGenerationContext.new(world_seed)
	var sampler = SurfaceSampler.new(world_seed)
	var macro = MacroRegionGenerator.generate(context, region_coord)
	if not macro.success:
		return _failure("macro_region", macro.diagnostics)
	var topology = PrimaryTopologyGenerator.generate(context, macro.data, sampler)
	if not topology.success:
		return _failure("primary_topology", topology.diagnostics)
	var entrances = EntranceGenerator.generate(context, macro.data, topology.data, sampler)
	if not entrances.success:
		return _failure("entrance_generation", entrances.diagnostics)
	return {
		"success": true,
		"fingerprint": entrances.fingerprint,
		"macro_fingerprint": macro.fingerprint,
		"topology_fingerprint": topology.fingerprint,
		"metrics": entrances.data.entrance_metrics,
		"diagnostics": [],
	}


static func _failure(stage: String, diagnostics: Array) -> Dictionary:
	return {
		"success": false,
		"fingerprint": "",
		"stage": stage,
		"diagnostics": diagnostics,
	}
