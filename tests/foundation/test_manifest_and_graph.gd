extends RefCounted

const GeneratorManifest := preload("res://worldgen/versioning/generator_manifest.gd")
const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")
const GraphCanonicalizer := preload("res://worldgen/validation/graph_canonicalizer.gd")
const GraphValidator := preload("res://worldgen/validation/graph_validator.gd")
const SampleGraph := preload("res://tests/foundation/sample_graph_fixture.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_canonical_primitives(failures)
	_test_dictionary_order_independence(failures)
	_test_manifest_vector(failures)
	_test_manifest_order_independence(failures)
	_test_valid_graph(failures)
	_test_graph_collection_order_independence(failures)
	_test_graph_validator_rejects_bad_profile(failures)
	return failures


static func _test_canonical_primitives(failures: Array[String]) -> void:
	_expect_equal(
		failures,
		"canonical i64 byte vector",
		CanonicalValue.encode(1),
		"i6416:0100000000000000"
	)
	_expect_equal(
		failures,
		"canonical f64 byte vector",
		CanonicalValue.encode(1.5),
		"f6416:000000000000f83f"
	)
	_expect_equal(
		failures,
		"canonical UTF-8 string vector",
		CanonicalValue.encode("A"),
		"s2:41"
	)


static func _test_dictionary_order_independence(failures: Array[String]) -> void:
	var first: Dictionary = {}
	first["b"] = 2
	first["a"] = 1
	var second: Dictionary = {}
	second["a"] = 1
	second["b"] = 2
	_expect_equal(
		failures,
		"canonical dictionary ignores insertion order",
		CanonicalValue.encode(first),
		CanonicalValue.encode(second)
	)


static func _test_manifest_vector(failures: Array[String]) -> void:
	var manifest = GeneratorManifest.foundation_default()
	var manifest_failures: Array[String] = manifest.validate()
	if not manifest_failures.is_empty():
		failures.append_array(manifest_failures)
		return
	_expect_equal(
		failures,
		"foundation GeneratorManifest SHA-256 vector",
		manifest.manifest_id(),
		"gm-sha256:682c1e0e1026a7272b43f7932143d4155f58ad8756f60369889ac94592fc66f0"
	)


static func _test_manifest_order_independence(failures: Array[String]) -> void:
	var stages_a: Dictionary = {}
	stages_a["primary_topology"] = 1
	stages_a["macro_region"] = 1
	var stages_b: Dictionary = {}
	stages_b["macro_region"] = 1
	stages_b["primary_topology"] = 1

	var profiles_a: Dictionary = {"depth_grammar": 1, "entrance_bias": 2}
	var profiles_b: Dictionary = {"entrance_bias": 2, "depth_grammar": 1}
	var manifest_a = GeneratorManifest.new(stages_a, profiles_a, 2, 1)
	var manifest_b = GeneratorManifest.new(stages_b, profiles_b, 2, 1)

	_expect_equal(
		failures,
		"GeneratorManifest ignores dictionary insertion order",
		manifest_a.manifest_id(),
		manifest_b.manifest_id()
	)

	var changed = GeneratorManifest.new(stages_b, profiles_b, 2, 2)
	_expect_true(
		failures,
		"changing deterministic contract changes manifest ID",
		changed.manifest_id() != manifest_a.manifest_id()
	)


static func _test_valid_graph(failures: Array[String]) -> void:
	var bundle = SampleGraph.build()
	var graph_failures: Array[String] = GraphValidator.validate_region_bundle(bundle)
	for failure in graph_failures:
		failures.append("valid sample graph: " + failure)

	var fingerprint: String = GraphCanonicalizer.region_bundle_fingerprint(bundle)
	_expect_true(
		failures,
		"valid graph produces canonical fingerprint",
		fingerprint.begins_with("sha256:") and fingerprint.length() == 71
	)


static func _test_graph_collection_order_independence(failures: Array[String]) -> void:
	var normal = SampleGraph.build(false)
	var reversed = SampleGraph.build(true)
	_expect_equal(
		failures,
		"graph fingerprint ignores definition collection order",
		GraphCanonicalizer.region_bundle_fingerprint(normal),
		GraphCanonicalizer.region_bundle_fingerprint(reversed)
	)


static func _test_graph_validator_rejects_bad_profile(failures: Array[String]) -> void:
	var bundle = SampleGraph.build()
	bundle.nodes[0].profile_blend = Vector3(0.8, 0.8, 0.0)
	var graph_failures: Array[String] = GraphValidator.validate_region_bundle(bundle)
	var found_expected_failure: bool = false
	for failure in graph_failures:
		if "not normalized" in failure:
			found_expected_failure = true
			break
	_expect_true(
		failures,
		"graph validator rejects non-normalized depth profile",
		found_expected_failure
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
