extends RefCounted

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const MacroRegionGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const PrimaryTopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const DepthProfiles := preload("res://worldgen/profiles/depth_profile_provider.gd")
const GraphValidator := preload("res://worldgen/validation/graph_validator.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_macro_plan_contract(failures)
	_test_primary_topology_determinism(failures)
	_test_negative_region(failures)
	_test_depth_grammar(failures)
	_test_connectivity_validator(failures)
	return failures


static func _test_macro_plan_contract(failures: Array[String]) -> void:
	var context = WorldGenerationContext.new(12345)
	var first = MacroRegionGenerator.generate(context, Vector2i(2, -3))
	var second = MacroRegionGenerator.generate(context, Vector2i(2, -3))
	_expect_true(failures, "macro plan succeeds", first.success and second.success)
	if not first.success or not second.success:
		return
	_expect_equal(
		failures,
		"macro plan is deterministic",
		first.fingerprint,
		second.fingerprint
	)
	_expect_equal(
		failures,
		"macro network candidate slots are fixed before acceptance",
		first.data.network_candidate_slots,
		[0, 1, 2, 3]
	)
	_expect_profile(failures, "macro profile bias", first.data.profile_bias)


static func _test_primary_topology_determinism(failures: Array[String]) -> void:
	var context = WorldGenerationContext.new(987654321)
	var macro = MacroRegionGenerator.generate(context, Vector2i.ZERO)
	if not macro.success:
		failures.append("primary topology macro input failed: %s" % macro.diagnostics)
		return
	var first = PrimaryTopologyGenerator.generate(context, macro.data)
	var second = PrimaryTopologyGenerator.generate(context, macro.data)
	_expect_true(failures, "primary topology succeeds", first.success and second.success)
	if not first.success or not second.success:
		failures.append("primary topology diagnostics: %s / %s" % [
			first.diagnostics,
			second.diagnostics,
		])
		return

	_expect_equal(
		failures,
		"same plan produces same topology fingerprint",
		first.fingerprint,
		second.fingerprint
	)
	var result = first.data
	_expect_equal(
		failures,
		"all network candidate slots remain represented",
		result.network_candidate_metadata.size(),
		4
	)
	for metadata in result.network_candidate_metadata:
		var slot: int = int(metadata["slot"])
		var expected = StableAddress.network(macro.data.stable_address, slot)
		_expect_equal(
			failures,
			"network candidate address is slot-stable %d" % slot,
			metadata["address"],
			expected.canonical_text()
		)
	for metadata in result.node_candidate_metadata:
		var network_slot: int = int(metadata["network_slot"])
		var node_slot: int = int(metadata["slot"])
		var network_address = StableAddress.network(
			macro.data.stable_address,
			network_slot
		)
		var expected = StableAddress.node(network_address, [node_slot])
		_expect_equal(
			failures,
			"node candidate address is slot-stable %d:%d" % [network_slot, node_slot],
			metadata["address"],
			expected.canonical_text()
		)

	var bundle = result.bundle
	for graph_failure in GraphValidator.validate_region_bundle(bundle):
		failures.append("generated topology invalid: " + graph_failure)
	for network in bundle.networks:
		_expect_equal(
			failures,
			"primary network is a connected tree",
			network.primary_edge_ids.size(),
			network.node_ids.size() - 1
		)
		_expect_true(
			failures,
			"network root remains in node membership",
			network.root_node_id in network.node_ids
		)


static func _test_negative_region(failures: Array[String]) -> void:
	var context = WorldGenerationContext.new(-445566)
	var macro = MacroRegionGenerator.generate(context, Vector2i(-4, -7))
	if not macro.success:
		failures.append("negative-region macro plan failed: %s" % macro.diagnostics)
		return
	var topology = PrimaryTopologyGenerator.generate(context, macro.data)
	if not topology.success:
		failures.append("negative-region topology failed: %s" % topology.diagnostics)
		return
	for node in topology.data.bundle.nodes:
		_expect_true(
			failures,
			"negative-region node remains inside owned bounds",
			macro.data.world_bounds.has_point(node.world_position)
		)


static func _test_depth_grammar(failures: Array[String]) -> void:
	var context = WorldGenerationContext.new(24680)
	var macro = MacroRegionGenerator.generate(context, Vector2i.ZERO)
	if not macro.success:
		failures.append("depth grammar macro input failed")
		return
	var address = StableAddress.node(StableAddress.network(macro.data.stable_address, 0))
	var shallow: Vector3 = DepthProfiles.sample(
		context, macro.data, Vector3(100.0, -24.0, 100.0), address
	)
	var deep: Vector3 = DepthProfiles.sample(
		context, macro.data, Vector3(100.0, -360.0, 100.0), address
	)
	_expect_profile(failures, "shallow depth sample", shallow)
	_expect_profile(failures, "deep depth sample", deep)
	_expect_true(failures, "shallow weight decreases with depth", shallow.x > deep.x)
	_expect_true(failures, "deep weight increases with depth", deep.z > shallow.z)
	var shallow_grammar: Dictionary = DepthProfiles.resolve_grammar(
		shallow, macro.data.topology_tendencies
	)
	var deep_grammar: Dictionary = DepthProfiles.resolve_grammar(
		deep, macro.data.topology_tendencies
	)
	_expect_true(
		failures,
		"deep grammar is more vertical than shallow grammar",
		float(deep_grammar["verticality"]) > float(shallow_grammar["verticality"])
	)


static func _test_connectivity_validator(failures: Array[String]) -> void:
	var context = WorldGenerationContext.new(112233)
	var macro = MacroRegionGenerator.generate(context, Vector2i.ZERO)
	var topology = PrimaryTopologyGenerator.generate(context, macro.data)
	if not topology.success:
		failures.append("connectivity fixture generation failed")
		return
	var bundle = topology.data.bundle
	var target = bundle.networks[0]
	if target.primary_edge_ids.is_empty():
		failures.append("connectivity fixture has no removable primary edge")
		return
	target.primary_edge_ids.remove_at(target.primary_edge_ids.size() - 1)
	var found_disconnected: bool = false
	for graph_failure in GraphValidator.validate_region_bundle(bundle):
		if "disconnected" in graph_failure:
			found_disconnected = true
			break
	_expect_true(
		failures,
		"graph validator rejects disconnected primary networks",
		found_disconnected
	)


static func _expect_profile(
	failures: Array[String],
	label: String,
	profile: Vector3
) -> void:
	_expect_true(
		failures,
		label + " is finite and normalized",
		is_finite(profile.x)
		and is_finite(profile.y)
		and is_finite(profile.z)
		and profile.x >= 0.0
		and profile.y >= 0.0
		and profile.z >= 0.0
		and absf(profile.x + profile.y + profile.z - 1.0) <= 0.001
	)


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(
	failures: Array[String],
	label: String,
	actual: Variant,
	expected: Variant
) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])
