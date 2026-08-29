extends "res://gameplay/resources/validation/resource_rule_extension.gd"

const PrototypeHarvestNodeDefinition := preload("res://tests/content/fixtures/resources/prototype_harvest_node_definition.gd")
const PrototypeDepositDefinition := preload("res://tests/content/fixtures/resources/prototype_deposit_definition.gd")

const NODE_CATEGORY := "category.resource.node"
const DEPOSIT_CATEGORY := "category.resource.deposit"
const HARVESTABLE_CAPABILITY := "capability.harvestable"
const EXCAVATABLE_CAPABILITY := "capability.excavatable"


func applies_to(definition, _context: Dictionary) -> bool:
	return definition != null and str(definition.definition_family) == "resource"


func validate_definition(definition, _context: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var is_node: bool = definition.category_ids.has(NODE_CATEGORY)
	var is_deposit: bool = definition.category_ids.has(DEPOSIT_CATEGORY)

	if is_node == is_deposit:
		failures.append(
			"resource form must declare exactly one of %s or %s" % [
				NODE_CATEGORY,
				DEPOSIT_CATEGORY,
			]
		)
		return failures

	if is_node:
		if not definition is PrototypeHarvestNodeDefinition:
			failures.append("node category requires harvest-node definition extension")
		if not definition.capability_ids.has(HARVESTABLE_CAPABILITY):
			failures.append("node category requires capability: %s" % HARVESTABLE_CAPABILITY)
		if definition.capability_ids.has(EXCAVATABLE_CAPABILITY):
			failures.append("node category forbids capability: %s" % EXCAVATABLE_CAPABILITY)

	if is_deposit:
		if not definition is PrototypeDepositDefinition:
			failures.append("deposit category requires deposit definition extension")
		if not definition.capability_ids.has(EXCAVATABLE_CAPABILITY):
			failures.append("deposit category requires capability: %s" % EXCAVATABLE_CAPABILITY)
		if definition.capability_ids.has(HARVESTABLE_CAPABILITY):
			failures.append("deposit category forbids capability: %s" % HARVESTABLE_CAPABILITY)

	failures.sort()
	return failures
