extends RefCounted

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const AssignmentService := preload("res://content/reserved_sites/reserved_site_assignment_service.gd")
const PlacementService := preload("res://content/placement/underground_placement_service.gd")
const Catalog := preload("res://gameplay/resources/runtime/underground_resource_composition_catalog.gd")
const ContentEvidence := preload("res://gameplay/resources/runtime/underground_resource_content_evidence.gd")

const RESOURCE_PATH := "res://content/resources/iron_outcrop_definition.tres"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_production_iron_binding(failures)
	_test_channel_metadata_fails_closed(failures)
	_test_content_validation_evidence_is_snapshot_bound(failures)
	return failures


static func _test_production_iron_binding(failures: Array[String]) -> void:
	var definitions: Array = Catalog.reserved_site_definitions()
	_expect_equal(failures, "one M3 resource reserved-site definition is authored", definitions.size(), 1)
	if definitions.is_empty():
		return
	_expect_true(failures, "iron reserved-site definition validates", definitions[0].validate_definition().is_empty())
	_expect_equal(
		failures,
		"iron reserved-site definition declares resource placement channel",
		definitions[0].metadata.get("placement_channel", ""),
		Catalog.RESOURCE_CHANNEL
	)

	var assigned: Dictionary = AssignmentService.assign([_hook()], definitions, Catalog.RULEBOOK_REVISION)
	_expect_true(failures, "generated reserved site assigns production iron site content", bool(assigned.get("success", false)))
	if not bool(assigned.get("success", false)) or assigned.get("assignments", []).size() != 1:
		return
	var assignment = assigned["assignments"][0]
	var candidate = Catalog.candidate_from_assignment(assignment, Vector2i(-3, 4), 0)
	_expect_true(failures, "production resource assignment adapts to a channel-scoped candidate", candidate != null)
	if candidate == null:
		return
	var site_id = StableId.parse(assignment.site_stable_id)
	var expected_candidate_id = StableId.from_address(
		site_id.address().child(["channel", Catalog.RESOURCE_CHANNEL])
	)
	_expect_equal(
		failures,
		"resource candidate identity is derived below generated site identity",
		candidate.stable_id,
		expected_candidate_id.value()
	)
	_expect_equal(failures, "production resource candidate capacity stays one", candidate.local_capacity, 1)

	var resource = load(RESOURCE_PATH)
	_expect_true(failures, "production iron resource loads", resource != null)
	if resource == null:
		return
	var registry = ContentRegistry.new()
	var registry_failures: Array[String] = registry.index_definitions([resource])
	for failure in registry_failures:
		failures.append("iron composition registry: %s" % failure)
	if not registry_failures.is_empty():
		return
	var policies: Array = Catalog.placement_policies()
	_expect_equal(failures, "one M3 iron placement policy is authored", policies.size(), 1)
	if policies.is_empty():
		return
	_expect_true(failures, "iron placement policy validates", policies[0].validate_policy().is_empty())
	var plan: Dictionary = PlacementService.plan([candidate], policies, registry, Catalog.RULEBOOK_REVISION)
	_expect_true(failures, "production iron placement plan succeeds", bool(plan.get("success", false)))
	if not bool(plan.get("success", false)):
		return
	_expect_equal(failures, "one reserved site produces exactly one iron placement", plan.get("placements", []).size(), 1)
	if plan.get("placements", []).size() == 1:
		var placement = plan["placements"][0]
		_expect_equal(
			failures,
			"production placement targets accepted iron resource identity",
			placement.target_content_id,
			Catalog.IRON_RESOURCE_CONTENT_ID
		)
		var candidate_id = StableId.parse(candidate.stable_id)
		var expected_placement_id = StableId.from_address(
			candidate_id.address().child(["placement", "slot", "0"])
		)
		_expect_equal(
			failures,
			"final placement identity remains placement/slot child of channel candidate",
			placement.placement_stable_id,
			expected_placement_id.value()
		)


