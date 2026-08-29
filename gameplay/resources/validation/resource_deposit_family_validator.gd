extends "res://gameplay/resources/validation/resource_family_validator_base.gd"

const ResourceDepositDefinition := preload("res://gameplay/resources/definitions/resource_deposit_definition.gd")

const DEFINITION_FAMILY := "resource_deposit"
const DEPOSIT_CATEGORY := "category.world_resource.deposit"
const REQUIRED_CAPABILITIES := ["capability.excavatable", "capability.depletable"]


func configure_deposit_rules() -> RefCounted:
	return configure_resource_rules(DEFINITION_FAMILY, DEPOSIT_CATEGORY, REQUIRED_CAPABILITIES)


func validate_validator() -> Array[String]:
	var failures: Array[String] = super.validate_validator()
	if definition_family != DEFINITION_FAMILY:
		failures.append("resource deposit validator must target '%s'" % DEFINITION_FAMILY)
	failures.sort()
	return failures


func validate_definition(definition, context: Dictionary) -> Array[String]:
	var failures: Array[String] = super.validate_definition(definition, context)
	if definition != null and not definition is ResourceDepositDefinition:
		failures.append("resource_deposit-family definition must inherit ResourceDepositDefinition: %s" % str(definition.content_id))
	failures.sort()
	return failures
