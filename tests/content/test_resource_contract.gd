extends RefCounted

const ContentDefinition := preload("res://core/content/registry/content_definition.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemFamilyValidator := preload("res://gameplay/items/validation/item_family_validator.gd")
const ResourceDefinition := preload("res://gameplay/resources/definitions/resource_definition.gd")
const ResourceYieldEntry := preload("res://gameplay/resources/definitions/resource_yield_entry.gd")
const ResourceNodeDefinition := preload("res://gameplay/resources/definitions/resource_node_definition.gd")
const ResourceDepositDefinition := preload("res://gameplay/resources/definitions/resource_deposit_definition.gd")
const ResourceDepletionState := preload("res://gameplay/resources/state/resource_depletion_state.gd")
const ResourceNodeFamilyValidator := preload("res://gameplay/resources/validation/resource_node_family_validator.gd")
const ResourceDepositFamilyValidator := preload("res://gameplay/resources/validation/resource_deposit_family_validator.gd")

const PATH_A := "res://tests/fixtures/content/resource_path_a/iron_node.tres"
const PATH_B := "res://tests/fixtures/content/resource_path_b/renamed_iron_definition.tres"
const RESOURCE_ROOT := "category.world_resource"
const RESOURCE_NODE := "category.world_resource.node"
const RESOURCE_DEPOSIT := "category.world_resource.deposit"
const ITEM_ROOT := "category.item"
const ITEM_RESOURCE := "category.item.resource"
const WORLD_OBJECT := "category.world_object"
const HARVESTABLE := "capability.harvestable"
const EXCAVATABLE := "capability.excavatable"
const DEPLETABLE := "capability.depletable"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_node_and_deposit_composition(failures)
	_test_typed_item_yields(failures)
	_test_family_validators_fail_closed(failures)
	_test_category_capability_contracts(failures)
	_test_mutable_depletion_state_is_separate(failures)
	_test_semantic_identity_survives_path_and_presentation_changes(failures)
	return failures


static func _test_node_and_deposit_composition(failures: Array[String]) -> void:
	var iron = _item("item.resource.iron")
	var stone = _item("item.resource.stone")
	var archetype = _plain_definition("archetype.resource.iron", "archetype")

	var node = ResourceNodeDefinition.new()
	node.configure_node("resource_node.iron.small", 12.0, 1.0, 1.4, 1)
	node.configure_schema_declarations([RESOURCE_NODE], [HARVESTABLE, DEPLETABLE])
	node.configure_yields([_yield("item.resource.iron", 1.0, 1, 2)])
	node.configure_presentation(archetype.content_id)

	var deposit = ResourceDepositDefinition.new()
	deposit.configure_deposit("resource_deposit.iron.large", 500.0, 22.0, 0.25, 1)
	deposit.configure_schema_declarations([RESOURCE_DEPOSIT], [EXCAVATABLE, DEPLETABLE])
	deposit.configure_yields([
		_yield("item.resource.iron", 0.85, 1, 4),
		_yield("item.resource.stone", 0.15, 0, 2),
	])
	deposit.configure_presentation(archetype.content_id)

	var result: Dictionary = _validate([node, deposit, iron, stone, archetype])
	if not bool(result.get("success", false)):
		failures.append("valid resource node/deposit definitions failed CONTENT-005: %s" % [result.get("diagnostics", [])])
	if not node is ResourceDefinition or not deposit is ResourceDefinition:
		failures.append("node/deposit definitions do not share ResourceDefinition base")
	if _has_property(ResourceDefinition.new(), "harvest_capacity_cost"):
		failures.append("small-node harvest field leaked into common ResourceDefinition")
	if _has_property(ResourceDefinition.new(), "capacity_units_per_cubic_meter"):
		failures.append("large-deposit volumetric field leaked into common ResourceDefinition")
	if not _has_property(node, "harvest_capacity_cost"):
		failures.append("resource node subtype does not own harvest interaction contract")
	if not _has_property(deposit, "capacity_units_per_cubic_meter"):
		failures.append("resource deposit subtype does not own volumetric excavation contract")


static func _test_typed_item_yields(failures: Array[String]) -> void:
	var node = _valid_node("resource_node.iron.typed_yield", "item.resource.iron")
	var iron = _item("item.resource.iron")
	var valid: Dictionary = _validate([node, iron])
	if not bool(valid.get("success", false)):
		failures.append("typed resource yield to ItemDefinition failed validation: %s" % [valid.get("diagnostics", [])])

	var missing = _valid_node("resource_node.iron.missing_yield", "item.resource.missing")
	var missing_result: Dictionary = _validate([missing])
	if not _has_code_fragment(missing_result, "reference_resolution", "missing content definition"):
		failures.append("missing required item yield did not fail through CONTENT-005 reference resolution")

	var wrong_family = ResourceNodeDefinition.new()
	wrong_family.configure_node("resource_node.iron.wrong_yield_family", 5.0, 1.0, 1.0, 1)
	wrong_family.configure_schema_declarations([RESOURCE_NODE], [HARVESTABLE, DEPLETABLE])
	wrong_family.configure_yields([_yield("effect.resource.fake", 1.0, 1, 1)])
	var wrong_family_result: Dictionary = _validate([
		wrong_family,
		_plain_definition("effect.resource.fake", "effect"),
	])
	if not _has_code_fragment(wrong_family_result, "definition_invalid", "must reference an item.* definition"):
		failures.append("non-item semantic yield target was accepted by resource definition")

	var spoofed_item = ContentDefinition.new()
	spoofed_item.configure("item.resource.spoofed", "item", 1)
	spoofed_item.configure_schema_declarations([ITEM_RESOURCE], [])
	var spoofed_node = _valid_node("resource_node.iron.spoofed_item", "item.resource.spoofed")
	var spoofed_result: Dictionary = _validate([spoofed_node, spoofed_item])
	if not _has_code_fragment(spoofed_result, "family_rule", "yield target must inherit ItemDefinition"):
		failures.append("generic item-family ContentDefinition spoofed an accepted resource yield target")


static func _test_family_validators_fail_closed(failures: Array[String]) -> void:
	var generic_node = ContentDefinition.new()
	generic_node.configure("resource_node.invalid.generic", "resource_node", 1)
	generic_node.configure_schema_declarations([RESOURCE_NODE], [HARVESTABLE, DEPLETABLE])
	var generic_result: Dictionary = _validate([generic_node])
	if not _has_code_fragment(generic_result, "family_rule", "must inherit ResourceNodeDefinition"):
		failures.append("generic ContentDefinition under resource_node family bypassed subtype rulebook")

	var base_deposit = ResourceDefinition.new()
	base_deposit.configure_resource("resource_deposit.invalid.base", "resource_deposit", 10.0, 1)
	base_deposit.configure_schema_declarations([RESOURCE_DEPOSIT], [EXCAVATABLE, DEPLETABLE])
	base_deposit.configure_yields([_yield("item.resource.iron", 1.0, 1, 1)])
	var base_deposit_result: Dictionary = _validate([base_deposit, _item("item.resource.iron")])
	if not _has_code_fragment(base_deposit_result, "family_rule", "must inherit ResourceDepositDefinition"):
		failures.append("common ResourceDefinition spoofed concrete resource_deposit family")


static func _test_category_capability_contracts(failures: Array[String]) -> void:
	var wrong_category = ResourceNodeDefinition.new()
	wrong_category.configure_node("resource_node.invalid.deposit_category", 5.0, 1.0, 1.0, 1)
	wrong_category.configure_schema_declarations([RESOURCE_DEPOSIT], [HARVESTABLE, DEPLETABLE])
	wrong_category.configure_yields([_yield("item.resource.iron", 1.0, 1, 1)])
	var wrong_category_result: Dictionary = _validate([wrong_category, _item("item.resource.iron")])
	if not _has_code_fragment(wrong_category_result, "family_rule", "must declare category under"):
		failures.append("resource node accepted deposit-only category declaration")

	var missing_capability = ResourceDepositDefinition.new()
	missing_capability.configure_deposit("resource_deposit.invalid.missing_capability", 20.0, 5.0, 0.1, 1)
	missing_capability.configure_schema_declarations([RESOURCE_DEPOSIT], [DEPLETABLE])
	missing_capability.configure_yields([_yield("item.resource.iron", 1.0, 1, 1)])
	var missing_capability_result: Dictionary = _validate([missing_capability, _item("item.resource.iron")])
	if not _has_code_fragment(missing_capability_result, "family_rule", "requires capability: capability.excavatable"):
		failures.append("resource deposit without excavatable capability passed family validation")

	var foreign_category = ResourceNodeDefinition.new()
	foreign_category.configure_node("resource_node.invalid.foreign_category", 5.0, 1.0, 1.0, 1)
	foreign_category.configure_schema_declarations([WORLD_OBJECT], [HARVESTABLE, DEPLETABLE])
	foreign_category.configure_yields([_yield("item.resource.iron", 1.0, 1, 1)])
	var foreign_result: Dictionary = _validate([foreign_category, _item("item.resource.iron")])
	if not _has_code_fragment(foreign_result, "family_rule", "declares category outside"):
		failures.append("resource family validator accepted a category outside category.world_resource")

	var missing_yields = ResourceNodeDefinition.new()
	missing_yields.configure_node("resource_node.invalid.no_yield", 5.0, 1.0, 1.0, 1)
	missing_yields.configure_schema_declarations([RESOURCE_NODE], [HARVESTABLE, DEPLETABLE])
	var missing_yields_result: Dictionary = _validate([missing_yields])
	if not _has_code_fragment(missing_yields_result, "definition_invalid", "at least one item yield"):
		failures.append("resource definition without any yield passed base definition validation")


static func _test_mutable_depletion_state_is_separate(failures: Array[String]) -> void:
	var node = _valid_node("resource_node.iron.state_probe", "item.resource.iron")
	var before: Dictionary = node.canonical_descriptor().duplicate(true)
	var state = ResourceDepletionState.new()
	state.configure(node.content_id, node.capacity_units, {"last_tool_class": "pick"})
	if not state.validate_state().is_empty():
		failures.append("valid resource depletion state failed its local contract")
	var consumed: float = state.apply_depletion(3.5)
	if not is_equal_approx(consumed, 3.5) or not is_equal_approx(state.remaining_capacity_units, 8.5):
		failures.append("resource depletion state did not consume/clamp mutable capacity correctly")
	state.set_value("last_tool_class", "drill")
	if node.canonical_descriptor() != before:
		failures.append("mutating depletion state changed shared authored ResourceDefinition")
	if str(state.get_value("last_tool_class", "")) != "drill":
		failures.append("resource depletion mutable-state boundary did not retain delta data")
	if _has_property(state, "placement_id") or _has_property(state, "stable_id") or _has_property(state, "world_position"):
		failures.append("RESOURCE-001 depletion state prematurely owns generated placement identity/location")
	state.apply_depletion(1000.0)
	if not state.is_depleted() or not is_zero_approx(state.remaining_capacity_units):
		failures.append("resource depletion state did not clamp at zero capacity")


static func _test_semantic_identity_survives_path_and_presentation_changes(failures: Array[String]) -> void:
	var first = ResourceLoader.load(PATH_A)
	var moved = ResourceLoader.load(PATH_B)
	if first == null or moved == null or not first is ResourceNodeDefinition or not moved is ResourceNodeDefinition:
		failures.append("authored resource path fixtures did not load as ResourceNodeDefinition")
		return
	for candidate in [first, moved]:
		candidate.configure_schema_declarations([RESOURCE_NODE], [HARVESTABLE, DEPLETABLE])
		candidate.configure_yields([_yield("item.resource.iron", 1.0, 1, 2)])
	var item = _item("item.resource.iron")
	for candidate in [first, moved]:
		var result: Dictionary = _validate([candidate, item])
		if not bool(result.get("success", false)):
			failures.append("valid authored resource path fixture failed validation: %s" % [result.get("diagnostics", [])])
	if first.content_id != "resource_node.iron.prototype" or moved.content_id != first.content_id:
		failures.append("physical resource file move changed semantic resource identity")
	if str(first.resource_path) == str(moved.resource_path):
		failures.append("resource path-independence proof did not use distinct physical paths")
	if first.canonical_descriptor() != moved.canonical_descriptor():
		failures.append("resource canonical authored data changed after physical file move")

	var identity_before: String = first.content_id
	first.configure_presentation("archetype.resource.iron_a", "archetype")
	first.configure_presentation("archetype.resource.iron_b", "archetype")
	if first.content_id != identity_before:
		failures.append("changing replaceable resource presentation changed semantic ContentId")


static func _validate(definitions: Array) -> Dictionary:
	var node_validator = ResourceNodeFamilyValidator.new()
	node_validator.configure_node_rules()
	var deposit_validator = ResourceDepositFamilyValidator.new()
	deposit_validator.configure_deposit_rules()
	var item_validator = ItemFamilyValidator.new()
	item_validator.configure_item_rules([])
	return ContentValidationPipeline.new().validate_all(
		definitions,
		_categories(),
		_capabilities(),
		[node_validator, deposit_validator, item_validator]
	)


static func _valid_node(content_id: String, item_content_id: String):
	var node = ResourceNodeDefinition.new()
	node.configure_node(content_id, 12.0, 1.0, 1.4, 1)
	node.configure_schema_declarations([RESOURCE_NODE], [HARVESTABLE, DEPLETABLE])
	node.configure_yields([_yield(item_content_id, 1.0, 1, 2)])
	return node


static func _yield(
	item_content_id: String,
	ratio: float,
	minimum_quantity: int,
	maximum_quantity: int
):
	return ResourceYieldEntry.new().configure(
		item_content_id,
		ratio,
		minimum_quantity,
		maximum_quantity
	)


static func _item(content_id: String):
	var item = ItemDefinition.new()
	item.configure_item(content_id, 64, 1.0, 1)
	item.configure_schema_declarations([ITEM_RESOURCE], [])
	return item


static func _plain_definition(content_id: String, family: String):
	var definition = ContentDefinition.new()
	definition.configure(content_id, family, 1)
	return definition


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
		CapabilitySchema.new().configure(DEPLETABLE),
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
