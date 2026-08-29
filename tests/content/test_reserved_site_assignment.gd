extends RefCounted

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const HookDefinition := preload("res://worldgen/graph/special_location_hook_definition.gd")
const ContentId := preload("res://core/content/identity/content_id.gd")
const ContentDefinition := preload("res://core/content/registry/content_definition.gd")
const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const Definition := preload("res://content/reserved_sites/reserved_site_content_definition.gd")
const Service := preload("res://content/reserved_sites/reserved_site_assignment_service.gd")

const CATEGORY_STRUCTURE := "category.structure"
const CATEGORY_UNDERWORLD := "category.structure.underworld"
const CATEGORY_LANDMARK := "category.structure.underworld.landmark"
const CATEGORY_SHRINE := "category.structure.underworld.shrine"
const CATEGORY_OUTPOST := "category.structure.underworld.outpost"
const CATEGORY_VAULT := "category.structure.underworld.vault"
const CATEGORY_SANCTUM := "category.structure.underworld.sanctum"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_definition_uses_core_content_contract(failures)
	_test_category_declarations_use_generic_validation(failures)
	_test_reserved_site_requires_non_empty_category_ids(failures)
	_test_assignment_preserves_procedural_site(failures)
	_test_category_order_and_fingerprint_are_canonical(failures)
	_test_assignment_order_independence(failures)
	_test_hook_categories_remain_independent(failures)
	_test_ineligible_and_invalid_definitions_fail(failures)
	_test_rulebook_revision_participates_in_assignment_identity(failures)
	return failures


static func _test_definition_uses_core_content_contract(failures: Array[String]) -> void:
	var declared_categories: Array[String] = [
		CATEGORY_STRUCTURE,
		CATEGORY_UNDERWORLD,
		CATEGORY_LANDMARK,
	]
	var definition = Definition.new(
		"structure.underworld.registry_probe",
		declared_categories,
		["reserved_site"],
		2,
		3
	)
	_expect_true(failures, "reserved-site definition inherits ContentDefinition", definition is ContentDefinition)
	_expect_true(failures, "reserved-site content ID uses canonical ContentId", ContentId.is_valid(definition.content_id))
	_expect_equal(failures, "definition family derives from canonical content ID", definition.definition_family, "structure")
	_expect_equal(failures, "reserved-site definition uses inherited schema revision", definition.schema_revision, 3)
	_expect_equal(failures, "reserved-site definition stores categories only in inherited category_ids", definition.category_ids, declared_categories)
	_expect_true(failures, "reserved-site subtype validates through ContentDefinition", definition.validate_definition().is_empty())
	var descriptor: Dictionary = definition.canonical_descriptor()
	_expect_equal(failures, "canonical descriptor exposes inherited category_ids", descriptor.get("category_ids", []), declared_categories)
	_expect_true(failures, "canonical descriptor has no duplicate family-owned categories field", not descriptor.has("categories"))

	var registry = ContentRegistry.new()
	var registry_failures: Array[String] = registry.index_definitions([definition])
	_expect_true(failures, "ContentRegistry accepts reserved-site ContentDefinition subtype", registry_failures.is_empty())
	var resolved: Dictionary = registry.resolve(definition.content_id, "structure")
	_expect_true(
		failures,
		"ContentRegistry resolves reserved-site subtype without diagnostics",
		resolved.get("diagnostics", []).is_empty()
	)
	_expect_true(failures, "ContentRegistry preserves reserved-site definition object", resolved.get("definition") == definition)
	var manifest: Array[Dictionary] = registry.canonical_manifest()
	_expect_equal(failures, "ContentRegistry manifest contains reserved-site subtype", manifest.size(), 1)
	if not manifest.is_empty():
		_expect_equal(failures, "manifest keeps inherited family", manifest[0].get("definition_family"), "structure")
		_expect_equal(failures, "manifest keeps inherited schema revision", manifest[0].get("schema_revision"), 3)
		_expect_equal(failures, "manifest observes the inherited category_ids truth", manifest[0].get("category_ids", []), declared_categories)
		_expect_true(failures, "manifest does not expose a second categories truth", not manifest[0].has("categories"))

	var validation: Dictionary = ContentValidationPipeline.new().validate_all(
		[definition],
		_categories(),
		_capabilities()
	)
	_expect_true(failures, "registered reserved-site categories pass CONTENT-005 validation", bool(validation.get("success", false)))


