extends RefCounted

const GeneratorManifest := preload("res://worldgen/versioning/generator_manifest.gd")
const RootPackage := preload("res://worldgen/versioning/root_generation_identity_package.gd")
const Context := preload("res://worldgen/pipeline/world_generation_context.gd")
const WorldId := preload("res://worldgen/identity/world_id.gd")

const GOLDEN_MANIFEST_ID: String = "gm-sha256:c3fb0a2e53be0593b588a6f9b375d087886ab55111b9ca1a78a5c09bf99a302f"
const GOLDEN_WORLD_ID_424242: String = "wid1:0e754d7b49bf348a7d49e5b27ffa6abbe81e939587f60d25402702714caad691"
const GOLDEN_CANONICAL: String = "gm1|15:manifest-schema|1:1|11:seed-schema|1:1|21:stable-address-schema|1:1|16:surface-contract|1:2|19:underworld-contract|1:1|19:provenance-contract|1:1|11:stage-count|1:7|5:stage|18:entrance_selection|1:1|5:stage|20:geometry_description|1:1|5:stage|12:macro_region|1:1|5:stage|16:primary_topology|1:1|5:stage|19:region_finalization|1:1|5:stage|22:secondary_connectivity|1:1|5:stage|22:special_location_hooks|1:1|13:profile-count|1:1|7:profile|13:depth_grammar|1:1|12:domain-count|2:26|6:domain|8:00010001|1:1|19:surface.tree.exists|6:domain|8:00010002|1:1|19:surface.tree.offset|6:domain|8:00010003|1:1|18:surface.tree.shape|6:domain|8:00010101|1:1|19:surface.rock.exists|6:domain|8:00010102|1:1|19:surface.rock.offset|6:domain|8:00010103|1:1|18:surface.rock.shape|6:domain|8:00010201|1:1|28:surface.pickup.branch.exists|6:domain|8:00010202|1:1|27:surface.pickup.branch.shape|6:domain|8:00010211|1:1|33:surface.pickup.loose_stone.exists|6:domain|8:00010212|1:1|32:surface.pickup.loose_stone.shape|6:domain|8:00020001|1:1|16:ug.region.layout|6:domain|8:00020101|1:1|17:ug.network.exists|6:domain|8:00020102|1:1|19:ug.network.topology|6:domain|8:00020200|1:1|14:ug.node.exists|6:domain|8:00020201|1:1|16:ug.node.position|6:domain|8:00020202|1:1|13:ug.node.shape|6:domain|8:00020203|1:1|15:ug.node.profile|6:domain|8:00020211|1:1|24:ug.primary_edge.topology|6:domain|8:00020301|1:1|21:ug.entrance.selection|6:domain|8:00020302|1:1|19:ug.entrance.profile|6:domain|8:00020303|1:1|19:ug.entrance.surface|6:domain|8:00020304|1:1|20:ug.entrance.geometry|6:domain|8:00020401|1:1|19:ug.secondary.exists|6:domain|8:00020402|1:1|18:ug.secondary.shape|6:domain|8:00020501|1:1|17:ug.special.exists|6:domain|8:00020601|1:1|17:ug.geometry.shape"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_current_golden_round_trip(failures)
	_test_deterministic_repeat_round_trip(failures)
	_test_snapshot_alias_boundaries(failures)
	_test_registry_compatibility_is_separate_from_identity(failures)
	_test_historical_manifest_schema_identity(failures)
	_test_world_id_contract_rehydration(failures)
	_test_malformed_and_duplicate_package_entries(failures)
	_test_context_immutability_and_provenance(failures)
	return failures


