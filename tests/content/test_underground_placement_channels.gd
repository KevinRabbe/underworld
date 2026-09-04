extends RefCounted

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const Assignment := preload("res://content/reserved_sites/reserved_site_assignment.gd")
const Candidate := preload("res://content/placement/underground_placement_candidate.gd")

const CATEGORY_SITE_RESOURCE := "category.structure.underworld.vault"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_channel_identity_is_semantic_and_stable(failures)
	_test_legacy_adapter_remains_unchanged(failures)
	_test_invalid_channel_fails_closed(failures)
	return failures


static func _test_channel_identity_is_semantic_and_stable(failures: Array[String]) -> void:
	var assignment = _assignment()
	var resource = Candidate.from_reserved_site_assignment_channel(
		assignment,
		"resource",
		Vector2i(-3, 4),
		2,
		[],
		1
	)
	var resource_again = Candidate.from_reserved_site_assignment_channel(
		assignment,
		"resource",
		Vector2i(-3, 4),
		2,
		[],
		1
	)
	var encounter = Candidate.from_reserved_site_assignment_channel(
		assignment,
		"encounter",
		Vector2i(-3, 4),
		2,
		[],
		1
	)
	_expect_true(failures, "resource channel candidate is created", resource != null)
	_expect_true(failures, "encounter channel candidate is created", encounter != null)
	if resource == null or resource_again == null or encounter == null:
		return
	var site_id = StableId.parse(assignment.site_stable_id)
	var expected_resource = StableId.from_address(
		site_id.address().child(["channel", "resource"])
	)
	_expect_equal(
		failures,
		"resource channel identity is an exact semantic child of the reserved site",
		resource.stable_id,
		expected_resource.value()
	)
	_expect_equal(
		failures,
		"same site/channel produces identical candidate identity",
		resource.stable_id,
		resource_again.stable_id
	)
	_expect_true(
		failures,
		"resource and encounter channels cannot collide",
		resource.stable_id != encounter.stable_id
	)
	_expect_equal(
		failures,
		"channel adapter preserves authored assignment categories",
		resource.category_ids,
		assignment.category_ids
	)
	_expect_true(failures, "resource channel candidate validates", resource.validate_candidate().is_empty())


static func _test_legacy_adapter_remains_unchanged(failures: Array[String]) -> void:
	var assignment = _assignment()
	var legacy = Candidate.from_reserved_site_assignment(
		assignment,
		Vector2i(1, -2),
		3,
		[],
		1
	)
	_expect_true(failures, "legacy reserved-site adapter still creates a candidate", legacy != null)
	if legacy != null:
		_expect_equal(
			failures,
			"legacy reserved-site adapter still preserves the site StableId exactly",
			legacy.stable_id,
			assignment.site_stable_id
		)


static func _test_invalid_channel_fails_closed(failures: Array[String]) -> void:
	var assignment = _assignment()
	for invalid_channel in ["", "Resource", " resource", "resource/channel"]:
		var candidate = Candidate.from_reserved_site_assignment_channel(
			assignment,
			invalid_channel,
			Vector2i.ZERO,
			0,
			[],
			1
		)
		_expect_true(
			failures,
			"invalid semantic channel fails closed: %s" % invalid_channel,
			candidate == null
		)


static func _assignment():
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
	return Assignment.new(
		stable_id.value(),
		AABB(Vector3(-2, -1, -2), Vector3(6, 4, 6)),
		"reserved_site.resource.iron_outcrop",
		[CATEGORY_SITE_RESOURCE],
		1,
		1,
		"rsa1:test-resource-channel",
		{"channel": "resource", "local_capacity": 1}
	)


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])
