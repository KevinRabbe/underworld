extends "res://gameplay/resources/validation/resource_family_validator_base.gd"

const ResourceNodeDefinition := preload("res://gameplay/resources/definitions/resource_node_definition.gd")

const DEFINITION_FAMILY := "resource_node"
const NODE_CATEGORY := "category.world_resource.node"
const REQUIRED_CAPABILITIES := ["capability.harvestable", "capability.depletable"]


func configure_node_rules() -> RefCounted:
	return configure_resource_rules(DEFINITION_FAMILY, NODE_CATEGORY, REQUIRED_CAPABILITIES)


func validate_validator() -> Array[String]:
	var failures: Array[String] = super.validate_validator()
	if definition_family != DEFINITION_FAMILY:
		failures.append("resource node validator must target '%s'" % DEFINITION_FAMILY)
	failures.sort()
	return failures


func validate_definition(definition, context: Dictionary) -> Array[String]:
	var failures: Array[String] = super.validate_definition(definition, context)
	if definition != null and not definition is ResourceNodeDefinition:
		failures.append("resource_node-family definition must inherit ResourceNodeDefinition: %s" % str(definition.content_id))
	failures.sort()
	return failures
