extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const LootRewardService := preload("res://gameplay/loot/runtime/loot_reward_service.gd")
const EncounterController := preload("res://gameplay/creatures/spawning/prototype_burrower_encounter_controller.gd")

const BURROWER_PATH := "res://content/characters/creatures/prototype_burrower_definition.tres"
const LOOT_PROFILE_PATH := "res://content/loot/profiles/prototype_burrower_reward_profile.tres"
const CHITIN_PATH := "res://content/items/resources/burrower_chitin_definition.tres"
const CHITIN_ID := "item.resource.burrower_chitin"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_burrower_death_to_exactly_once_collection(failures)
	_test_capacity_failure_preserves_inventory_and_pending(failures)
	_test_weight_failure_preserves_inventory_and_pending(failures)
	_test_definition_contract_drift_fails_closed(failures)
	_test_reward_events_are_semantic(failures)
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

	var inventory_after: String = inventory.canonical_json()
	var second_collect: Dictionary = controller.collect_pending_loot("burrower_contract_1", inventory)
	if bool(second_collect.get("success", false)):
		failures.append("consumed Burrower reward could be collected a second time")
	if inventory.canonical_json() != inventory_after:
		failures.append("second collection attempt mutated inventory after reward was consumed")
	controller.free()


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