static func _test_category_declarations_use_generic_validation(failures: Array[String]) -> void:
	var malformed = Definition.new(
		"structure.underworld.malformed_category",
		["category.Structure"],
		["reserved_site"],
		1
	)
	var malformed_local: Array[String] = malformed.validate_definition()
	_expect_true(
		failures,
		"malformed category fails inherited SchemaId validation",
		_contains_diagnostic(malformed_local, "declared category")
	)
	_expect_true(
		failures,
		"CONTENT-001 no longer reports its removed local category parser",
		not _contains_diagnostic(malformed_local, "Invalid reserved-site category reference")
	)
	var malformed_result: Dictionary = ContentValidationPipeline.new().validate_all(
		[malformed],
		_categories(),
		_capabilities()
	)
	_expect_true(
		failures,
		"malformed category routes through generic definition validation",
		_has_code_fragment(malformed_result, "definition_invalid", "declared category")
	)

	var duplicate = Definition.new(
		"structure.underworld.duplicate_category",
		[CATEGORY_STRUCTURE, CATEGORY_STRUCTURE],
		["reserved_site"],
		1
	)
	var duplicate_result: Dictionary = ContentValidationPipeline.new().validate_all(
		[duplicate],
		_categories(),
		_capabilities()
	)
	_expect_true(
		failures,
		"duplicate category declaration routes through inherited ContentDefinition",
		_has_code_fragment(duplicate_result, "definition_invalid", "duplicate declared category schema id")
	)

	var unknown = Definition.new(
		"structure.underworld.unknown_category",
		[CATEGORY_STRUCTURE, "category.structure.underworld.missing"],
		["reserved_site"],
		1
	)
	_expect_true(failures, "unknown-but-well-formed category passes local schema syntax", unknown.validate_definition().is_empty())
	var unknown_result: Dictionary = ContentValidationPipeline.new().validate_all(
		[unknown],
		_categories(),
		_capabilities()
	)
	_expect_true(
		failures,
		"missing registered category is rejected by CONTENT-005",
		_has_code_fragment(unknown_result, "category_unknown", "unknown category schema id")
	)


static func _test_reserved_site_requires_non_empty_category_ids(failures: Array[String]) -> void:
	var empty_categories = Definition.new(
		"structure.underworld.empty_categories",
		[],
		["reserved_site"],
		1
	)
	var local_failures: Array[String] = empty_categories.validate_definition()
	_expect_true(
		failures,
		"reserved-site family rejects empty category_ids locally",
		_contains_diagnostic(local_failures, "at least one category_id")
	)
	var validation: Dictionary = ContentValidationPipeline.new().validate_all(
		[empty_categories],
		_categories(),
		_capabilities()
	)
	_expect_true(
		failures,
		"empty reserved-site category_ids route through definition validation",
		_has_code_fragment(validation, "definition_invalid", "at least one category_id")
	)
	var assignment_result: Dictionary = Service.assign(
		[_hook(7, "reserved_site", Vector3(0.25, 0.25, 0.25))],
		[empty_categories],
		1
	)
	_expect_true(
		failures,
		"assignment rejects a reserved-site definition with empty category_ids",
		not bool(assignment_result.get("success", true))
	)
	_expect_true(
		failures,
		"assignment preserves the family non-empty category diagnostic",
		_contains_diagnostic(assignment_result.get("diagnostics", []), "at least one category_id")
	)


