extends RefCounted
class_name UnderworldDepthProfileProvider

const SeedDomains := preload("res://worldgen/random/seed_domains.gd")
const SeedDeriver := preload("res://worldgen/random/seed_deriver.gd")


static func sample(context, region_plan, world_position: Vector3, stable_address) -> Vector3:
	if context == null or region_plan == null or stable_address == null:
		return Vector3(1.0, 0.0, 0.0)

	var depth_span: float = maxf(region_plan.world_bounds.size.y, 1.0)
	var depth_ratio: float = clampf(
		(region_plan.surface_reference_y - world_position.y) / depth_span,
		0.0,
		1.0
	)
	var shallow: float = clampf(1.0 - depth_ratio * 2.0, 0.0, 1.0)
	var deep: float = clampf(depth_ratio * 2.0 - 1.0, 0.0, 1.0)
	var mid: float = clampf(1.0 - absf(depth_ratio - 0.5) * 2.0, 0.0, 1.0)
	var domain = SeedDomains.get_domain(SeedDomains.UG_NODE_PROFILE)
	var jitter := Vector3(
		SeedDeriver.random_unit(context.world_seed, stable_address, domain, "shallow"),
		SeedDeriver.random_unit(context.world_seed, stable_address, domain, "mid"),
		SeedDeriver.random_unit(context.world_seed, stable_address, domain, "deep")
	) * 0.08
	var weighted := Vector3(shallow, mid, deep)
	weighted += region_plan.profile_bias * 0.30
	weighted += jitter
	return _normalized_profile(weighted)


static func resolve_grammar(profile: Vector3, regional_tendencies: Dictionary) -> Dictionary:
	return {
		"branch_acceptance": clampf(
			0.42 * profile.x + 0.62 * profile.y + 0.48 * profile.z
			+ float(regional_tendencies.get("branching", 0.5)) * 0.20,
			0.25,
			0.88
		),
		"chamber_scale": 0.85 * profile.x + 1.10 * profile.y + 1.35 * profile.z,
		"tunnel_length": 46.0 * profile.x + 62.0 * profile.y + 78.0 * profile.z,
		"verticality": clampf(
			0.18 * profile.x + 0.42 * profile.y + 0.78 * profile.z
			+ float(regional_tendencies.get("verticality", 0.5)) * 0.25,
			0.10,
			1.0
		),
		"tunnel_width": 5.5 * profile.x + 4.8 * profile.y + 4.2 * profile.z,
	}


static func _normalized_profile(value: Vector3) -> Vector3:
	var total: float = value.x + value.y + value.z
	if total <= 0.0:
		return Vector3(1.0, 0.0, 0.0)
	return value / total
