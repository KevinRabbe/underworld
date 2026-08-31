extends RefCounted
class_name UnderworldNaturalEntranceRouteSelector

const WorldContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const MacroGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const TopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const EntranceGenerator := preload("res://worldgen/underworld/entrance_generator.gd")
const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")

const DEFAULT_REGION_RADIUS: int = 1
const MIN_SPAWN_DISTANCE: float = 32.0
const TARGET_SPAWN_DISTANCE: float = 40.0
const MAX_SPAWN_DISTANCE: float = 48.0
const MAX_SPAWN_SLOPE: float = 0.70


static func select(
	world_seed: int,
	preferred_surface_position: Vector3,
	region_radius: int = DEFAULT_REGION_RADIUS
) -> Dictionary:
	if not _is_finite_vector3(preferred_surface_position):
		return _failure(["Natural entrance selection requires a finite preferred surface position"])
	var context = WorldContext.new(world_seed)
	var context_failures: Array[String] = context.validate()
	if not context_failures.is_empty():
		return _failure(context_failures)
	var sampler = SurfaceSampler.new(world_seed)
	var radius: int = maxi(region_radius, 0)
	var center_region := Vector2i(
		floori(preferred_surface_position.x / MacroGenerator.REGION_SIZE),
		floori(preferred_surface_position.z / MacroGenerator.REGION_SIZE)
	)
	var candidates: Array[Dictionary] = []
	var rejected_approaches: Array[String] = []
	for region_z in range(center_region.y - radius, center_region.y + radius + 1):
		for region_x in range(center_region.x - radius, center_region.x + radius + 1):
			var region := Vector2i(region_x, region_z)
			var macro = MacroGenerator.generate(context, region)
			if not macro.success:
				return _prefixed_failure("Natural entrance macro region", macro.diagnostics)
			var topology = TopologyGenerator.generate(context, macro.data, sampler)
			if not topology.success:
				return _prefixed_failure("Natural entrance topology", topology.diagnostics)
			var entrances = EntranceGenerator.generate(context, macro.data, topology.data, sampler)
			if not entrances.success:
				return _prefixed_failure("Natural entrance generation", entrances.diagnostics)
			for descriptor in entrances.data.surface_integration_descriptors:
				var spawn_result: Dictionary = _recommended_spawn(descriptor, sampler)
				if not bool(spawn_result.get("success", false)):
					rejected_approaches.append(str(descriptor.entrance_id))
					continue
				var delta := Vector2(
					descriptor.surface_world_position.x - preferred_surface_position.x,
					descriptor.surface_world_position.z - preferred_surface_position.z
				)
				candidates.append({
					"descriptor": descriptor,
					"entrance_id": str(descriptor.entrance_id),
					"region_coord": region,
					"entrance_fingerprint": str(entrances.fingerprint),
					"distance_squared": delta.length_squared(),
					"spawn_xz": spawn_result["spawn_xz"],
				})
	if candidates.is_empty():
		var detail := ""
		if not rejected_approaches.is_empty():
			rejected_approaches.sort()
			detail = "; rejected non-viable approaches: %s" % [rejected_approaches]
		return _failure([
			"Natural entrance selection found no viable generated entrances within region radius %d%s" % [radius, detail],
		])
	var selected: Dictionary = _select_viable_candidate(candidates)
	if selected.is_empty():
		return _failure(["Natural entrance selection failed to choose a viable candidate"])
	var descriptor = selected["descriptor"]
	var route: Dictionary = {
		"world_seed": world_seed,
		"region_coord": selected["region_coord"],
		"entrance_id": str(descriptor.entrance_id),
		"owning_region_id": str(descriptor.owning_region_id),
		"surface_world_position": descriptor.surface_world_position,
		"orientation": descriptor.orientation,
		"required_opening_bounds": descriptor.required_opening_bounds,
		"clearance_radius": float(descriptor.clearance_radius),
		"underground_anchor": descriptor.underground_anchor,
		"descent_profile": str(descriptor.descent_profile),
		"source_entrance_fingerprint": str(selected["entrance_fingerprint"]),
		"recommended_spawn_xz": selected["spawn_xz"],
	}
	var route_fingerprint: String = "entrance-route-" + CanonicalValue.fingerprint(route)
	if route_fingerprint == "entrance-route-":
		return _failure(["Natural entrance selection could not fingerprint selected route"])
	route["selection_fingerprint"] = route_fingerprint
	route.make_read_only()
	return {
		"success": true,
		"route": route,
		"diagnostics": [],
	}


