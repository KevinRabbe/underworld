extends RefCounted

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const SeedDomains := preload("res://worldgen/random/seed_domains.gd")
const SeedDeriver := preload("res://worldgen/random/seed_deriver.gd")
const DeterministicRng := preload("res://worldgen/random/deterministic_rng.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	failures.append_array(SeedDomains.validate_registry())

	_test_seed_vector_surface(failures)
	_test_seed_vector_underground(failures)
	_test_domain_isolation(failures)
	_test_subkey_isolation(failures)
	_test_rng_vector(failures)
	_test_rng_range_contract(failures)

	return failures


static func _test_seed_vector_surface(failures: Array[String]) -> void:
	var address = StableAddress.surface_candidate("tree", 10, -4, "0")
	var domain = SeedDomains.get_domain(SeedDomains.SURFACE_TREE_EXISTS)
	var actual: int = SeedDeriver.derive_u32(123456, address, domain)
	_expect_equal(
		failures,
		"seed-v1 surface.tree.exists fixed vector",
		actual,
		1295039235
	)

	var state: Array[int] = SeedDeriver.derive_state_words(123456, address, domain)
	_expect_equal(
		failures,
		"seed-v1 four-lane state vector",
		state,
		[4244929522, 2899852513, 1554775504, 2380379975]
	)


static func _test_seed_vector_underground(failures: Array[String]) -> void:
	var region = StableAddress.underground_region(-4, 7)
	var network = StableAddress.network(region, 3)
	var node = StableAddress.node(network, [1, 3])
	var topology_domain = SeedDomains.get_domain(SeedDomains.UG_NETWORK_TOPOLOGY)
	var position_domain = SeedDomains.get_domain(SeedDomains.UG_NODE_POSITION)

	_expect_equal(
		failures,
		"seed-v1 negative-world-seed underground vector",
		SeedDeriver.derive_u32(-987654321, node, topology_domain, "branch"),
		2395995233
	)
	_expect_equal(
		failures,
		"seed-v1 independent underground property vector",
		SeedDeriver.derive_u32(-987654321, node, position_domain, "x"),
		161049360
	)


static func _test_domain_isolation(failures: Array[String]) -> void:
	var address = StableAddress.surface_candidate("tree", 10, -4, "0")
	var exists_domain = SeedDomains.get_domain(SeedDomains.SURFACE_TREE_EXISTS)
	var shape_domain = SeedDomains.get_domain(SeedDomains.SURFACE_TREE_SHAPE)

	var exists_before: int = SeedDeriver.derive_u32(123456, address, exists_domain)
	var local_shape_rng = DeterministicRng.from_context(123456, address, shape_domain, "appearance")
	for _index in range(100):
		local_shape_rng.next_u32()
	var exists_after: int = SeedDeriver.derive_u32(123456, address, exists_domain)

	_expect_equal(
		failures,
		"consuming another domain does not perturb candidate existence",
		exists_after,
		exists_before
	)
	_expect_true(
		failures,
		"different domains produce independent values",
		exists_before != SeedDeriver.derive_u32(123456, address, shape_domain)
	)


static func _test_subkey_isolation(failures: Array[String]) -> void:
	var address = StableAddress.surface_candidate("tree", 10, -4, "0")
	var shape_domain = SeedDomains.get_domain(SeedDomains.SURFACE_TREE_SHAPE)

	_expect_equal(
		failures,
		"seed-v1 tree shape yaw fixed vector",
		SeedDeriver.derive_u32(123456, address, shape_domain, "yaw"),
		276255557
	)
	_expect_equal(
		failures,
		"seed-v1 tree shape scale fixed vector",
		SeedDeriver.derive_u32(123456, address, shape_domain, "scale"),
		1680716830
	)
	_expect_true(
		failures,
		"semantic subkeys are independent",
		SeedDeriver.derive_u32(123456, address, shape_domain, "yaw")
		!= SeedDeriver.derive_u32(123456, address, shape_domain, "scale")
	)


static func _test_rng_vector(failures: Array[String]) -> void:
	var address = StableAddress.surface_candidate("tree", 10, -4, "0")
	var domain = SeedDomains.get_domain(SeedDomains.SURFACE_TREE_EXISTS)
	var rng = DeterministicRng.from_context(123456, address, domain)
	var expected: Array[int] = [
		22661168,
		99230889,
		3075140585,
		1590014181,
		3897214579,
		1846025244,
		2726205295,
		413462561,
	]
	var actual: Array[int] = []
	for _index in range(expected.size()):
		actual.append(rng.next_u32())
	_expect_equal(failures, "xoshiro128** fixed output vector", actual, expected)


static func _test_rng_range_contract(failures: Array[String]) -> void:
	var address = StableAddress.surface_candidate("tree", 10, -4, "0")
	var domain = SeedDomains.get_domain(SeedDomains.SURFACE_TREE_EXISTS)
	var rng = DeterministicRng.from_context(123456, address, domain)
	_expect_equal(failures, "range_int first fixed sample", rng.range_int(0, 10), 8)

	for _index in range(1000):
		var unit: float = rng.unit_float()
		if unit < 0.0 or unit >= 1.0:
			failures.append("unit_float escaped [0,1): " + str(unit))
			break


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
