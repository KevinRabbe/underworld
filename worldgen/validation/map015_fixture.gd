extends RefCounted
class_name UnderworldMap015Fixture

const EntranceProbe := preload("res://worldgen/validation/entrance_reproduction_probe.gd")
const GeometryProbe := preload("res://worldgen/validation/cave_geometry_reproduction_probe.gd")
const Context := preload("res://worldgen/pipeline/world_generation_context.gd")
const Sampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const Macro := preload("res://worldgen/underworld/macro_region_generator.gd")
const Topology := preload("res://worldgen/underworld/primary_topology_generator.gd")
const Entrances := preload("res://worldgen/underworld/entrance_generator.gd")
const SurfacePlan := preload("res://worldgen/surface/surface_entrance_chunk_plan.gd")

const SEED := 1
const REGION := Vector2i(0, 0)
const ENTRANCE_ID := "sid1:sa1|2:ug|6:region|1:0|1:0|8:entrance|4:slot|1:0"
const ENTRANCE_FINGERPRINT := "entrances-sha256:0168b5914511eefdd887e44b0e83eb3f8ba77cdc09e33f4889da0c69c9997151"
const GEOMETRY_FINGERPRINT := "geometry-sha256:ae101fd53557e706925adc51f605f20354173483efc26c183c13658384ef1b62"

static func validate() -> Array[String]:
	var failures: Array[String] = []
	var context := Context.new(SEED); var sampler := Sampler.new(SEED)
	var macro = Macro.generate(context, REGION); var topology = Topology.generate(context, macro.data, sampler); var entrances = Entrances.generate(context, macro.data, topology.data, sampler)
	if not entrances.success: return ["fixture entrance generation failed: %s" % entrances.diagnostics]
	if entrances.fingerprint != ENTRANCE_FINGERPRINT: failures.append("fixture entrance fingerprint drift")
	var found := false
	for descriptor in entrances.data.surface_integration_descriptors:
		if descriptor.entrance_id == ENTRANCE_ID:
			found = true
			var plan = SurfacePlan.build(AABB(descriptor.surface_world_position - Vector3(32, 32, 32), Vector3(64, 64, 64)), [descriptor], Vector2i(16, 16), entrances.fingerprint)
			if not plan.success or plan.data.underground_cells.size() < 4: failures.append("fixture does not have four prefetched geometry cells")
	if not found: failures.append("fixture entrance id missing")
	var geometry := GeometryProbe.build(SEED, REGION)
	if not geometry.success or geometry.fingerprint != GEOMETRY_FINGERPRINT: failures.append("fixture geometry fingerprint drift")
	return failures