static func _select_viable_candidate(candidates: Array[Dictionary]) -> Dictionary:
	var viable: Array[Dictionary] = []
	for candidate in candidates:
		var spawn_variant: Variant = candidate.get("spawn_xz", null)
		if not spawn_variant is Vector3:
			continue
		if not _is_finite_vector3(spawn_variant):
			continue
		viable.append(candidate)
	if viable.is_empty():
		return {}
	viable.sort_custom(_candidate_less)
	return viable[0]


static func _recommended_spawn(descriptor, sampler) -> Dictionary:
	var orientation: Vector3 = Vector3(
		descriptor.orientation.x,
		0.0,
		descriptor.orientation.z
	)
	if orientation.length_squared() <= 0.000001:
		return _failure(["Natural entrance selection requires a horizontal entrance orientation"])
	var outward: Vector3 = -orientation.normalized()
	var lateral := Vector3(-outward.z, 0.0, outward.x)
	var best_score: float = -1.0e20
	var best_position := Vector3.ZERO
	var found := false
	var opening: AABB = descriptor.required_opening_bounds.grow(descriptor.clearance_radius)
	for distance in [MIN_SPAWN_DISTANCE, TARGET_SPAWN_DISTANCE, MAX_SPAWN_DISTANCE]:
		for lateral_offset in [0.0, -16.0, 16.0, -24.0, 24.0]:
			var candidate: Vector3 = (
				descriptor.surface_world_position
				+ outward * float(distance)
				+ lateral * float(lateral_offset)
			)
			if _contains_xz(opening, candidate):
				continue
			var sample = sampler.sample(candidate.x, candidate.z)
			if sample == null or sample.is_submerged() or sample.slope > MAX_SPAWN_SLOPE:
				continue
			var horizontal_distance: float = Vector2(
				sample.world_position.x - descriptor.surface_world_position.x,
				sample.world_position.z - descriptor.surface_world_position.z
			).length()
			var score: float = (
				float(sample.buildability) * 5.0
				+ (1.0 - float(sample.slope)) * 2.0
				- absf(horizontal_distance - TARGET_SPAWN_DISTANCE) / TARGET_SPAWN_DISTANCE
				- absf(float(lateral_offset)) / 192.0
			)
			if not found or score > best_score or (
				is_equal_approx(score, best_score)
				and _position_less(sample.world_position, best_position)
			):
				found = true
				best_score = score
				best_position = sample.world_position
	if not found:
		return _failure([
			"Natural entrance selection found no dry bounded approach spawn for %s" % descriptor.entrance_id,
		])
	return {
		"success": true,
		"spawn_xz": Vector3(best_position.x, 0.0, best_position.z),
		"diagnostics": [],
	}


static func _candidate_less(a: Dictionary, b: Dictionary) -> bool:
	var left_distance: float = float(a["distance_squared"])
	var right_distance: float = float(b["distance_squared"])
	if not is_equal_approx(left_distance, right_distance):
		return left_distance < right_distance
	return str(a.get("entrance_id", "")) < str(b.get("entrance_id", ""))


static func _contains_xz(bounds: AABB, point: Vector3) -> bool:
	return (
		point.x >= bounds.position.x
		and point.x <= bounds.end.x
		and point.z >= bounds.position.z
		and point.z <= bounds.end.z
	)


static func _position_less(a: Vector3, b: Vector3) -> bool:
	if not is_equal_approx(a.x, b.x):
		return a.x < b.x
	return a.z < b.z


static func _is_finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)


static func _prefixed_failure(prefix: String, diagnostics: Array) -> Dictionary:
	var failures: Array[String] = []
	for diagnostic in diagnostics:
		failures.append("%s: %s" % [prefix, str(diagnostic)])
	return _failure(failures)


static func _failure(diagnostics: Array) -> Dictionary:
	var failures: Array[String] = []
	for diagnostic in diagnostics:
		failures.append(str(diagnostic))
	failures.sort()
	return {
		"success": false,
		"route": {},
		"diagnostics": failures,
	}