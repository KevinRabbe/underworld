extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CreatureDefinition := preload("res://gameplay/creatures/definitions/creature_definition.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const InventoryStateCodec := preload("res://gameplay/items/inventory/inventory_state_codec.gd")
const InventoryTransactionPlan := preload("res://gameplay/items/inventory/inventory_transaction_plan.gd")
const InventoryTransactionService := preload("res://gameplay/items/inventory/inventory_transaction_service.gd")
const LootProfileDefinition := preload("res://gameplay/loot/definitions/loot_profile_definition.gd")
const PendingLootState := preload("res://gameplay/loot/runtime/pending_loot_state.gd")

var _issued_occurrences: Dictionary = {}
var _pending_by_occurrence: Dictionary = {}


func issue_for_creature(
	occurrence_id: String,
	creature_definition,
	profile,
	content_registry
) -> Dictionary:
	if _issued_occurrences.has(occurrence_id):
		return _success({
			"already_issued": true,
			"pending": _pending_by_occurrence.get(occurrence_id, null),
			"events": [],
		})

	var failures: Array[String] = []
	if occurrence_id.is_empty() or occurrence_id != occurrence_id.strip_edges():
		failures.append("loot occurrence id must be non-empty and trimmed")
	if creature_definition == null or not creature_definition is CreatureDefinition:
		failures.append("loot issuance requires CreatureDefinition")
	if profile == null or not profile is LootProfileDefinition:
		failures.append("loot issuance requires LootProfileDefinition")
	if content_registry == null or not content_registry is ContentRegistry:
		failures.append("loot issuance requires ContentRegistry")
	if not failures.is_empty():
		return _failure(failures)

	for failure in profile.validate_definition():
		failures.append("loot profile: %s" % failure)
	if str(profile.source_creature_id) != str(creature_definition.content_id):
		failures.append("loot profile source creature does not match death creature: %s != %s" % [
			profile.source_creature_id,
			creature_definition.content_id,
		])

	var source_resolution: Dictionary = content_registry.resolve(
		profile.source_creature_id,
		LootProfileDefinition.CREATURE_FAMILY
	)
	for diagnostic in source_resolution.get("diagnostics", []):
		failures.append("loot source creature resolution: %s" % diagnostic)
	var source_definition = source_resolution.get("definition", null)
	if source_definition != null and not source_definition is CreatureDefinition:
		failures.append("loot source creature resolution did not return CreatureDefinition")

	var resolved_rewards: Array[Dictionary] = []
	for entry in profile.reward_entries():
		var item_id: String = str(entry.get("item_id", ""))
		var item_resolution: Dictionary = content_registry.resolve(
			item_id,
			LootProfileDefinition.ITEM_FAMILY
		)
		for diagnostic in item_resolution.get("diagnostics", []):
			failures.append("loot reward item resolution %s: %s" % [item_id, diagnostic])
		var definition = item_resolution.get("definition", null)
		if definition == null or not definition is ItemDefinition:
			failures.append("loot reward item resolution did not return ItemDefinition: %s" % item_id)
			continue
		resolved_rewards.append({
			"item_id": item_id,
			"quantity": int(entry.get("quantity", 0)),
			"definition_contract": InventoryStateCodec.canonical_json(definition.canonical_descriptor()),
		})

	if not failures.is_empty():
		return _failure(failures)

	var pending = PendingLootState.new().configure(
		occurrence_id,
		str(profile.content_id),
		resolved_rewards
	)
	var pending_failures: Array[String] = pending.validate_state()
	if not pending_failures.is_empty():
		return _failure(pending_failures)

	_issued_occurrences[occurrence_id] = true
	_pending_by_occurrence[occurrence_id] = pending
	return _success({
		"already_issued": false,
		"pending": pending,
		"events": [{
			"event": "loot.reward_pending",
			"occurrence_id": occurrence_id,
			"profile_id": str(profile.content_id),
			"rewards": _event_rewards(pending.rewards),
		}],
	})


func collect_pending(
	occurrence_id: String,
	destination_container,
	content_registry
) -> Dictionary:
	if not _pending_by_occurrence.has(occurrence_id):
		return _failure(["no pending loot for occurrence: %s" % occurrence_id])
	var pending = _pending_by_occurrence.get(occurrence_id, null)
	var failures: Array[String] = []
	if pending == null or not pending is PendingLootState:
		failures.append("pending loot registry contains incompatible state: %s" % occurrence_id)
	if destination_container == null or not destination_container is ItemContainerState:
		failures.append("loot collection requires destination ItemContainerState")
	if content_registry == null or not content_registry is ContentRegistry:
		failures.append("loot collection requires ContentRegistry")
	if not failures.is_empty():
		return _failure(failures)

	for failure in pending.validate_state():
		failures.append("pending loot: %s" % failure)
	if not pending.is_pending():
		failures.append("pending loot occurrence is already consumed: %s" % occurrence_id)
	if not failures.is_empty():
		return _failure(failures)

	var plan = InventoryTransactionPlan.new()
	plan.bind_container("destination", destination_container)
	for reward in pending.rewards:
		var item_id: String = str(reward.get("item_id", ""))
		var quantity: int = int(reward.get("quantity", 0))
		var resolution: Dictionary = content_registry.resolve(
			item_id,
			LootProfileDefinition.ITEM_FAMILY
		)
		for diagnostic in resolution.get("diagnostics", []):
			failures.append("loot collection item resolution %s: %s" % [item_id, diagnostic])
		var definition = resolution.get("definition", null)
		if definition == null or not definition is ItemDefinition:
			failures.append("loot collection item target must be ItemDefinition: %s" % item_id)
			continue
		var current_contract: String = InventoryStateCodec.canonical_json(
			definition.canonical_descriptor()
		)
		if current_contract != str(reward.get("definition_contract", "")):
			failures.append("loot reward authored definition changed after issuance: %s" % item_id)
			continue
		if definition.stack_limit > 1:
			plan.add_stack("destination", definition, quantity)
		else:
			for _copy_index in range(quantity):
				plan.add_instance("destination", definition)

	if not failures.is_empty():
		return _failure(failures)

	var transaction: Dictionary = InventoryTransactionService.new().commit(plan)
	if not bool(transaction.get("success", false)):
		return {
			"success": false,
			"diagnostics": transaction.get("diagnostics", []).duplicate(),
			"transaction_fingerprint": str(transaction.get("transaction_fingerprint", "")),
			"events": [],
		}

	var reward_snapshot: Array = _event_rewards(pending.rewards)
	if not pending.consume_after_commit():
		return _failure(["loot consumption invariant failed after successful inventory transaction"])
	_pending_by_occurrence.erase(occurrence_id)
	return _success({
		"transaction_fingerprint": str(transaction.get("transaction_fingerprint", "")),
		"inventory_events": transaction.get("events", []).duplicate(true),
		"events": [{
			"event": "loot.collected",
			"occurrence_id": occurrence_id,
			"profile_id": pending.profile_id,
			"rewards": reward_snapshot,
		}],
	})


func pending_count() -> int:
	return _pending_by_occurrence.size()


func has_pending(occurrence_id: String) -> bool:
	return _pending_by_occurrence.has(occurrence_id)


func pending_state(occurrence_id: String):
	return _pending_by_occurrence.get(occurrence_id, null)


func pending_snapshot(occurrence_id: String) -> Dictionary:
	var pending = pending_state(occurrence_id)
	if pending == null or not pending is PendingLootState:
		return {}
	return pending.canonical_snapshot()


func pending_occurrence_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in _pending_by_occurrence.keys():
		ids.append(str(raw_id))
	ids.sort()
	return ids


static func _event_rewards(rewards: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for reward in rewards:
		if not reward is Dictionary:
			continue
		result.append({
			"item_id": str(reward.get("item_id", "")),
			"quantity": int(reward.get("quantity", 0)),
		})
	result.sort_custom(func(a, b): return str(a.get("item_id", "")) < str(b.get("item_id", "")))
	return result


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {"success": false, "diagnostics": diagnostics, "events": []}


static func _success(extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"success": true, "diagnostics": [], "events": []}
	for key in extra.keys():
		result[key] = extra[key]
	return result