static func _test_current_golden_round_trip(failures: Array[String]) -> void:
	var context = Context.new(424242)
	_expect_empty(failures, "current context validates", context.validate())
	_expect_equal(
		failures,
		"pre-430 canonical manifest bytes remain exact",
		context.generator_manifest.canonical_text(),
		GOLDEN_CANONICAL
	)
	_expect_equal(
		failures,
		"pre-430 manifest ID remains exact",
		context.generator_manifest_id,
		GOLDEN_MANIFEST_ID
	)
	_expect_equal(
		failures,
		"pre-430 WorldId remains exact",
		context.world_id,
		GOLDEN_WORLD_ID_424242
	)

	var package: Dictionary = RootPackage.encode(context)
	var rehydrated: Dictionary = RootPackage.rehydrate(424242, package)
	_expect_true(failures, "current package rehydrates structurally", bool(rehydrated.get("success", false)))
	_expect_true(failures, "current package is runtime compatible", bool(rehydrated.get("compatible", false)))
	if not bool(rehydrated.get("success", false)):
		return
	var restored = rehydrated["context"]
	_expect_equal(
		failures,
		"rehydrated canonical header is exact",
		restored.canonical_header(),
		context.canonical_header()
	)
	_expect_equal(
		failures,
		"rehydrated manifest bytes are exact",
		restored.generator_manifest.canonical_text(),
		GOLDEN_CANONICAL
	)
	_expect_equal(
		failures,
		"rehydrated manifest ID is exact",
		restored.generator_manifest_id,
		GOLDEN_MANIFEST_ID
	)
	_expect_equal(
		failures,
		"rehydrated WorldId is exact",
		restored.world_id,
		GOLDEN_WORLD_ID_424242
	)


static func _test_deterministic_repeat_round_trip(failures: Array[String]) -> void:
	var context = Context.new(424242)
	var package_a: Dictionary = RootPackage.encode(context)
	var first: Dictionary = RootPackage.rehydrate(424242, package_a)
	if not bool(first.get("success", false)):
		failures.append("first deterministic package rehydrate failed: " + str(first.get("failures", [])))
		return
	var package_b: Dictionary = RootPackage.encode(first["context"])
	var second: Dictionary = RootPackage.rehydrate(424242, package_b)
	if not bool(second.get("success", false)):
		failures.append("second deterministic package rehydrate failed: " + str(second.get("failures", [])))
		return
	var package_c: Dictionary = RootPackage.encode(second["context"])
	_expect_equal(failures, "encode/decode/rehydrate package is deterministic", package_b, package_c)
	_expect_equal(
		failures,
		"repeated rehydrate keeps exact canonical header",
		first["context"].canonical_header(),
		second["context"].canonical_header()
	)


static func _test_snapshot_alias_boundaries(failures: Array[String]) -> void:
	var stages: Dictionary = {"macro_region": 1, "primary_topology": 2}
	var profiles: Dictionary = {"depth_grammar": 3}
	var manifest = GeneratorManifest.new(stages, profiles, 2, 1, 1)
	var baseline_text: String = manifest.canonical_text()
	var baseline_id: String = manifest.manifest_id()

	stages["macro_region"] = 999
	stages["injected"] = 1
	profiles.clear()
	manifest.seed_schema_version = 999
	manifest.surface_contract_revision = 999

	var snapshot: Dictionary = manifest.snapshot()
	snapshot["seed_schema_version"] = 777
	snapshot["stage_entries"][0]["revision"] = 777
	snapshot["seed_domain_descriptors"][0]["revision"] = 777

	var returned_domains: Array = manifest.seed_domain_descriptors()
	returned_domains[0]["readable_name"] = "mutated"

	_expect_equal(failures, "constructor aliases cannot mutate manifest bytes", manifest.canonical_text(), baseline_text)
	_expect_equal(failures, "constructor aliases cannot mutate manifest ID", manifest.manifest_id(), baseline_id)
	_expect_equal(failures, "manifest scalar assignment cannot mutate seed schema", manifest.seed_schema_version, 1)
	_expect_equal(failures, "manifest scalar assignment cannot mutate surface contract", manifest.surface_contract_revision, 2)


