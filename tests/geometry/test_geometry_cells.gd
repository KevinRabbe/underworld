extends RefCounted

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const SampleGraphFixture := preload("res://tests/foundation/sample_graph_fixture.gd")
const GeometryResult := preload("res://worldgen/underworld/cave_geometry_result.gd")
const FinalizationResult := preload("res://worldgen/underworld/region_finalization_result.gd")
const Chamber := preload("res://worldgen/geometry/chamber_geometry_descriptor.gd")
const Tunnel := preload("res://worldgen/geometry/tunnel_geometry_descriptor.gd")
const SurfaceDescriptor := preload("res://worldgen/graph/surface_entrance_integration_descriptor.gd")
const RegionDefinition := preload("res://worldgen/graph/underground_region_definition.gd")
const RegionGraphBundle := preload("res://worldgen/graph/region_graph_bundle.gd")
const Config := preload("res://worldgen/geometry/geometry_cell_partition_config.gd")
const Partitioner := preload("res://worldgen/geometry/geometry_cell_partitioner.gd")
const Context := preload("res://worldgen/pipeline/world_generation_context.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_determinism_and_order(failures)
	_test_exact_boundaries_and_continuation(failures)
	_test_negative_cells_and_configuration(failures)
	_test_configuration_identity_mutation(failures)
	_test_type_and_region_validation(failures)
	return failures


static func _test_determinism_and_order(failures: Array[String]) -> void:
	var fixture := _fixture()
	var first = _partition(fixture, Config.new(), [Vector3i(0, 0, 0), Vector3i(-1, 0, 0)])
	var second = _partition(fixture, Config.new(), [Vector3i(-1, 0, 0), Vector3i(0, 0, 0)])
	_expect_true(failures, "geometry cell partition succeeds", first.success)
	_expect_true(failures, "reordered requested cells succeed", second.success)
	if first.success and second.success:
		_expect_equal(failures, "requested cell order is canonical", first.fingerprint, second.fingerprint)
		_expect_true(failures, "partition has plans", first.data.plans.size() == 2)
		var fragment_ids: Dictionary = {}
		for plan in first.data.plans:
			for fragment in plan.fragments:
				_expect_true(failures, "fragment id uses gfrag namespace", str(fragment.fragment_id).begins_with("gfrag1:sha256:"))
				_expect_true(failures, "fragment source fingerprint is present", not fragment.source_fingerprint.is_empty())
				_expect_true(failures, "fragment ids are unique", not fragment_ids.has(fragment.fragment_id))
				fragment_ids[fragment.fragment_id] = true


static func _test_exact_boundaries_and_continuation(failures: Array[String]) -> void:
	var fixture := _fixture()
	var result = _partition(fixture, Config.new())
	_expect_true(failures, "derived partition succeeds", result.success)
	if not result.success:
		return
	var plan_by_coord: Dictionary = {}
	for plan in result.data.plans:
		plan_by_coord[plan.cell_address.coordinate] = plan
	# The chamber ends exactly at x=32, so it must not create a false x=1 fragment.
	_expect_true(failures, "exact maximum boundary does not add a neighbor", not plan_by_coord.has(Vector3i(1, 0, 0)))
	# A second chamber crosses x=32; the two fragments expose mirrored faces.
	var crossing := _crossing_fixture()
	var crossing_result = _partition(crossing, Config.new())
	_expect_true(failures, "cross-cell partition succeeds", crossing_result.success)
	if crossing_result.success:
		var left = _find_fragment(crossing_result.data.plans, "chamber", Vector3i(0, 0, 0))
		var right = _find_fragment(crossing_result.data.plans, "chamber", Vector3i(1, 0, 0))
		_expect_true(failures, "left continuation is exposed", left != null and bool(left.continuation_mask.get("+x", false)))
		_expect_true(failures, "right continuation is exposed", right != null and bool(right.continuation_mask.get("-x", false)))
		var owner_count := 0
		for plan in crossing_result.data.plans:
			for fragment in plan.fragments:
				if fragment.source_kind == "chamber" and fragment.is_owner:
					owner_count += 1
		_expect_true(failures, "owner is unique across crossing fragments", owner_count == 1)


static func _test_negative_cells_and_configuration(failures: Array[String]) -> void:
	var fixture := _negative_fixture()
	var result = _partition(fixture, Config.new())
	_expect_true(failures, "negative cell partition succeeds", result.success)
	if result.success:
		var has_negative := false
		for plan in result.data.plans:
			if plan.cell_address.coordinate.x < 0 or plan.cell_address.coordinate.y < 0 or plan.cell_address.coordinate.z < 0:
				has_negative = true
		_expect_true(failures, "negative coordinates are represented", has_negative)
	var smaller := Config.new(Vector3(16.0, 16.0, 16.0), 0.5, 32, 1)
	var changed = _partition(fixture, smaller)
	_expect_true(failures, "explicit configuration change succeeds", changed.success)
	if result.success and changed.success:
		_expect_true(failures, "configuration participates in partition identity", result.fingerprint != changed.fingerprint)
		_expect_equal(failures, "source geometry identity is unchanged", result.data.source_geometry_fingerprint, changed.data.source_geometry_fingerprint)


static func _test_type_and_region_validation(failures: Array[String]) -> void:
	var fixture := _fixture()
	var missing_context = Partitioner.partition(fixture.geometry, fixture.finalization, Config.new())
	_expect_true(failures, "authoritative partition requires context", not missing_context.success)
	var wrong = Partitioner.partition(fixture.finalization, fixture.finalization, Config.new(), [], fixture.context)
	_expect_true(failures, "wrong geometry input type is rejected", not wrong.success)
	var source_bundle = SampleGraphFixture.build()
	var other_region_address = StableAddress.underground_region(99, 99)
	var other_region = RegionDefinition.new(other_region_address, Vector2i(99, 99), Vector3.ZERO, AABB(Vector3.ZERO, Vector3.ONE))
	var other_bundle = RegionGraphBundle.new(other_region)
	var other_finalization := FinalizationResult.new(other_bundle, [], [], {}, "finalization-other")
	var mismatched = Partitioner.partition(fixture.geometry, other_finalization, Config.new(), [], fixture.context)
	_expect_true(failures, "mismatched region input is rejected", not mismatched.success)


static func _test_configuration_identity_mutation(failures: Array[String]) -> void:
	var configuration := Config.new()
	var original := configuration.fingerprint
	configuration.cell_size = Vector3(16.0, 16.0, 16.0)
	configuration.cubes_per_axis = 32
	_expect_true(failures, "mutated configuration identity is rejected", not configuration.validate().is_empty())
	_expect_equal(failures, "mutation does not rewrite cached identity", configuration.fingerprint, original)


static func _fixture() -> Dictionary:
	var bundle = SampleGraphFixture.build()
	var node = bundle.nodes[0]
	var chamber := Chamber.new(
		StableAddress.generated_child(node.stable_address, "test-chamber", 0),
		node.stable_id,
		bundle.region_definition.stable_id,
		node.owning_network_id,
		Vector3(31.0, 0.0, 0.0),
		Vector3(2.0, 2.0, 2.0),
		0.0, "ellipsoid", 0.5, 0.5, 0.2, Vector3.ONE, Vector3.ONE, "chamber", []
	)
	var surface := SurfaceDescriptor.new(
		bundle.entrances[0].stable_id, bundle.region_definition.stable_id, Vector3.ZERO, Vector3.FORWARD,
		AABB(Vector3(-4.0, -4.0, -4.0), Vector3(8.0, 8.0, 8.0)), 3.0,
		bundle.entrances[0].connected_network_id, bundle.entrances[0].connected_node_id,
		bundle.entrances[0].underground_connection_position, bundle.entrances[0].descent_profile
	)
	var context := Context.new(123)
	var macro_provenance = context.make_provenance("macro_region", bundle.region_definition.stable_id, bundle.region_definition.stable_address.canonical_text())
	var finalization_provenance = context.make_provenance("region_finalization", bundle.region_definition.stable_id, bundle.region_definition.stable_address.canonical_text(), ["entrance-fixture"])
	var geometry_provenance = context.make_provenance("geometry_description", bundle.region_definition.stable_id, bundle.region_definition.stable_address.canonical_text(), [macro_provenance.fingerprint, finalization_provenance.fingerprint])
	var geometry := GeometryResult.new(bundle, [chamber], [], {"fixture": true}, "geometry-fixture", geometry_provenance)
	var finalization := FinalizationResult.new(bundle, [], [surface], {}, "finalization-fixture", finalization_provenance)
	return {"geometry": geometry, "finalization": finalization, "context": context}


static func _crossing_fixture() -> Dictionary:
	var bundle = SampleGraphFixture.build()
	var node = bundle.nodes[0]
	var chamber := Chamber.new(
		StableAddress.generated_child(node.stable_address, "crossing-chamber", 0), node.stable_id,
		bundle.region_definition.stable_id, node.owning_network_id, Vector3(32.0, 0.0, 0.0),
		Vector3(4.0, 2.0, 2.0), 0.0, "ellipsoid", 0.5, 0.5, 0.2, Vector3.ONE, Vector3.ONE, "chamber", []
	)
	var context := Context.new(123)
	var finalization_provenance = context.make_provenance("region_finalization", bundle.region_definition.stable_id, bundle.region_definition.stable_address.canonical_text(), ["entrance-fixture"])
	var macro_provenance = context.make_provenance("macro_region", bundle.region_definition.stable_id, bundle.region_definition.stable_address.canonical_text())
	var geometry_provenance = context.make_provenance("geometry_description", bundle.region_definition.stable_id, bundle.region_definition.stable_address.canonical_text(), [macro_provenance.fingerprint, finalization_provenance.fingerprint])
	var geometry := GeometryResult.new(bundle, [chamber], [], {}, "geometry-crossing", geometry_provenance)
	var finalization := FinalizationResult.new(bundle, [], [], {}, "finalization-crossing", finalization_provenance)
	return {"geometry": geometry, "finalization": finalization, "context": context}


static func _negative_fixture() -> Dictionary:
	var bundle = SampleGraphFixture.build()
	var node = bundle.nodes[0]
	var chamber := Chamber.new(
		StableAddress.generated_child(node.stable_address, "negative-chamber", 0), node.stable_id,
		bundle.region_definition.stable_id, node.owning_network_id, Vector3(-33.0, -33.0, -33.0),
		Vector3(4.0, 4.0, 4.0), 0.0, "ellipsoid", 0.5, 0.5, 0.2, Vector3.ONE, Vector3.ONE, "chamber", []
	)
	var context := Context.new(123)
	var finalization_provenance = context.make_provenance("region_finalization", bundle.region_definition.stable_id, bundle.region_definition.stable_address.canonical_text(), ["entrance-fixture"])
	var macro_provenance = context.make_provenance("macro_region", bundle.region_definition.stable_id, bundle.region_definition.stable_address.canonical_text())
	var geometry_provenance = context.make_provenance("geometry_description", bundle.region_definition.stable_id, bundle.region_definition.stable_address.canonical_text(), [macro_provenance.fingerprint, finalization_provenance.fingerprint])
	var geometry := GeometryResult.new(bundle, [chamber], [], {}, "geometry-negative", geometry_provenance)
	var finalization := FinalizationResult.new(bundle, [], [], {}, "finalization-negative", finalization_provenance)
	return {"geometry": geometry, "finalization": finalization, "context": context}


static func _partition(fixture: Dictionary, config, cells: Array = []) -> Object:
	return Partitioner.partition(fixture.geometry, fixture.finalization, config, cells, fixture.context)


static func _find_fragment(plans: Array, kind: String, coordinate: Vector3i):
	for plan in plans:
		if plan.cell_address.coordinate != coordinate:
			continue
		for fragment in plan.fragments:
			if fragment.source_kind == kind:
				return fragment
	return null


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s: actual=%s expected=%s" % [label, actual, expected])
