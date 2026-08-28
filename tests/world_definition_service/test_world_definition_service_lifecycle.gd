extends RefCounted

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const WorldDefinitionService := preload("res://worldgen/services/world_definition_service.gd")
const SampleGraphFixture := preload("res://tests/foundation/sample_graph_fixture.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_configure_clears_cache(failures)
	_test_store_get_has_evict(failures)
	_test_stable_id_address_mismatch_rejected(failures)
	_test_negative_region_address(failures)
	_test_request_determinism(failures)
	_test_cache_order_does_not_rekey_regions(failures)
	return failures


static func _test_configure_clears_cache(failures: Array[String]) -> void:
	var service = WorldDefinitionService.new()
	var first_context = WorldGenerationContext.new(10101)
	var second_context = WorldGenerationContext.new(20202)
	_expect_empty(failures, "initial configure", service.configure(first_context))

	var bundle = _bundle_for_region(0, 0)
	_expect_empty(failures, "store before reconfigure", service.store_finalized_region(bundle))
	_expect_equal(failures, "cache populated before reconfigure", service.cached_region_count(), 1)

	_expect_empty(failures, "second configure", service.configure(second_context))
	_expect_equal(failures, "configure clears cache", service.cached_region_count(), 0)
	_expect_true(
		failures,
		"configure clears address lookup",
		not service.has_region(StableAddress.underground_region(0, 0))
	)
	_expect_equal(failures, "configure replaces context", service.generation_context, second_context)


static func _test_store_get_has_evict(failures: Array[String]) -> void:
	var service = WorldDefinitionService.new()
	_expect_empty(failures, "cache semantics configure", service.configure(WorldGenerationContext.new(30303)))
	var address = StableAddress.underground_region(0, 0)
	var bundle = _bundle_for_region(0, 0)

	_expect_true(failures, "uncached region absent", not service.has_region(address))
	_expect_equal(failures, "uncached region returns null", service.get_region_if_ready(address), null)
	_expect_true(failures, "uncached eviction returns false", not service.evict_region(address))

	_expect_empty(failures, "store finalized region", service.store_finalized_region(bundle))
	_expect_true(failures, "stored region present", service.has_region(address))
	_expect_equal(failures, "stored bundle round-trips", service.get_region_if_ready(address), bundle)
	_expect_equal(failures, "cache count after store", service.cached_region_count(), 1)
	_expect_true(failures, "stored region evicts", service.evict_region(address))
	_expect_true(failures, "evicted region absent", not service.has_region(address))
	_expect_equal(failures, "cache count after eviction", service.cached_region_count(), 0)


static func _test_stable_id_address_mismatch_rejected(failures: Array[String]) -> void:
	var service = WorldDefinitionService.new()
	_expect_empty(failures, "mismatch configure", service.configure(WorldGenerationContext.new(40404)))
	var bundle = _bundle_for_region(2, 3)
	var correct_address = bundle.region_definition.stable_address
	var correct_id: String = bundle.region_definition.stable_id
	bundle.region_definition.stable_id = StableId.from_address(
		StableAddress.underground_region(9, 9)
	).value()

	var store_failures: Array[String] = service.store_finalized_region(bundle)
	_expect_contains(
		failures,
		"StableId/address mismatch rejected",
		store_failures,
		"StableId/address mismatch"
	)
	_expect_equal(failures, "rejected mismatch does not populate cache", service.cached_region_count(), 0)
	_expect_true(failures, "rejected mismatch not visible by address", not service.has_region(correct_address))
	bundle.region_definition.stable_id = correct_id


static func _test_negative_region_address(failures: Array[String]) -> void:
	var service = WorldDefinitionService.new()
	_expect_empty(failures, "negative configure", service.configure(WorldGenerationContext.new(50505)))
	var address = StableAddress.underground_region(-17, -23)
	var bundle = _bundle_for_region(-17, -23)

	_expect_empty(failures, "negative region store", service.store_finalized_region(bundle))
	_expect_true(failures, "negative region lookup", service.has_region(address))
	_expect_equal(failures, "negative region round-trip", service.get_region_if_ready(address), bundle)
	var request: Dictionary = service.make_region_request(-17, -23, -4)
	_expect_equal(failures, "negative request address", request.get("region_address"), address.canonical_text())
	_expect_equal(
		failures,
		"negative request stable identity",
		request.get("region_id"),
		StableId.from_address(address).value()
	)


static func _test_request_determinism(failures: Array[String]) -> void:
	var service = WorldDefinitionService.new()
	var context = WorldGenerationContext.new(60606)
	_expect_empty(failures, "request configure", service.configure(context))
	var first: Dictionary = service.make_region_request(-8, 13, 7)
	var second: Dictionary = service.make_region_request(-8, 13, 7)
	_expect_equal(failures, "same request is stable", first, second)
	_expect_equal(failures, "request world identity", first.get("world_id"), context.world_id)
	_expect_equal(
		failures,
		"request manifest identity",
		first.get("generator_manifest_id"),
		context.generator_manifest_id
	)
	_expect_equal(failures, "request priority preserved", first.get("priority"), 7)


static func _test_cache_order_does_not_rekey_regions(failures: Array[String]) -> void:
	var context = WorldGenerationContext.new(70707)
	var address_a = StableAddress.underground_region(4, -2)
	var address_b = StableAddress.underground_region(-9, 6)
	var bundle_a = _bundle_for_region(4, -2)
	var bundle_b = _bundle_for_region(-9, 6)
	var expected_a_id: String = StableId.from_address(address_a).value()
	var expected_b_id: String = StableId.from_address(address_b).value()

	var first_service = WorldDefinitionService.new()
	var second_service = WorldDefinitionService.new()
	_expect_empty(failures, "first order configure", first_service.configure(context))
	_expect_empty(failures, "second order configure", second_service.configure(context))

	_expect_empty(failures, "first order store A", first_service.store_finalized_region(bundle_a))
	_expect_empty(failures, "first order store B", first_service.store_finalized_region(bundle_b))
	_expect_empty(failures, "second order store B", second_service.store_finalized_region(bundle_b))
	_expect_empty(failures, "second order store A", second_service.store_finalized_region(bundle_a))

	_expect_equal(
		failures,
		"request order-independent region A identity",
		first_service.make_region_request(4, -2, 1).get("region_id"),
		expected_a_id
	)
	_expect_equal(
		failures,
		"reversed request order-independent region A identity",
		second_service.make_region_request(4, -2, 99).get("region_id"),
		expected_a_id
	)
	_expect_equal(
		failures,
		"request order-independent region B identity",
		first_service.make_region_request(-9, 6, 99).get("region_id"),
		expected_b_id
	)
	_expect_equal(
		failures,
		"reversed request order-independent region B identity",
		second_service.make_region_request(-9, 6, 1).get("region_id"),
		expected_b_id
	)
	_expect_equal(failures, "first-order A bundle remains keyed to A", first_service.get_region_if_ready(address_a), bundle_a)
	_expect_equal(failures, "first-order B bundle remains keyed to B", first_service.get_region_if_ready(address_b), bundle_b)
	_expect_equal(failures, "reverse-order A bundle remains keyed to A", second_service.get_region_if_ready(address_a), bundle_a)
	_expect_equal(failures, "reverse-order B bundle remains keyed to B", second_service.get_region_if_ready(address_b), bundle_b)
	_expect_equal(failures, "first-order cache count", first_service.cached_region_count(), 2)
	_expect_equal(failures, "reverse-order cache count", second_service.cached_region_count(), 2)


static func _bundle_for_region(region_x: int, region_z: int):
	var bundle = SampleGraphFixture.build()
	var address = StableAddress.underground_region(region_x, region_z)
	bundle.region_definition.stable_address = address
	bundle.region_definition.stable_id = StableId.from_address(address).value()
	bundle.region_definition.region_coord = Vector2i(region_x, region_z)
	return bundle


static func _expect_contains(
	failures: Array[String],
	label: String,
	actual: Array[String],
	expected_fragment: String
) -> void:
	for entry in actual:
		if expected_fragment in entry:
			return
	failures.append("%s — expected diagnostic containing '%s', got %s" % [label, expected_fragment, str(actual)])


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
