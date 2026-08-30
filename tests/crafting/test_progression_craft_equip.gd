extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const ItemFamilyValidator := preload("res://gameplay/items/validation/item_family_validator.gd")
const RecipeFamilyValidator := preload("res://gameplay/crafting/validation/recipe_family_validator.gd")
const CraftingContext := preload("res://gameplay/crafting/runtime/crafting_context.gd")
const CraftingService := preload("res://gameplay/crafting/runtime/crafting_service.gd")
const ProgressionCraftEquipService := preload("res://gameplay/crafting/runtime/progression_craft_equip_service.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquipmentSlotRule := preload("res://gameplay/items/equipment/equipment_slot_rule.gd")
const EquipmentService := preload("res://gameplay/items/equipment/equipment_service.gd")
const SurfaceHarvestInventoryService := preload("res://gameplay/survival/surface_harvest_inventory_service.gd")
const TrackingEquipmentService := preload("res://tests/crafting/tracking_equipment_service.gd")

const RECIPE_PATH := "res://content/recipes/stone_axe.tres"
const WOOD_PATH := "res://content/items/resources/wood_definition.tres"
const STONE_PATH := "res://content/items/resources/stone_definition.tres"
const AXE_PATH := "res://content/items/tools/stone_axe_definition.tres"

const RECIPE_ID := "recipe.hand.stone_axe"
const WOOD_ID := "item.resource.wood"
const STONE_ID := "item.resource.stone"
const AXE_ID := "item.tool.stone_axe"

const ITEM_ROOT := "category.item"
const ITEM_RESOURCE := "category.item.resource"
const ITEM_EQUIPMENT := "category.item.equipment"
const ITEM_TOOL := "category.item.equipment.tool"
const ITEM_TOOL_AXE := "category.item.equipment.tool.axe"
const ITEM_TOOL_PICKAXE := "category.item.equipment.tool.pickaxe"
const EQUIPABLE := "capability.equipable"
const HARVEST_TOOL := "capability.harvest_tool"
const AXE_SLOT := "equipment_slot.hotbar.axe"
const PICKAXE_SLOT := "equipment_slot.hotbar.pickaxe"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_production_axe_craft_equip_and_harvest_resolution(failures)
	_test_craft_failure_never_attempts_equip(failures)
	_test_equip_failure_retains_successfully_crafted_output(failures)
	_test_explicit_incompatible_equip_is_atomic(failures)
	_test_replacement_swap_uses_equipment_service(failures)
	_test_hotbar_number_requires_existing_semantic_binding(failures)
	failures.sort()
	return failures


static func _test_production_axe_craft_equip_and_harvest_resolution(
	failures: Array[String]
) -> void:
	var harness: Dictionary = _production_harness(failures)
	if harness.is_empty():
		return
	var inventory = ItemContainerState.new().configure(4, 30.0)
	inventory.add_stack(harness["wood"], 4)
	inventory.add_stack(harness["stone"], 3)
	var equipment = _axe_equipment()
	var bridge = ProgressionCraftEquipService.new().configure(
		harness["crafting"],
		harness["registry"]
	)
	var result: Dictionary = bridge.craft_and_equip(
		RECIPE_ID,
		CraftingContext.new(),
		inventory,
		equipment,
		AXE_ID,
		AXE_SLOT,
		2
	)
	if not bool(result.get("success", false)):
		failures.append("production stone-axe progression bridge failed: %s" % [result.get("diagnostics", [])])
		return
	_expect_equal(failures, "production axe wood consumed", inventory.quantity_of(WOOD_ID), 0)
	_expect_equal(failures, "production axe stone consumed", inventory.quantity_of(STONE_ID), 0)
	_expect_equal(failures, "crafted axe moved out of inventory", inventory.quantity_of(AXE_ID), 0)
	_expect_equal(failures, "semantic hotbar selected", equipment.selected_hotbar(), 2)
	_expect_equal(failures, "selected semantic slot", equipment.selected_slot_key(), AXE_SLOT)
	var equipped_definition = equipment.selected_definition()
	if equipped_definition != harness["axe"]:
		failures.append("progression bridge did not preserve authored production axe definition identity")
	var selected: Dictionary = result.get("selected_item", {})
	_expect_equal(failures, "selected item id", str(selected.get("item_id", "")), AXE_ID)
	if not bool(selected.get("can_harvest", false)):
		failures.append("selected production axe did not resolve harvest capability")
	if selected.has("definition") or selected.has("item_state"):
		failures.append("progression semantic outcome leaked mutable definition/item-state authority")
	if not _has_event(result, "progression.craft_equip_completed"):
		failures.append("successful progression bridge omitted semantic completion event")

	var harvest_bridge = SurfaceHarvestInventoryService.new().configure(
		inventory,
		equipment,
		[harness["wood"], harness["stone"], harness["axe"]]
	)
	var eligibility: Dictionary = harvest_bridge.tool_eligibility("tree")
	if not bool(eligibility.get("success", false)):
		failures.append("selected crafted axe did not reach accepted harvest item-use seam: %s" % [eligibility.get("diagnostics", [])])
	else:
		_expect_equal(failures, "harvest seam selected axe", str(eligibility.get("item_id", "")), AXE_ID)
		_expect_equal(failures, "harvest seam selected slot", str(eligibility.get("slot_key", "")), AXE_SLOT)


static func _test_craft_failure_never_attempts_equip(failures: Array[String]) -> void:
	var harness: Dictionary = _production_harness(failures)
	if harness.is_empty():
		return
	var inventory = ItemContainerState.new().configure(4, 30.0)
	inventory.add_stack(harness["wood"], 3)
	inventory.add_stack(harness["stone"], 3)
	var equipment = _axe_equipment()
	var tracker = TrackingEquipmentService.new()
	var bridge = ProgressionCraftEquipService.new().configure(
		harness["crafting"], harness["registry"], tracker
	)
	var inventory_before: String = inventory.canonical_json()
	var equipment_before: String = equipment.canonical_json()
	var result: Dictionary = bridge.craft_and_equip(
		RECIPE_ID, CraftingContext.new(), inventory, equipment, AXE_ID, AXE_SLOT, 2
	)
	if bool(result.get("success", false)):
		failures.append("insufficient production ingredients unexpectedly progressed to equip")
	_expect_equal(failures, "craft failure stage", str(result.get("stage", "")), "craft")
	_expect_equal(failures, "craft failure equip attempts", tracker.attempts, 0)
	if bool(result.get("equip_attempted", false)):
		failures.append("craft failure reported an equip attempt")
	if inventory.canonical_json() != inventory_before:
		failures.append("failed progression craft mutated inventory")
	if equipment.canonical_json() != equipment_before:
		failures.append("failed progression craft mutated equipment")


static func _test_equip_failure_retains_successfully_crafted_output(
	failures: Array[String]
) -> void:
	var harness: Dictionary = _production_harness(failures)
	if harness.is_empty():
		return
	var inventory = ItemContainerState.new().configure(4, 30.0)
	inventory.add_stack(harness["wood"], 4)
	inventory.add_stack(harness["stone"], 3)
	var equipment = _axe_equipment()
	var equipment_before: String = equipment.canonical_json()
	var tracker = TrackingEquipmentService.new()
	tracker.reject_equips = true
	var bridge = ProgressionCraftEquipService.new().configure(
		harness["crafting"], harness["registry"], tracker
	)
	var result: Dictionary = bridge.craft_and_equip(
		RECIPE_ID, CraftingContext.new(), inventory, equipment, AXE_ID, AXE_SLOT, 2
	)
	if bool(result.get("success", false)):
		failures.append("injected equip rejection unexpectedly succeeded")
	_expect_equal(failures, "equip rejection stage", str(result.get("stage", "")), "equip")
	_expect_equal(failures, "equip rejection attempts", tracker.attempts, 1)
	if not bool(result.get("craft_succeeded", false)) or not bool(result.get("equip_attempted", false)):
		failures.append("equip rejection did not preserve craft/equip stage semantics")
	_expect_equal(failures, "wood consumed before equip rejection", inventory.quantity_of(WOOD_ID), 0)
	_expect_equal(failures, "stone consumed before equip rejection", inventory.quantity_of(STONE_ID), 0)
	_expect_equal(failures, "crafted axe retained after equip rejection", inventory.quantity_of(AXE_ID), 1)
	if equipment.canonical_json() != equipment_before:
		failures.append("injected equip rejection mutated equipment")
	if str(result.get("craft_transaction_fingerprint", "")).is_empty():
		failures.append("successful craft before equip rejection omitted transaction fingerprint")
	if not str(result.get("equip_transaction_fingerprint", "")).is_empty():
		failures.append("rejected equip emitted a transaction fingerprint")


static func _test_explicit_incompatible_equip_is_atomic(failures: Array[String]) -> void:
	var harness: Dictionary = _production_harness(failures)
	if harness.is_empty():
		return
	var inventory = ItemContainerState.new().configure(2, 30.0)
	var added: Dictionary = inventory.add_instance(harness["axe"])
	var source_slot: int = int(added.get("slot", -1))
	var pickaxe_rule = EquipmentSlotRule.new().configure(
		PICKAXE_SLOT,
		[ITEM_TOOL_PICKAXE],
		[EQUIPABLE]
	)
	var equipment = EquipmentHotbarState.new().configure([pickaxe_rule], {3: PICKAXE_SLOT})
	var tracker = TrackingEquipmentService.new()
	var bridge = ProgressionCraftEquipService.new().configure(
		harness["crafting"], harness["registry"], tracker
	)
	var inventory_before: String = inventory.canonical_json()
	var equipment_before: String = equipment.canonical_json()
	var result: Dictionary = bridge.equip_existing(
		inventory, equipment, source_slot, AXE_ID, PICKAXE_SLOT, 3
	)
	if bool(result.get("success", false)):
		failures.append("axe unexpectedly equipped into pickaxe-only semantic slot")
	_expect_equal(failures, "incompatible explicit equip attempts", tracker.attempts, 0)
	if inventory.canonical_json() != inventory_before or equipment.canonical_json() != equipment_before:
		failures.append("incompatible explicit equip mutated canonical inventory/equipment state")


static func _test_replacement_swap_uses_equipment_service(failures: Array[String]) -> void:
	var harness: Dictionary = _production_harness(failures)
	if harness.is_empty():
		return
	var inventory = ItemContainerState.new().configure(5, 30.0)
	var initial_add: Dictionary = inventory.add_instance(harness["axe"])
	var equipment = _axe_equipment()
	var initial_equip: Dictionary = EquipmentService.new().equip_from_inventory(
		equipment,
		inventory,
		int(initial_add.get("slot", -1)),
		harness["axe"],
		AXE_SLOT
	)
	if not bool(initial_equip.get("success", false)):
		failures.append("replacement setup could not equip initial production axe")
		return
	inventory.add_stack(harness["wood"], 4)
	inventory.add_stack(harness["stone"], 3)
	var bridge = ProgressionCraftEquipService.new().configure(
		harness["crafting"], harness["registry"]
	)
	var result: Dictionary = bridge.craft_and_equip(
		RECIPE_ID, CraftingContext.new(), inventory, equipment, AXE_ID, AXE_SLOT, 2
	)
	if not bool(result.get("success", false)):
		failures.append("replacement craft/equip failed: %s" % [result.get("diagnostics", [])])
		return
	_expect_equal(failures, "replacement returned old axe to inventory", inventory.quantity_of(AXE_ID), 1)
	if equipment.definition_at(AXE_SLOT) != harness["axe"]:
		failures.append("replacement swap changed authored axe definition identity")
	if not _has_event_field(result, "equipment.slot_changed", "replaced_item_id", AXE_ID):
		failures.append("replacement swap did not surface accepted EquipmentService replacement event")


static func _test_hotbar_number_requires_existing_semantic_binding(
	failures: Array[String]
) -> void:
	var harness: Dictionary = _production_harness(failures)
	if harness.is_empty():
		return
	var inventory = ItemContainerState.new().configure(4, 30.0)
	inventory.add_stack(harness["wood"], 4)
	inventory.add_stack(harness["stone"], 3)
	var equipment = _axe_equipment()
	var inventory_before: String = inventory.canonical_json()
	var equipment_before: String = equipment.canonical_json()
	var bridge = ProgressionCraftEquipService.new().configure(
		harness["crafting"], harness["registry"]
	)
	var result: Dictionary = bridge.craft_and_equip(
		RECIPE_ID, CraftingContext.new(), inventory, equipment, AXE_ID, AXE_SLOT, 3
	)
	if bool(result.get("success", false)):
		failures.append("unbound physical hotbar index unexpectedly gained progression authority")
	if not _has_fragment(result.get("diagnostics", []), "must already bind semantic slot"):
		failures.append("hotbar semantic-binding rejection was not explicit: %s" % [result.get("diagnostics", [])])
	if inventory.canonical_json() != inventory_before or equipment.canonical_json() != equipment_before:
		failures.append("hotbar binding preflight failure mutated state")


static func _production_harness(failures: Array[String]) -> Dictionary:
	var recipe = ResourceLoader.load(RECIPE_PATH)
	var wood = ResourceLoader.load(WOOD_PATH)
	var stone = ResourceLoader.load(STONE_PATH)
	var axe = ResourceLoader.load(AXE_PATH)
	if recipe == null or wood == null or stone == null or axe == null:
		failures.append("production progression content failed to load")
		return {}
	var definitions: Array = [recipe, wood, stone, axe]
	var registry = ContentRegistry.new()
	var registry_failures: Array[String] = registry.index_definitions(definitions)
	if not registry_failures.is_empty():
		failures.append("production progression registry failed: %s" % [registry_failures])
		return {}
	var validation: Dictionary = ContentValidationPipeline.new().validate_all(
		definitions,
		_categories(),
		_capabilities(),
		[
			ItemFamilyValidator.new().configure_item_rules([]),
			RecipeFamilyValidator.new().configure_recipe_rules(),
		]
	)
	if not bool(validation.get("success", false)):
		failures.append("production progression CONTENT-005 validation failed: %s" % [validation.get("diagnostics", [])])
		return {}
	var crafting = CraftingService.new().configure(registry, validation)
	return {
		"recipe": recipe,
		"wood": wood,
		"stone": stone,
		"axe": axe,
		"registry": registry,
		"validation": validation,
		"crafting": crafting,
	}


static func _axe_equipment():
	var rule = EquipmentSlotRule.new().configure(
		AXE_SLOT,
		[ITEM_TOOL_AXE],
		[EQUIPABLE]
	)
	return EquipmentHotbarState.new().configure([rule], {2: AXE_SLOT})


static func _categories():
	var registry = CategorySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CategorySchema.new().configure(ITEM_ROOT),
		CategorySchema.new().configure(ITEM_RESOURCE, [ITEM_ROOT]),
		CategorySchema.new().configure(ITEM_EQUIPMENT, [ITEM_ROOT]),
		CategorySchema.new().configure(ITEM_TOOL, [ITEM_EQUIPMENT]),
		CategorySchema.new().configure(ITEM_TOOL_AXE, [ITEM_TOOL]),
		CategorySchema.new().configure(ITEM_TOOL_PICKAXE, [ITEM_TOOL]),
	])
	assert(diagnostics.is_empty())
	return registry


static func _capabilities():
	var registry = CapabilitySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CapabilitySchema.new().configure(EQUIPABLE),
		CapabilitySchema.new().configure(HARVEST_TOOL),
	])
	assert(diagnostics.is_empty())
	return registry


static func _has_event(result: Dictionary, event_type: String) -> bool:
	for event in result.get("events", []):
		if str(event.get("type", "")) == event_type:
			return true
	return false


static func _has_event_field(
	result: Dictionary,
	event_type: String,
	field: String,
	expected: Variant
) -> bool:
	for event in result.get("events", []):
		if str(event.get("type", "")) == event_type and event.get(field) == expected:
			return true
	return false


static func _has_fragment(messages: Array, fragment: String) -> bool:
	for message in messages:
		if str(message).contains(fragment):
			return true
	return false


static func _expect_equal(
	failures: Array[String],
	label: String,
	actual: Variant,
	expected: Variant
) -> void:
	if actual != expected:
		failures.append("%s expected %s, got %s" % [label, str(expected), str(actual)])
