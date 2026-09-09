extends RefCounted

const PendingLootState := preload("res://gameplay/loot/runtime/pending_loot_state.gd")
const Support := preload("res://gameplay/persistence/codecs/component_codec_support.gd")

const PENDING_LOOT_SCHEMA := "persistence.pending_loot.v1"
const PENDING_LOOT_ROOT_KEYS := ["schema", "occurrence_id", "profile_id", "rewards", "consumed"]
const PENDING_LOOT_REWARD_KEYS := ["item_id", "quantity", "definition_contract"]


static func encode(pending, content_registry) -> Dictionary:
	var failures: Array[String] = []
	Support.validate_registry(content_registry, failures)
	if pending == null or not pending is PendingLootState:
		failures.append("pending-loot encode requires PendingLootState")
	else:
		for failure in pending.validate_state():
			failures.append("pending-loot encode: %s" % failure)
	if not failures.is_empty():
		return Support.failure(failures)

	Support.resolve_loot_profile(content_registry, pending.profile_id, "pending-loot encode", failures)
	var rewards: Array[Dictionary] = []
	for reward in pending.rewards:
		var item_id: String = str(reward.get("item_id", ""))
		var definition = Support.resolve_item(content_registry, item_id, "pending-loot encode", failures)
		if definition == null:
			continue
		var saved_contract: String = str(reward.get("definition_contract", ""))
		if Support.definition_contract(definition) != saved_contract:
			failures.append("pending-loot reward authored definition changed: %s" % item_id)
			continue
		rewards.append(reward.duplicate(true))
	if not failures.is_empty():
		return Support.failure(failures)

	rewards.sort_custom(func(a, b): return str(a.get("item_id", "")) < str(b.get("item_id", "")))
	return Support.encoded({
		"schema": PENDING_LOOT_SCHEMA,
		"occurrence_id": pending.occurrence_id,
		"profile_id": pending.profile_id,
		"rewards": rewards,
		"consumed": pending.consumed,
	}, "pending-loot snapshot")


static func decode(snapshot: Variant, content_registry) -> Dictionary:
	var failures: Array[String] = []
	Support.validate_registry(content_registry, failures)
	var source: Dictionary = Support.require_snapshot(
		snapshot,
		PENDING_LOOT_SCHEMA,
		"pending-loot",
		PENDING_LOOT_ROOT_KEYS,
		failures
	)
	if source.is_empty() and not failures.is_empty():
		return Support.failure(failures)

	var raw_occurrence = source.get("occurrence_id", null)
	var raw_profile = source.get("profile_id", null)
	var raw_rewards = source.get("rewards", null)
	var raw_consumed = source.get("consumed", null)
	if typeof(raw_occurrence) != TYPE_STRING:
		failures.append("pending-loot snapshot occurrence_id must be String")
	if typeof(raw_profile) != TYPE_STRING:
		failures.append("pending-loot snapshot profile_id must be String")
	if not raw_rewards is Array:
		failures.append("pending-loot snapshot rewards must be Array")
	if typeof(raw_consumed) != TYPE_BOOL:
		failures.append("pending-loot snapshot consumed must be bool")
	if not failures.is_empty():
		return Support.failure(failures)

	Support.resolve_loot_profile(content_registry, str(raw_profile), "pending-loot snapshot", failures)
	var rewards: Array[Dictionary] = []
	for raw_reward in raw_rewards:
		if not raw_reward is Dictionary:
			failures.append("pending-loot snapshot reward must be Dictionary")
			continue
		var reward: Dictionary = raw_reward
		Support.validate_exact_keys(
			reward,
			PENDING_LOOT_REWARD_KEYS,
			"pending-loot snapshot reward",
			failures
		)
		var raw_item_id = reward.get("item_id", null)
		var raw_quantity = reward.get("quantity", null)
		var raw_contract = reward.get("definition_contract", null)
		if typeof(raw_item_id) != TYPE_STRING:
			failures.append("pending-loot snapshot reward item_id must be String")
		if typeof(raw_quantity) != TYPE_INT:
			failures.append("pending-loot snapshot reward quantity must be int")
		if typeof(raw_contract) != TYPE_STRING or str(raw_contract).is_empty():
			failures.append("pending-loot snapshot reward requires definition_contract")
		if typeof(raw_item_id) != TYPE_STRING or typeof(raw_quantity) != TYPE_INT:
			continue
		var item_id: String = str(raw_item_id)
		var definition = Support.resolve_item(
			content_registry,
			item_id,
			"pending-loot snapshot reward",
			failures
		)
		if definition == null:
			continue
		if Support.definition_contract(definition) != str(raw_contract):
			failures.append("pending-loot saved authored definition changed: %s" % item_id)
			continue
		rewards.append({
			"item_id": item_id,
			"quantity": int(raw_quantity),
			"definition_contract": str(raw_contract),
		})

	if not failures.is_empty():
		return Support.failure(failures)
	var restored = PendingLootState.new().configure(str(raw_occurrence), str(raw_profile), rewards)
	if bool(raw_consumed):
		if not restored.consume_after_commit():
			failures.append("pending-loot consumed state could not be reconstructed")
	for failure in restored.validate_state():
		failures.append("restored pending-loot: %s" % failure)
	if not failures.is_empty():
		return Support.failure(failures)
	return Support.success({"state": restored})
