extends RefCounted

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const MacroRegionGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const PrimaryTopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const EntranceGenerator := preload("res://worldgen/underworld/entrance_generator.gd")
const DepthProfiles := preload("res://worldgen/profiles/depth_profile_provider.gd")
const GraphValidator := preload("res://worldgen/validation/graph_validator.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_surface_sampler(failures)
	_test_surface_relative_depth(failures)
	_test_entrance_generation(failures)
	_test_count_tendency_and_profiles(failures)
	_test_negative_region(failures)
	return failures


static func _test_surface_sampler(failures: Array[String]) -> void:
	var first = SurfaceSampler.new(12345).sample(91.25, -48.75)
	var second = SurfaceSampler.new(12345).sample(91.25, -48.75)
	_expect_equal(failures, "surface sampler is deterministic", first.canonical_data(), second.canonical_data())
	_expect_true(failures, "surface sample normal is normalized", absf(first.normal.length() - 1.0) < 0.001)
	_expect_true(failures, "surface sample exposes viability", first.buildability >= 0.0 and first.buildability <= 1.0)


static func _test_surface_relative_depth(failures: Array[String]) -> void:
	var sampler = SurfaceSampler.new(24680)
	var position := Vector3(413.0, -40.0, -287.0)
	var surface = sampler.sample(position.x, position.z)
	_expect_equal(
		failures,
		"depth is measured against sampled local surface",
		DepthProfiles.surface_relative_depth(sampler, position),
		surface.world_position.y - position.y
	)


static func _test_entrance_generation(failures: Array[String]) -> void:
	var built: Dictionary = _build(987654321, Vector2i.ZERO)
	if not bool(built.get("success", false)):
		failures.append("entrance fixture failed: %s" % built.get("diagnostics", []))
		return
	var repeated: Dictionary = _build(987654321, Vector2i.ZERO)
	_expect_equal(failures, "entrance generation is deterministic", built["result"].fingerprint, repeated["result"].fingerprint)
	var macro = built["macro"]
	var topology = built["topology"]
	var result = built["result"]
	_expect_equal(failures, "entrance candidate slots are fixed", macro.entrance_candidate_slots, [0, 1, 2, 3, 4, 5])
	_expect_equal(failures, "every stable candidate is reported", result.entrance_candidate_metadata.size(), 6)
	for metadata in result.entrance_candidate_metadata:
		var slot: int = int(metadata["slot"])
		_expect_equal(
			failures,
			"entrance address is slot-stable %d" % slot,
			metadata["address"],
			StableAddress.entrance(macro.stable_address, slot).canonical_text()
		)
	_expect_true(failures, "primary topology input remains immutable", topology.bundle.entrances.is_empty())
	_expect_equal(failures, "one surface descriptor per entrance", result.surface_integration_descriptors.size(), result.bundle.entrances.size())
	for graph_failure in GraphValidator.validate_region_bundle(result.bundle):
		failures.append("entrance graph invalid: " + graph_failure)
	for descriptor in result.surface_integration_descriptors:
		_expect_true(failures, "descriptor has opening bounds", descriptor.required_opening_bounds.size.x > 0.0 and descriptor.required_opening_bounds.size.z > 0.0)
		_expect_true(failures, "descriptor has clearance", descriptor.clearance_radius > 0.0)
	_expect_true(failures, "secondary connectivity remains out of scope", result.bundle.region_definition.secondary_edge_ids.is_empty())


static func _test_count_tendency_and_profiles(failures: Array[String]) -> void:
	var total: int = 0
	var profiles: Dictionary = {}
	for seed in range(1, 33):
		var built: Dictionary = _build(seed, Vector2i(1, -1))
		if not bool(built.get("success", false)):
			failures.append("entrance distribution fixture failed seed=%d: %s" % [seed, built.get("diagnostics", [])])
			continue
		var result = built["result"]
		var count: int = result.bundle.entrances.size()
		total += count
		_expect_true(failures, "entrance tendency never becomes a hard excess", count <= 3)
		for entrance in result.bundle.entrances:
			profiles[entrance.descent_profile] = true
	var average: float = float(total) / 32.0
	_expect_true(failures, "entrance count tends toward one to three", average >= 0.75 and average <= 2.5)
	_expect_true(failures, "multiple descent profiles are generated", profiles.size() >= 2)


static func _test_negative_region(failures: Array[String]) -> void:
	var built: Dictionary = _build(-445566, Vector2i(-4, -7))
	_expect_true(failures, "negative-coordinate entrance generation succeeds", bool(built.get("success", false)))
	if not bool(built.get("success", false)):
		return
	for descriptor in built["result"].surface_integration_descriptors:
		_expect_true(failures, "negative descriptor remains in owning region XZ", built["macro"].world_bounds.has_point(Vector3(descriptor.surface_world_position.x, -1.0, descriptor.surface_world_position.z)))


static func _build(seed: int, coord: Vector2i) -> Dictionary:
	var context = WorldGenerationContext.new(seed)
	var sampler = SurfaceSampler.new(seed)
	var macro = MacroRegionGenerator.generate(context, coord)
	if not macro.success:
		return {"success": false, "diagnostics": macro.diagnostics}
	var topology = PrimaryTopologyGenerator.generate(context, macro.data, sampler)
	if not topology.success:
		return {"success": false, "diagnostics": topology.diagnostics}
	var entrances = EntranceGenerator.generate(context, macro.data, topology.data, sampler)
	if not entrances.success:
		return {"success": false, "diagnostics": entrances.diagnostics}
	return {
		"success": true,
		"macro": macro.data,
		"topology": topology.data,
		"result": entrances.data,
	}


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])