static func _test_registry_compatibility_is_separate_from_identity(failures: Array[String]) -> void:
	var manifest = GeneratorManifest.foundation_default()
	var baseline_text: String = manifest.canonical_text()
	var baseline_id: String = manifest.manifest_id()
	var support: Dictionary = GeneratorManifest.current_runtime_support()

	var extra_domains: Array = support["seed_domain_descriptors"].duplicate(true)
	extra_domains.append(
		{
			"domain_id": 0x7f0001,
			"revision": 1,
			"readable_name": "fixture.extra.domain",
		}
	)
	support["seed_domain_descriptors"] = extra_domains
	_expect_empty(
		failures,
		"extra runtime seed domain does not invalidate captured required set",
		manifest.runtime_compatibility_failures(support)
	)
	_expect_equal(failures, "extra runtime domain cannot change manifest bytes", manifest.canonical_text(), baseline_text)
	_expect_equal(failures, "extra runtime domain cannot change manifest ID", manifest.manifest_id(), baseline_id)

	var package: Dictionary = RootPackage.encode(Context.new(424242))
	var package_with_extra_support: Dictionary = RootPackage.rehydrate(
		424242,
		package,
		support
	)
	_expect_true(
		failures,
		"package rehydrate stays compatible after extra runtime domain appears",
		bool(package_with_extra_support.get("compatible", false))
	)
	if bool(package_with_extra_support.get("success", false)):
		_expect_equal(
			failures,
			"package rehydrate after extra runtime domain preserves exact manifest ID",
			package_with_extra_support["context"].generator_manifest_id,
			GOLDEN_MANIFEST_ID
		)
		_expect_equal(
			failures,
			"package rehydrate after extra runtime domain preserves exact canonical bytes",
			package_with_extra_support["context"].generator_manifest.canonical_text(),
			GOLDEN_CANONICAL
		)

	var mismatch_support: Dictionary = GeneratorManifest.current_runtime_support()
	mismatch_support["seed_domain_descriptors"][0]["revision"] = 2
	mismatch_support["seed_domain_descriptors"][0]["readable_name"] = "fixture.changed.name"
	var mismatch_failures: Array[String] = manifest.runtime_compatibility_failures(mismatch_support)
	_expect_true(
		failures,
		"same domain ID with revision/name mismatch fails compatibility",
		not mismatch_failures.is_empty()
	)
	var package_with_mismatch: Dictionary = RootPackage.rehydrate(
		424242,
		package,
		mismatch_support
	)
	_expect_true(
		failures,
		"package rehydrate reports same-ID seed-domain mismatch",
		not bool(package_with_mismatch.get("compatible", true))
	)
	if bool(package_with_mismatch.get("success", false)):
		_expect_equal(
			failures,
			"package compatibility mismatch cannot rewrite exact manifest ID",
			package_with_mismatch["context"].generator_manifest_id,
			GOLDEN_MANIFEST_ID
		)
	_expect_equal(failures, "compatibility failure cannot rewrite manifest identity", manifest.manifest_id(), baseline_id)


static func _test_historical_manifest_schema_identity(failures: Array[String]) -> void:
	var current = GeneratorManifest.foundation_default()
	var historical_snapshot: Dictionary = current.snapshot()
	historical_snapshot["manifest_schema_version"] = 7
	historical_snapshot["manifest_schema_prefix"] = "gm7"
	_expect_empty(
		failures,
		"historical manifest snapshot is structurally valid",
		GeneratorManifest.validate_snapshot(historical_snapshot)
	)
	var historical = GeneratorManifest.from_snapshot(historical_snapshot)
	var historical_id: String = historical.manifest_id()
	_expect_true(
		failures,
		"historical manifest canonicalization uses captured prefix",
		historical.canonical_text().begins_with("gm7|")
	)
	_expect_true(
		failures,
		"historical manifest is explicitly runtime incompatible with current build",
		not historical.runtime_compatibility_failures().is_empty()
	)

	var simulated_newer_support: Dictionary = GeneratorManifest.current_runtime_support()
	simulated_newer_support["manifest_schema_version"] = 2
	simulated_newer_support["manifest_schema_prefix"] = "gm2"
	var baseline_current_id: String = current.manifest_id()
	_expect_true(
		failures,
		"simulated newer default reports old gm1 support mismatch explicitly",
		not current.runtime_compatibility_failures(simulated_newer_support).is_empty()
	)
	_expect_equal(
		failures,
		"simulated newer default cannot rewrite captured gm1 identity",
		current.manifest_id(),
		baseline_current_id
	)

	var package: Dictionary = {
		"package_schema_version": RootPackage.PACKAGE_SCHEMA_VERSION,
		"world_id": GOLDEN_WORLD_ID_424242,
		"world_id_contract": WorldId.current_contract_descriptor(),
		"manifest_snapshot": historical_snapshot,
	}
	var result: Dictionary = RootPackage.rehydrate(424242, package)
	_expect_true(failures, "runtime-incompatible historical package remains structurally decodable", bool(result.get("success", false)))
	_expect_true(failures, "runtime-incompatible historical package is classified incompatible", not bool(result.get("compatible", true)))
	if bool(result.get("success", false)):
		_expect_equal(
			failures,
			"runtime incompatibility preserves historical manifest ID",
			result["context"].generator_manifest_id,
			historical_id
		)
		_expect_true(
			failures,
			"runtime incompatibility preserves historical manifest prefix",
			result["context"].generator_manifest.canonical_text().begins_with("gm7|")
		)


