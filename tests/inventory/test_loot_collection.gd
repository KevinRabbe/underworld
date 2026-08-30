extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const LootRewardService := preload("res://gameplay/loot/runtime/loot_reward_service.gd")
const PendingLootState := preload("res://gameplay/loot/runtime/pending_loot_state.gd")
const EncounterController := preload("res://gameplay/creatures/spawning/prototype_burrower_encounter_controller.gd")

const BURROWER_PATH := "res://content/characters/creatures/prototype_burrower_definition.tres"
const LOOT_PROFILE_PATH := "res://content/loot/profiles/prototype_burrower_reward_profile.tres"
const CHITIN_PATH := "res://content/items/resources/burrower_chitin_definition.tres"
const CHITIN_ID := "item.resource.burrower_chitin"


class PlayerPositionProbe:
	extends RefCounted
	var global_position: Vector3 = Vector3.ZERO


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_burrower_death_to_exactly_once_collection(failures)
	_test_loot_unready_does_not_gate_encounter_runtime(failures)
	_test_capacity_failure_preserves_inventory_and_pending(failures)
	_test_weight_failure_preserves_inventory_and_pending(failures)
	_test_definition_contract_drift_fails_closed(failures)
	_test_reward_events_are_semantic(failures)
	_test_locator_retry_and_nearby_collection(failures)
	_test_service_import_is_atomic_and_deep_owned(failures)
	_test_restored_pending_is_collectible_without_reissuance(failures)
	_test_restored_import_rejects_bad_identity_and_nonfinite_anchor(failures)
	return failures


static func _test_burrower_death_to_exactly_once_collection(failures: Array[String]) -> void:
	var controller = EncounterController.new()
	controller.configure(null, null, null)
	var pending_events: Array = []
	controller.loot_pending.connect(func(occurrence_id, profile_id, world_position):
		pending_events.append({
			"occurrence_id": str(occurrence_id),
			"profile_id": str(profile_id),
			"world_position": world_position,
		})
	)

	controller._on_enemy_died("burrower_contract_1")
	controller._on_enemy_died("burrower_contract_1")
	if controller.get_pending_loot_count() != 1:
		failures.append("repeated Burrower death callback created more than one pending reward")
	if pending_events.size() != 1:
		failures.append("repeated Burrower death callback emitted more than one loot_pending event")
	if not controller.has_pending_loot_locator("burrower_contract_1"):
		failures.append("first Burrower reward issuance did not create a transient collection locator")
	if controller.get_pending_loot_locator("burrower_contract_1") != Vector3.ZERO:
		failures.append("Burrower reward locator did not preserve the captured death position")
	var pending: Dictionary = controller.get_pending_loot_snapshot("burrower_contract_1")
	if str(pending.get("profile_id", "")) != "loot_profile.creature.burrower.m3":
		failures.append("Burrower death did not resolve the authored semantic reward profile")
	var rewards: Array = pending.get("rewards", [])
	if rewards.size() != 1 or str(rewards[0].get("item_id", "")) != CHITIN_ID:
		failures.append("Burrower death did not produce the expected semantic chitin reward")

	var inventory = ItemContainerState.new().configure(2)
	var collect_result: Dictionary = controller.collect_pending_loot("burrower_contract_1", inventory)
	if not bool(collect_result.get("success", false)):
		failures.append("valid Burrower pending reward failed INV-002 collection: %s" % [
			collect_result.get("diagnostics", []),
		])
	if inventory.quantity_of(CHITIN_ID) != 2:
		failures.append("Burrower collection did not add exactly two chitin through inventory")
	if controller.get_pending_loot_count() != 0:
		failures.append("successful Burrower collection did not consume pending reward exactly once")
	if controller.has_pending_loot_locator("burrower_contract_1"):
		failures.append("successful Burrower collection did not clear transient locator")

	var inventory_after: String = inventory.canonical_json()
	var second_collect: Dictionary = controller.collect_pending_loot("burrower_contract_1", inventory)
	if bool(second_collect.get("success", false)):
		failures.append("consumed Burrower reward could be collected a second time")
	if inventory.canonical_json() != inventory_after:
		failures.append("second collection attempt mutated inventory after reward was consumed")
	controller.free()


static func _test_loot_unready_does_not_gate_encounter_runtime(failures: Array[String]) -> void:
	var controller = EncounterController.new()
	var world_probe = Node3D.new()
	var player_probe = Node3D.new()
	var settings_probe = RefCounted.new()
	controller.world = world_probe
	controller.player = player_probe
	controller.settings = settings_probe
	controller.creature_definition_ready = true
	controller.loot_ready = false
	if not controller._encounter_runtime_ready():
		failures.append("loot-unready state incorrectly disabled normal Burrower encounter readiness")
	controller.creature_definition_ready = false
	if controller._encounter_runtime_ready():
		failures.append("encounter readiness ignored the authoritative creature-definition gate")
	controller.free()
	world_probe.free()
	player_probe.free()


