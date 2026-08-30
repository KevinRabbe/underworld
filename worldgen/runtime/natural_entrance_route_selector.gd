extends RefCounted
class_name UnderworldNaturalEntranceRouteSelector

const WorldContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const MacroGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const TopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const EntranceGenerator := preload("res://worldgen/underworld/entrance_generator.gd")

const MACRO_REGION_SIZE_METERS := 512.0
const DEFAULT_SEARCH_RADIUS := 1


static func select_route(world_seed: int, intended_spawn: Vector3, search_radius: int = DEFAULT_SEARCH_RADIUS) -> Dictionary:
	var failures: Array[String] = []
	if not _finite_vec3(intended_spawn):
		return _failure(["Natural entrance selection requires finite intended spawn"])
	if search_radius < 0 or search_radius > 2:
		return _failure(["Natural entrance search radius must be within [0, 2]"])

	var context := WorldContext.new(world_seed)
	failures.append_array(context.validate())
	if not failures.is_empty():
		return _failure(failures)
	var sampler := SurfaceSampler.new(world_seed)
	var center := Vector2i(
		int(floor(intended_spawn.x / MACRO_REGION_SIZE_METERS)),
		int(floor(intended_spawn.z / MACRO_REGION_SIZE_METERS))
	)
	var candidates: Array[Dictionary] = []
	var scanned_regions: int = 0

	for z_offset in range(-search_radius, search_radius + 1):
		for x_offset in range(-search_radius, search_radius + 1):
			var region := center + Vector2i(x_offset, z_offset)
			scanned_regions += 1
			var macro = MacroGenerator.generate(context, region)
			if not macro.success:
				for diagnostic in macro.diagnostics:
					failures.append("region %s macro: %s" % [region, diagnostic])
				continue
			var topology = TopologyGenerator.generate(context, macro.data, sampler)
			if not topology.success:
				for diagnostic in topology.diagnostics:
					failures.append("region %s topology: %s" % [region, diagnostic])
				continue
			var entrances = EntranceGenerator.generate(context, macro.data, topology.data, sampler)
			if not entrances.success:
				for diagnostic in entrances.diagnostics:
					failures.append("region %s entrances: %s" % [region, diagnostic])
				continue
			for descriptor in entrances.data.surface_integration_descriptors:
				if descriptor == null:
					continue
				var descriptor_failures: Array[String] = descriptor.validate()
				if not descriptor_failures.is_empty():
					continue
				var surface_position: Vector3 = descriptor.surface_world_position
				if not _finite_vec3(surface_position):
					continue
				var sample = sampler.sample(surface_position.x, surface_position.z)
				if sample == null or sample.is_submerged() or not _finite_vec3(sample.world_position):
					continue
				var delta := Vector2(surface_position.x - intended_spawn.x, surface_position.z - intended_spawn.z)
				candidates.append({
					"descriptor": descriptor,
					"descriptor_data": descriptor.canonical_data(),
					"entrance_id": str(descriptor.entrance_id),
					"region": region,
					"slot": int(descriptor.slot),
					"surface_world_position": surface_position,
					"clearance": float(descriptor.clearance),
					"distance_squared": delta.length_squared(),
					"entrance_stage_fingerprint": str(entrances.fingerprint),
				})

	if candidates.is_empty():
		if failures.is_empty():
			failures.append("No valid generated surface entrance found in bounded search")
		return _failure(failures, scanned_regions)
	candidates.sort_custom(_candidate_less)
	var selected: Dictionary = candidates[0]
	return {
		"success": true,
		"entrance_id": selected["entrance_id"],
		"region": selected["region"],
		"slot": selected["slot"],
		"surface_world_position": selected["surface_world_position"],
		"clearance": selected["clearance"],
		"distance_squared": selected["distance_squared"],
		"descriptor_data": selected["descriptor_data"].duplicate(true),
		"entrance_stage_fingerprint": selected["entrance_stage_fingerprint"],
		"scanned_regions": scanned_regions,
		"diagnostics": [],
	}


static func _candidate_less(left: Dictionary, right: Dictionary) -> bool:
	var left_distance := float(left.get("distance_squared", INF))
	var right_distance := float(right.get("distance_squared", INF))
	if not is_equal_approx(left_distance, right_distance):
		return left_distance < right_distance
	var left_region: Vector2i = left.get("region", Vector2i.ZERO)
	var right_region: Vector2i = right.get("region", Vector2i.ZERO)
	if left_region.x != right_region.x:
		return left_region.x < right_region.x
	if left_region.y != right_region.y:
		return left_region.y < right_region.y
	var left_slot := int(left.get("slot", 0))
	var right_slot := int(right.get("slot", 0))
	if left_slot != right_slot:
		return left_slot < right_slot
	return str(left.get("entrance_id", "")) < str(right.get("entrance_id", ""))


static func _failure(failures: Array, scanned_regions: int = 0) -> Dictionary:
	var diagnostics: Array[String] = []
	for failure in failures:
		diagnostics.append(str(failure))
	return {"success": false, "diagnostics": diagnostics, "scanned_regions": scanned_regions}


static func _finite_vec3(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)