static func _test_world_id_contract_rehydration(failures: Array[String]) -> void:
	var context = Context.new(424242)
	var package: Dictionary = RootPackage.encode(context)
	var old_contract: Dictionary = WorldId.current_contract_descriptor()
	var simulated_new_contract: Dictionary = {
		"revision": 2,
		"prefix": "wid2:",
		"contract_tag": "underworld-world-id-v2",
	}
	var compatible_with_both: Dictionary = RootPackage.rehydrate(
		424242,
		package,
		{},
		[old_contract, simulated_new_contract]
	)
	_expect_true(
		failures,
		"historical wid1 remains compatible when a newer default is also supported",
		bool(compatible_with_both.get("compatible", false))
	)
	if bool(compatible_with_both.get("success", false)):
		_expect_equal(
			failures,
			"newer supported WorldId contract cannot rewrite captured wid1",
			compatible_with_both["context"].world_id,
			GOLDEN_WORLD_ID_424242
		)

	var unsupported_contract: Dictionary = {
		"revision": 99,
		"prefix": "wid99:",
		"contract_tag": "fixture-world-id-v99",
	}
	var unsupported_id: String = "wid99:" + "a".repeat(64)
	var unsupported_package: Dictionary = package.duplicate(true)
	unsupported_package["world_id_contract"] = unsupported_contract
	unsupported_package["world_id"] = unsupported_id
	var unsupported: Dictionary = RootPackage.rehydrate(424242, unsupported_package)
	_expect_true(
		failures,
		"unsupported WorldId contract remains structurally decodable",
		bool(unsupported.get("success", false))
	)
	_expect_true(
		failures,
		"unsupported WorldId contract fails runtime compatibility",
		not bool(unsupported.get("compatible", true))
	)
	if bool(unsupported.get("success", false)):
		_expect_equal(
			failures,
			"unsupported WorldId compatibility failure cannot rewrite saved identity",
			unsupported["context"].world_id,
			unsupported_id
		)