static func _test_capacity_failure_preserves_inventory_and_pending(failures: Array[String]) -> void:
	var service = LootRewardService.new()
	var registry = _registry()
	var issued: Dictionary = service.issue_for_creature(
		"burrower_capacity_contract",
		ResourceLoader.load(BURROWER_PATH),
		ResourceLoader.load(LOOT_PROFILE_PATH),
		registry
	)
	if not bool(issued.get("success", false)):
		failures.append("capacity test could not issue pending loot")
		return

	var inventory = ItemContainerState.new().configure(1)
	var blocker = ItemDefinition.new()
	blocker.configure_item("item.resource.capacity_blocker", 1, 0.0, 1)
	blocker.configure_schema_declarations(["category.item.resource"], [])
	var blocker_result: Dictionary = inventory.add_instance(blocker)
	if not bool(blocker_result.get("success", false)):
		failures.append("capacity test could not prepare a full destination inventory")
		return
	var inventory_before: String = inventory.canonical_json()
	var pending_before: Dictionary = service.pending_snapshot("burrower_capacity_contract")

	var result: Dictionary = service.collect_pending(
		"burrower_capacity_contract",
		inventory,
		registry
	)
	if bool(result.get("success", false)):
		failures.append("full inventory unexpectedly accepted pending Burrower loot")
	if inventory.canonical_json() != inventory_before:
		failures.append("capacity-rejected loot collection changed inventory")
	if service.pending_snapshot("burrower_capacity_contract") != pending_before:
		failures.append("capacity-rejected loot collection changed pending reward state")


static func _test_weight_failure_preserves_inventory_and_pending(failures: Array[String]) -> void:
	var service = LootRewardService.new()
	var registry = _registry()
	service.issue_for_creature(
		"burrower_weight_contract",
		ResourceLoader.load(BURROWER_PATH),
		ResourceLoader.load(LOOT_PROFILE_PATH),
		registry
	)
	var inventory = ItemContainerState.new().configure(2, 0.1)
	var inventory_before: String = inventory.canonical_json()
	var pending_before: Dictionary = service.pending_snapshot("burrower_weight_contract")
	var result: Dictionary = service.collect_pending(
		"burrower_weight_contract",
		inventory,
		registry
	)
	if bool(result.get("success", false)):
		failures.append("overweight destination unexpectedly accepted Burrower loot")
	if inventory.canonical_json() != inventory_before:
		failures.append("weight-rejected loot collection changed inventory")
	if service.pending_snapshot("burrower_weight_contract") != pending_before:
		failures.append("weight-rejected loot collection changed pending reward state")


static func _test_definition_contract_drift_fails_closed(failures: Array[String]) -> void:
	var service = LootRewardService.new()
	var registry = _registry()
	service.issue_for_creature(
		"burrower_definition_drift",
		ResourceLoader.load(BURROWER_PATH),
		ResourceLoader.load(LOOT_PROFILE_PATH),
		registry
	)
	var pending_before: Dictionary = service.pending_snapshot("burrower_definition_drift")
	var inventory = ItemContainerState.new().configure(2)
	var inventory_before: String = inventory.canonical_json()

	var changed_definition = ItemDefinition.new()
	changed_definition.configure_item(CHITIN_ID, 10, 0.25, 1)
	changed_definition.configure_schema_declarations(["category.item.resource"], [])
	var changed_registry = ContentRegistry.new()
	var registry_failures: Array[String] = changed_registry.index_definitions([changed_definition])
	if not registry_failures.is_empty():
		failures.append("definition-drift test registry setup failed")
		return
	var result: Dictionary = service.collect_pending(
		"burrower_definition_drift",
		inventory,
		changed_registry
	)
	if bool(result.get("success", false)):
		failures.append("same-ContentId reward with changed authored definition was collected")
	if not _contains_fragment(result.get("diagnostics", []), "authored definition changed"):
		failures.append("definition-drift rejection did not expose the fail-closed diagnostic")
	if inventory.canonical_json() != inventory_before:
		failures.append("definition-drift rejection changed inventory")
	if service.pending_snapshot("burrower_definition_drift") != pending_before:
		failures.append("definition-drift rejection changed pending reward state")


