extends RefCounted

const ContentDefinition := preload("res://core/content/registry/content_definition.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const CreatureDefinition := preload("res://gameplay/creatures/definitions/creature_definition.gd")
const CreatureFamilyValidator := preload("res://gameplay/creatures/validation/creature_family_validator.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemFamilyValidator := preload("res://gameplay/items/validation/item_family_validator.gd")
const LootProfileDefinition := preload("res://gameplay/loot/definitions/loot_profile_definition.gd")
const LootFamilyValidator := preload("res://gameplay/loot/validation/loot_family_validator.gd")

const BURROWER_PATH := "res://content/characters/creatures/prototype_burrower_definition.tres"
const ATTACK_PROFILE_PATH := "res://content/characters/attacks/prototype_burrower_attack_profile.tres"
const ARCHETYPE_PATH := "res://content/characters/archetypes/prototype_burrower_archetype.tres"
const ANIMATION_SET_PATH := "res://content/characters/animation_sets/prototype_humanoid_animation_set.tres"
const RIG_PROFILE_PATH := "res://content/characters/rig_profiles/prototype_humanoid_rig_profile.tres"
const LOOT_PROFILE_PATH := "res://content/loot/profiles/prototype_burrower_reward_profile.tres"
const CHITIN_PATH := "res://content/items/resources/burrower_chitin_definition.tres"

const CREATURE_ROOT := "category.creature"
const ENEMY_CATEGORY := "category.creature.enemy"
const ITEM_ROOT := "category.item"
const ITEM_RESOURCE := "category.item.resource"
const MOVEMENT := "capability.movement"
const SENSING := "capability.sensing"
const DAMAGE_DEALER := "capability.damage_dealer"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_authored_burrower_reward_bundle(failures)
	_test_reward_order_is_nonsemantic(failures)
	_test_missing_reward_target_fails_closed(failures)
	_test_wrong_concrete_targets_fail_closed(failures)
	_test_invalid_profile_data_fails_deterministically(failures)
	return failures


static func _test_authored_burrower_reward_bundle(failures: Array[String]) -> void:
	var definitions: Array = _accepted_bundle()
	if definitions.is_empty():
		failures.append("Burrower authored loot bundle failed to load")
		return
	var profile = ResourceLoader.load(LOOT_PROFILE_PATH)
	var chitin = ResourceLoader.load(CHITIN_PATH)
	if profile == null or not profile is LootProfileDefinition:
		failures.append("Burrower reward profile did not load as LootProfileDefinition")
		return
	if chitin == null or not chitin is ItemDefinition:
		failures.append("Burrower chitin reward did not load as ItemDefinition")
		return

	var result: Dictionary = ContentValidationPipeline.new().validate_all(
		definitions,
		_categories(),
		_capabilities(),
		[
			CreatureFamilyValidator.new().configure_creature_rules(),
			ItemFamilyValidator.new().configure_item_rules([]),
			LootFamilyValidator.new().configure_loot_rules(),
		]
	)
	if not bool(result.get("success", false)):
		failures.append("valid Burrower loot bundle failed CONTENT-005: %s" % [result.get("diagnostics", [])])
	if profile.content_id != "loot_profile.creature.burrower.m3":
		failures.append("Burrower loot profile semantic identity drifted")
	if profile.source_creature_id != "creature.enemy.burrower":
		failures.append("Burrower loot profile no longer targets the semantic Burrower ContentId")
	var rewards: Array[Dictionary] = profile.reward_entries()
	if rewards.size() != 1:
		failures.append("M3 Burrower reward profile must contain exactly one simple reward")
	else:
		if str(rewards[0].get("item_id", "")) != "item.resource.burrower_chitin":
			failures.append("Burrower reward item semantic identity drifted")
		if int(rewards[0].get("quantity", 0)) != 2:
			failures.append("Burrower reward quantity drifted from the M3 fixed reward")
	if chitin.stack_limit != 20 or not is_equal_approx(chitin.unit_weight, 0.25):
		failures.append("Burrower chitin authored item contract drifted")
	var descriptor: Dictionary = profile.canonical_descriptor()
	if descriptor.has("resource_path") or str(descriptor).contains("res://"):
		failures.append("loot profile canonical identity leaked a physical Resource path")


static func _test_reward_order_is_nonsemantic(failures: Array[String]) -> void:
	var first = LootProfileDefinition.new()
	first.configure_profile(
		"loot_profile.contract.order_probe",
		"creature.enemy.burrower",
		["item.resource.burrower_chitin", "item.resource.contract_dust"],
		[2, 3],
		1
	)
	var second = LootProfileDefinition.new()
	second.configure_profile(
		"loot_profile.contract.order_probe",
		"creature.enemy.burrower",
		["item.resource.contract_dust", "item.resource.burrower_chitin"],
		[3, 2],
		1
	)
	if first.canonical_descriptor() != second.canonical_descriptor():
		failures.append("loot reward declaration order changed canonical semantic identity")


static func _test_missing_reward_target_fails_closed(failures: Array[String]) -> void:
	var profile = LootProfileDefinition.new()
	profile.configure_profile(
		"loot_profile.contract.missing_item",
		"creature.enemy.burrower",
		["item.resource.missing_reward"],
		[1],
		1
	)
	var definitions: Array = _shared_targets()
	definitions.push_front(ResourceLoader.load(BURROWER_PATH))
	definitions.append(profile)
	var result: Dictionary = ContentValidationPipeline.new().validate_all(
		definitions,
		_categories(),
		_capabilities(),
		[LootFamilyValidator.new().configure_loot_rules()]
	)
	if not _has_code_fragment(result, "reference_resolution", "missing content definition"):
		failures.append("missing loot reward item did not fail through CONTENT-005 reference resolution")


static func _test_wrong_concrete_targets_fail_closed(failures: Array[String]) -> void:
	var wrong_item = ContentDefinition.new()
	wrong_item.configure("item.resource.generic_wrong_type", "item", 1)
	wrong_item.configure_schema_declarations([ITEM_RESOURCE], [])
	var item_profile = LootProfileDefinition.new()
	item_profile.configure_profile(
		"loot_profile.contract.wrong_item_type",
		"creature.enemy.burrower",
		[wrong_item.content_id],
		[1],
		1
	)
	var item_definitions: Array = _shared_targets()
	item_definitions.push_front(ResourceLoader.load(BURROWER_PATH))
	item_definitions.append(item_profile)
	item_definitions.append(wrong_item)
	var item_result: Dictionary = ContentValidationPipeline.new().validate_all(
		item_definitions,
		_categories(),
		_capabilities(),
		[LootFamilyValidator.new().configure_loot_rules()]
	)
	if not _has_code_fragment(item_result, "family_rule", "must inherit ItemDefinition"):
		failures.append("generic item-family reward target bypassed LootFamilyValidator")

	var wrong_creature = ContentDefinition.new()
	wrong_creature.configure("creature.enemy.generic_loot_source", "creature", 1)
	wrong_creature.configure_schema_declarations([ENEMY_CATEGORY], [MOVEMENT, SENSING, DAMAGE_DEALER])
	var creature_profile = LootProfileDefinition.new()
	creature_profile.configure_profile(
		"loot_profile.contract.wrong_creature_type",
		wrong_creature.content_id,
		["item.resource.burrower_chitin"],
		[1],
		1
	)
	var creature_result: Dictionary = ContentValidationPipeline.new().validate_all(
		[wrong_creature, creature_profile, ResourceLoader.load(CHITIN_PATH)],
		_categories(),
		_capabilities(),
		[LootFamilyValidator.new().configure_loot_rules()]
	)
	if not _has_code_fragment(creature_result, "family_rule", "must inherit CreatureDefinition"):
		failures.append("generic creature-family loot source bypassed LootFamilyValidator")


static func _test_invalid_profile_data_fails_deterministically(failures: Array[String]) -> void:
	var duplicate = LootProfileDefinition.new()
	duplicate.configure_profile(
		"loot_profile.contract.duplicate",
		"creature.enemy.burrower",
		["item.resource.burrower_chitin", "item.resource.burrower_chitin"],
		[1, 2],
		1
	)
	if not _contains_fragment(duplicate.validate_definition(), "duplicate reward item id"):
		failures.append("duplicate loot reward item id did not fail locally")

	var invalid_quantity = LootProfileDefinition.new()
	invalid_quantity.configure_profile(
		"loot_profile.contract.invalid_quantity",
		"creature.enemy.burrower",
		["item.resource.burrower_chitin"],
		[0],
		1
	)
	if not _contains_fragment(invalid_quantity.validate_definition(), "quantity must be > 0"):
		failures.append("non-positive loot quantity did not fail locally")

	var wrong_family = LootProfileDefinition.new()
	wrong_family.configure_profile(
		"loot_profile.contract.wrong_family",
		"creature.enemy.burrower",
		["creature.enemy.not_an_item"],
		[1],
		1
	)
	if not _contains_fragment(wrong_family.validate_definition(), "must use 'item.' family"):
		failures.append("loot reward ContentId with wrong family did not fail locally")


static func _accepted_bundle() -> Array:
	var definitions: Array = _shared_targets()
	for path in [BURROWER_PATH, LOOT_PROFILE_PATH, CHITIN_PATH]:
		var definition = ResourceLoader.load(path)
		if definition == null:
			return []
		definitions.append(definition)
	return definitions


static func _shared_targets() -> Array:
	var definitions: Array = []
	for path in [ATTACK_PROFILE_PATH, ARCHETYPE_PATH, ANIMATION_SET_PATH, RIG_PROFILE_PATH]:
		var definition = ResourceLoader.load(path)
		if definition == null:
			return []
		definitions.append(definition)
	return definitions


static func _categories():
	var registry = CategorySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CategorySchema.new().configure(CREATURE_ROOT),
		CategorySchema.new().configure(ENEMY_CATEGORY, [CREATURE_ROOT]),
		CategorySchema.new().configure(ITEM_ROOT),
		CategorySchema.new().configure(ITEM_RESOURCE, [ITEM_ROOT]),
	])
	assert(diagnostics.is_empty())
	return registry


static func _capabilities():
	var registry = CapabilitySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CapabilitySchema.new().configure(MOVEMENT),
		CapabilitySchema.new().configure(SENSING),
		CapabilitySchema.new().configure(DAMAGE_DEALER),
	])
	assert(diagnostics.is_empty())
	return registry


static func _has_code_fragment(result: Dictionary, code: String, fragment: String) -> bool:
	for diagnostic in result.get("diagnostics", []):
		if str(diagnostic.get("code", "")) == code and str(diagnostic.get("message", "")).contains(fragment):
			return true
	return false


static func _contains_fragment(messages: Array[String], fragment: String) -> bool:
	for message in messages:
		if message.contains(fragment):
			return true
	return false
