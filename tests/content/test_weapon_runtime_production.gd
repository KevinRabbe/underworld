extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const ArchetypeComposition := preload("res://core/content/archetypes/archetype_composition.gd")
const ArchetypeDefinition := preload("res://core/content/archetypes/archetype_definition.gd")
const ArchetypeFamilyValidator := preload("res://core/content/archetypes/archetype_family_validator.gd")
const ArchetypeRealizer := preload("res://core/content/archetypes/archetype_realizer.gd")
const PackedSceneArchetypeAdapter := preload("res://core/content/archetypes/packed_scene_archetype_adapter.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemFamilyValidator := preload("res://gameplay/items/validation/item_family_validator.gd")
const WeaponDefinition := preload("res://gameplay/items/weapons/definitions/weapon_definition.gd")
const WeaponAttackSetDefinition := preload("res://gameplay/items/weapons/definitions/weapon_attack_set_definition.gd")
const WeaponItemRuleExtension := preload("res://gameplay/items/weapons/validation/weapon_item_rule_extension.gd")
const SelectedWeaponAttackSourceService := preload("res://gameplay/items/weapons/runtime/selected_weapon_attack_source_service.gd")
const CharacterSemanticSchemaCatalog := preload("res://presentation/characters/animation/character_semantic_schema_catalog.gd")
const RecipeDefinition := preload("res://gameplay/crafting/definitions/recipe_definition.gd")
const RecipeFamilyValidator := preload("res://gameplay/crafting/validation/recipe_family_validator.gd")
const CraftingContext := preload("res://gameplay/crafting/runtime/crafting_context.gd")
const CraftingService := preload("res://gameplay/crafting/runtime/crafting_service.gd")
const ProgressionCraftEquipService := preload("res://gameplay/crafting/runtime/progression_craft_equip_service.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquipmentSlotRule := preload("res://gameplay/items/equipment/equipment_slot_rule.gd")
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
	var bundle: Dictionary = _load_bundle(failures)
	if bundle.is_empty():
		return failures
	var definitions: Array = _definitions(bundle)
	var validation: Dictionary = _validate(definitions)
	if not bool(validation.get("success", false)):
		failures.append("production iron-sword bundle failed CONTENT-005: %s" % [validation.get("diagnostics", [])])
		return failures
	var registry = ContentRegistry.new()
	var registry_failures: Array[String] = registry.index_definitions(definitions)
	if not registry_failures.is_empty():
		failures.append("production iron-sword registry indexing failed: %s" % [registry_failures])
		return failures

	_test_production_identity_and_recipe(bundle, failures)
	_test_missing_targets_fail_closed(bundle, failures)
	_test_archetype_realization(bundle, registry, validation, failures)
	_test_craft_equip_and_player_binding(bundle, registry, validation, failures)
	failures.sort()
	return failures


static func _load_bundle(failures: Array[String]) -> Dictionary:
	var bundle := {
		"wood": ResourceLoader.load(WOOD_PATH),
		"iron": ResourceLoader.load(IRON_PATH),
		"sword": ResourceLoader.load(SWORD_PATH),
		"attack_set": ResourceLoader.load(ATTACK_SET_PATH),
		"archetype": ResourceLoader.load(ARCHETYPE_PATH),
		"recipe": ResourceLoader.load(RECIPE_PATH),
	}
	if bundle["wood"] == null or not bundle["wood"] is ItemDefinition:
		failures.append("production wood definition did not load")
	if bundle["iron"] == null or not bundle["iron"] is ItemDefinition:
		failures.append("production iron-chunk definition did not load")
	if bundle["sword"] == null or not bundle["sword"] is WeaponDefinition:
		failures.append("production iron sword did not load as WeaponDefinition")
	if bundle["attack_set"] == null or not bundle["attack_set"] is WeaponAttackSetDefinition:
		failures.append("production sword attack set did not load as WeaponAttackSetDefinition")
	if bundle["archetype"] == null or not bundle["archetype"] is ArchetypeDefinition:
		failures.append("production sword archetype did not load as ArchetypeDefinition")
	if bundle["recipe"] == null or not bundle["recipe"] is RecipeDefinition:
		failures.append("production iron-sword recipe did not load as RecipeDefinition")
	return {} if not failures.is_empty() else bundle


static func _definitions(bundle: Dictionary) -> Array:
	return [
		bundle["wood"],
		bundle["iron"],
		bundle["sword"],
		bundle["attack_set"],
		bundle["archetype"],
		bundle["recipe"],
	]


static func _test_production_identity_and_recipe(bundle: Dictionary, failures: Array[String]) -> void:
	var sword = bundle["sword"]
	var attack_set = bundle["attack_set"]
	var archetype = bundle["archetype"]
	var recipe = bundle["recipe"]
	if str(sword.content_id) != SWORD_ID:
		failures.append("production sword ContentId drifted")
	if str(sword.attack_set_id) != ATTACK_SET_ID or str(sword.archetype_id) != ARCHETYPE_ID:
		failures.append("production sword semantic dependencies are not closed")
	if not sword.category_ids.has(ITEM_SWORD):
		failures.append("production sword is not in semantic sword category")
	if not sword.capability_ids.has(EQUIPABLE) or not sword.capability_ids.has(DAMAGE_DEALER):
		failures.append("production sword lacks equipable/damage-dealer capabilities")
	if sword.stack_limit != 1 or not is_equal_approx(sword.unit_weight, 3.0):
		failures.append("production sword ITEM base fields are invalid")
	if str(attack_set.attack_id_for("weapon_technique.light.primary")) != "sword_light_01":
		failures.append("production sword attack set lacks light semantic binding")
	if str(attack_set.attack_id_for("weapon_technique.heavy.primary")) != "sword_heavy_01":
		failures.append("production sword attack set lacks heavy semantic binding")
	if str(recipe.content_id) != RECIPE_ID:
		failures.append("production sword recipe ContentId drifted")
	var outputs: Array = recipe.aggregated_outputs()
	if outputs.size() != 1 or str(outputs[0].get("item_id", "")) != SWORD_ID or int(outputs[0].get("quantity", 0)) != 1:
		failures.append("production recipe does not output exactly one production iron sword")
	var ingredients: Dictionary = {}
	for descriptor in recipe.aggregated_ingredients():
		ingredients[str(descriptor.get("item_id", ""))] = int(descriptor.get("quantity", 0))
	if int(ingredients.get(WOOD_ID, 0)) != 1 or int(ingredients.get(IRON_ID, 0)) != 4:
		failures.append("production iron-sword recipe ingredient contract changed")
	for path in [sword.resource_path, attack_set.resource_path, archetype.resource_path, archetype.composition.resource_binding.resource_path]:
		if str(path).contains("tests/fixtures"):
			failures.append("production sword bundle references test fixture path: %s" % path)


static func _test_missing_targets_fail_closed(bundle: Dictionary, failures: Array[String]) -> void:
	var sword = bundle["sword"]
	var attack_set = bundle["attack_set"]
	var archetype = bundle["archetype"]

	var missing_attack = sword.duplicate(true)
	missing_attack.content_id = "item.weapon.iron_sword_missing_attack"
	missing_attack.attack_set_id = "attack_set.weapon.missing"
	var missing_attack_result: Dictionary = _validate([missing_attack, archetype])
	if bool(missing_attack_result.get("success", false)):
		failures.append("production-shaped sword accepted missing attack-set target")

	var missing_archetype = sword.duplicate(true)
	missing_archetype.content_id = "item.weapon.iron_sword_missing_archetype"
	missing_archetype.archetype_id = "archetype.weapon.missing"
	var missing_archetype_result: Dictionary = _validate([missing_archetype, attack_set])
	if bool(missing_archetype_result.get("success", false)):
		failures.append("production-shaped sword accepted missing archetype target")


static func _test_archetype_realization(
	bundle: Dictionary,
	registry,
	validation: Dictionary,
	failures: Array[String]
) -> void:
	var realizer = ArchetypeRealizer.new()
	var adapter_failures: Array[String] = realizer.register_adapter(PackedSceneArchetypeAdapter.new())
	if not adapter_failures.is_empty():
		failures.append("production sword realizer rejected packed-scene adapter: %s" % [adapter_failures])
		return
	var result: Dictionary = realizer.realize(registry, validation, ARCHETYPE_ID)
	if not bool(result.get("success", false)):
		failures.append("production sword archetype failed realization: %s" % [result.get("diagnostics", [])])
		return
	var instance = result.get("instance", null)
	if instance == null or not instance is Node:
		failures.append("production sword archetype did not create a Node instance")
	elif not instance.is_in_group(ArchetypeComposition.role_group_name("root")):
		failures.append("production sword placeholder lacks semantic root role")
	if instance != null and instance is Node:
		instance.free()


static func _test_craft_equip_and_player_binding(
	bundle: Dictionary,
	registry,
	validation: Dictionary,
	failures: Array[String]
) -> void:
	var inventory = ItemContainerState.new().configure(6, 40.0)
	var wood_add: Dictionary = inventory.add_stack(bundle["wood"], 1)
	var iron_add: Dictionary = inventory.add_stack(bundle["iron"], 4)
	if not bool(wood_add.get("success", false)) or not bool(iron_add.get("success", false)):
		failures.append("production sword progression test could not seed ingredients")
		return

	var equipment = _equipment_state()
	var crafting = CraftingService.new().configure(registry, validation)
	var progression = ProgressionCraftEquipService.new().configure(crafting, registry)
	var progressed: Dictionary = progression.craft_and_equip(
		RECIPE_ID,
		CraftingContext.new(),
		inventory,
		equipment,
		SWORD_ID,
		SLOT_UTILITY,
		4
	)
	if not bool(progressed.get("success", false)):
		failures.append("production sword craft/equip progression failed: %s" % [progressed.get("diagnostics", [])])
		return
	if inventory.quantity_of(WOOD_ID) != 0 or inventory.quantity_of(IRON_ID) != 0:
		failures.append("production sword craft did not consume authoritative ingredients")
	if inventory.quantity_of(SWORD_ID) != 0:
		failures.append("equipped production sword remained duplicated in inventory")
	if equipment.selected_hotbar() != 4 or equipment.selected_slot_key() != SLOT_UTILITY:
		failures.append("production sword did not select existing semantic hotbar-4 utility binding")
	if equipment.selected_definition() != bundle["sword"]:
		failures.append("production sword equip did not preserve authored definition identity")

	var player = PlayerScript.new()
	var binder = SelectedWeaponAttackSourceService.new()
	var bound: Dictionary = binder.bind_selected(equipment, registry, player)
	if not bool(bound.get("success", false)) or not bool(bound.get("weapon_bound", false)):
		failures.append("selected production sword failed Player weapon-source binding: %s" % [bound.get("diagnostics", [])])
		player.free()
		return
	var light = player._resolve_attack_definition("", &"light")
	var heavy = player._resolve_attack_definition("", &"heavy")
	if light == null or str(light.attack_id) != "sword_light_01" or light.attack_kind != &"light":
		failures.append("Player light attack did not resolve production sword semantic attack")
	if heavy == null or str(heavy.attack_id) != "sword_heavy_01" or heavy.attack_kind != &"heavy":
		failures.append("Player heavy attack did not resolve production sword semantic attack")
	var sword_identity_before: Dictionary = bundle["sword"].canonical_descriptor().duplicate(true)
	if light != null:
		light.damage += 3
	if bundle["sword"].canonical_descriptor() != sword_identity_before:
		failures.append("gameplay-owned attack tuning mutated WeaponDefinition identity")

	var equipment_to_hands: Dictionary = equipment.select_hotbar(1)
	if not bool(equipment_to_hands.get("success", false)):
		failures.append("could not switch production equipment back to hands")
	else:
		var cleared: Dictionary = binder.bind_selected(equipment, registry, player)
		if not bool(cleared.get("success", false)) or bool(cleared.get("weapon_bound", true)):
			failures.append("switching away from sword did not clear semantic weapon source")
		if player.equipped_weapon_definition != null:
			failures.append("Player retained stale WeaponDefinition after hands selection")
		var hands = player._resolve_attack_definition("hands", &"light")
		if hands == null or str(hands.attack_id) != "hands_light":
			failures.append("hands fallback did not recover after clearing sword source")

	equipment.select_hotbar(4)
	var rebound: Dictionary = binder.bind_selected(equipment, registry, player)
	if not bool(rebound.get("success", false)):
		failures.append("could not restore sword source for stale-source failure proof")
	else:
		var incomplete_registry = ContentRegistry.new()
		var index_failures: Array[String] = incomplete_registry.index_definitions([bundle["sword"]])
		if not index_failures.is_empty():
			failures.append("stale-source proof registry setup failed: %s" % [index_failures])
		else:
			var rejected: Dictionary = binder.bind_selected(equipment, incomplete_registry, player)
			if bool(rejected.get("success", false)):
				failures.append("weapon binding accepted missing production attack-set target")
			if player.equipped_weapon_definition != null or player.equipped_weapon_attack_set != null:
				failures.append("failed source resolution left stale previous sword source active")
	player.free()


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
		[
			_item_validator(),
			ArchetypeFamilyValidator.new().configure("archetype"),
			RecipeFamilyValidator.new().configure_recipe_rules(),
		]
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