static func _test_channel_metadata_fails_closed(failures: Array[String]) -> void:
	var definitions: Array = Catalog.reserved_site_definitions()
	var assigned: Dictionary = AssignmentService.assign([_hook()], definitions, Catalog.RULEBOOK_REVISION)
	if not bool(assigned.get("success", false)) or assigned.get("assignments", []).is_empty():
		failures.append("channel failure fixture assignment failed")
		return
	var assignment = assigned["assignments"][0]
	assignment.definition_metadata["placement_channel"] = "encounter"
	_expect_true(
		failures,
		"resource catalog rejects assignment belonging to another semantic channel",
		Catalog.candidate_from_assignment(assignment, Vector2i.ZERO, 0) == null
	)
	assignment.definition_metadata["placement_channel"] = Catalog.RESOURCE_CHANNEL
	assignment.definition_metadata["local_capacity"] = 2
	_expect_true(
		failures,
		"resource catalog rejects unexpected site-local capacity",
		Catalog.candidate_from_assignment(assignment, Vector2i.ZERO, 0) == null
	)


static func _test_content_validation_evidence_is_snapshot_bound(failures: Array[String]) -> void:
	var authority: Dictionary = ContentEvidence.build_first_iron_authority()
	_expect_true(
		failures,
		"first iron CONTENT-006 authority has no setup failures",
		authority.get("setup_failures", []).is_empty()
	)
	var validation_result: Dictionary = authority.get("validation_result", {})
	_expect_true(
		failures,
		"real validation pipeline accepts exact first iron closure",
		bool(validation_result.get("success", false))
	)
	_expect_true(
		failures,
		"fresh first iron validation evidence verifies against current authorities",
		ContentEvidence.verification_failures(authority).is_empty()
	)
	var evidence = validation_result.get("evidence", null)
	_expect_true(
		failures,
		"validation evidence covers accepted iron resource identity",
		evidence != null and evidence.has_method("covers") and evidence.covers(Catalog.IRON_RESOURCE_CONTENT_ID)
	)

	var definitions: Array = authority.get("definitions", [])
	var content_registry = authority.get("content_registry", null)
	if definitions.size() >= 2 and content_registry != null:
		content_registry.index_definitions([definitions[0], definitions[1]])
		_expect_true(
			failures,
			"content manifest mutation invalidates prior iron validation evidence",
			not ContentEvidence.verification_failures(authority).is_empty()
		)
	else:
		failures.append("content evidence mutation fixture is incomplete")

	var schema_authority: Dictionary = ContentEvidence.build_first_iron_authority()
	var category_registry = schema_authority.get("category_registry", null)
	if category_registry == null:
		failures.append("category evidence mutation fixture is missing registry")
		return
	var mutated_schemas: Array = [
		CategorySchema.new().configure(ContentEvidence.IRON_RESOURCE_CATEGORY_ID, [], 2),
		CategorySchema.new().configure(ContentEvidence.IRON_ITEM_CATEGORY_ID),
	]
	_expect_true(
		failures,
		"mutated category schema registry remains structurally valid",
		category_registry.index_schemas(mutated_schemas).is_empty()
	)
	_expect_true(
		failures,
		"schema manifest mutation invalidates prior iron validation evidence",
		not ContentEvidence.verification_failures(schema_authority).is_empty()
	)


static func _hook() -> Dictionary:
	var address = StableAddress.from_segments([
		"ug",
		"region",
		"-3",
		"4",
		"reserved",
		"site",
		"0",
	])
	var stable_id = StableId.from_address(address)
	return {
		"stable_id": stable_id.value(),
		"semantic_category": "reserved_site",
		"reserved_bounds": AABB(Vector3(-2, -1, -2), Vector3(6, 4, 6)),
		"profile_blend": Vector3(0.3, 0.4, 0.3),
	}


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])