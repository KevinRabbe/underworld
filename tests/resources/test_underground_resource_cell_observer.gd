extends RefCounted

const CaveRuntimeController := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const CellAddress := preload("res://worldgen/geometry/geometry_cell_address.gd")
const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const Observer := preload("res://gameplay/resources/runtime/underworld_resource_cell_observer.gd")
const CompositionService := preload("res://gameplay/resources/runtime/underground_resource_composition_service.gd")
const ContentEvidence := preload("res://gameplay/resources/runtime/underground_resource_content_evidence.gd")
const Catalog := preload("res://gameplay/resources/runtime/underground_resource_composition_catalog.gd")


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
		"stable_id": _owner_site_stable_id(),
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

	var authority: Dictionary = ContentEvidence.build_first_iron_authority()
	var composition: Dictionary = CompositionService.plan_current_cell(controller, address, authority)
	if not bool(composition.get("success", false)):
		failures.append(
			"current generated owner site composes through canonical assignment and placement services — %s" % [
				composition.get("diagnostics", [])
			]
		)
	else:
		_expect_equal(failures, "one current owner site yields one placement", composition.get("placements", []).size(), 1)
		if composition.get("placements", []).size() == 1:
			_expect_equal(
				failures,
				"current-cell composition targets accepted iron resource",
				composition["placements"][0].target_content_id,
				Catalog.IRON_RESOURCE_CONTENT_ID
			)
		_expect_equal(
			failures,
			"composition preserves generated hook StableId rather than source descriptor identity",
			str(composition.get("hooks", [])[0].get("stable_id", "")) if not composition.get("hooks", []).is_empty() else "",
			str(owner.metadata.get("stable_id", ""))
		)

	controller.streamer.reconfigure("world:test", "manifest:test")
	_expect_true(failures, "old snapshot becomes stale after generation advance", not Observer.snapshot_is_current(controller, snapshot))
	_expect_true(failures, "unready reconfigured cell returns no current snapshot", Observer.current_snapshot(controller, address).is_empty())
	_expect_true(
		failures,
		"unready reconfigured cell cannot publish a resource placement plan",
		not bool(CompositionService.plan_current_cell(controller, address, authority).get("success", false))
	)


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


static func _owner_site_stable_id() -> String:
	var region_address = StableAddress.underground_region(0, 0)
	var site_address = StableAddress.special_location(region_address, "reserved_site", 0)
	var stable_id = StableId.from_address(site_address)
	return "" if stable_id == null else stable_id.value()


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, expected, actual])
