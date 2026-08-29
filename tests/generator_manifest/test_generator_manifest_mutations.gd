extends RefCounted

const GeneratorManifest := preload("res://worldgen/versioning/generator_manifest.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_stage_revision_order(failures)
	_test_profile_revision_order(failures)
	_test_stage_revision_mutation(failures)
	_test_profile_revision_mutation(failures)
	_test_contract_revision_mutation(failures)
	_test_valid_provenance_revision(failures)
	_test_invalid_revisions(failures)
	_test_revision_map_copy_boundary(failures)
	return failures


static func _test_stage_revision_order(failures: Array[String]) -> void:
	var stages_a: Dictionary = {}
	stages_a["region_finalization"] = 4
	stages_a["macro_region"] = 1
	stages_a["secondary_connectivity"] = 3
	var stages_b: Dictionary = {}
	stages_b["secondary_connectivity"] = 3
	stages_b["region_finalization"] = 4
	stages_b["macro_region"] = 1
	var profiles: Dictionary = {"depth_grammar": 2}

	var first = GeneratorManifest.new(stages_a, profiles, 2, 1, 1)
	var second = GeneratorManifest.new(stages_b, profiles, 2, 1, 1)
	_expect_equal(
		failures,
		"stage insertion order canonical text",
		first.canonical_text(),
		second.canonical_text()
	)
	_expect_equal(
		failures,
		"stage insertion order manifest ID",
		first.manifest_id(),
		second.manifest_id()
	)


static func _test_profile_revision_order(failures: Array[String]) -> void:
	var stages: Dictionary = {"macro_region": 1}
	var profiles_a: Dictionary = {}
	profiles_a["entrance_bias"] = 3
	profiles_a["depth_grammar"] = 2
	profiles_a["chamber_shape"] = 5
	var profiles_b: Dictionary = {}
	profiles_b["chamber_shape"] = 5
	profiles_b["entrance_bias"] = 3
	profiles_b["depth_grammar"] = 2

	var first = GeneratorManifest.new(stages, profiles_a, 2, 1, 1)
	var second = GeneratorManifest.new(stages, profiles_b, 2, 1, 1)
	_expect_equal(
		failures,
		"profile insertion order canonical text",
		first.canonical_text(),
		second.canonical_text()
	)
	_expect_equal(
		failures,
		"profile insertion order manifest ID",
		first.manifest_id(),
		second.manifest_id()
	)


static func _test_stage_revision_mutation(failures: Array[String]) -> void:
	var baseline = GeneratorManifest.new(
		{"macro_region": 1, "primary_topology": 2},
		{"depth_grammar": 1},
		2,
		1,
		1
	)
	var changed = GeneratorManifest.new(
		{"macro_region": 1, "primary_topology": 3},
		{"depth_grammar": 1},
		2,
		1,
		1
	)
	_expect_true(
		failures,
		"changing one stage revision changes manifest ID",
		baseline.manifest_id() != changed.manifest_id()
	)


static func _test_profile_revision_mutation(failures: Array[String]) -> void:
	var baseline = GeneratorManifest.new(
		{"macro_region": 1},
		{"depth_grammar": 1, "entrance_bias": 2},
		2,
		1,
		1
	)
	var changed = GeneratorManifest.new(
		{"macro_region": 1},
		{"depth_grammar": 2, "entrance_bias": 2},
		2,
		1,
		1
	)
	_expect_true(
		failures,
		"changing one profile revision changes manifest ID",
		baseline.manifest_id() != changed.manifest_id()
	)


static func _test_contract_revision_mutation(failures: Array[String]) -> void:
	var stages: Dictionary = {"macro_region": 1}
	var profiles: Dictionary = {"depth_grammar": 1}
	var baseline = GeneratorManifest.new(stages, profiles, 2, 1, 1)
	var surface_changed = GeneratorManifest.new(stages, profiles, 3, 1, 1)
	var underworld_changed = GeneratorManifest.new(stages, profiles, 2, 2, 1)
	var provenance_changed = GeneratorManifest.new(stages, profiles, 2, 1, 2)

	_expect_true(
		failures,
		"changing surface contract revision changes manifest ID",
		baseline.manifest_id() != surface_changed.manifest_id()
	)
	_expect_true(
		failures,
		"changing underworld contract revision changes manifest ID",
		baseline.manifest_id() != underworld_changed.manifest_id()
	)
	_expect_true(
		failures,
		"changing provenance contract revision changes canonical text",
		baseline.canonical_text() != provenance_changed.canonical_text()
	)
	_expect_true(
		failures,
		"changing provenance contract revision changes manifest ID",
		baseline.manifest_id() != provenance_changed.manifest_id()
	)


static func _test_valid_provenance_revision(failures: Array[String]) -> void:
	var manifest = GeneratorManifest.new(
		{"macro_region": 1},
		{"depth_grammar": 1},
		2,
		1,
		7
	)
	_expect_empty(failures, "positive provenance revision accepted", manifest.validate())
	_expect_equal(
		failures,
		"positive provenance revision preserved",
		manifest.provenance_contract_revision,
		7
	)


static func _test_invalid_revisions(failures: Array[String]) -> void:
	_expect_invalid_contains(
		failures,
		"zero stage revision rejected",
		GeneratorManifest.new({"macro_region": 0}, {}, 1, 1, 1),
		"stage revision must be positive"
	)
	_expect_invalid_contains(
		failures,
		"negative stage revision rejected",
		GeneratorManifest.new({"macro_region": -2}, {}, 1, 1, 1),
		"stage revision must be positive"
	)
	_expect_invalid_contains(
		failures,
		"zero profile revision rejected",
		GeneratorManifest.new({}, {"depth_grammar": 0}, 1, 1, 1),
		"profile revision must be positive"
	)
	_expect_invalid_contains(
		failures,
		"negative profile revision rejected",
		GeneratorManifest.new({}, {"depth_grammar": -4}, 1, 1, 1),
		"profile revision must be positive"
	)
	_expect_invalid_contains(
		failures,
		"zero surface revision rejected",
		GeneratorManifest.new({}, {}, 0, 1, 1),
		"surface contract revision must be positive"
	)
	_expect_invalid_contains(
		failures,
		"negative surface revision rejected",
		GeneratorManifest.new({}, {}, -1, 1, 1),
		"surface contract revision must be positive"
	)
	_expect_invalid_contains(
		failures,
		"zero underworld revision rejected",
		GeneratorManifest.new({}, {}, 1, 0, 1),
		"Underworld contract revision must be positive"
	)
	_expect_invalid_contains(
		failures,
		"negative underworld revision rejected",
		GeneratorManifest.new({}, {}, 1, -1, 1),
		"Underworld contract revision must be positive"
	)
	_expect_invalid_contains(
		failures,
		"zero provenance revision rejected",
		GeneratorManifest.new({}, {}, 1, 1, 0),
		"provenance contract revision must be positive"
	)
	_expect_invalid_contains(
		failures,
		"negative provenance revision rejected",
		GeneratorManifest.new({}, {}, 1, 1, -3),
		"provenance contract revision must be positive"
	)


static func _test_revision_map_copy_boundary(failures: Array[String]) -> void:
	var manifest = GeneratorManifest.new(
		{"macro_region": 1, "primary_topology": 2},
		{"depth_grammar": 3, "entrance_bias": 4},
		2,
		1,
		1
	)
	var baseline_id: String = manifest.manifest_id()

	var stages: Dictionary = manifest.stage_revisions()
	stages["macro_region"] = 999
	stages.erase("primary_topology")
	stages["injected_stage"] = 7

	var profiles: Dictionary = manifest.profile_revisions()
	profiles["depth_grammar"] = 999
	profiles.clear()

	_expect_equal(
		failures,
		"returned stage revisions cannot mutate internal state",
		manifest.stage_revisions(),
		{"macro_region": 1, "primary_topology": 2}
	)
	_expect_equal(
		failures,
		"returned profile revisions cannot mutate internal state",
		manifest.profile_revisions(),
		{"depth_grammar": 3, "entrance_bias": 4}
	)
	_expect_equal(
		failures,
		"returned revision mutation cannot change manifest ID",
		manifest.manifest_id(),
		baseline_id
	)


static func _expect_invalid_contains(
	failures: Array[String],
	label: String,
	manifest: Variant,
	expected_fragment: String
) -> void:
	var validation_failures: Array[String] = manifest.validate()
	for failure in validation_failures:
		if expected_fragment in failure:
			return
	failures.append(
		"%s — expected diagnostic containing '%s', got %s"
		% [label, expected_fragment, str(validation_failures)]
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
	actual: Variant,
	expected: Variant
) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])
