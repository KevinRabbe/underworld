extends RefCounted

const ContentDefinition := preload("res://core/content/registry/content_definition.gd")
const ContentReference := preload("res://core/content/references/content_reference.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemStackState := preload("res://gameplay/items/state/item_stack_state.gd")
const ItemInstanceState := preload("res://gameplay/items/state/item_instance_state.gd")
const ItemFamilyValidator := preload("res://gameplay/items/validation/item_family_validator.gd")
const PrototypeToolItemDefinition := preload("res://tests/content/fixtures/items/prototype_tool_item_definition.gd")
const PrototypeToolRuleExtension := preload("res://tests/content/fixtures/items/prototype_tool_rule_extension.gd")

const ITEM_PATH_A := "res://tests/fixtures/content/path_a/iron_sword.tres"
const ITEM_PATH_B := "res://tests/fixtures/content/path_b/renamed_weapon_definition.tres"
const ITEM_ROOT := "category.item"
const ITEM_RESOURCE := "category.item.resource"
const ITEM_EQUIPMENT := "category.item.equipment"
const ITEM_WEAPON := "category.item.equipment.weapon"
const ITEM_TOOL := "category.item.equipment.tool"
const WORLD_OBJECT := "category.world_object"
const HARVEST_TOOL := "capability.harvest_tool"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_authored_definition_and_path_identity(failures)
	_test_mutable_state_is_separate_from_definition(failures)
	_test_wrong_item_definition_type_fails_closed(failures)
	_test_family_extension_and_category_capability_rules(failures)
	_test_typed_semantic_references(failures)
	return failures


static func _test_authored_definition_and_path_identity(failures: Array[String]) -> void:
	var first = ResourceLoader.load(ITEM_PATH_A)
	var moved = ResourceLoader.load(ITEM_PATH_B)
	if first == null or moved == null or not first is ItemDefinition or not moved is ItemDefinition:
		failures.append("authored item path fixtures did not load as ItemDefinition resources")
		return

	first.configure_schema_declarations([ITEM_WEAPON], [])
	moved.configure_schema_declarations([ITEM_WEAPON], [])
	var validator = ItemFamilyValidator.new()
	validator.configure_item_rules([])
	var pipeline = ContentValidationPipeline.new()
	for candidate in [first, moved]:
		var result: Dictionary = pipeline.validate_all(
			[candidate],
			_categories(),
			_capabilities(),
			[validator]
		)
		if not bool(result.get("success", false)):
			failures.append("valid authored item failed CONTENT-005 validation: %s" % [result.get("diagnostics", [])])

	if first.content_id != "item.weapon.iron_sword" or moved.content_id != first.content_id:
		failures.append("physical item file move changed semantic item identity")
	if str(first.resource_path) == str(moved.resource_path):
		failures.append("item path-independence proof did not use two distinct physical paths")
	if first.canonical_descriptor() != moved.canonical_descriptor():
		failures.append("item canonical definition changed after physical file move")
	if first.stack_limit != 1 or not is_equal_approx(first.unit_weight, 3.0):
		failures.append("authored item base fields were not loaded from .tres data")


static func _test_mutable_state_is_separate_from_definition(failures: Array[String]) -> void:
	var definition = ItemDefinition.new()
	definition.configure_item("item.tool.prototype_pickaxe", 1, 2.0, 1)
	definition.configure_schema_declarations([ITEM_TOOL], [HARVEST_TOOL])
	var before: Dictionary = definition.canonical_descriptor().duplicate(true)

	var stack = ItemStackState.new()
	stack.configure("item.resource.wood", 40, {"quality": "ordinary"})
	var instance = ItemInstanceState.new()
	instance.configure("item.tool.prototype_pickaxe", {"durability": 100})
	if not stack.validate_state().is_empty() or not instance.validate_state().is_empty():
		failures.append("valid item stack/instance mutable state failed its local contract")

	stack.quantity = 12
	stack.compatibility_state["quality"] = "weathered"
	instance.set_value("durability", 25)
	if definition.canonical_descriptor() != before:
		failures.append("mutating item stack/instance state changed the shared authored definition")
	if int(instance.get_value("durability", -1)) != 25:
		failures.append("item instance mutable-state boundary did not retain per-copy state")

	var compatible = ItemStackState.new()
	compatible.configure("item.resource.wood", 1, {"quality": "weathered"})
	if not stack.is_compatible_with(compatible):
		failures.append("equivalent item stack compatibility state was not recognized")
	compatible.compatibility_state["quality"] = "ordinary"
	if stack.is_compatible_with(compatible):
		failures.append("different item stack compatibility state was incorrectly merge-compatible")


static func _test_wrong_item_definition_type_fails_closed(failures: Array[String]) -> void:
	var wrong_type = ContentDefinition.new()
	wrong_type.configure("item.invalid.generic_definition", "item", 1)
	wrong_type.configure_schema_declarations([ITEM_RESOURCE], [])

	var validator = ItemFamilyValidator.new()
	validator.configure_item_rules([])
	if not validator.applies_to(wrong_type):
		failures.append("item validator did not select semantic item family when concrete subtype was wrong")
		return

	var result: Dictionary = ContentValidationPipeline.new().validate_all(
		[wrong_type],
		_categories(),
		_capabilities(),
		[validator]
	)
	if not _has_code_fragment(result, "family_rule", "must inherit ItemDefinition"):
		failures.append("generic ContentDefinition under semantic item family bypassed the item rulebook")


static func _test_family_extension_and_category_capability_rules(failures: Array[String]) -> void:
	var validator = ItemFamilyValidator.new()
	validator.configure_item_rules([PrototypeToolRuleExtension.new()])
	var pipeline = ContentValidationPipeline.new()

	var tool = PrototypeToolItemDefinition.new()
	tool.configure_tool("item.tool.prototype_pickaxe", 2.5, 1)
	var valid_result: Dictionary = pipeline.validate_all(
		[tool],
		_categories(),
		_capabilities(),
		[validator]
	)
	if not bool(valid_result.get("success", false)):
		failures.append("valid child item rule extension failed CONTENT-005 validation: %s" % [valid_result.get("diagnostics", [])])
	if _has_property(ItemDefinition.new(), "harvest_power"):
		failures.append("family-specific harvest field leaked into generic ItemDefinition")
	if not _has_property(tool, "harvest_power"):
		failures.append("family-specific item extension did not own its harvest field")

	var missing_capability = PrototypeToolItemDefinition.new()
	missing_capability.configure_tool("item.tool.invalid_missing_capability", 1.0, 1)
	missing_capability.configure_schema_declarations([ITEM_TOOL], [])
	var missing_capability_result: Dictionary = pipeline.validate_all(
		[missing_capability],
		_categories(),
		_capabilities(),
		[validator]
	)
	if not _has_code_fragment(
		missing_capability_result,
		"family_rule",
		"tool category requires capability"
	):
		failures.append("item category/capability combination did not fail through the child rule extension")

	var foreign_category = ItemDefinition.new()
	foreign_category.configure_item("item.invalid.foreign_category", 1, 0.0, 1)
	foreign_category.configure_schema_declarations([WORLD_OBJECT], [])
	var foreign_result: Dictionary = pipeline.validate_all(
		[foreign_category],
		_categories(),
		_capabilities(),
		[validator]
	)
	if not _has_code_fragment(foreign_result, "family_rule", "declares category outside"):
		failures.append("item family validator accepted a category outside category.item")

	var invalid_base = ItemDefinition.new()
	invalid_base.configure_item("item.invalid.stack_limit", 0, 0.0, 1)
	invalid_base.configure_schema_declarations([ITEM_RESOURCE], [])
	var invalid_base_result: Dictionary = pipeline.validate_all(
		[invalid_base],
		_categories(),
		_capabilities(),
		[validator]
	)
	if not _has_code_fragment(invalid_base_result, "definition_invalid", "stack limit must be >= 1"):
		failures.append("invalid common item definition data did not fail before runtime")


static func _test_typed_semantic_references(failures: Array[String]) -> void:
	var item = ItemDefinition.new()
	item.configure_item("item.resource.reference_probe", 64, 0.1, 1)
	item.configure_schema_declarations([ITEM_RESOURCE], [])
	item.configure_semantic_references([
		ContentReference.new(
			"item.resource.reference_probe",
			"presentation.archetype",
			"archetype.item.reference_probe",
			"archetype",
			true
		),
		ContentReference.new(
			"item.resource.reference_probe",
			"presentation.animation_set",
			"animation_set.item.reference_probe",
			"animation_set",
			true
		),
		ContentReference.new(
			"item.resource.reference_probe",
			"effect.primary",
			"effect.item.reference_probe",
			"effect",
			true
		),
	])

	var targets: Array = [
		_content_definition("archetype.item.reference_probe", "archetype"),
		_content_definition("animation_set.item.reference_probe", "animation_set"),
		_content_definition("effect.item.reference_probe", "effect"),
	]
	var definitions: Array = [item]
	definitions.append_array(targets)
	var validator = ItemFamilyValidator.new()
	validator.configure_item_rules([])
	var valid_result: Dictionary = ContentValidationPipeline.new().validate_all(
		definitions,
		_categories(),
		_capabilities(),
		[validator]
	)
	if not bool(valid_result.get("success", false)):
		failures.append("typed item presentation/animation/effect references failed CONTENT-005 validation: %s" % [valid_result.get("diagnostics", [])])

	var missing = ItemDefinition.new()
	missing.configure_item("item.resource.missing_reference", 1, 0.0, 1)
	missing.configure_schema_declarations([ITEM_RESOURCE], [])
	missing.configure_semantic_references([
		ContentReference.new(
			"item.resource.missing_reference",
			"presentation.archetype",
			"archetype.item.missing",
			"archetype",
			true
		),
	])
	var missing_result: Dictionary = ContentValidationPipeline.new().validate_all(
		[missing],
		_categories(),
		_capabilities(),
		[validator]
	)
	if not _has_code_fragment(missing_result, "reference_resolution", "missing content definition"):
		failures.append("missing typed item semantic reference did not fail through CONTENT-005")


static func _categories():
	var registry = CategorySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CategorySchema.new().configure(ITEM_ROOT),
		CategorySchema.new().configure(ITEM_RESOURCE, [ITEM_ROOT]),
		CategorySchema.new().configure(ITEM_EQUIPMENT, [ITEM_ROOT]),
		CategorySchema.new().configure(ITEM_WEAPON, [ITEM_EQUIPMENT]),
		CategorySchema.new().configure(ITEM_TOOL, [ITEM_EQUIPMENT]),
		CategorySchema.new().configure(WORLD_OBJECT),
	])
	assert(diagnostics.is_empty())
	return registry


static func _capabilities():
	var registry = CapabilitySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CapabilitySchema.new().configure(HARVEST_TOOL),
	])
	assert(diagnostics.is_empty())
	return registry


static func _content_definition(content_id: String, family: String):
	var definition = ContentDefinition.new()
	definition.configure(content_id, family, 1)
	return definition


static func _has_property(value, property_name: String) -> bool:
	for descriptor in value.get_property_list():
		if str(descriptor.get("name", "")) == property_name:
			return true
	return false


static func _has_code_fragment(result: Dictionary, code: String, fragment: String) -> bool:
	for diagnostic in result.get("diagnostics", []):
		if (
			str(diagnostic.get("code", "")) == code
			and str(diagnostic.get("message", "")).contains(fragment)
		):
			return true
	return false