static func _test_reward_events_are_semantic(failures: Array[String]) -> void:
	var service = LootRewardService.new()
	var registry = _registry()
	var issued: Dictionary = service.issue_for_creature(
		"burrower_event_contract",
		ResourceLoader.load(BURROWER_PATH),
		ResourceLoader.load(LOOT_PROFILE_PATH),
		registry
	)
	var event_text: String = str(issued.get("events", []))
	if not event_text.contains("loot.reward_pending") or not event_text.contains(CHITIN_ID):
		failures.append("loot issuance event did not expose semantic reward identity")
	if event_text.contains("res://") or event_text.contains("resource_path") or event_text.contains("ui_slot"):
		failures.append("loot issuance event leaked physical/presentation identity")

	var duplicate: Dictionary = service.issue_for_creature(
		"burrower_event_contract",
		ResourceLoader.load(BURROWER_PATH),
		ResourceLoader.load(LOOT_PROFILE_PATH),
		registry
	)
	if not bool(duplicate.get("success", false)) or not bool(duplicate.get("already_issued", false)):
		failures.append("repeated reward issuance did not resolve as an idempotent already-issued occurrence")
	if not duplicate.get("events", []).is_empty():
		failures.append("idempotent repeated reward issuance emitted a duplicate semantic reward event")


static func _test_locator_retry_and_nearby_collection(failures: Array[String]) -> void:
	var controller = EncounterController.new()
	controller.configure(null, null, null)
	var player_probe = PlayerPositionProbe.new()
	player_probe.global_position = Vector3.ZERO
	controller.player = player_probe
	controller._on_enemy_died("burrower_locator_contract")
	if not controller.has_pending_loot_locator("burrower_locator_contract"):
		failures.append("Burrower death did not retain transient locator for collection")

	var full_inventory = ItemContainerState.new().configure(1)
	var blocker = ItemDefinition.new()
	blocker.configure_item("item.resource.locator_blocker", 1, 0.0, 1)
	blocker.configure_schema_declarations(["category.item.resource"], [])
	full_inventory.add_instance(blocker)
	var full_before: String = full_inventory.canonical_json()
	var failed_collect: Dictionary = controller.collect_nearby_pending_loot(full_inventory)
	if bool(failed_collect.get("success", false)):
		failures.append("nearby collection unexpectedly succeeded into full inventory")
	if full_inventory.canonical_json() != full_before:
		failures.append("failed nearby collection changed full inventory")
	if not controller.has_pending_loot_locator("burrower_locator_contract"):
		failures.append("failed nearby collection removed transient retry locator")
	if controller.get_pending_loot_count() != 1:
		failures.append("failed nearby collection consumed pending reward")

	var retry_inventory = ItemContainerState.new().configure(2)
	var retry: Dictionary = controller.collect_nearby_pending_loot(retry_inventory)
	if not bool(retry.get("success", false)):
		failures.append("nearby retry did not collect pending reward: %s" % [retry.get("diagnostics", [])])
	if retry_inventory.quantity_of(CHITIN_ID) != 2:
		failures.append("nearby retry did not award exactly two chitin")
	if controller.has_pending_loot_locator("burrower_locator_contract"):
		failures.append("successful nearby retry did not clear transient locator")
	controller.free()


static func _test_service_import_is_atomic_and_deep_owned(failures: Array[String]) -> void:
	var source = LootRewardService.new()
	var registry = _registry()
	source.issue_for_creature(
		"burrower_7",
		ResourceLoader.load(BURROWER_PATH),
		ResourceLoader.load(LOOT_PROFILE_PATH),
		registry
	)
	var source_state = source.pending_state("burrower_7")
	var imported = LootRewardService.new()
	var import_result: Dictionary = imported.import_pending_states([source_state])
	if not bool(import_result.get("success", false)):
		failures.append("valid unresolved pending state failed service import: %s" % [
			import_result.get("diagnostics", []),
		])
		return
	if not import_result.get("events", []).is_empty():
		failures.append("pending state import replayed reward issuance events")
	var imported_before: Dictionary = imported.pending_snapshot("burrower_7")
	source_state.rewards[0]["quantity"] = 99
	source_state.profile_id = "loot_profile.mutated.after_import"
	if imported.pending_snapshot("burrower_7") != imported_before:
		failures.append("service import retained caller PendingLootState/reward aliases")

	var duplicate_copy = PendingLootState.new().configure(
		"burrower_8",
		str(imported_before.get("profile_id", "")),
		imported_before.get("rewards", [])
	)
	var duplicate_copy_2 = PendingLootState.new().configure(
		"burrower_8",
		str(imported_before.get("profile_id", "")),
		imported_before.get("rewards", [])
	)
	var count_before: int = imported.pending_count()
	var failed_batch: Dictionary = imported.import_pending_states([duplicate_copy, duplicate_copy_2])
	if bool(failed_batch.get("success", false)):
		failures.append("duplicate restored occurrence batch was accepted")
	if imported.pending_count() != count_before or imported.has_pending("burrower_8"):
		failures.append("failed duplicate import batch partially mutated service authority")


