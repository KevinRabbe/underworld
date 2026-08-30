extends SceneTree

const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const RuntimeService := preload("res://gameplay/resources/runtime/underground_resource_runtime_service.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const RuntimeTests := preload("res://tests/resources/test_underground_resource_runtime.gd")
const REQUIRED_ITEM_DEPENDENCY_PATHS: Array[String] = [
	"content/items/resources/stone_definition.tres",
	"content/items/tools/stone_pickaxe_definition.tres",
	"gameplay/items/definitions/item_definition.gd",
	"gameplay/items/equipment/equipment_hotbar_state.gd",
	"gameplay/items/equipment/equipped_item_resolver.gd",
	"gameplay/items/equipment/equipment_slot_rule.gd",
	"gameplay/items/equipment/equipment_service.gd",
	"gameplay/items/weapons/definitions/weapon_definition.gd",
	"gameplay/items/weapons/runtime/weapon_attack_resolver.gd",
	"gameplay/items/inventory/item_container_state.gd",
	"gameplay/items/inventory/inventory_transaction_plan.gd",
	"gameplay/items/inventory/inventory_transaction_service.gd",
	"gameplay/items/inventory/inventory_transaction_checkpoint.gd",
	"gameplay/items/inventory/inventory_state_codec.gd",
	"gameplay/items/inventory/item_stack_state.gd",
	"gameplay/items/inventory/item_instance_state.gd",
]


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
	_test_workflow_dependency_triggers(failures)
	_test_commit_phase_failure_restores_world_delta(failures)
	if failures.is_empty():
		print("[RESOURCE RUNTIME VALIDATION] PASS")
		print("  iron content / archetype realization / semantic pickaxe eligibility / atomic inventory yield / persistent depletion / idempotence / strict restore compatibility / commit-phase rollback / workflow dependency triggers passed")
		quit(0)
		return

	printerr("[RESOURCE RUNTIME VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)


func _test_workflow_dependency_triggers(failures: Array[String]) -> void:
	const WORKFLOW_PATH := "res://.github/workflows/resource-runtime-validation.yml"
	if not FileAccess.file_exists(WORKFLOW_PATH):
		failures.append("Resource Runtime workflow file is missing")
		return
	var workflow_file := FileAccess.open(WORKFLOW_PATH, FileAccess.READ)
	if workflow_file == null:
		failures.append("Resource Runtime workflow could not be opened for dependency-trigger validation")
		return
	var pull_request_paths: Array[String] = _pull_request_path_filters(
		workflow_file.get_as_text(),
		failures
	)
	if pull_request_paths.has("gameplay/items/**"):
		failures.append(
			"Resource Runtime dependency trigger must remain precise; broad gameplay/items/** is not allowed"
		)
	for dependency_path in REQUIRED_ITEM_DEPENDENCY_PATHS:
		if not pull_request_paths.has(dependency_path):
			failures.append(
				"Resource Runtime pull_request.paths is missing item dependency trigger: %s" % dependency_path
			)


func _pull_request_path_filters(
	workflow_text: String,
	failures: Array[String]
) -> Array[String]:
	var result: Array[String] = []
	var found_pull_request: bool = false
	var found_paths: bool = false
	var in_pull_request: bool = false
	var in_paths: bool = false

	for raw_line in workflow_text.split("\n"):
		var line: String = str(raw_line).replace("\r", "")
		if line == "  pull_request:":
			found_pull_request = true
			in_pull_request = true
			in_paths = false
			continue
		if not in_pull_request:
			continue

		# Any new two-space key ends the pull_request mapping.
		if line.begins_with("  ") and not line.begins_with("    "):
			break

		if not in_paths:
			if line == "    paths:":
				found_paths = true
				in_paths = true
			continue

		# Any new four-space key ends the paths sequence.
		if line.begins_with("    ") and not line.begins_with("      "):
			break
		if line.begins_with("      - "):
			var encoded_value: String = line.substr(8)
			if encoded_value.length() < 2:
				failures.append("Resource Runtime pull_request.paths contains an empty list entry")
				continue
			var quote: String = encoded_value.substr(0, 1)
			if (quote != "'" and quote != "\"") or not encoded_value.ends_with(quote):
				failures.append(
					"Resource Runtime pull_request.paths entry must be a quoted scalar: %s" % encoded_value
				)
				continue
			var path_value: String = encoded_value.substr(1, encoded_value.length() - 2)
			if path_value.is_empty() or path_value != path_value.strip_edges():
				failures.append("Resource Runtime pull_request.paths contains an invalid path scalar")
				continue
			if result.has(path_value):
				failures.append(
					"Resource Runtime pull_request.paths contains duplicate entry: %s" % path_value
				)
				continue
			result.append(path_value)
			continue

		var trimmed: String = line.strip_edges()
		if not trimmed.is_empty() and not trimmed.begins_with("#"):
			failures.append(
				"Resource Runtime pull_request.paths contains unexpected non-list content: %s" % trimmed
			)

	if not found_pull_request:
		failures.append("Resource Runtime workflow is missing on.pull_request")
	elif not found_paths:
		failures.append("Resource Runtime workflow is missing on.pull_request.paths")
	return result


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
