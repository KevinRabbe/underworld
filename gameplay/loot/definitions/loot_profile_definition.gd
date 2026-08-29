extends "res://core/content/registry/content_definition.gd"

const ContentReference := preload("res://core/content/references/content_reference.gd")

const LOOT_PROFILE_FAMILY := "loot_profile"
const CREATURE_FAMILY := "creature"
const ITEM_FAMILY := "item"
const ROLE_SOURCE_CREATURE := "reward.source_creature"

@export var source_creature_id: String = ""
@export var reward_item_ids: Array[String] = []
@export var reward_quantities: Array[int] = []


func configure_profile(
	p_content_id: String,
	p_source_creature_id: String,
	p_reward_item_ids: Array,
	p_reward_quantities: Array,
	p_schema_revision: int = 1
) -> Resource:
	configure(p_content_id, LOOT_PROFILE_FAMILY, p_schema_revision)
	source_creature_id = p_source_creature_id
	reward_item_ids.clear()
	for item_id in p_reward_item_ids:
		reward_item_ids.append(str(item_id))
	reward_quantities.clear()
	for quantity in p_reward_quantities:
		reward_quantities.append(int(quantity))
	return self


func reward_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var count: int = mini(reward_item_ids.size(), reward_quantities.size())
	for index in range(count):
		entries.append({
			"item_id": reward_item_ids[index],
			"quantity": reward_quantities[index],
		})
	entries.sort_custom(func(a, b): return str(a.get("item_id", "")) < str(b.get("item_id", "")))
	return entries


func validation_references() -> Array:
	var references: Array = [
		ContentReference.new(
			content_id,
			ROLE_SOURCE_CREATURE,
			source_creature_id,
			CREATURE_FAMILY,
			true
		),
	]
	var item_ids: Array[String] = []
	item_ids.append_array(reward_item_ids)
	item_ids.sort()
	for item_id in item_ids:
		references.append(ContentReference.new(
			content_id,
			_reward_role(item_id),
			item_id,
			ITEM_FAMILY,
			true
		))
	return references


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if definition_family != LOOT_PROFILE_FAMILY:
		failures.append("loot profile definition family must be '%s': %s" % [
			LOOT_PROFILE_FAMILY,
			definition_family,
		])
	_validate_content_id_family(source_creature_id, CREATURE_FAMILY, "source creature", failures)
	if reward_item_ids.is_empty():
		failures.append("loot profile requires at least one reward item: %s" % content_id)
	if reward_item_ids.size() != reward_quantities.size():
		failures.append("loot profile reward item/quantity arrays must have equal length: %s" % content_id)

	var seen: Dictionary = {}
	for index in range(reward_item_ids.size()):
		var item_id: String = reward_item_ids[index]
		_validate_content_id_family(item_id, ITEM_FAMILY, "reward item", failures)
		if seen.has(item_id):
			failures.append("loot profile contains duplicate reward item id: %s" % item_id)
		seen[item_id] = true
		if index >= reward_quantities.size() or reward_quantities[index] <= 0:
			failures.append("loot profile reward quantity must be > 0 for %s" % item_id)

	for reference in validation_references():
		if reference == null or not reference is ContentReference:
			failures.append("loot profile semantic reference must inherit ContentReference")
			continue
		for failure in reference.validate_reference():
			failures.append("loot profile semantic reference '%s': %s" % [reference.role, failure])
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["source_creature_id"] = source_creature_id
	descriptor["rewards"] = reward_entries()
	return descriptor


static func _validate_content_id_family(
	value: String,
	expected_family: String,
	label: String,
	failures: Array[String]
) -> void:
	for failure in ContentId.validate(value):
		failures.append("loot profile %s id: %s" % [label, failure])
	if ContentId.is_valid(value) and ContentId.family_of(value) != expected_family:
		failures.append("loot profile %s id must use '%s.' family: %s" % [
			label,
			expected_family,
			value,
		])


static func _reward_role(item_id: String) -> String:
	return "reward.item.%s" % item_id.replace(".", "_")
