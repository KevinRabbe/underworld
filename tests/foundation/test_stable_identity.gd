extends RefCounted

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []

	_test_surface_vector(failures)
	_test_parse_round_trip(failures)
	_test_parser_rejects_noncanonical_input(failures)
	_test_candidate_slots_are_independent(failures)
	_test_underground_hierarchy(failures)
	_test_undirected_connector_canonicalization(failures)
	_test_cross_region_owner_is_order_independent(failures)
	_test_stable_id_round_trip(failures)
	_test_nested_address_segment_round_trip(failures)
	_test_invalid_semantic_segment_rejected(failures)

	return failures


static func _test_surface_vector(failures: Array[String]) -> void:
	var address = StableAddress.surface_candidate("tree", 401, -73, "0")
	_expect_not_null(failures, "surface vector address exists", address)
	if address == null:
		return

	var expected := "sa1|7:surface|9:candidate|4:tree|4:cell|3:401|3:-73|4:slot|1:0"
	_expect_equal(failures, "surface vector canonical text", address.canonical_text(), expected)

	var stable_id = StableId.from_address(address)
	_expect_not_null(failures, "surface vector StableId exists", stable_id)
	if stable_id != null:
		_expect_equal(
			failures,
			"surface vector StableId text",
			stable_id.value(),
			"sid1:" + expected
		)


static func _test_parse_round_trip(failures: Array[String]) -> void:
	var original = StableAddress.surface_candidate("loose-stone", -18, 27, "slot-2")
	var parsed = StableAddress.parse(original.canonical_text())
	_expect_not_null(failures, "address parser round-trip", parsed)
	if parsed != null:
		_expect_true(failures, "parsed address equals original", parsed.equals(original))
		_expect_equal(
			failures,
			"parsed canonical representation unchanged",
			parsed.canonical_text(),
			original.canonical_text()
		)


static func _test_parser_rejects_noncanonical_input(failures: Array[String]) -> void:
	_expect_null(
		failures,
		"parser rejects leading-zero segment length",
		StableAddress.parse("sa1|07:surface")
	)
	_expect_null(
		failures,
		"parser rejects wrong segment length",
		StableAddress.parse("sa1|6:surface")
	)
	_expect_null(
		failures,
		"parser rejects trailing garbage",
		StableAddress.parse("sa1|7:surfaceX")
	)
	_expect_null(
		failures,
		"StableId parser rejects wrong prefix",
		StableId.parse("sid2:sa1|7:surface")
	)


static func _test_candidate_slots_are_independent(failures: Array[String]) -> void:
	var slot_zero = StableAddress.surface_candidate("tree", 12, 9, "0")
	var slot_one = StableAddress.surface_candidate("tree", 12, 9, "1")
	var other_cell = StableAddress.surface_candidate("tree", 13, 9, "0")

	_expect_true(
		failures,
		"different pre-existing candidate slots have different identity",
		slot_zero.canonical_text() != slot_one.canonical_text()
	)
	_expect_true(
		failures,
		"candidate identity includes global cell",
		slot_zero.canonical_text() != other_cell.canonical_text()
	)

	# Identity is derived directly from each candidate address. There is no
	# accepted-object count to compact/renumber if another candidate is absent.
	var slot_one_again = StableAddress.surface_candidate("tree", 12, 9, "1")
	_expect_true(
		failures,
		"slot identity is independent of sibling acceptance",
		slot_one.equals(slot_one_again)
	)


static func _test_underground_hierarchy(failures: Array[String]) -> void:
	var region = StableAddress.underground_region(-4, 7)
	var network = StableAddress.network(region, 3)
	var root = StableAddress.node(network)
	var child = StableAddress.node(network, [1, 3])
	var entrance = StableAddress.entrance(region, 2)
	var special = StableAddress.special_location(child, "ore-deposit", 6)
	var deposit_child = StableAddress.generated_child(special, "exposed-chunk", 4)

	_expect_not_null(failures, "region identity exists", region)
	_expect_not_null(failures, "network identity exists", network)
	_expect_not_null(failures, "root node identity exists", root)
	_expect_not_null(failures, "child node identity exists", child)
	_expect_not_null(failures, "entrance identity exists", entrance)
	_expect_not_null(failures, "special location identity exists", special)
	_expect_not_null(failures, "persistent generated child identity exists", deposit_child)

	if network != null:
		_expect_true(
			failures,
			"network retains region lineage",
			network.has_prefix(region.segments())
		)
	if child != null and root != null:
		_expect_true(
			failures,
			"distinct node lineage has distinct identity",
			child.canonical_text() != root.canonical_text()
		)


