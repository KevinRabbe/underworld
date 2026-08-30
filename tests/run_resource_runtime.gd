extends SceneTree

const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const RuntimeService := preload("res://gameplay/resources/runtime/underground_resource_runtime_service.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const RuntimeTests := preload("res://tests/resources/test_underground_resource_runtime.gd")


class CommitFailingInventory extends ItemContainerState:
	var fail_add_stack: bool = false

	func add_stack(definition, quantity: int, stack_state: Dictionary = {}) -> Dictionary:
		if fail_add_stack:
			return {
				"success": false,
				"diagnostics": ["injected resource-runtime commit-phase add failure"],
			}
		return super.add_stack(definition, quantity, stack_state)


func _init() -> void:
	var failures: Array[String] = RuntimeTests.run()
	_test_commit_phase_failure_restores_world_delta(failures)
	if failures.is_empty():
		print("[RESOURCE RUNTIME VALIDATION] PASS")
		print("  iron content / archetype realization / semantic pickaxe eligibility / atomic inventory yield / persistent depletion / idempotence / strict restore compatibility / commit-phase rollback passed")
		quit(0)
		return

	printerr("[RESOURCE RUNTIME VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)


func _test_commit_phase_failure_restores_world_delta(failures: Array[String]) -> void:
	var fixture: Dictionary = RuntimeTests._content_fixture(failures)
	if fixture.is_empty():
		return
	var equipment_fixture: Dictionary = RuntimeTests._pickaxe_equipment(fixture["pickaxe"], failures)
	if equipment_fixture.is_empty():
		return
	var placement = RuntimeTests._placement()

	# Fresh placement: preflight succeeds, the runtime temporarily writes depletion,
	# the real container add fails during commit, and rollback must restore true
	# object_state absence rather than materializing an empty dictionary entry.
	var fresh_inventory = CommitFailingInventory.new()
	fresh_inventory.configure(2)
	fresh_inventory.fail_add_stack = true
	var fresh_store = WorldDeltaStore.new()
	var fresh_before_inventory: String = fresh_inventory.canonical_json()
	var fresh_before_store: Dictionary = fresh_store.snapshot()
	var fresh_result: Dictionary = RuntimeService.new().mine(
		placement,
		fixture["registry"],
		equipment_fixture["equipment"],
		fresh_inventory,
		fresh_store,
		"commit-failure-fresh"
	)
	if bool(fresh_result.get("success", true)):
		failures.append("fresh commit-phase inventory failure was accepted")
	if fresh_inventory.canonical_json() != fresh_before_inventory:
		failures.append("fresh commit-phase failure changed canonical inventory state")
	if fresh_store.snapshot() != fresh_before_store:
		failures.append("fresh commit-phase failure changed complete WorldDeltaStore snapshot")
	var fresh_object_state = fresh_store.snapshot().get("object_state", {})
	if fresh_object_state is Dictionary and fresh_object_state.has(placement.placement_stable_id):
		failures.append("fresh commit-phase rollback materialized an object_state entry that was absent before mining")

	# Existing depletion: rollback must reproduce the exact prior non-empty envelope,
	# not merely remove or replace the current placement entry.
	var existing_inventory = CommitFailingInventory.new()
	existing_inventory.configure(2)
	var existing_store = WorldDeltaStore.new()
	var service = RuntimeService.new()
	var setup: Dictionary = service.mine(
		placement,
		fixture["registry"],
		equipment_fixture["equipment"],
		existing_inventory,
		existing_store,
		"commit-failure-existing-setup"
	)
	if not bool(setup.get("success", false)):
		failures.append("existing commit-phase rollback fixture setup failed: %s" % [setup.get("diagnostics", [])])
		return
	existing_inventory.fail_add_stack = true
	var existing_before_inventory: String = existing_inventory.canonical_json()
	var existing_before_store: Dictionary = existing_store.snapshot()
	var existing_before_envelope: Dictionary = existing_store.get_object_state(placement.placement_stable_id)
	var existing_result: Dictionary = service.mine(
		placement,
		fixture["registry"],
		equipment_fixture["equipment"],
		existing_inventory,
		existing_store,
		"commit-failure-existing"
	)
	if bool(existing_result.get("success", true)):
		failures.append("existing-state commit-phase inventory failure was accepted")
	if existing_inventory.canonical_json() != existing_before_inventory:
		failures.append("existing-state commit-phase failure changed canonical inventory state")
	if existing_store.snapshot() != existing_before_store:
		failures.append("existing-state commit-phase failure changed complete WorldDeltaStore snapshot")
	if existing_store.get_object_state(placement.placement_stable_id) != existing_before_envelope:
		failures.append("existing-state commit-phase rollback did not restore the exact prior depletion envelope")