static func _test_assignment_preserves_procedural_site(failures: Array[String]) -> void:
	var hook = _hook(0, "reserved_site", Vector3(0.25, 0.55, 0.75))
	var before: Dictionary = hook.canonical_data()
	var definition = Definition.new(
		"structure.underworld.crystal_shrine",
		[CATEGORY_STRUCTURE, CATEGORY_UNDERWORLD, CATEGORY_SHRINE],
		["reserved_site"],
		1,
		1,
		Vector3.ZERO,
		Vector3.ONE,
		{"family": "shrine"}
	)
	var result: Dictionary = Service.assign([hook], [definition], 1)
	_expect_true(failures, "registry-independent reserved-site assignment succeeds", bool(result.get("success", false)))
	if not bool(result.get("success", false)):
		return
	_expect_equal(failures, "assignment does not mutate source hook", hook.canonical_data(), before)
	_expect_equal(failures, "one assignment is emitted", result["assignments"].size(), 1)
	if result["assignments"].is_empty():
		return
	var assignment = result["assignments"][0]
	_expect_equal(failures, "procedural StableId is preserved", assignment.site_stable_id, hook.stable_id)
	_expect_equal(failures, "reserved bounds are preserved", assignment.site_bounds, hook.reserved_bounds)
	_expect_equal(failures, "semantic content ID is assigned", assignment.content_id, definition.content_id)
	_expect_equal(failures, "assignment snapshots canonical schema revision", assignment.content_schema_revision, definition.schema_revision)
	_expect_equal(
		failures,
		"assignment category snapshot comes from inherited category_ids",
		assignment.category_ids,
		definition.canonical_descriptor().get("category_ids", [])
	)
	var canonical: Dictionary = assignment.canonical_data()
	_expect_equal(failures, "assignment canonical data exposes category_ids", canonical.get("category_ids", []), assignment.category_ids)
	_expect_true(failures, "assignment canonical data has no ambiguous categories key", not canonical.has("categories"))
	_expect_true(failures, "semantic ID remains distinct from procedural StableId", assignment.content_id != assignment.site_stable_id)
	_expect_true(failures, "assignment fingerprint has its own namespace", assignment.assignment_fingerprint.begins_with("rsa1:"))


static func _test_category_order_and_fingerprint_are_canonical(failures: Array[String]) -> void:
	var hook = _hook(1, "reserved_site", Vector3(0.35, 0.45, 0.55))
	var ordered = Definition.new(
		"structure.underworld.category_probe",
		[CATEGORY_STRUCTURE, CATEGORY_UNDERWORLD, CATEGORY_SHRINE],
		["reserved_site"],
		1,
		2
	)
	var reordered = Definition.new(
		"structure.underworld.category_probe",
		[CATEGORY_SHRINE, CATEGORY_STRUCTURE, CATEGORY_UNDERWORLD],
		["reserved_site"],
		1,
		2
	)
	_expect_equal(
		failures,
		"caller category order cannot change canonical definition descriptor",
		ordered.canonical_descriptor(),
		reordered.canonical_descriptor()
	)
	var forward: Dictionary = Service.assign([hook], [ordered], 5)
	var reverse: Dictionary = Service.assign([hook], [reordered], 5)
	_expect_true(failures, "ordered category assignment succeeds", bool(forward.get("success", false)))
	_expect_true(failures, "reordered category assignment succeeds", bool(reverse.get("success", false)))
	if bool(forward.get("success", false)) and bool(reverse.get("success", false)):
		_expect_equal(
			failures,
			"caller category order cannot change assignment overlay/fingerprint",
			forward["assignments"][0].canonical_data(),
			reverse["assignments"][0].canonical_data()
		)

	var changed = Definition.new(
		"structure.underworld.category_probe",
		[CATEGORY_STRUCTURE, CATEGORY_UNDERWORLD, CATEGORY_LANDMARK],
		["reserved_site"],
		1,
		2
	)
	var changed_result: Dictionary = Service.assign([hook], [changed], 5)
	_expect_true(failures, "changed category assignment succeeds", bool(changed_result.get("success", false)))
	if bool(forward.get("success", false)) and bool(changed_result.get("success", false)):
		var first = forward["assignments"][0]
		var second = changed_result["assignments"][0]
		_expect_equal(failures, "category change does not alter procedural StableId", first.site_stable_id, second.site_stable_id)
		_expect_equal(failures, "category change does not alter reserved bounds", first.site_bounds, second.site_bounds)
		_expect_equal(failures, "category change does not alter semantic content ID", first.content_id, second.content_id)
		_expect_true(
			failures,
			"category declaration participates in assignment compatibility fingerprint",
			first.assignment_fingerprint != second.assignment_fingerprint
		)