static func _test_restored_pending_is_collectible_without_reissuance(failures: Array[String]) -> void:
	var source = LootRewardService.new()
	var registry = _registry()
	source.issue_for_creature(
		"burrower_12",
		ResourceLoader.load(BURROWER_PATH),
		ResourceLoader.load(LOOT_PROFILE_PATH),
		registry
	)
	var restored_state = source.pending_state("burrower_12")
	var controller = EncounterController.new()
	controller.configure(null, null, null)
	var issuance_events: Array = []
	controller.loot_pending.connect(func(occurrence_id, profile_id, world_position):
		issuance_events.append([occurrence_id, profile_id, world_position])
	)
	var anchor := Vector3(14.0, 2.0, -6.0)
	var import_result: Dictionary = controller.import_pending_loot_states([restored_state], anchor)
	if not bool(import_result.get("success", false)):
		failures.append("valid restored pending state failed encounter import: %s" % [
			import_result.get("diagnostics", []),
		])
		controller.free()
		return
	if not issuance_events.is_empty():
		failures.append("restored pending import replayed loot_pending issuance signal")
	if controller.get_pending_loot_locator("burrower_12") != anchor:
		failures.append("restored pending state did not use supplied recovery anchor as transient locator")
	if controller.spawn_serial != 12 or int(import_result.get("next_spawn_serial", -1)) != 13:
		failures.append("restored burrower_N did not advance occurrence allocator beyond unresolved identity")

	var restored_snapshot: Dictionary = controller.get_pending_loot_snapshot("burrower_12")
	restored_state.rewards[0]["quantity"] = 77
	if controller.get_pending_loot_snapshot("burrower_12") != restored_snapshot:
		failures.append("encounter restore retained alias to detached SAVE pending state")

	var player_probe = PlayerPositionProbe.new()
	player_probe.global_position = anchor
	controller.player = player_probe
	var inventory = ItemContainerState.new().configure(2)
	var collect: Dictionary = controller.collect_nearby_pending_loot(inventory)
	if not bool(collect.get("success", false)):
		failures.append("restored pending reward was not collectible at recovery anchor")
	if inventory.quantity_of(CHITIN_ID) != 2:
		failures.append("restored pending collection did not award exact authoritative reward")
	var after: String = inventory.canonical_json()
	var duplicate: Dictionary = controller.collect_pending_loot("burrower_12", inventory)
	if bool(duplicate.get("success", false)) or inventory.canonical_json() != after:
		failures.append("restored pending reward was collectible more than once")
	controller.free()


static func _test_restored_import_rejects_bad_identity_and_nonfinite_anchor(failures: Array[String]) -> void:
	var source = LootRewardService.new()
	var registry = _registry()
	source.issue_for_creature(
		"burrower_3",
		ResourceLoader.load(BURROWER_PATH),
		ResourceLoader.load(LOOT_PROFILE_PATH),
		registry
	)
	var valid = source.pending_state("burrower_3")
	var valid_snapshot: Dictionary = valid.canonical_snapshot()
	var malformed = PendingLootState.new().configure(
		"not_burrower_3",
		str(valid_snapshot.get("profile_id", "")),
		valid_snapshot.get("rewards", [])
	)
	var controller = EncounterController.new()
	controller.configure(null, null, null)
	var malformed_result: Dictionary = controller.import_pending_loot_states(
		[valid, malformed],
		Vector3.ZERO
	)
	if bool(malformed_result.get("success", false)):
		failures.append("restore import accepted non-canonical Burrower occurrence identity")
	if controller.get_pending_loot_count() != 0 or controller.spawn_serial != 0:
		failures.append("malformed restored occurrence partially mutated encounter authority")

	var nonfinite_result: Dictionary = controller.import_pending_loot_states(
		[valid],
		Vector3(INF, 0.0, 0.0)
	)
	if bool(nonfinite_result.get("success", false)):
		failures.append("restore import accepted non-finite recovery anchor")
	if controller.get_pending_loot_count() != 0 or controller.has_pending_loot_locator("burrower_3"):
		failures.append("non-finite recovery anchor partially activated restored loot")
	controller.free()


static func _registry():
	var registry = ContentRegistry.new()
	var diagnostics: Array[String] = registry.index_definitions([
		ResourceLoader.load(BURROWER_PATH),
		ResourceLoader.load(LOOT_PROFILE_PATH),
		ResourceLoader.load(CHITIN_PATH),
	])
	assert(diagnostics.is_empty())
	return registry


static func _contains_fragment(messages: Array, fragment: String) -> bool:
	for message in messages:
		if str(message).contains(fragment):
			return true
	return false