static func _test_undirected_connector_canonicalization(failures: Array[String]) -> void:
	var region = StableAddress.underground_region(2, -5)
	var network = StableAddress.network(region, 1)
	var node_a = StableAddress.node(network, [0])
	var node_b = StableAddress.node(network, [3])

	var forward = StableAddress.secondary_connector(region, node_a, node_b, "loop", 0)
	var reverse = StableAddress.secondary_connector(region, node_b, node_a, "loop", 0)

	_expect_not_null(failures, "forward secondary connector exists", forward)
	_expect_not_null(failures, "reverse secondary connector exists", reverse)
	if forward != null and reverse != null:
		_expect_equal(
			failures,
			"A-B and B-A resolve to one connector identity",
			forward.canonical_text(),
			reverse.canonical_text()
		)

	var primary_forward = StableAddress.primary_edge(network, node_a, node_b, 4)
	var primary_reverse = StableAddress.primary_edge(network, node_b, node_a, 4)
	_expect_equal(
		failures,
		"undirected primary endpoints are canonicalized",
		primary_forward.canonical_text(),
		primary_reverse.canonical_text()
	)


static func _test_cross_region_owner_is_order_independent(failures: Array[String]) -> void:
	var region_a = StableAddress.underground_region(-1, 8)
	var region_b = StableAddress.underground_region(3, -2)
	var owner_ab = StableAddress.canonical_owner(region_a, region_b)
	var owner_ba = StableAddress.canonical_owner(region_b, region_a)

	_expect_not_null(failures, "canonical cross-region owner exists", owner_ab)
	if owner_ab != null and owner_ba != null:
		_expect_equal(
			failures,
			"cross-region owner does not depend on request direction",
			owner_ab.canonical_text(),
			owner_ba.canonical_text()
		)


static func _test_stable_id_round_trip(failures: Array[String]) -> void:
	var region = StableAddress.underground_region(0, 0)
	var entrance = StableAddress.entrance(region, 1)
	var original = StableId.from_address(entrance)
	var parsed = StableId.parse(original.value())

	_expect_not_null(failures, "StableId parser round-trip", parsed)
	if parsed != null:
		_expect_true(failures, "parsed StableId equals original", parsed.equals(original))
		_expect_true(
			failures,
			"StableId exposes equivalent semantic address copy",
			parsed.address().equals(entrance)
		)


static func _test_nested_address_segment_round_trip(failures: Array[String]) -> void:
	var owner = StableAddress.underground_region(10, 11)
	var network = StableAddress.network(owner, 2)
	var node_a = StableAddress.node(network, [1])
	var node_b = StableAddress.node(network, [5])
	var connector = StableAddress.secondary_connector(owner, node_a, node_b, "proximity", 7)

	# Connector endpoint components contain complete canonical addresses, which
	# themselves contain ':' and '|'. Length-prefixing must still round-trip.
	var parsed = StableAddress.parse(connector.canonical_text())
	_expect_not_null(failures, "nested endpoint address parses", parsed)
	if parsed != null:
		_expect_equal(
			failures,
			"nested endpoint address canonical text survives parse",
			parsed.canonical_text(),
			connector.canonical_text()
		)


static func _test_invalid_semantic_segment_rejected(failures: Array[String]) -> void:
	_expect_null(
		failures,
		"spaces are not allowed in persistent semantic tokens",
		StableAddress.from_segments(["surface", "bad token"])
	)
	_expect_null(
		failures,
		"Unicode is not allowed in persistent semantic tokens",
		StableAddress.from_segments(["surface", "trée"])
	)
	_expect_null(
		failures,
		"negative candidate slots are rejected",
		StableAddress.network(StableAddress.underground_region(0, 0), -1)
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


static func _expect_null(failures: Array[String], label: String, value: Variant) -> void:
	if value != null:
		failures.append("%s — expected null, got %s" % [label, str(value)])


static func _expect_not_null(failures: Array[String], label: String, value: Variant) -> void:
	if value == null:
		failures.append(label + " — expected non-null value")