static func _test_assignment_order_independence(failures: Array[String]) -> void:
	var hooks: Array = [
		_hook(2, "reserved_site", Vector3(0.20, 0.45, 0.70)),
		_hook(3, "reserved_site", Vector3(0.60, 0.35, 0.25)),
	]
	var definitions: Array = [
		Definition.new(
			"structure.underworld.crystal_shrine",
			[CATEGORY_STRUCTURE, CATEGORY_UNDERWORLD, CATEGORY_SHRINE],
			["reserved_site"],
			2
		),
		Definition.new(
			"structure.underworld.watch_post",
			[CATEGORY_STRUCTURE, CATEGORY_UNDERWORLD, CATEGORY_OUTPOST],
			["reserved_site"],
			3
		),
	]
	var forward: Dictionary = Service.assign(hooks, definitions, 4)
	var reversed_hooks: Array = hooks.duplicate()
	reversed_hooks.reverse()
	var reversed_definitions: Array = definitions.duplicate()
	reversed_definitions.reverse()
	var reverse: Dictionary = Service.assign(reversed_hooks, reversed_definitions, 4)
	_expect_true(failures, "forward assignment succeeds", bool(forward.get("success", false)))
	_expect_true(failures, "reversed assignment succeeds", bool(reverse.get("success", false)))
	if not bool(forward.get("success", false)) or not bool(reverse.get("success", false)):
		return
	_expect_equal(
		failures,
		"runtime array order cannot change assignment output",
		_assignment_data(forward["assignments"]),
		_assignment_data(reverse["assignments"])
	)


static func _test_hook_categories_remain_independent(failures: Array[String]) -> void:
	var hook = _hook(4, "reserved_site", Vector3(0.25, 0.25, 0.25))
	var reserved = Definition.new(
		"structure.underworld.hook_probe",
		[CATEGORY_STRUCTURE, CATEGORY_UNDERWORLD, CATEGORY_LANDMARK],
		["reserved_site"],
		1
	)
	var boss_only = Definition.new(
		"structure.underworld.hook_probe",
		[CATEGORY_STRUCTURE, CATEGORY_UNDERWORLD, CATEGORY_LANDMARK],
		["boss_site"],
		1
	)
	_expect_equal(
		failures,
		"hook eligibility does not alter generic CategorySchema identity",
		reserved.canonical_descriptor().get("category_ids", []),
		boss_only.canonical_descriptor().get("category_ids", [])
	)
	var reserved_result: Dictionary = Service.assign([hook], [reserved], 1)
	var boss_result: Dictionary = Service.assign([hook], [boss_only], 1)
	_expect_true(failures, "reserved-site hook vocabulary remains eligible independently", bool(reserved_result.get("success", false)))
	_expect_true(failures, "boss-only hook vocabulary remains ineligible independently", not bool(boss_result.get("success", true)))


static func _test_ineligible_and_invalid_definitions_fail(failures: Array[String]) -> void:
	var hook = _hook(5, "reserved_site", Vector3(0.10, 0.20, 0.30))
	var incompatible = Definition.new(
		"structure.underworld.deep_vault",
		[CATEGORY_STRUCTURE, CATEGORY_UNDERWORLD, CATEGORY_VAULT],
		["boss_site"],
		1
	)
	var ineligible: Dictionary = Service.assign([hook], [incompatible], 1)
	_expect_true(failures, "ineligible content is rejected", not bool(ineligible.get("success", true)))
	_expect_true(
		failures,
		"ineligible failure is actionable",
		_contains_diagnostic(ineligible.get("diagnostics", []), "No eligible reserved-site content")
	)

	var invalid = Definition.new(
		"Invalid Content Id",
		[CATEGORY_STRUCTURE],
		["reserved_site"],
		1
	)
	var invalid_result: Dictionary = Service.assign([hook], [invalid], 1)
	_expect_true(failures, "invalid semantic content ID is rejected", not bool(invalid_result.get("success", true)))
	_expect_true(
		failures,
		"invalid semantic ID reports canonical ContentId diagnostics",
		_contains_diagnostic(invalid_result.get("diagnostics", []), "content id")
	)

	var invalid_revision = Definition.new(
		"structure.underworld.invalid_revision",
		[CATEGORY_STRUCTURE],
		["reserved_site"],
		1,
		0
	)
	var revision_result: Dictionary = Service.assign([hook], [invalid_revision], 1)
	_expect_true(failures, "invalid schema revision is rejected by ContentDefinition", not bool(revision_result.get("success", true)))
	_expect_true(
		failures,
		"invalid schema revision reports canonical ContentDefinition diagnostics",
		_contains_diagnostic(revision_result.get("diagnostics", []), "schema revision")
	)

	var profile_limited = Definition.new(
		"structure.underworld.deep_sanctum",
		[CATEGORY_STRUCTURE, CATEGORY_UNDERWORLD, CATEGORY_SANCTUM],
		["reserved_site"],
		1,
		1,
		Vector3(0.0, 0.8, 0.8),
		Vector3.ONE
	)
	var profile_result: Dictionary = Service.assign([hook], [profile_limited], 1)
	_expect_true(failures, "profile-ineligible definition is rejected", not bool(profile_result.get("success", true)))


