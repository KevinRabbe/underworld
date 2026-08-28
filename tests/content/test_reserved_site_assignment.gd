extends RefCounted

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const HookDefinition := preload("res://worldgen/graph/special_location_hook_definition.gd")
const Definition := preload("res://content/reserved_sites/reserved_site_content_definition.gd")
const Service := preload("res://content/reserved_sites/reserved_site_assignment_service.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_assignment_preserves_procedural_site(failures)
	_test_assignment_order_independence(failures)
	_test_ineligible_and_invalid_definitions_fail(failures)
	_test_rulebook_revision_participates_in_assignment_identity(failures)
	return failures


static func _test_assignment_preserves_procedural_site(failures: Array[String]) -> void:
	var hook = _hook(0, "reserved_site", Vector3(0.25, 0.55, 0.75))
	var before: Dictionary = hook.canonical_data()
	var definition = Definition.new(
		"structure.underworld.crystal_shrine",
		[
			"category.structure",
			"category.structure.underworld",
			"category.structure.underworld.shrine",
		],
		["reserved_site"],
		1,
		1,
		Vector3.ZERO,
		Vector3.ONE,
		{"family": "shrine"}
	)
	var result: Dictionary = Service.assign([hook], [definition], 1)
	_expect_true(failures, "reserved-site assignment succeeds", bool(result.get("success", false)))
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
	_expect_true(failures, "semantic ID remains distinct from procedural StableId", assignment.content_id != assignment.site_stable_id)
	_expect_true(failures, "assignment fingerprint has its own namespace", assignment.assignment_fingerprint.begins_with("rsa1:"))
	_expect_true(
		failures,
		"subcategory classification is retained",
		assignment.categories.has("category.structure.underworld.shrine")
	)


static func _test_assignment_order_independence(failures: Array[String]) -> void:
	var hooks: Array = [
		_hook(0, "reserved_site", Vector3(0.20, 0.45, 0.70)),
		_hook(1, "reserved_site", Vector3(0.60, 0.35, 0.25)),
	]
	var definitions: Array = [
		Definition.new(
			"structure.underworld.crystal_shrine",
			["category.structure", "category.structure.underworld", "category.structure.underworld.shrine"],
			["reserved_site"],
			2
		),
		Definition.new(
			"structure.underworld.watch_post",
			["category.structure", "category.structure.underworld", "category.structure.underworld.outpost"],
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


static func _test_ineligible_and_invalid_definitions_fail(failures: Array[String]) -> void:
	var hook = _hook(2, "reserved_site", Vector3(0.10, 0.20, 0.30))
	var incompatible = Definition.new(
		"structure.underworld.deep_vault",
		["category.structure", "category.structure.underworld", "category.structure.underworld.vault"],
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
		["category.structure"],
		["reserved_site"],
		1
	)
	var invalid_result: Dictionary = Service.assign([hook], [invalid], 1)
	_expect_true(failures, "invalid semantic content ID is rejected", not bool(invalid_result.get("success", true)))
	_expect_true(
		failures,
		"invalid semantic ID reports the content contract",
		_contains_diagnostic(invalid_result.get("diagnostics", []), "semantic content ID")
	)

	var profile_limited = Definition.new(
		"structure.underworld.deep_sanctum",
		["category.structure", "category.structure.underworld", "category.structure.underworld.sanctum"],
		["reserved_site"],
		1,
		1,
		Vector3(0.0, 0.8, 0.8),
		Vector3.ONE
	)
	var profile_result: Dictionary = Service.assign([hook], [profile_limited], 1)
	_expect_true(failures, "profile-ineligible definition is rejected", not bool(profile_result.get("success", true)))


static func _test_rulebook_revision_participates_in_assignment_identity(failures: Array[String]) -> void:
	var hook = _hook(3, "reserved_site", Vector3(0.35, 0.45, 0.55))
	var definition = Definition.new(
		"structure.underworld.echo_chamber",
		["category.structure", "category.structure.underworld", "category.structure.underworld.landmark"],
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
	_expect_true(
		failures,
		"rulebook revision changes compatibility-sensitive assignment fingerprint",
		first.assignment_fingerprint != second.assignment_fingerprint
	)


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


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s: actual=%s expected=%s" % [label, actual, expected])
