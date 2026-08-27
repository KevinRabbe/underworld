extends RefCounted
class_name UnderworldSecondaryConnectivityReproductionProbe

const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const MacroRegionGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const PrimaryTopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const EntranceGenerator := preload("res://worldgen/underworld/entrance_generator.gd")
const ConnectivityGenerator := preload("res://worldgen/underworld/secondary_connectivity_generator.gd")


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

	var neighbor_views: Array = []
	for offset in [
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(0, -1),
		Vector2i(0, 1),
	]:
		var neighbor_macro = MacroRegionGenerator.generate(context, region_coord + offset)
		if not neighbor_macro.success:
			return _failure("neighbor_macro_region", neighbor_macro.diagnostics)
		var neighbor_topology = PrimaryTopologyGenerator.generate(
			context,
			neighbor_macro.data,
			sampler
		)
		if not neighbor_topology.success:
			return _failure("neighbor_primary_topology", neighbor_topology.diagnostics)
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
		return _failure("secondary_connectivity", connectivity.diagnostics)

	return {
		"success": true,
		"fingerprint": connectivity.fingerprint,
		"macro_fingerprint": macro.fingerprint,
		"topology_fingerprint": topology.fingerprint,
		"entrance_fingerprint": entrances.fingerprint,
		"metrics": connectivity.data.connectivity_metrics,
		"diagnostics": [],
	}


static func _failure(stage: String, diagnostics: Array) -> Dictionary:
	return {
		"success": false,
		"fingerprint": "",
		"stage": stage,
		"diagnostics": diagnostics,
	}
