extends RefCounted

const ContentId := preload("res://core/content/identity/content_id.gd")
const InventoryStateCodec := preload("res://gameplay/items/inventory/inventory_state_codec.gd")

const SNAPSHOT_SCHEMA := "loot.pending.v1"
const LOOT_PROFILE_FAMILY := "loot_profile"
const ITEM_FAMILY := "item"

var occurrence_id: String = ""
var profile_id: String = ""
var rewards: Array[Dictionary] = []
var consumed: bool = false


func configure(
	p_occurrence_id: String,
	p_profile_id: String,
	p_rewards: Array
) -> RefCounted:
	occurrence_id = p_occurrence_id
	profile_id = p_profile_id
	rewards.clear()
	for candidate in p_rewards:
		if not candidate is Dictionary:
			continue
		rewards.append({
			"item_id": str(candidate.get("item_id", "")),
			"quantity": int(candidate.get("quantity", 0)),
			"definition_contract": str(candidate.get("definition_contract", "")),
		})
	consumed = false
	return self


func validate_state() -> Array[String]:
	var failures: Array[String] = []
	if occurrence_id.is_empty() or occurrence_id != occurrence_id.strip_edges():
		failures.append("pending loot occurrence id must be non-empty and trimmed")
	_validate_family(profile_id, LOOT_PROFILE_FAMILY, "profile", failures)
	if rewards.is_empty():
		failures.append("pending loot requires at least one semantic reward")
	var seen: Dictionary = {}
	for reward in rewards:
		var item_id: String = str(reward.get("item_id", ""))
		_validate_family(item_id, ITEM_FAMILY, "reward item", failures)
		if seen.has(item_id):
			failures.append("pending loot contains duplicate reward item id: %s" % item_id)
		seen[item_id] = true
		if int(reward.get("quantity", 0)) <= 0:
			failures.append("pending loot reward quantity must be > 0: %s" % item_id)
		var contract: String = str(reward.get("definition_contract", ""))
		if contract.is_empty():
			failures.append("pending loot reward is missing authored definition contract: %s" % item_id)
	failures.sort()
	return failures


func is_pending() -> bool:
	return not consumed


func consume_after_commit() -> bool:
	if consumed:
		return false
	consumed = true
	return true


func canonical_snapshot() -> Dictionary:
	var ordered_rewards: Array[Dictionary] = []
	for reward in rewards:
		ordered_rewards.append(reward.duplicate(true))
	ordered_rewards.sort_custom(func(a, b): return str(a.get("item_id", "")) < str(b.get("item_id", "")))
	return {
		"schema": SNAPSHOT_SCHEMA,
		"occurrence_id": occurrence_id,
		"profile_id": profile_id,
		"rewards": ordered_rewards,
		"consumed": consumed,
	}


func canonical_json() -> String:
	return InventoryStateCodec.canonical_json(canonical_snapshot())


static func _validate_family(
	value: String,
	expected_family: String,
	label: String,
	failures: Array[String]
) -> void:
	for failure in ContentId.validate(value):
		failures.append("pending loot %s id: %s" % [label, failure])
	if ContentId.is_valid(value) and ContentId.family_of(value) != expected_family:
		failures.append("pending loot %s id must use '%s.' family: %s" % [
			label,
			expected_family,
			value,
		])
