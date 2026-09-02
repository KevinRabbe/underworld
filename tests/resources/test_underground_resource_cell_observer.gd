extends RefCounted

const CaveRuntimeController := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const CellAddress := preload("res://worldgen/geometry/geometry_cell_address.gd")
const Observer := preload("res://gameplay/resources/runtime/underworld_resource_cell_observer.gd")


class FakeFragment extends RefCounted:
	var fragment_id: String
	var source_descriptor_id: String
	var source_kind: String
	var cell_bounds: AABB
	var clipped_source_bounds: AABB
	var is_owner: bool
	var source_fingerprint: String
	var metadata: Dictionary

	func _init(
		fragment_id_value: String,
		source_id_value: String,
		kind_value: String,
		owner_value: bool,
		metadata_value: Dictionary
	) -> void:
		fragment_id = fragment_id_value
		source_descriptor_id = source_id_value
		source_kind = kind_value
		cell_bounds = AABB(Vector3(-4, -8, -4), Vector3(8, 8, 8))
		clipped_source_bounds = cell_bounds
		is_owner = owner_value
		source_fingerprint = "fragment:" + source_id_value
		metadata = metadata_value.duplicate(true)


class FakePlan extends RefCounted:
	var fragments: Array = []


class FakeStage extends RefCounted:
	var success: bool = true
	var data: Dictionary = {}

	func _init(data_value: Dictionary) -> void:
		data = data_value


class FakeDefinitionService extends RefCounted:
	var definitions: Dictionary = {}

	func cell_definition(address):
		return FakeStage.new(definitions.get(address.canonical_text(), {}))


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_detached_owner_snapshot_and_stale_generation(failures)
	_test_identity_mismatch_fails_closed(failures)
	return failures


static func _test_detached_owner_snapshot_and_stale_generation(failures: Array[String]) -> void:
	var controller = CaveRuntimeController.new()
	controller.configure("world:test", "manifest:test")
	var address = CellAddress.new(Vector3i(2, -3, -1))
	var record = controller.streamer.demand_cell(
		address,
		"resource-observer-test",
		["render"],
		"source:test",
		"provenance:test"
	)
	record.readiness["render"] = true

	var owner_metadata: Dictionary = {
		"stable_id": "sid1:sa1|2:ug|6:region|1:0|1:0|8:special|13:reserved_site|4:slot|1:0",
		"free_world_anchor": Vector3(1.5, -20.0, 3.0),
		"semantic_category": "reserved_site",
		"reserved_bounds": AABB(Vector3(-2, -24, -2), Vector3(8, 8, 8)),
		"profile_blend": Vector3(0.2, 0.5, 0.3),
		"generation_metadata": {"candidate_slot": 0},
	}
	var owner = FakeFragment.new(
		"fragment-owner",
		"site-owner",
		"reserved_site",
		true,
		owner_metadata
	)
	var continuation = FakeFragment.new(
		"fragment-continuation",
		"site-continuation",
		"reserved_site",
		false,
		{"stable_id": "ignored"}
	)
	var chamber = FakeFragment.new(
		"fragment-chamber",
		"chamber-1",
		"chamber",
		true,
		{"stable_id": "ignored-chamber"}
	)
	var plan = FakePlan.new()
	plan.fragments = [continuation, chamber, owner]
	var definitions = FakeDefinitionService.new()
	definitions.definitions[address.canonical_text()] = {
		"region": Vector2i(-1, 4),
		"cell_plan": plan,
		"source_fingerprint": "source:test",
		"provenance_fingerprint": "provenance:test",
	}
	controller._definition_service = definitions

	var snapshot: Dictionary = Observer.current_snapshot(controller, address)
	_expect_true(failures, "current render-ready cell produces detached snapshot", not snapshot.is_empty())
	if snapshot.is_empty():
		return
	_expect_equal(failures, "snapshot keeps exact current generation", int(snapshot.get("generation", -1)), int(record.generation))
	_expect_equal(failures, "snapshot keeps exact region coordinate", snapshot.get("region_coord"), Vector2i(-1, 4))
	var sites: Array = snapshot.get("owner_reserved_sites", [])
	_expect_equal(failures, "only owner reserved-site fragment participates", sites.size(), 1)
	if sites.size() == 1:
		_expect_equal(failures, "owner source identity survives detachment", str(sites[0].get("source_descriptor_id", "")), "site-owner")
		var detached_metadata: Dictionary = sites[0].get("metadata", {})
		detached_metadata["generation_metadata"]["candidate_slot"] = 99
		_expect_equal(
			failures,
			"mutating returned metadata cannot mutate definition source",
			int(owner.metadata["generation_metadata"]["candidate_slot"]),
			0
		)

	_expect_true(failures, "fresh snapshot validates against current record", Observer.snapshot_is_current(controller, snapshot))
	var all_current: Array = Observer.current_snapshots(controller)
	_expect_equal(failures, "bounded enumeration returns exact current render-ready cell", all_current.size(), 1)

	controller.streamer.reconfigure("world:test", "manifest:test")
	_expect_true(failures, "old snapshot becomes stale after generation advance", not Observer.snapshot_is_current(controller, snapshot))
	_expect_true(failures, "unready reconfigured cell returns no current snapshot", Observer.current_snapshot(controller, address).is_empty())


static func _test_identity_mismatch_fails_closed(failures: Array[String]) -> void:
	var controller = CaveRuntimeController.new()
	controller.configure("world:test", "manifest:test")
	var address = CellAddress.new(Vector3i(0, -2, 0))
	var record = controller.streamer.demand_cell(
		address,
		"resource-observer-test",
		["render"],
		"source:record",
		"provenance:record"
	)
	record.readiness["render"] = true
	var plan = FakePlan.new()
	plan.fragments = []
	var definitions = FakeDefinitionService.new()
	definitions.definitions[address.canonical_text()] = {
		"region": Vector2i.ZERO,
		"cell_plan": plan,
		"source_fingerprint": "source:definition",
		"provenance_fingerprint": "provenance:record",
	}
	controller._definition_service = definitions
	_expect_true(
		failures,
		"definition/record source mismatch fails closed",
		Observer.current_snapshot(controller, address).is_empty()
	)


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, expected, actual])
