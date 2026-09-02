extends RefCounted

const GeneratorManifest := preload("res://worldgen/versioning/generator_manifest.gd")
const RootPackage := preload("res://worldgen/versioning/root_generation_identity_package.gd")
const Context := preload("res://worldgen/pipeline/world_generation_context.gd")
const WorldId := preload("res://worldgen/identity/world_id.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_returned_manifest_cannot_alias_context_authority(failures)
	_test_non_current_historical_world_id_uses_explicit_support(failures)
	return failures


static func _test_returned_manifest_cannot_alias_context_authority(
	failures: Array[String]
) -> void:
	var context = Context.new(424242, GeneratorManifest.foundation_default())
	var baseline_header: Dictionary = context.canonical_header()
	var baseline_manifest_id: String = context.generator_manifest_id
	var baseline_stage_revision: int = context.stage_contract_revision("macro_region")
	var baseline_provenance = context.make_provenance(
		"macro_region",
		"reviewer:region",
		"reviewer:address"
	)
	var baseline_provenance_fingerprint: String = baseline_provenance.fingerprint

	var returned_manifest = context.generator_manifest
	var hostile_snapshot: Dictionary = returned_manifest.snapshot()
	for entry_variant in hostile_snapshot.get("stage_entries", []):
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		if str(entry.get("id", "")) == "macro_region":
			entry["revision"] = 999
	hostile_snapshot["manifest_schema_prefix"] = "hostile"
	returned_manifest._apply_snapshot(hostile_snapshot)

	_expect_true(
		failures,
		"returned manifest attack mutates only the detached view",
		returned_manifest.stage_revisions().get("macro_region", 0) == 999
		and returned_manifest.canonical_text().begins_with("hostile|")
	)
	_expect_equal(
		failures,
		"returned manifest object cannot change context canonical header",
		context.canonical_header(),
		baseline_header
	)
	_expect_equal(
		failures,
		"returned manifest object cannot change context manifest ID",
		context.generator_manifest_id,
		baseline_manifest_id
	)
	_expect_equal(
		failures,
		"returned manifest object cannot change context stage revisions",
		context.stage_contract_revision("macro_region"),
		baseline_stage_revision
	)
	var after_provenance = context.make_provenance(
		"macro_region",
		"reviewer:region",
		"reviewer:address"
	)
	_expect_equal(
		failures,
		"returned manifest object cannot change context provenance",
		after_provenance.fingerprint,
		baseline_provenance_fingerprint
	)
	_expect_empty(
		failures,
		"context remains valid after detached manifest mutation",
		context.validate()
	)


static func _test_non_current_historical_world_id_uses_explicit_support(
	failures: Array[String]
) -> void:
	var world_seed: int = 424242
	var historical_contract: Dictionary = {
		"revision": 7,
		"prefix": "wid7:",
		"contract_tag": "fixture-world-id-v7",
	}
	var historical_source: String = "%s|seed|%d" % [
		str(historical_contract["contract_tag"]),
		world_seed,
	]
	var historical_world_id: String = (
		str(historical_contract["prefix"]) + historical_source.sha256_text()
	)
	var explicit_support: Array = [historical_contract.duplicate(true)]

	_expect_true(
		failures,
		"fixture historical WorldId contract is intentionally non-current",
		historical_contract != WorldId.current_contract_descriptor()
	)
	_expect_empty(
		failures,
		"explicitly supported non-current historical WorldId validates exactly",
		WorldId.validate_exact_for_seed(
			world_seed,
			historical_world_id,
			historical_contract,
			explicit_support
		)
	)
	var derived = WorldId.from_seed_with_contract(
		world_seed,
		historical_contract,
		explicit_support
	)
	_expect_true(
		failures,
		"explicit historical support is preserved through exact derivation",
		derived != null and derived.value() == historical_world_id
	)
	_expect_true(
		failures,
		"same non-current historical contract remains unsupported by current defaults alone",
		not WorldId.validate_exact_for_seed(
			world_seed,
			historical_world_id,
			historical_contract
		).is_empty()
	)

	var package: Dictionary = RootPackage.encode(Context.new(world_seed))
	package["world_id"] = historical_world_id
	package["world_id_contract"] = historical_contract.duplicate(true)
	var rehydrated: Dictionary = RootPackage.rehydrate(
		world_seed,
		package,
		{},
		explicit_support
	)
	_expect_true(
		failures,
		"package rehydrate accepts explicitly supported non-current historical WorldId",
		bool(rehydrated.get("success", false))
		and bool(rehydrated.get("compatible", false))
	)
	if bool(rehydrated.get("success", false)):
		var restored = rehydrated.get("context")
		_expect_equal(
			failures,
			"historical package rehydrate preserves exact saved WorldId",
			restored.world_id,
			historical_world_id
		)
		_expect_equal(
			failures,
			"historical package rehydrate preserves exact captured WorldId contract",
			restored.world_id_contract(),
			historical_contract
		)


static func _expect_empty(
	failures: Array[String],
	label: String,
	actual: Array[String]
) -> void:
	if not actual.is_empty():
		failures.append("%s — expected no failures, got %s" % [label, str(actual)])


static func _expect_true(
	failures: Array[String],
	label: String,
	condition: bool
) -> void:
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
