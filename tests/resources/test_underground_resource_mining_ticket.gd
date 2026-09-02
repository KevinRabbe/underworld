extends RefCounted

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const UndergroundPlacementRecord := preload("res://content/placement/underground_placement_record.gd")
const EquipmentSlotRule := preload("res://gameplay/items/equipment/equipment_slot_rule.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const TicketService := preload("res://gameplay/resources/runtime/underground_resource_mining_ticket_service.gd")
const RuntimeTests := preload("res://tests/resources/test_underground_resource_runtime.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_retry_reuses_captured_operation_identity(failures)
	_test_failed_inventory_does_not_advance_durable_ordinal(failures)
	_test_wrong_tool_does_not_advance_durable_ordinal(failures)
	_test_reconstruction_advances_from_world_delta(failures)
	_test_same_ordinal_never_aliases_across_placements(failures)
	_test_depletion_is_restored_before_realization_eligibility(failures)
	_test_stale_ticket_fails_without_mutation(failures)
	_test_stale_cell_generation_fails_without_mutation(failures)
	return failures


static func _test_retry_reuses_captured_operation_identity(failures: Array[String]) -> void:
	var fixture: Dictionary = RuntimeTests._content_fixture(failures)
	if fixture.is_empty():
		return
	var equipment_fixture: Dictionary = RuntimeTests._pickaxe_equipment(fixture["pickaxe"], failures)
	if equipment_fixture.is_empty():
		return
	var placement = RuntimeTests._placement()
	var cell_entry: Dictionary = _cell_entry(placement)
	var inventory = ItemContainerState.new().configure(4)
	var store = WorldDeltaStore.new()
	var service = TicketService.new()

	var prepared: Dictionary = service.prepare_ticket(placement, fixture["registry"], store, cell_entry)
	_expect_true(failures, "first production mining ticket prepares", bool(prepared.get("success", false)))
	if not bool(prepared.get("success", false)):
		return
	var ticket = prepared.get("ticket", null)
	_expect_equal(failures, "first durable mining ordinal is one", ticket.operation_ordinal(), 1)
	var first_operation_id: String = ticket.operation_id()
	_expect_true(failures, "mining operation identity is canonical StableId", StableId.parse(first_operation_id) != null)

	var first: Dictionary = service.execute_ticket(
		ticket,
		placement,
		fixture["registry"],
		equipment_fixture["equipment"],
		inventory,
		store,
		cell_entry
	)
	_expect_true(failures, "first ticket execution succeeds", bool(first.get("success", false)))
	_expect_true(failures, "first ticket execution is not duplicate", not bool(first.get("duplicate", true)))
	_expect_equal(failures, "first ticket yields one iron", inventory.quantity_of("item.resource.iron_chunk"), 1)

	var retry: Dictionary = service.execute_ticket(
		ticket,
		placement,
		fixture["registry"],
		equipment_fixture["equipment"],
		inventory,
		store,
		cell_entry
	)
	_expect_true(failures, "same ticket retry succeeds idempotently", bool(retry.get("success", false)))
	_expect_true(failures, "same ticket retry reports duplicate", bool(retry.get("duplicate", false)))
	_expect_equal(failures, "same ticket retry yields no second iron", inventory.quantity_of("item.resource.iron_chunk"), 1)
	_expect_equal(failures, "same immutable ticket preserves captured operation id", ticket.operation_id(), first_operation_id)

	var next_prepared: Dictionary = service.prepare_ticket(placement, fixture["registry"], store, cell_entry)
	_expect_true(failures, "later legitimate interaction prepares next ticket", bool(next_prepared.get("success", false)))
	if bool(next_prepared.get("success", false)):
		var next_ticket = next_prepared.get("ticket", null)
		_expect_equal(failures, "next legitimate interaction advances durable ordinal", next_ticket.operation_ordinal(), 2)
		_expect_true(failures, "next legitimate interaction has distinct operation id", next_ticket.operation_id() != first_operation_id)


static func _test_failed_inventory_does_not_advance_durable_ordinal(failures: Array[String]) -> void:
	var fixture: Dictionary = RuntimeTests._content_fixture(failures)
	if fixture.is_empty():
		return
	var equipment_fixture: Dictionary = RuntimeTests._pickaxe_equipment(fixture["pickaxe"], failures)
	if equipment_fixture.is_empty():
		return
	var placement = RuntimeTests._placement()
	var cell_entry: Dictionary = _cell_entry(placement)
	var full_inventory = ItemContainerState.new().configure(1)
	var fill: Dictionary = full_inventory.add_stack(fixture["stone"], 1)
	_expect_true(failures, "ticket failure fixture inventory fills", bool(fill.get("success", false)))
	var store = WorldDeltaStore.new()
	var service = TicketService.new()
	var before_store: Dictionary = store.snapshot()

	var first_prepare: Dictionary = service.prepare_ticket(placement, fixture["registry"], store, cell_entry)
	_expect_true(failures, "failed-inventory ticket prepares", bool(first_prepare.get("success", false)))
	if not bool(first_prepare.get("success", false)):
		return
	var first_ticket = first_prepare.get("ticket", null)
	var failed: Dictionary = service.execute_ticket(
		first_ticket,
		placement,
		fixture["registry"],
		equipment_fixture["equipment"],
		full_inventory,
		store,
		cell_entry
	)
	_expect_true(failures, "inventory rejection fails ticket execution", not bool(failed.get("success", true)))
	_expect_equal(failures, "failed ticket execution leaves WorldDelta unchanged", store.snapshot(), before_store)

	var retry_prepare: Dictionary = TicketService.new().prepare_ticket(placement, fixture["registry"], store, cell_entry)
	_expect_true(failures, "later preparation after failed inventory succeeds", bool(retry_prepare.get("success", false)))
	if bool(retry_prepare.get("success", false)):
		var retry_ticket = retry_prepare.get("ticket", null)
		_expect_equal(failures, "failed inventory does not advance ordinal", retry_ticket.operation_ordinal(), first_ticket.operation_ordinal())
		_expect_equal(failures, "failed inventory reuses same durable operation identity", retry_ticket.operation_id(), first_ticket.operation_id())


static func _test_wrong_tool_does_not_advance_durable_ordinal(failures: Array[String]) -> void:
	var fixture: Dictionary = RuntimeTests._content_fixture(failures)
	if fixture.is_empty():
		return
	var placement = RuntimeTests._placement()
	var cell_entry: Dictionary = _cell_entry(placement)
	var rule = EquipmentSlotRule.new().configure(
		"equipment_slot.tool.primary",
		["category.item.equipment.tool.pickaxe"],
		["capability.harvest_tool"]
	)
	var empty_equipment = EquipmentHotbarState.new().configure([rule], {1: "equipment_slot.tool.primary"})
	var inventory = ItemContainerState.new().configure(4)
	var store = WorldDeltaStore.new()
	var service = TicketService.new()
	var before_store: Dictionary = store.snapshot()
	var prepared: Dictionary = service.prepare_ticket(placement, fixture["registry"], store, cell_entry)
	_expect_true(failures, "wrong-tool ticket prepares from semantic resource state", bool(prepared.get("success", false)))
	if not bool(prepared.get("success", false)):
		return
	var ticket = prepared.get("ticket", null)
	var failed: Dictionary = service.execute_ticket(
		ticket,
		placement,
		fixture["registry"],
		empty_equipment,
		inventory,
		store,
		cell_entry
	)
	_expect_true(failures, "wrong tool rejects ticket execution", not bool(failed.get("success", true)))
	_expect_equal(failures, "wrong tool leaves WorldDelta unchanged", store.snapshot(), before_store)
	_expect_equal(failures, "wrong tool yields no iron", inventory.quantity_of("item.resource.iron_chunk"), 0)
	var retry_prepare: Dictionary = TicketService.new().prepare_ticket(placement, fixture["registry"], store, cell_entry)
	_expect_true(failures, "later preparation after wrong tool succeeds", bool(retry_prepare.get("success", false)))
	if bool(retry_prepare.get("success", false)):
		var retry_ticket = retry_prepare.get("ticket", null)
		_expect_equal(failures, "wrong tool does not advance durable ordinal", retry_ticket.operation_ordinal(), ticket.operation_ordinal())
		_expect_equal(failures, "wrong tool reuses same durable operation identity", retry_ticket.operation_id(), ticket.operation_id())


static func _test_reconstruction_advances_from_world_delta(failures: Array[String]) -> void:
	var fixture: Dictionary = RuntimeTests._content_fixture(failures)
	if fixture.is_empty():
		return
	var equipment_fixture: Dictionary = RuntimeTests._pickaxe_equipment(fixture["pickaxe"], failures)
	if equipment_fixture.is_empty():
		return
	var placement = RuntimeTests._placement()
	var cell_entry: Dictionary = _cell_entry(placement)
	var inventory = ItemContainerState.new().configure(4)
	var store = WorldDeltaStore.new()
	var first_service = TicketService.new()
	var prepared: Dictionary = first_service.prepare_ticket(placement, fixture["registry"], store, cell_entry)
	if not bool(prepared.get("success", false)):
		failures.append("reconstruction ticket fixture could not prepare: %s" % [prepared.get("diagnostics", [])])
		return
	var first_ticket = prepared.get("ticket", null)
	var first: Dictionary = first_service.execute_ticket(
		first_ticket,
		placement,
		fixture["registry"],
		equipment_fixture["equipment"],
		inventory,
		store,
		cell_entry
	)
	_expect_true(failures, "reconstruction fixture first mine succeeds", bool(first.get("success", false)))

	# New service instance models runtime unload/re-entry or Continue composition.
	# The next ordinal comes only from restored WorldDelta, not service lifetime.
	var reconstructed_service = TicketService.new()
	var next: Dictionary = reconstructed_service.prepare_ticket(placement, fixture["registry"], store, cell_entry)
	_expect_true(failures, "reconstructed service prepares from durable depletion", bool(next.get("success", false)))
	if bool(next.get("success", false)):
		var next_ticket = next.get("ticket", null)
		_expect_equal(failures, "reconstructed service advances durable ordinal", next_ticket.operation_ordinal(), 2)
		_expect_true(failures, "reconstructed service does not repeat prior operation id", next_ticket.operation_id() != first_ticket.operation_id())


static func _test_same_ordinal_never_aliases_across_placements(failures: Array[String]) -> void:
	var fixture: Dictionary = RuntimeTests._content_fixture(failures)
	if fixture.is_empty():
		return
	var store = WorldDeltaStore.new()
	var service = TicketService.new()
	var placement_a = RuntimeTests._placement()
	var placement_b = _placement_for_slot(1)
	var prepared_a: Dictionary = service.prepare_ticket(placement_a, fixture["registry"], store, _cell_entry(placement_a))
	var prepared_b: Dictionary = service.prepare_ticket(placement_b, fixture["registry"], store, _cell_entry(placement_b))
	_expect_true(failures, "placement A ticket prepares", bool(prepared_a.get("success", false)))
	_expect_true(failures, "placement B ticket prepares", bool(prepared_b.get("success", false)))
	if bool(prepared_a.get("success", false)) and bool(prepared_b.get("success", false)):
		var ticket_a = prepared_a.get("ticket", null)
		var ticket_b = prepared_b.get("ticket", null)
		_expect_equal(failures, "both fresh placements use ordinal one", ticket_a.operation_ordinal(), ticket_b.operation_ordinal())
		_expect_true(failures, "same ordinal on distinct placements cannot alias", ticket_a.operation_id() != ticket_b.operation_id())


static func _test_depletion_is_restored_before_realization_eligibility(failures: Array[String]) -> void:
	var fixture: Dictionary = RuntimeTests._content_fixture(failures)
	if fixture.is_empty():
		return
	var equipment_fixture: Dictionary = RuntimeTests._pickaxe_equipment(fixture["pickaxe"], failures)
	if equipment_fixture.is_empty():
		return
	var placement = RuntimeTests._placement()
	var cell_entry: Dictionary = _cell_entry(placement)
	var inventory = ItemContainerState.new().configure(4)
	var store = WorldDeltaStore.new()
	var service = TicketService.new()
	var fresh_state: Dictionary = service.inspect_realization_state(placement, fixture["registry"], store)
	_expect_true(failures, "fresh placement restores before realization decision", bool(fresh_state.get("success", false)))
	_expect_true(failures, "fresh depletion state permits later gated realization", bool(fresh_state.get("depletion_allows_realization", false)))

	for ordinal in range(1, 5):
		var prepared: Dictionary = service.prepare_ticket(placement, fixture["registry"], store, cell_entry)
		if not bool(prepared.get("success", false)):
			failures.append("depletion ticket %d could not prepare: %s" % [ordinal, prepared.get("diagnostics", [])])
			return
		var mined: Dictionary = service.execute_ticket(
			prepared.get("ticket", null),
			placement,
			fixture["registry"],
			equipment_fixture["equipment"],
			inventory,
			store,
			cell_entry
		)
		if not bool(mined.get("success", false)):
			failures.append("depletion ticket %d could not execute: %s" % [ordinal, mined.get("diagnostics", [])])
			return

	var before_reconstruction: Dictionary = store.snapshot()
	var depleted_state: Dictionary = TicketService.new().inspect_realization_state(placement, fixture["registry"], store)
	_expect_true(failures, "depleted placement state still restores successfully", bool(depleted_state.get("success", false)))
	_expect_true(failures, "depleted placement blocks realization before Node creation", not bool(depleted_state.get("depletion_allows_realization", true)))
	_expect_equal(failures, "depletion restore inspection does not rewrite WorldDelta", store.snapshot(), before_reconstruction)
	var impossible_ticket: Dictionary = TicketService.new().prepare_ticket(placement, fixture["registry"], store, cell_entry)
	_expect_true(failures, "depleted placement cannot prepare another mining ticket", not bool(impossible_ticket.get("success", true)))


static func _test_stale_ticket_fails_without_mutation(failures: Array[String]) -> void:
	var fixture: Dictionary = RuntimeTests._content_fixture(failures)
	if fixture.is_empty():
		return
	var equipment_fixture: Dictionary = RuntimeTests._pickaxe_equipment(fixture["pickaxe"], failures)
	if equipment_fixture.is_empty():
		return
	var placement = RuntimeTests._placement()
	var changed_placement = RuntimeTests._placement("upf1:resource-ticket-replanned")
	var inventory = ItemContainerState.new().configure(4)
	var store = WorldDeltaStore.new()
	var service = TicketService.new()
	var prepared: Dictionary = service.prepare_ticket(placement, fixture["registry"], store, _cell_entry(placement))
	if not bool(prepared.get("success", false)):
		failures.append("stale-ticket fixture could not prepare: %s" % [prepared.get("diagnostics", [])])
		return
	var before_inventory: String = inventory.canonical_json()
	var before_store: Dictionary = store.snapshot()
	var result: Dictionary = service.execute_ticket(
		prepared.get("ticket", null),
		changed_placement,
		fixture["registry"],
		equipment_fixture["equipment"],
		inventory,
		store,
		_cell_entry(changed_placement)
	)
	_expect_true(failures, "ticket prepared for old placement fingerprint fails closed", not bool(result.get("success", true)))
	_expect_equal(failures, "stale ticket changes no inventory", inventory.canonical_json(), before_inventory)
	_expect_equal(failures, "stale ticket changes no WorldDelta", store.snapshot(), before_store)


static func _test_stale_cell_generation_fails_without_mutation(failures: Array[String]) -> void:
	var fixture: Dictionary = RuntimeTests._content_fixture(failures)
	if fixture.is_empty():
		return
	var equipment_fixture: Dictionary = RuntimeTests._pickaxe_equipment(fixture["pickaxe"], failures)
	if equipment_fixture.is_empty():
		return
	var placement = RuntimeTests._placement()
	var old_entry: Dictionary = _cell_entry(placement, 7)
	var fresh_entry: Dictionary = _cell_entry(placement, 8)
	var inventory = ItemContainerState.new().configure(4)
	var store = WorldDeltaStore.new()
	var service = TicketService.new()
	var prepared: Dictionary = service.prepare_ticket(placement, fixture["registry"], store, old_entry)
	_expect_true(failures, "old-generation ticket fixture prepares", bool(prepared.get("success", false)))
	if not bool(prepared.get("success", false)):
		return
	var before_inventory: String = inventory.canonical_json()
	var before_store: Dictionary = store.snapshot()
	var result: Dictionary = service.execute_ticket(
		prepared.get("ticket", null),
		placement,
		fixture["registry"],
		equipment_fixture["equipment"],
		inventory,
		store,
		fresh_entry
	)
	_expect_true(failures, "ticket from retired owner-cell generation fails closed", not bool(result.get("success", true)))
	_expect_equal(failures, "stale cell-generation ticket yields no iron", inventory.canonical_json(), before_inventory)
	_expect_equal(failures, "stale cell-generation ticket mutates no WorldDelta", store.snapshot(), before_store)


static func _cell_entry(placement, generation: int = 1) -> Dictionary:
	return {
		"cell_address": "gcell1:r1:x2:y-3:z-1",
		"generation": generation,
		"source_fingerprint": "source:resource-ticket-test",
		"provenance_fingerprint": "provenance:resource-ticket-test",
		"collision_ready": true,
		"placements": [placement],
	}


static func _placement_for_slot(slot_index: int):
	var address = StableAddress.from_segments(["underworld", "resource", "iron", "slot", str(slot_index)])
	var stable_id = StableId.from_address(address)
	var candidate_address = StableAddress.from_segments(["underworld", "resource", "iron"])
	var candidate_id = StableId.from_address(candidate_address)
	return UndergroundPlacementRecord.new(
		stable_id.value(),
		candidate_id.value(),
		slot_index,
		"placement_policy.resource.iron_outcrop",
		"resource.deposit.iron_outcrop",
		"resource",
		"upf1:iron-runtime-slot-%d" % slot_index
	)


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, expected, actual])