static func _test_rulebook_revision_participates_in_assignment_identity(failures: Array[String]) -> void:
	var hook = _hook(6, "reserved_site", Vector3(0.35, 0.45, 0.55))
	var definition = Definition.new(
		"structure.underworld.echo_chamber",
		[CATEGORY_STRUCTURE, CATEGORY_UNDERWORLD, CATEGORY_LANDMARK],
		["reserved_site"],
		1,
		7
	)
	var revision_one: Dictionary = Service.assign([hook], [definition], 1)
	var revision_two: Dictionary = Service.assign([hook], [definition], 2)
	_expect_true(failures, "rulebook revision one succeeds", bool(revision_one.get("success", false)))
	_expect_true(failures, "rulebook revision two succeeds", bool(revision_two.get("success", false)))
	if not bool(revision_one.get("success", false)) or not bool(revision_two.get("success", false)):
		return
	var first = revision_one["assignments"][0]
	var second = revision_two["assignments"][0]
	_expect_equal(failures, "rulebook revision does not alter site StableId", first.site_stable_id, second.site_stable_id)
	_expect_equal(failures, "rulebook revision does not alter reserved bounds", first.site_bounds, second.site_bounds)
	_expect_equal(failures, "rulebook revision does not alter semantic definition", first.content_id, second.content_id)
	_expect_equal(failures, "rulebook revision does not alter content schema revision", first.content_schema_revision, second.content_schema_revision)
	_expect_true(
		failures,
		"rulebook revision changes compatibility-sensitive assignment fingerprint",
		first.assignment_fingerprint != second.assignment_fingerprint
	)


static func _categories():
	var registry = CategorySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CategorySchema.new().configure(CATEGORY_STRUCTURE),
		CategorySchema.new().configure(CATEGORY_UNDERWORLD, [CATEGORY_STRUCTURE]),
		CategorySchema.new().configure(CATEGORY_LANDMARK, [CATEGORY_UNDERWORLD]),
		CategorySchema.new().configure(CATEGORY_SHRINE, [CATEGORY_UNDERWORLD]),
		CategorySchema.new().configure(CATEGORY_OUTPOST, [CATEGORY_UNDERWORLD]),
		CategorySchema.new().configure(CATEGORY_VAULT, [CATEGORY_UNDERWORLD]),
		CategorySchema.new().configure(CATEGORY_SANCTUM, [CATEGORY_UNDERWORLD]),
	])
	assert(diagnostics.is_empty())
	return registry


static func _capabilities():
	var registry = CapabilitySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([])
	assert(diagnostics.is_empty())
	return registry


static func _hook(slot: int, semantic_category: String, profile: Vector3):
	var region_address = StableAddress.underground_region(4, -2)
	var address = StableAddress.special_location(region_address, "reserved_site", slot)
	return HookDefinition.new(
		address,
		"sid1:owner-region-fixture",
		"sid1:anchor-node-fixture-%d" % slot,
		"",
		Vector3(float(slot) * 10.0, -20.0, 5.0),
		semantic_category,
		AABB(Vector3(float(slot) * 10.0, -24.0, 1.0), Vector3(12.0, 8.0, 12.0)),
		profile,
		{"fixture_slot": slot}
	)


static func _assignment_data(assignments: Array) -> Array:
	var result: Array = []
	for assignment in assignments:
		result.append(assignment.canonical_data())
	return result


static func _contains_diagnostic(diagnostics: Array, needle: String) -> bool:
	for diagnostic in diagnostics:
		if str(diagnostic).contains(needle):
			return true
	return false


static func _has_code_fragment(result: Dictionary, code: String, fragment: String) -> bool:
	for diagnostic in result.get("diagnostics", []):
		if (
			str(diagnostic.get("code", "")) == code
			and str(diagnostic.get("message", "")).contains(fragment)
		):
			return true
	return false


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s: actual=%s expected=%s" % [label, actual, expected])
