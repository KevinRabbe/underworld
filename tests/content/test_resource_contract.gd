extends RefCounted

const ContentDefinition := preload("res://core/content/registry/content_definition.gd")
const ContentReference := preload("res://core/content/references/content_reference.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemFamilyValidator := preload("res://gameplay/items/validation/item_family_validator.gd")
const ResourceDefinition := preload("res://gameplay/resources/definitions/resource_definition.gd")
const ResourceYieldRule := preload("res://gameplay/resources/definitions/resource_yield_rule.gd")
const ResourceDepletionState := preload("res://gameplay/resources/state/resource_depletion_state.gd")
const ResourceFamilyValidator := preload("res://gameplay/resources/validation/resource_family_validator.gd")
const PrototypeHarvestNodeDefinition := preload("res://tests/content/fixtures/resources/prototype_harvest_node_definition.gd")
const PrototypeDepositDefinition := preload("res://tests/content/fixtures/resources/prototype_deposit_definition.gd")
const PrototypeResourceFormRuleExtension := preload("res://tests/content/fixtures/resources/prototype_resource_form_rule_extension.gd")

const RESOURCE_PATH_A := "res://tests/fixtures/content/path_a/copper_node.tres"
const RESOURCE_PATH_B := "res://tests/fixtures/content/path_b/renamed_copper_node_definition.tres"

const RESOURCE_ROOT := "category.resource"
const RESOURCE_NODE := "category.resource.node"
const RESOURCE_DEPOSIT := "category.resource.deposit"
const ITEM_ROOT := "category.item"
const ITEM_RESOURCE := "category.item.resource"
const WORLD_OBJECT := "category.world_object"
const HARVESTABLE := "capability.harvestable"
const EXCAVATABLE := "capability.excavatable"
const ITEM_COPPER := "item.resource.copper_chunk"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_authored_path_and_presentation_identity(failures)
	_test_small_node_and_large_deposit_composition(failures)
	_test_mutable_depletion_is_separate(failures)
	_test_wrong_resource_definition_type_fails_closed(failures)
	_test_typed_item_yields(failures)
	_test_missing_yield_and_incompatible_rules(failures)
	return failures


static func _test_authored_path_and_presentation_identity(failures: Array[String]) -> void:
	var first = ResourceLoader.load(RESOURCE_PATH_A)
	var moved = ResourceLoader.load(RESOURCE_PATH_B)
	if (
		first == null
		or moved == null
		or not first is PrototypeHarvestNodeDefinition
		or not moved is PrototypeHarvestNodeDefinition
	):
		failures.append("authored resource path fixtures did not load as harvest-node definitions")
		return

	for candidate in [first, moved]:
		candidate.configure_schema_declarations([RESOURCE_NODE], [HARVESTABLE])
		candidate.configure_yield_rules([_yield(candidate.content_id, ITEM_COPPER, 0.5)])
		var result: Dictionary = _pipeline().validate_all(
			[candidate, _item(ITEM_COPPER)],
			_categories(),
			_capabilities(),
			[_resource_validator(), _item_validator()]
		)
		if not bool(result.get("success", false)):
			failures.append(
				"valid authored resource failed CONTENT-005 validation: %s" % [
					result.get("diagnostics", []),
				]
			)

	if first.content_id != "resource.node.copper" or moved.content_id != first.content_id:
		failures.append("physical resource file move changed semantic resource identity")
	if str(first.resource_path) == str(moved.resource_path):
		failures.append("resource path-independence proof did not use two distinct physical paths")
	if first.canonical_descriptor() != moved.canonical_descriptor():
		failures.append("resource canonical definition changed after physical file move")

	var stable_id: String = first.content_id
	first.configure_semantic_references([
		ContentReference.new(
			stable_id,
			"presentation.archetype",
			"archetype.resource.copper_a",
			"archetype",
			true
		),
	])
	first.configure_semantic_references([
		ContentReference.new(
			stable_id,
			"presentation.archetype",
			"archetype.resource.copper_b",
			"archetype",
			true
		),
	])
	if first.content_id != stable_id:
		failures.append("replaceable semantic presentation binding changed resource ContentId")


static func _test_small_node_and_large_deposit_composition(failures: Array[String]) -> void:
	var node = _node("resource.node.iron_outcrop", ITEM_COPPER)
	var deposit = _deposit("resource.deposit.iron_seam", ITEM_COPPER)
	var result: Dictionary = _pipeline().validate_all(
		[node, deposit, _item(ITEM_COPPER)],
		_categories(),
		_capabilities(),
		[_resource_validator(), _item_validator()]
	)
	if not bool(result.get("success", false)):
		failures.append("valid node/deposit composition failed validation: %s" % [result.get("diagnostics", [])])

	var base = ResourceDefinition.new()
	if _has_property(base, "harvest_chunk_units") or _has_property(base, "excavation_step_units"):
		failures.append("small-node/deposit fields leaked into common ResourceDefinition")
	if not _has_property(node, "harvest_chunk_units"):
		failures.append("small harvest-node extension did not own its form-specific field")
	if not _has_property(deposit, "excavation_step_units"):
		failures.append("large deposit extension did not own its excavation field")


static func _test_mutable_depletion_is_separate(failures: Array[String]) -> void:
	var definition = _node("resource.node.depletion_probe", ITEM_COPPER)
	var before: Dictionary = definition.canonical_descriptor().duplicate(true)
	var state = ResourceDepletionState.new()
	state.configure(definition.content_id, definition.capacity_units, {"surface_state": "intact"})
	if not state.validate_state().is_empty():
		failures.append("valid resource depletion state failed its local contract")
	var consumed: float = state.consume_capacity(3.0)
	state.set_delta_value("surface_state", "worked")
	if not is_equal_approx(consumed, 3.0):
		failures.append("resource depletion state did not consume requested available capacity")
	if not is_equal_approx(state.remaining_capacity_units, definition.capacity_units - 3.0):
		failures.append("resource depletion state retained the wrong remaining capacity")
	if definition.canonical_descriptor() != before:
		failures.append("mutating depletion delta changed shared authored ResourceDefinition")
	if str(state.get_delta_value("surface_state", "")) != "worked":
		failures.append("resource mutable delta did not retain depletion-side state")
	if _has_property(definition, "remaining_capacity_units") or _has_property(definition, "mutable_delta"):
		failures.append("mutable depletion fields leaked into authored ResourceDefinition")


static func _test_wrong_resource_definition_type_fails_closed(failures: Array[String]) -> void:
	var wrong_type = ContentDefinition.new()
	wrong_type.configure("resource.invalid.generic_definition", "resource", 1)
	wrong_type.configure_schema_declarations([RESOURCE_NODE], [HARVESTABLE])

	var validator = _resource_validator()
	if not validator.applies_to(wrong_type):
		failures.append("resource validator did not select semantic resource family for wrong subtype")
		return

	var result: Dictionary = _pipeline().validate_all(
		[wrong_type],
		_categories(),
		_capabilities(),
		[validator]
	)
	if not _has_code_fragment(result, "family_rule", "must inherit ResourceDefinition"):
		failures.append("generic ContentDefinition under semantic resource family bypassed the rulebook")


static func _test_typed_item_yields(failures: Array[String]) -> void:
	var node = _node("resource.node.valid_yield_probe", ITEM_COPPER)
	var valid_result: Dictionary = _pipeline().validate_all(
		[node, _item(ITEM_COPPER)],
		_categories(),
		_capabilities(),
		[_resource_validator(), _item_validator()]
	)
	if not bool(valid_result.get("success", false)):
		failures.append("typed resource -> item yield failed CONTENT-005 validation: %s" % [valid_result.get("diagnostics", [])])

	var wrong_item = ContentDefinition.new()
	wrong_item.configure("item.resource.fake_generic", "item", 1)
	wrong_item.configure_schema_declarations([ITEM_RESOURCE], [])
	var wrong_target_node = _node("resource.node.wrong_item_type", "item.resource.fake_generic")
	var wrong_target_result: Dictionary = _pipeline().validate_all(
		[wrong_target_node, wrong_item],
		_categories(),
		_capabilities(),
		[_resource_validator(), _item_validator()]
	)
	if not _has_code_fragment(
		wrong_target_result,
		"family_rule",
		"yield target must inherit accepted ItemDefinition"
	):
		failures.append("resource yield resolved to generic item-family content instead of ItemDefinition")

	var missing_target = _node("resource.node.missing_item", "item.resource.missing")
	var missing_target_result: Dictionary = _pipeline().validate_all(
		[missing_target],
		_categories(),
		_capabilities(),
		[_resource_validator()]
	)
	if not _has_code_fragment(missing_target_result, "reference_resolution", "missing content definition"):
		failures.append("missing typed resource yield target did not fail through CONTENT-005")


static func _test_missing_yield_and_incompatible_rules(failures: Array[String]) -> void:
	var missing_yield = PrototypeHarvestNodeDefinition.new()
	missing_yield.configure_node("resource.node.missing_yield", 10.0, 1.0, 1)
	missing_yield.configure_schema_declarations([RESOURCE_NODE], [HARVESTABLE])
	var missing_result: Dictionary = _pipeline().validate_all(
		[missing_yield],
		_categories(),
		_capabilities(),
		[_resource_validator()]
	)
	if not _has_code_fragment(missing_result, "definition_invalid", "at least one typed item yield"):
		failures.append("resource definition without a yield bypassed authored validation")

	var incompatible = PrototypeHarvestNodeDefinition.new()
	incompatible.configure_node("resource.node.incompatible_capability", 10.0, 1.0, 1)
	incompatible.configure_schema_declarations([RESOURCE_NODE], [EXCAVATABLE])
	incompatible.configure_yield_rules([_yield(incompatible.content_id, ITEM_COPPER, 1.0)])
	var incompatible_result: Dictionary = _pipeline().validate_all(
		[incompatible, _item(ITEM_COPPER)],
		_categories(),
		_capabilities(),
		[_resource_validator(), _item_validator()]
	)
	if not _has_code_fragment(incompatible_result, "family_rule", "node category requires capability"):
		failures.append("resource node missing harvest capability did not fail family rules")
	if not _has_code_fragment(incompatible_result, "family_rule", "node category forbids capability"):
		failures.append("resource node accepted incompatible excavation capability")

	var wrong_family_yield = _yield("resource.node.wrong_yield_family", ITEM_COPPER, 1.0)
	wrong_family_yield.item_reference.expected_family = "effect"
	var wrong_yield_node = PrototypeHarvestNodeDefinition.new()
	wrong_yield_node.configure_node("resource.node.wrong_yield_family", 10.0, 1.0, 1)
	wrong_yield_node.configure_schema_declarations([RESOURCE_NODE], [HARVESTABLE])
	wrong_yield_node.configure_yield_rules([wrong_family_yield])
	var wrong_yield_result: Dictionary = _pipeline().validate_all(
		[wrong_yield_node, _item(ITEM_COPPER)],
		_categories(),
		_capabilities(),
		[_resource_validator(), _item_validator()]
	)
	if not _has_code_fragment(wrong_yield_result, "definition_invalid", "must expect item family"):
		failures.append("resource yield with incompatible semantic target family did not fail")

	var foreign_category = _node("resource.node.foreign_category", ITEM_COPPER)
	foreign_category.configure_schema_declarations([WORLD_OBJECT], [HARVESTABLE])
	var foreign_result: Dictionary = _pipeline().validate_all(
		[foreign_category, _item(ITEM_COPPER)],
		_categories(),
		_capabilities(),
		[_resource_validator(), _item_validator()]
	)
	if not _has_code_fragment(foreign_result, "family_rule", "declares category outside"):
		failures.append("resource family validator accepted a category outside category.resource")


static func _node(content_id: String, item_id: String):
	var definition = PrototypeHarvestNodeDefinition.new()
	definition.configure_node(content_id, 12.0, 2.0, 1)
	definition.configure_schema_declarations([RESOURCE_NODE], [HARVESTABLE])
	definition.configure_yield_rules([_yield(content_id, item_id, 0.5)])
	return definition


static func _deposit(content_id: String, item_id: String):
	var definition = PrototypeDepositDefinition.new()
	definition.configure_deposit(content_id, 120.0, 4.0, 1)
	definition.configure_schema_declarations([RESOURCE_DEPOSIT], [EXCAVATABLE])
	definition.configure_yield_rules([_yield(content_id, item_id, 0.75)])
	return definition


static func _yield(source_id: String, item_id: String, quantity: float):
	return ResourceYieldRule.new().configure(source_id, "yield.primary", item_id, quantity)


static func _item(content_id: String):
	var definition = ItemDefinition.new()
	definition.configure_item(content_id, 64, 0.1, 1)
	definition.configure_schema_declarations([ITEM_RESOURCE], [])
	return definition


static func _resource_validator():
	var extension = PrototypeResourceFormRuleExtension.new()
	extension.configure("resource_form")
	var validator = ResourceFamilyValidator.new()
	validator.configure_resource_rules([extension])
	return validator


static func _item_validator():
	var validator = ItemFamilyValidator.new()
	validator.configure_item_rules([])
	return validator


static func _pipeline():
	return ContentValidationPipeline.new()


static func _categories():
	var registry = CategorySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CategorySchema.new().configure(RESOURCE_ROOT),
		CategorySchema.new().configure(RESOURCE_NODE, [RESOURCE_ROOT]),
		CategorySchema.new().configure(RESOURCE_DEPOSIT, [RESOURCE_ROOT]),
		CategorySchema.new().configure(ITEM_ROOT),
		CategorySchema.new().configure(ITEM_RESOURCE, [ITEM_ROOT]),
		CategorySchema.new().configure(WORLD_OBJECT),
	])
	assert(diagnostics.is_empty())
	return registry


static func _capabilities():
	var registry = CapabilitySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CapabilitySchema.new().configure(HARVESTABLE),
		CapabilitySchema.new().configure(EXCAVATABLE),
	])
	assert(diagnostics.is_empty())
	return registry


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