static func _test_malformed_and_duplicate_package_entries(failures: Array[String]) -> void:
	var package: Dictionary = RootPackage.encode(Context.new(424242))

	var duplicate_stage: Dictionary = package.duplicate(true)
	duplicate_stage["manifest_snapshot"]["stage_entries"].append(
		duplicate_stage["manifest_snapshot"]["stage_entries"][0].duplicate(true)
	)
	var duplicate_stage_result: Dictionary = RootPackage.decode(duplicate_stage)
	_expect_true(
		failures,
		"duplicate stage package entry fails closed",
		not bool(duplicate_stage_result.get("success", true))
	)
	_expect_contains(
		failures,
		"duplicate stage package diagnostic is deterministic",
		duplicate_stage_result.get("failures", []),
		"duplicate stage revision key"
	)

	var duplicate_profile: Dictionary = package.duplicate(true)
	duplicate_profile["manifest_snapshot"]["profile_entries"].append(
		duplicate_profile["manifest_snapshot"]["profile_entries"][0].duplicate(true)
	)
	var duplicate_profile_result: Dictionary = RootPackage.decode(duplicate_profile)
	_expect_true(
		failures,
		"duplicate profile package entry fails closed",
		not bool(duplicate_profile_result.get("success", true))
	)
	_expect_contains(
		failures,
		"duplicate profile package diagnostic is deterministic",
		duplicate_profile_result.get("failures", []),
		"duplicate profile revision key"
	)

	var duplicate_domain: Dictionary = package.duplicate(true)
	duplicate_domain["manifest_snapshot"]["seed_domain_descriptors"].append(
		duplicate_domain["manifest_snapshot"]["seed_domain_descriptors"][0].duplicate(true)
	)
	var duplicate_domain_result: Dictionary = RootPackage.decode(duplicate_domain)
	_expect_true(
		failures,
		"duplicate seed-domain package entry fails closed",
		not bool(duplicate_domain_result.get("success", true))
	)
	_expect_contains(
		failures,
		"duplicate seed-domain package diagnostic is deterministic",
		duplicate_domain_result.get("failures", []),
		"duplicate seed-domain ID"
	)

	var malformed: Dictionary = package.duplicate(true)
	malformed.erase("world_id_contract")
	var malformed_result: Dictionary = RootPackage.decode(malformed)
	_expect_true(
		failures,
		"missing package entry fails closed",
		not bool(malformed_result.get("success", true))
	)
	_expect_contains(
		failures,
		"missing package entry diagnostic is deterministic",
		malformed_result.get("failures", []),
		"missing field: world_id_contract"
	)


static func _test_context_immutability_and_provenance(failures: Array[String]) -> void:
	var source_manifest = GeneratorManifest.foundation_default()
	var context = Context.new(424242, source_manifest)
	var baseline_header: Dictionary = context.canonical_header()
	var baseline_contract: Dictionary = context.world_id_contract()

	context.world_seed = 1
	context.world_id = "world:wrong"
	context.generator_manifest_id = "manifest:wrong"
	context.generator_manifest = GeneratorManifest.new({"macro_region": 99})

	var returned_contract: Dictionary = context.world_id_contract()
	returned_contract["revision"] = 999
	var returned_snapshot: Dictionary = context.manifest_snapshot()
	returned_snapshot["manifest_schema_version"] = 999
	source_manifest.seed_schema_version = 999

	_expect_equal(failures, "context identity scalars cannot be externally mutated", context.canonical_header(), baseline_header)
	_expect_equal(failures, "context returned WorldId contract cannot alias authority", context.world_id_contract(), baseline_contract)
	_expect_empty(failures, "immutable context remains operationally valid", context.validate())

	var package: Dictionary = RootPackage.encode(context)
	var rehydrated: Dictionary = RootPackage.rehydrate(424242, package)
	if not bool(rehydrated.get("success", false)):
		failures.append("provenance rehydrate fixture failed: " + str(rehydrated.get("failures", [])))
		return
	var restored = rehydrated["context"]
	var provenance = restored.make_provenance("macro_region", "region:test", "address:test")
	_expect_empty(
		failures,
		"provenance from rehydrated context validates against exact pinned identity",
		restored.validate_provenance(provenance)
	)

	var restored_header: Dictionary = restored.canonical_header()
	package["world_id"] = "wid1:" + "b".repeat(64)
	package["manifest_snapshot"]["manifest_schema_version"] = 999
	_expect_equal(
		failures,
		"caller mutation of package after rehydrate cannot alter context",
		restored.canonical_header(),
		restored_header
	)


static func _expect_contains(
	failures: Array[String],
	label: String,
	actual_failures,
	expected_fragment: String
) -> void:
	for failure in actual_failures:
		if expected_fragment in str(failure):
			return
	failures.append(
		"%s — expected diagnostic containing '%s', got %s"
		% [label, expected_fragment, str(actual_failures)]
	)


static func _expect_empty(failures: Array[String], label: String, actual: Array[String]) -> void:
	if not actual.is_empty():
		failures.append("%s — expected no failures, got %s" % [label, str(actual)])


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(
	failures: Array[String],
	label: String,
	actual,
	expected
) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])
