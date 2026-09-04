extends RefCounted

const CaveRuntimeController := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const CellAddress := preload("res://worldgen/geometry/geometry_cell_address.gd")
const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const Observer := preload("res://gameplay/resources/runtime/underworld_resource_cell_observer.gd")
const CompositionService := preload("res://gameplay/resources/runtime/underground_resource_composition_service.gd")
const ResidencyService := preload("res://gameplay/resources/runtime/underground_resource_residency_service.gd")
const ActionService := preload("res://gameplay/resources/runtime/underground_resource_action_service.gd")
const ContentEvidence := preload("res://gameplay/resources/runtime/underground_resource_content_evidence.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const RuntimeTests := preload("res://tests/resources/test_underground_resource_runtime.gd")


class FakeFragment extends RefCounted:
	var fragment_id: String = "fragment-root-alias"
	var source_descriptor_id: String = "site-root-alias"
	var source_kind: String = "reserved_site"
	var cell_bounds: AABB = AABB(Vector3(-8, -28, -8), Vector3(16, 16, 16))
	var clipped_source_bounds: AABB = cell_bounds
	var is_owner: bool = true
	var source_fingerprint: String = "fragment:root-alias"
	var metadata: Dictionary

	func _init(metadata_value: Dictionary) -> void:
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


class FakeResidency extends ResidencyService:
	var current_entry: Dictionary = {}

	func semantic_entry(cell_address: String) -> Dictionary:
		if str(current_entry.get("cell_address", "")) != cell_address:
			return {}
		return current_entry.duplicate(true)


static func run() -> Array[String]:
	var failures: Array[String] = []
	var controller = CaveRuntimeController.new()
	var address = CellAddress.new(Vector3i(4, -3, 2))
	var authority: Dictionary = ContentEvidence.build_first_iron_authority()
	for failure in ContentEvidence.verification_failures(authority):
		failures.append("root alias content authority: %s" % failure)
	if not failures.is_empty():
		controller.free()
		return failures

	var record_a = _configure_root(
		controller,
		address,
		"world:resource-root-a",
		"manifest:resource-root-a",
		"source:resource-root-a",
		"provenance:resource-root-a"
	)
	var snapshot_a: Dictionary = Observer.current_snapshot(controller, address)
	_expect_true(failures, "root A exposes a current detached resource snapshot", not snapshot_a.is_empty())
	if snapshot_a.is_empty():
		controller.free()
		return failures
	var planned_a: Dictionary = CompositionService.plan_snapshot(snapshot_a, authority)
	_expect_true(failures, "root A snapshot plans resource placement", bool(planned_a.get("success", false)))
	if not bool(planned_a.get("success", false)) or planned_a.get("placements", []).size() != 1:
		failures.append("root A expected one resource placement: %s" % [planned_a.get("diagnostics", [])])
		controller.free()
		return failures
	var placement_a = planned_a["placements"][0]
	var generation_a: int = int(record_a.generation)

	# configure() creates a new #372 streamer whose generation allocator starts
	# from its local initial token again. The same numeric generation must not
	# make the old root-A snapshot/ticket authoritative under root B.
	var record_b = _configure_root(
		controller,
		address,
		"world:resource-root-b",
		"manifest:resource-root-b",
		"source:resource-root-b",
		"provenance:resource-root-b"
	)
	var snapshot_b: Dictionary = Observer.current_snapshot(controller, address)
	_expect_true(failures, "root B exposes a current detached resource snapshot", not snapshot_b.is_empty())
	if snapshot_b.is_empty():
		controller.free()
		return failures
	_expect_equal(failures, "new root naturally aliases the old numeric generation token", int(record_b.generation), generation_a)
	_expect_true(failures, "old root-A snapshot is stale despite equal numeric generation", not Observer.snapshot_is_current(controller, snapshot_a))
	_expect_true(failures, "fresh root-B snapshot is current", Observer.snapshot_is_current(controller, snapshot_b))
	_expect_true(
		failures,
		"root replacement changes source or provenance freshness",
		str(snapshot_a.get("source_fingerprint", "")) != str(snapshot_b.get("source_fingerprint", ""))
		or str(snapshot_a.get("provenance_fingerprint", "")) != str(snapshot_b.get("provenance_fingerprint", ""))
	)

	var planned_b: Dictionary = CompositionService.plan_snapshot(snapshot_b, authority)
	_expect_true(failures, "fresh root B snapshot plans resource placement", bool(planned_b.get("success", false)))
	if not bool(planned_b.get("success", false)) or planned_b.get("placements", []).size() != 1:
		failures.append("root B expected one resource placement: %s" % [planned_b.get("diagnostics", [])])
		controller.free()
		return failures
	var placement_b = planned_b["placements"][0]
	_expect_equal(
		failures,
		"runtime root/generation replacement does not rewrite durable placement identity",
		placement_b.canonical_data(),
		placement_a.canonical_data()
	)

	var residency = FakeResidency.new()
	residency.current_entry = _entry_from_snapshot(snapshot_a, planned_a["placements"])
	var action = ActionService.new()
	var action_failures: Array[String] = action.configure(residency)
	for failure in action_failures:
		failures.append("root alias action configure: %s" % failure)
	if not action_failures.is_empty():
		controller.free()
		return failures
	var store = WorldDeltaStore.new()
	var prepared_a: Dictionary = action.prepare_mining(
		str(snapshot_a.get("cell_address", "")),
		str(placement_a.placement_stable_id),
		authority.get("content_registry", null),
		store
	)
	_expect_true(failures, "root A prepares immutable mining ticket", bool(prepared_a.get("success", false)))
	var ticket_a = prepared_a.get("ticket", null)

	var runtime_fixture: Dictionary = RuntimeTests._content_fixture(failures)
	var equipment_fixture: Dictionary = (
		RuntimeTests._pickaxe_equipment(runtime_fixture.get("pickaxe", null), failures)
		if not runtime_fixture.is_empty()
		else {}
	)
	if runtime_fixture.is_empty() or equipment_fixture.is_empty():
		controller.free()
		return failures
	var inventory = ItemContainerState.new().configure(4)

	residency.current_entry = _entry_from_snapshot(snapshot_b, planned_b["placements"])
	var stale: Dictionary = action.execute_mining(
		ticket_a,
		authority.get("content_registry", null),
		equipment_fixture["equipment"],
		inventory,
		store
	)
	_expect_true(failures, "root-A ticket rejects under root B despite generation alias", not bool(stale.get("success", true)))
	_expect_true(
		failures,
		"root-A ticket rejection is provenance/source freshness based",
		_has_fragment(stale, "source fingerprint is stale") or _has_fragment(stale, "provenance fingerprint is stale")
	)
	_expect_equal(failures, "cross-root stale ticket grants zero iron", inventory.quantity_of("item.resource.iron_chunk"), 0)
	_expect_true(failures, "cross-root stale ticket writes no durable depletion", store.get_object_state(placement_a.placement_stable_id).is_empty())

	var prepared_b: Dictionary = action.prepare_mining(
		str(snapshot_b.get("cell_address", "")),
		str(placement_b.placement_stable_id),
		authority.get("content_registry", null),
		store
	)
	_expect_true(failures, "fresh root B prepares normally", bool(prepared_b.get("success", false)))
	var committed_b: Dictionary = action.execute_mining(
		prepared_b.get("ticket", null),
		authority.get("content_registry", null),
		equipment_fixture["equipment"],
		inventory,
		store
	)
	_expect_true(failures, "fresh root B mining proceeds normally", bool(committed_b.get("success", false)))
	_expect_equal(failures, "fresh root B operation yields exactly one iron", inventory.quantity_of("item.resource.iron_chunk"), 1)
	var durable: Dictionary = store.get_object_state(placement_b.placement_stable_id)
	_expect_true(failures, "fresh root B operation creates durable depletion", not durable.is_empty())
	_expect_true(failures, "durable depletion does not persist runtime generation", not durable.has("generation") and not durable.has("cell_generation"))
	_expect_true(failures, "durable depletion does not persist runtime provenance", not durable.has("provenance_fingerprint") and not durable.has("source_fingerprint"))

	controller.free()
	return failures


static func _configure_root(
	controller,
	address,
	world_id: String,
	manifest_id: String,
	source_fingerprint: String,
	provenance_fingerprint: String
):
	controller.configure(world_id, manifest_id)
	var record = controller.streamer.demand_cell(
		address,
		"resource-root-alias",
		["render", "collision"],
		source_fingerprint,
		provenance_fingerprint
	)
	record.readiness["render"] = true
	record.readiness["collision"] = true
	var plan = FakePlan.new()
	plan.fragments = [FakeFragment.new(_owner_metadata())]
	var definitions = FakeDefinitionService.new()
	definitions.definitions[address.canonical_text()] = {
		"region": Vector2i.ZERO,
		"cell_plan": plan,
		"source_fingerprint": source_fingerprint,
		"provenance_fingerprint": provenance_fingerprint,
	}
	controller._definition_service = definitions
	return record


static func _entry_from_snapshot(snapshot: Dictionary, placements: Array) -> Dictionary:
	return {
		"cell_address": str(snapshot.get("cell_address", "")),
		"generation": int(snapshot.get("generation", 0)),
		"source_fingerprint": str(snapshot.get("source_fingerprint", "")),
		"provenance_fingerprint": str(snapshot.get("provenance_fingerprint", "")),
		"collision_ready": true,
		"placements": placements.duplicate(),
	}


static func _owner_metadata() -> Dictionary:
	var region_address = StableAddress.underground_region(0, 0)
	var site_address = StableAddress.special_location(region_address, "reserved_site", 0)
	var stable_id = StableId.from_address(site_address)
	return {
		"stable_id": "" if stable_id == null else stable_id.value(),
		"free_world_anchor": Vector3(1.5, -20.0, 3.0),
		"semantic_category": "reserved_site",
		"reserved_bounds": AABB(Vector3(-2.0, -24.0, -2.0), Vector3(8.0, 8.0, 8.0)),
		"profile_blend": Vector3(0.2, 0.5, 0.3),
		"generation_metadata": {"candidate_slot": 0},
	}


static func _has_fragment(result: Dictionary, fragment: String) -> bool:
	for diagnostic in result.get("diagnostics", []):
		if str(diagnostic).contains(fragment):
			return true
	return false


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, expected, actual])
