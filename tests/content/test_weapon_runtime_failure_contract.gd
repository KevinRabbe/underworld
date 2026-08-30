extends RefCounted

const ContentDefinition := preload("res://core/content/registry/content_definition.gd")
const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const ItemFamilyValidator := preload("res://gameplay/items/validation/item_family_validator.gd")
const WeaponItemRuleExtension := preload("res://gameplay/items/weapons/validation/weapon_item_rule_extension.gd")
const CharacterSemanticSchemaCatalog := preload("res://presentation/characters/animation/character_semantic_schema_catalog.gd")
const RecipeFamilyValidator := preload("res://gameplay/crafting/validation/recipe_family_validator.gd")
const CraftingContext := preload("res://gameplay/crafting/runtime/crafting_context.gd")
const CraftingService := preload("res://gameplay/crafting/runtime/crafting_service.gd")
const ProgressionCraftEquipService := preload("res://gameplay/crafting/runtime/progression_craft_equip_service.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquipmentSlotRule := preload("res://gameplay/items/equipment/equipment_slot_rule.gd")
const EquipmentService := preload("res://gameplay/items/equipment/equipment_service.gd")
const SelectedWeaponAttackSourceService := preload("res://gameplay/items/weapons/runtime/selected_weapon_attack_source_service.gd")
const TrackingEquipmentService := preload("res://tests/crafting/tracking_equipment_service.gd")
const PlayerScript := preload("res://gameplay/player/player.gd")

const WOOD_PATH := "res://content/items/resources/wood_definition.tres"
const IRON_PATH := "res://content/items/resources/iron_chunk_definition.tres"
const SWORD_PATH := "res://content/items/weapons/iron_sword_definition.tres"
const ATTACK_SET_PATH := "res://content/items/weapons/iron_sword_attack_set.tres"
const ARCHETYPE_PATH := "res://content/items/weapons/iron_sword_archetype.tres"
const RECIPE_PATH := "res://content/recipes/iron_sword.tres"

const SWORD_ID := "item.weapon.iron_sword"
const ATTACK_SET_ID := "attack_set.weapon.sword.basic"
const ARCHETYPE_ID := "archetype.weapon.iron_sword"
const RECIPE_ID := "recipe.hand.iron_sword"
const WOOD_ID := "item.resource.wood"
const IRON_ID := "item.resource.iron_chunk"

const ITEM_ROOT := "category.item"
const ITEM_RESOURCE := "category.item.resource"
const ITEM_EQUIPMENT := "category.item.equipment"
const ITEM_WEAPON := "category.item.equipment.weapon"
const ITEM_WEAPON_MELEE := "category.item.equipment.weapon.melee"
const ITEM_SWORD := "category.item.equipment.weapon.melee.sword"
const EQUIPABLE := "capability.equipable"
const DAMAGE_DEALER := "capability.damage_dealer"
const SLOT_HANDS := "equipment_slot.hotbar.hands"
const SLOT_UTILITY := "equipment_slot.hotbar.utility"


static func run() -> Array[String]:
	var failures: Array[String] = []
	var harness: Dictionary = _harness(failures)
	if harness.is_empty():
		return failures
	_test_wrong_reference_types_fail_closed(harness, failures)
	_test_craft_failure_preserves_existing_weapon_source(harness, failures)
	_test_equip_failure_preserves_output_and_existing_source(harness, failures)
	_test_source_failure_clears_stale_source_without_item_loss(harness, failures)
	failures.sort()
	return failures


static func _test_wrong_reference_types_fail_closed(
	harness: Dictionary,
	failures: Array[String]
) -> void:
	var sword = harness["sword"]
	var attack_set = harness["attack_set"]
	var archetype = harness["archetype"]

	var wrong_attack_target = ContentDefinition.new()
	wrong_attack_target.configure(ATTACK_SET_ID, "attack_set", 1)
	var wrong_attack_sword = sword.duplicate(true)
	wrong_attack_sword.content_id = "item.weapon.iron_sword_wrong_attack_target"
	var wrong_attack_result: Dictionary = _validate([
		wrong_attack_sword,
		wrong_attack_target,
		archetype,
	])
	if bool(wrong_attack_result.get("success", false)):
		failures.append("production-shaped sword accepted wrong-type attack-set target")
	elif not _diagnostics_contain(
		wrong_attack_result,
		"must inherit WeaponAttackSetDefinition"
	):
		failures.append(
			"wrong attack-set target did not report typed WEAPON failure: %s"
			% [wrong_attack_result.get("diagnostics", [])]
		)

	var wrong_archetype_target = ContentDefinition.new()
	wrong_archetype_target.configure(ARCHETYPE_ID, "archetype", 1)
	var wrong_archetype_sword = sword.duplicate(true)
	wrong_archetype_sword.content_id = "item.weapon.iron_sword_wrong_archetype_target"
	var wrong_archetype_result: Dictionary = _validate([
		wrong_archetype_sword,
		attack_set,
		wrong_archetype_target,
	])
	if bool(wrong_archetype_result.get("success", false)):
		failures.append("production-shaped sword accepted wrong-type archetype target")
	elif not _diagnostics_contain(
		wrong_archetype_result,
		"must inherit ArchetypeDefinition"
	):
		failures.append(
			"wrong archetype target did not report typed WEAPON failure: %s"
			% [wrong_archetype_result.get("diagnostics", [])]
		)


static func _test_craft_failure_preserves_existing_weapon_source(
	harness: Dictionary,
	failures: Array[String]
) -> void:
	var seeded: Dictionary = _bound_sword_state(harness, failures)
	if seeded.is_empty():
		return
	var inventory = ItemContainerState.new().configure(5, 40.0)
	var equipment = seeded["equipment"]
	var player = seeded["player"]
	var runtime = SelectedWeaponAttackSourceService.new()
	var progression = ProgressionCraftEquipService.new().configure(
		harness["crafting"],
		harness["registry"]
	)
	var inventory_before: String = inventory.canonical_json()
	var equipment_before: String = equipment.canonical_json()
	var source_before = player.equipped_weapon_definition
	var result: Dictionary = runtime.craft_equip_and_bind(
		progression,
		RECIPE_ID,
		CraftingContext.new(),
		inventory,
		equipment,
		harness["registry"],
		player,
		SWORD_ID,
		SLOT_UTILITY,
		4
	)
	if bool(result.get("success", false)):
		failures.append("sword progression unexpectedly succeeded without ingredients")
	if str(result.get("stage", "")) != "craft":
		failures.append("ingredient failure did not remain a craft-stage failure")
	if bool(result.get("source_binding_attempted", true)):
		failures.append("craft failure attempted to mutate Player weapon source")
	if inventory.canonical_json() != inventory_before:
		failures.append("craft failure mutated authoritative inventory")
	if equipment.canonical_json() != equipment_before:
		failures.append("craft failure mutated authoritative equipment")
	if player.equipped_weapon_definition != source_before:
		failures.append("craft failure changed the previously valid Player weapon source")
	player.free()


static func _test_equip_failure_preserves_output_and_existing_source(
	harness: Dictionary,
	failures: Array[String]
) -> void:
	var seeded: Dictionary = _bound_sword_state(harness, failures)
	if seeded.is_empty():
		return
	var inventory = ItemContainerState.new().configure(6, 40.0)
	inventory.add_stack(harness["wood"], 1)
	inventory.add_stack(harness["iron"], 4)
	var equipment = seeded["equipment"]
	var player = seeded["player"]
	var equipment_before: String = equipment.canonical_json()
	var source_before = player.equipped_weapon_definition
	var tracker = TrackingEquipmentService.new()
	tracker.reject_equips = true
	var progression = ProgressionCraftEquipService.new().configure(
		harness["crafting"],
		harness["registry"],
		tracker
	)
	var result: Dictionary = SelectedWeaponAttackSourceService.new().craft_equip_and_bind(
		progression,
		RECIPE_ID,
		CraftingContext.new(),
		inventory,
		equipment,
		harness["registry"],
		player,
		SWORD_ID,
		SLOT_UTILITY,
		4
	)
	if bool(result.get("success", false)):
		failures.append("injected sword equip rejection unexpectedly succeeded")
	if str(result.get("stage", "")) != "equip" or tracker.attempts != 1:
		failures.append("injected sword equip rejection did not stay inside accepted #260 equip stage")
	if bool(result.get("source_binding_attempted", true)):
		failures.append("equip failure attempted to change Player weapon source")
	if inventory.quantity_of(WOOD_ID) != 0 or inventory.quantity_of(IRON_ID) != 0:
		failures.append("successful craft before equip rejection did not consume ingredients")
	if inventory.quantity_of(SWORD_ID) != 1:
		failures.append("equip rejection did not retain exactly one newly crafted sword in inventory")
	if equipment.canonical_json() != equipment_before:
		failures.append("equip rejection mutated semantic equipment state")
	if player.equipped_weapon_definition != source_before:
		failures.append("equip rejection changed the previously valid Player weapon source")
	player.free()


static func _test_source_failure_clears_stale_source_without_item_loss(
	harness: Dictionary,
	failures: Array[String]
) -> void:
	var seeded: Dictionary = _bound_sword_state(harness, failures)
	if seeded.is_empty():
		return
	var player = seeded["player"]
	var inventory = ItemContainerState.new().configure(6, 40.0)
	inventory.add_stack(harness["wood"], 1)
	inventory.add_stack(harness["iron"], 4)
	var equipment = _equipment_state()
	var incomplete_registry = ContentRegistry.new()
	var incomplete_failures: Array[String] = incomplete_registry.index_definitions([
		harness["sword"],
		harness["archetype"],
	])
	if not incomplete_failures.is_empty():
		failures.append("source-failure registry setup failed: %s" % [incomplete_failures])
		player.free()
		return
	var progression = ProgressionCraftEquipService.new().configure(
		harness["crafting"],
		harness["registry"]
	)
	var result: Dictionary = SelectedWeaponAttackSourceService.new().craft_equip_and_bind(
		progression,
		RECIPE_ID,
		CraftingContext.new(),
		inventory,
		equipment,
		incomplete_registry,
		player,
		SWORD_ID,
		SLOT_UTILITY,
		4
	)
	if bool(result.get("success", false)):
		failures.append("source binding unexpectedly succeeded without production attack-set target")
	if str(result.get("stage", "")) != "weapon_source":
		failures.append("post-equip source failure did not report weapon_source stage")
	if not bool(result.get("progression_succeeded", false)):
		failures.append("source-failure proof did not complete accepted craft/equip progression first")
	if not bool(result.get("source_binding_attempted", false)):
		failures.append("source-failure proof did not attempt semantic binding")
	if inventory.quantity_of(SWORD_ID) != 0:
		failures.append("source binding failure duplicated/returned an already equipped sword")
	if equipment.selected_definition() != harness["sword"]:
		failures.append("source binding failure lost the successfully equipped sword")
	if player.equipped_weapon_definition != null or player.equipped_weapon_attack_set != null:
		failures.append("source binding failure retained stale previous weapon source")
	player.free()


static func _bound_sword_state(
	harness: Dictionary,
	failures: Array[String]
) -> Dictionary:
	var inventory = ItemContainerState.new().configure(3, 40.0)
	var added: Dictionary = inventory.add_instance(harness["sword"])
	if not bool(added.get("success", false)):
		failures.append("could not seed production sword for source-atomicity proof")
		return {}
	var equipment = _equipment_state()
	var equipped: Dictionary = EquipmentService.new().equip_from_inventory(
		equipment,
		inventory,
		int(added.get("slot", -1)),
		harness["sword"],
		SLOT_UTILITY
	)
	if not bool(equipped.get("success", false)):
		failures.append("could not equip seed sword for source-atomicity proof")
		return {}
	var selected: Dictionary = equipment.select_hotbar(4)
	if not bool(selected.get("success", false)):
		failures.append("could not select seed sword for source-atomicity proof")
		return {}
	var player = PlayerScript.new()
	var bound: Dictionary = SelectedWeaponAttackSourceService.new().bind_selected(
		equipment,
		harness["registry"],
		player
	)
	if not bool(bound.get("success", false)) or not bool(bound.get("weapon_bound", false)):
		failures.append("could not establish valid seed Player weapon source: %s" % [bound.get("diagnostics", [])])
		player.free()
		return {}
	return {"equipment": equipment, "player": player}


static func _harness(failures: Array[String]) -> Dictionary:
	var harness := {
		"wood": ResourceLoader.load(WOOD_PATH),
		"iron": ResourceLoader.load(IRON_PATH),
		"sword": ResourceLoader.load(SWORD_PATH),
		"attack_set": ResourceLoader.load(ATTACK_SET_PATH),
		"archetype": ResourceLoader.load(ARCHETYPE_PATH),
		"recipe": ResourceLoader.load(RECIPE_PATH),
	}
	for key in harness.keys():
		if harness[key] == null:
			failures.append("weapon runtime failure harness could not load production content: %s" % key)
	if not failures.is_empty():
		return {}
	var definitions: Array = [
		harness["wood"],
		harness["iron"],
		harness["sword"],
		harness["attack_set"],
		harness["archetype"],
		harness["recipe"],
	]
	var validation: Dictionary = _validate(definitions)
	if not bool(validation.get("success", false)):
		failures.append("weapon runtime failure harness CONTENT-005 failed: %s" % [validation.get("diagnostics", [])])
		return {}
	var registry = ContentRegistry.new()
	var index_failures: Array[String] = registry.index_definitions(definitions)
	if not index_failures.is_empty():
		failures.append("weapon runtime failure harness registry failed: %s" % [index_failures])
		return {}
	harness["validation"] = validation
	harness["registry"] = registry
	harness["crafting"] = CraftingService.new().configure(registry, validation)
	return harness


static func _equipment_state():
	var hands_rule = EquipmentSlotRule.new().configure(
		SLOT_HANDS,
		[ITEM_EQUIPMENT],
		[EQUIPABLE]
	)
	var utility_rule = EquipmentSlotRule.new().configure(
		SLOT_UTILITY,
		[ITEM_EQUIPMENT],
		[EQUIPABLE]
	)
	var equipment = EquipmentHotbarState.new().configure(
		[hands_rule, utility_rule],
		{1: SLOT_HANDS, 4: SLOT_UTILITY}
	)
	equipment.select_hotbar(1)
	return equipment


static func _validate(definitions: Array) -> Dictionary:
	return ContentValidationPipeline.new().validate_all(
		definitions,
		_categories(),
		_capabilities(),
		[_item_validator(), RecipeFamilyValidator.new().configure_recipe_rules()]
	)


static func _item_validator():
	var extension = WeaponItemRuleExtension.new()
	extension.configure_weapon_rules(CharacterSemanticSchemaCatalog.build_registry())
	var validator = ItemFamilyValidator.new()
	validator.configure_item_rules([extension])
	return validator


static func _categories():
	var registry = CategorySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CategorySchema.new().configure(ITEM_ROOT),
		CategorySchema.new().configure(ITEM_RESOURCE, [ITEM_ROOT]),
		CategorySchema.new().configure(ITEM_EQUIPMENT, [ITEM_ROOT]),
		CategorySchema.new().configure(ITEM_WEAPON, [ITEM_EQUIPMENT]),
		CategorySchema.new().configure(ITEM_WEAPON_MELEE, [ITEM_WEAPON]),
		CategorySchema.new().configure(ITEM_SWORD, [ITEM_WEAPON_MELEE]),
	])
	assert(diagnostics.is_empty())
	return registry


static func _capabilities():
	var registry = CapabilitySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CapabilitySchema.new().configure(EQUIPABLE),
		CapabilitySchema.new().configure(DAMAGE_DEALER),
	])
	assert(diagnostics.is_empty())
	return registry


static func _diagnostics_contain(result: Dictionary, fragment: String) -> bool:
	for diagnostic in result.get("diagnostics", []):
		if str(diagnostic.get("message", diagnostic)).contains(fragment):
			return true
	return false
