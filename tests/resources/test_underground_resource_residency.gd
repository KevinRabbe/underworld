extends RefCounted

const CaveRuntimeController := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const CellAddress := preload("res://worldgen/geometry/geometry_cell_address.gd")
const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const ResidencyService := preload("res://gameplay/resources/runtime/underground_resource_residency_service.gd")
const ActionService := preload("res://gameplay/resources/runtime/underground_resource_action_service.gd")
const ContentEvidence := preload("res://gameplay/resources/runtime/underground_resource_content_evidence.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const RuntimeTests := preload("res://tests/resources/test_underground_resource_runtime.gd")


class FakeFragment extends RefCounted:
	var fragment_id: String
	var source_descriptor_id: String
	var source_kind: String
	var cell_bounds: AABB
	var clipped_source_bounds: AABB
	var is_owner: bool
	var source_fingerprint: String
	var metadata: Dictionary

	func _init(metadata_value: Dictionary) -> void:
		fragment_id = "fragment-owner"
		source_descriptor_id = "site-owner"
		source_kind = "reserved_site"
		cell_bounds = AABB(Vector3(-4, -8, -4), Vector3(8, 8, 8))
		clipped_source_bounds = cell_bounds
		is_owner = true
		source_fingerprint = "fragment:site-owner"
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
	_test_render_first_collision_lifecycle_and_reentry(failures)
	return failures


static func _test_render_first_collision_lifecycle_and_reentry(failures: Array[String]) -> void:
	var controller = CaveRuntimeController.new()
	controller.configure("world:residency", "manifest:residency")
	var address = CellAddress.new(Vector3i(1, -2, 1))
	var source := "resource-residency-test"
	var source_fingerprint := "source:residency"
	var provenance_fingerprint := "provenance:residency"
	var record = controller.streamer.demand_cell(
		address,
		source,
		["render", "collision"],
		source_fingerprint,
		provenance_fingerprint
	)
	record.readiness["render"] = true
	record.readiness["collision"] = false

	var plan = FakePlan.new()
	plan.fragments = [FakeFragment.new(_owner_metadata())]
	var definitions = FakeDefinitionService.new()
	definitions.definitions[address.canonical_text()] = {
		"region": Vector2i(0, 0),
		"cell_plan": plan,
		"source_fingerprint": source_fingerprint,
		"provenance_fingerprint": provenance_fingerprint,
	}
	controller._definition_service = definitions

	var authority: Dictionary = ContentEvidence.build_first_iron_authority()
	var service = ResidencyService.new()
	var configure_failures: Array[String] = service.configure(controller, authority)
	for failure in configure_failures:
		failures.append("residency configure: %s" % failure)
	if not configure_failures.is_empty():
		service.dispose()
		controller.free()
		return

	var action = ActionService.new()
	var action_failures: Array[String] = action.configure(service)
	for failure in action_failures:
		failures.append("resource action configure: %s" % failure)
	if not action_failures.is_empty():
		service.dispose()
		controller.free()
		return
	var runtime_fixture: Dictionary = RuntimeTests._content_fixture(failures)
	if runtime_fixture.is_empty():
		service.dispose()
		controller.free()
		return
	var equipment_fixture: Dictionary = RuntimeTests._pickaxe_equipment(runtime_fixture["pickaxe"], failures)
	if equipment_fixture.is_empty():
		service.dispose()
		controller.free()
		return
	var inventory = ItemContainerState.new().configure(4)
	var store = WorldDeltaStore.new()

	_expect_equal(failures, "render-ready owner cell creates one semantic residency entry", service.semantic_cell_count(), 1)
	var initial: Dictionary = service.semantic_entry(address.canonical_text())
	_expect_true(failures, "render-first semantic residency has no collision authority", not bool(initial.get("collision_ready", true)))
	_expect_equal(failures, "render-first semantic residency has one placement", initial.get("placements", []).size(), 1)
	if initial.get("placements", []).is_empty():
		service.dispose()
		controller.free()
		return
	var placement_id: String = str(initial["placements"][0].placement_stable_id)
	var initial_generation: int = int(initial.get("generation", -1))
	var no_collision_ticket: Dictionary = action.prepare_mining(
		address.canonical_text(),
		placement_id,
		runtime_fixture["registry"],
		store
	)
	_expect_true(failures, "render-only resource cannot prepare interactive mining ticket", not bool(no_collision_ticket.get("success", true)))

	# Collision arrives later for the same current incarnation. The attach edge is
	# sufficient to update readiness; no Player movement/observer poll is needed.
	record.readiness["collision"] = true
	controller.cell_attached.emit(address, "collision")
	var collision_ready: Dictionary = service.semantic_entry(address.canonical_text())
	_expect_true(failures, "matching collision attach marks semantic placement collision-ready", bool(collision_ready.get("collision_ready", false)))
	_expect_equal(failures, "collision attach does not duplicate semantic placements", collision_ready.get("placements", []).size(), 1)
	var prepared_before_retire: Dictionary = action.prepare_mining(
		address.canonical_text(),
		placement_id,
		runtime_fixture["registry"],
		store
	)
	_expect_true(failures, "collision-ready current placement prepares mining ticket", bool(prepared_before_retire.get("success", false)))
	var pre_retire_ticket = prepared_before_retire.get("ticket", null)
	var before_stale_inventory: String = inventory.canonical_json()
	var before_stale_store: Dictionary = store.snapshot()

	# Retiring only collision advances #372's cell generation. Semantic placement
	# identity survives deterministic refresh while collision authority disappears.
	_expect_true(
		failures,
		"streamer accepts collision-only retirement",
		controller.streamer.release_demand(address, source, ["collision"])
	)
	var after_collision_retire: Dictionary = service.semantic_entry(address.canonical_text())
	_expect_true(failures, "render-relevant semantic placement survives collision retirement", not after_collision_retire.is_empty())
	_expect_true(failures, "collision retirement removes collision readiness", not bool(after_collision_retire.get("collision_ready", true)))
	_expect_true(
		failures,
		"collision retirement refreshes to a new cell generation",
		int(after_collision_retire.get("generation", -1)) != initial_generation
	)
	if not after_collision_retire.get("placements", []).is_empty():
		_expect_equal(
			failures,
			"generation refresh preserves durable placement identity",
			str(after_collision_retire["placements"][0].placement_stable_id),
			placement_id
		)
	if pre_retire_ticket != null:
		var blocked_without_collision: Dictionary = action.execute_mining(
			pre_retire_ticket,
			runtime_fixture["registry"],
			equipment_fixture["equipment"],
			inventory,
			store
		)
		_expect_true(failures, "ticket cannot execute after collision retirement", not bool(blocked_without_collision.get("success", true)))
		_expect_equal(failures, "collision-retired ticket yields no inventory", inventory.canonical_json(), before_stale_inventory)
		_expect_equal(failures, "collision-retired ticket mutates no WorldDelta", store.snapshot(), before_stale_store)

	# Reacquire collision for the current generation and prove a single placement
	# is still present.
	record = controller.streamer.set_demand(
		address,
		source,
		["render", "collision"],
		source_fingerprint,
		provenance_fingerprint
	)
	record.readiness["collision"] = true
	controller.cell_attached.emit(address, "collision")
	var reacquired: Dictionary = service.semantic_entry(address.canonical_text())
	_expect_true(failures, "reacquired collision restores readiness", bool(reacquired.get("collision_ready", false)))
	_expect_equal(failures, "collision reacquisition keeps one placement", reacquired.get("placements", []).size(), 1)
	if not reacquired.get("placements", []).is_empty():
		_expect_equal(failures, "collision reacquisition preserves placement StableId", str(reacquired["placements"][0].placement_stable_id), placement_id)
	if pre_retire_ticket != null:
		var blocked_stale_generation: Dictionary = action.execute_mining(
			pre_retire_ticket,
			runtime_fixture["registry"],
			equipment_fixture["equipment"],
			inventory,
			store
		)
		_expect_true(failures, "ticket from prior cell generation remains stale after collision reacquisition", not bool(blocked_stale_generation.get("success", true)))
		_expect_equal(failures, "stale generation after reacquisition yields no inventory", inventory.canonical_json(), before_stale_inventory)
		_expect_equal(failures, "stale generation after reacquisition mutates no WorldDelta", store.snapshot(), before_stale_store)

	var fresh_ticket_result: Dictionary = action.prepare_mining(
		address.canonical_text(),
		placement_id,
		runtime_fixture["registry"],
		store
	)
	_expect_true(failures, "fresh current generation prepares replacement mining ticket", bool(fresh_ticket_result.get("success", false)))
	var fresh_ticket = fresh_ticket_result.get("ticket", null)
	if fresh_ticket != null:
		var mined: Dictionary = action.execute_mining(
			fresh_ticket,
			runtime_fixture["registry"],
			equipment_fixture["equipment"],
			inventory,
			store
		)
		_expect_true(failures, "fresh current-generation ticket mines through ordinary runtime service", bool(mined.get("success", false)))
		_expect_equal(failures, "fresh current-generation ticket yields one iron", inventory.quantity_of("item.resource.iron_chunk"), 1)
		var duplicate: Dictionary = action.execute_mining(
			fresh_ticket,
			runtime_fixture["registry"],
			equipment_fixture["equipment"],
			inventory,
			store
		)
		_expect_true(failures, "same current-generation ticket retry is accepted idempotently", bool(duplicate.get("success", false)))
		_expect_true(failures, "same current-generation ticket retry reports duplicate", bool(duplicate.get("duplicate", false)))
		_expect_equal(failures, "same current-generation ticket retry yields no second iron", inventory.quantity_of("item.resource.iron_chunk"), 1)

	# Full owner-cell retirement removes only transient semantic residency.
	_expect_true(failures, "full owner-cell demand release succeeds", controller.streamer.release_demand(address, source))
	_expect_equal(failures, "render retirement removes semantic residency", service.semantic_cell_count(), 0)
	if fresh_ticket != null:
		var dormant_result: Dictionary = action.execute_mining(
			fresh_ticket,
			runtime_fixture["registry"],
			equipment_fixture["equipment"],
			inventory,
			store
		)
		_expect_true(failures, "ticket cannot target fully retired owner cell", not bool(dormant_result.get("success", true)))
		_expect_equal(failures, "dormant owner cell cannot duplicate yield", inventory.quantity_of("item.resource.iron_chunk"), 1)

	# Re-entry reconstructs from the same generated owner source and therefore the
	# same placement identity, without a historical placement table. Durable
	# depletion is restored before any later realization decision.
	record = controller.streamer.demand_cell(
		address,
		source,
		["render"],
		source_fingerprint,
		provenance_fingerprint
	)
	record.readiness["render"] = true
	controller.cell_attached.emit(address, "render")
	var reentered: Dictionary = service.semantic_entry(address.canonical_text())
	_expect_equal(failures, "owner-cell re-entry reconstructs one semantic placement", reentered.get("placements", []).size(), 1)
	if not reentered.get("placements", []).is_empty():
		_expect_equal(failures, "owner-cell re-entry reproduces placement StableId", str(reentered["placements"][0].placement_stable_id), placement_id)
	var restored_before_realization: Dictionary = action.inspect_current_placement_state(
		address.canonical_text(),
		placement_id,
		runtime_fixture["registry"],
		store
	)
	_expect_true(failures, "re-entry restores durable depletion before realization decision", bool(restored_before_realization.get("success", false)))
	_expect_equal(failures, "re-entry restores partial remaining capacity", float(restored_before_realization.get("remaining_capacity_units", -1.0)), 3.0)
	_expect_true(failures, "partial depletion permits later realization subject to other gates", bool(restored_before_realization.get("depletion_allows_realization", false)))
	_expect_true(failures, "render-only re-entry still lacks collision readiness", not bool(restored_before_realization.get("collision_ready", true)))

	service.dispose()
	controller.free()


static func _owner_metadata() -> Dictionary:
	var region_address = StableAddress.underground_region(0, 0)
	var site_address = StableAddress.special_location(region_address, "reserved_site", 0)
	var stable_id = StableId.from_address(site_address)
	return {
		"stable_id": "" if stable_id == null else stable_id.value(),
		"free_world_anchor": Vector3(1.5, -20.0, 3.0),
		"semantic_category": "reserved_site",
		"reserved_bounds": AABB(Vector3(-2, -24, -2), Vector3(8, 8, 8)),
		"profile_blend": Vector3(0.2, 0.5, 0.3),
		"generation_metadata": {"candidate_slot": 0},
	}


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, expected, actual])
