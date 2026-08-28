extends RefCounted
class_name UnderworldMacroRegionGenerator

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const SeedDomains := preload("res://worldgen/random/seed_domains.gd")
const SeedDeriver := preload("res://worldgen/random/seed_deriver.gd")
const StageResult := preload("res://worldgen/pipeline/generation_stage_result.gd")
const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")
const MacroRegionPlan := preload("res://worldgen/underworld/macro_region_plan.gd")

const REGION_SIZE: float = 512.0
const REGION_DEPTH: float = 384.0
const NETWORK_CANDIDATE_COUNT: int = 4
const SPECIAL_CANDIDATE_COUNT: int = 4
const ENTRANCE_CANDIDATE_COUNT: int = 6


static func generate(context, region_coord: Vector2i):
	var failures: Array[String] = []
	if context == null:
		return StageResult.fail("macro_region", ["WorldGenerationContext is null"])
	failures.append_array(context.validate())
	if not failures.is_empty():
		return StageResult.fail("macro_region", failures)

	var address = StableAddress.underground_region(region_coord.x, region_coord.y)
	var domain = SeedDomains.get_domain(SeedDomains.UG_REGION_LAYOUT)
	var min_corner := Vector3(
		float(region_coord.x) * REGION_SIZE,
		-REGION_DEPTH,
		float(region_coord.y) * REGION_SIZE
	)
	var bounds := AABB(min_corner, Vector3(REGION_SIZE, REGION_DEPTH, REGION_SIZE))
	var anchor := Vector3(
		min_corner.x + REGION_SIZE * 0.5,
		0.0,
		min_corner.z + REGION_SIZE * 0.5
	)

	var raw_bias := Vector3(
		0.65 + SeedDeriver.random_unit(context.world_seed, address, domain, "shallow-bias"),
		0.65 + SeedDeriver.random_unit(context.world_seed, address, domain, "mid-bias"),
		0.65 + SeedDeriver.random_unit(context.world_seed, address, domain, "deep-bias")
	)
	var profile_bias: Vector3 = _normalized_profile(raw_bias)
	var network_slots: Array[int] = []
	for slot in range(NETWORK_CANDIDATE_COUNT):
		network_slots.append(slot)
	var special_slots: Array[int] = []
	for slot in range(SPECIAL_CANDIDATE_COUNT):
		special_slots.append(slot)
	var entrance_slots: Array[int] = []
	for slot in range(ENTRANCE_CANDIDATE_COUNT):
		entrance_slots.append(slot)

	var tendencies: Dictionary = {
		"branching": 0.35 + SeedDeriver.random_unit(
			context.world_seed, address, domain, "branching"
		) * 0.45,
		"verticality": 0.20 + SeedDeriver.random_unit(
			context.world_seed, address, domain, "verticality"
		) * 0.60,
		"network_acceptance": 0.45 + SeedDeriver.random_unit(
			context.world_seed, address, domain, "network-acceptance"
		) * 0.25,
	}
	var plan = MacroRegionPlan.new(
		address,
		region_coord,
		anchor,
		bounds,
		profile_bias,
		tendencies,
		network_slots,
		special_slots,
		entrance_slots
	)
	var fingerprint: String = CanonicalValue.fingerprint(plan.canonical_data())
	var provenance = context.make_provenance(
		"macro_region", plan.stable_id, plan.stable_address.canonical_text(), []
	)
	plan.provenance = provenance
	return StageResult.ok(
		"macro_region",
		plan,
		fingerprint,
		provenance
	)


static func _normalized_profile(value: Vector3) -> Vector3:
	var total: float = value.x + value.y + value.z
	if total <= 0.0:
		return Vector3(1.0, 0.0, 0.0)
	return value / total
