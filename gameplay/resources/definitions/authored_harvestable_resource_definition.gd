extends "res://gameplay/resources/definitions/resource_definition.gd"

const ContentReference := preload("res://core/content/references/content_reference.gd")
const ResourceYieldRule := preload("res://gameplay/resources/definitions/resource_yield_rule.gd")

const PRIMARY_YIELD_ROLE := "yield.primary"
const PRESENTATION_ARCHETYPE_ROLE := "presentation.archetype"

@export var primary_yield_item_id: String = ""
@export var primary_yield_quantity_per_capacity_unit: float = 1.0
@export var presentation_archetype_id: String = ""


func yield_rules() -> Array:
	_refresh_authored_contracts()
	return super.yield_rules()


func validation_references() -> Array:
	_refresh_authored_contracts()
	return super.validation_references()


func validate_definition() -> Array[String]:
	_refresh_authored_contracts()
	var failures: Array[String] = super.validate_definition()
	if presentation_archetype_id.is_empty():
		failures.append("harvestable resource requires presentation archetype id: %s" % content_id)
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	_refresh_authored_contracts()
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["primary_yield_item_id"] = primary_yield_item_id
	descriptor["primary_yield_quantity_per_capacity_unit"] = primary_yield_quantity_per_capacity_unit
	descriptor["presentation_archetype_id"] = presentation_archetype_id
	return descriptor


func _refresh_authored_contracts() -> void:
	var yield_rule = ResourceYieldRule.new()
	yield_rule.configure(
		content_id,
		PRIMARY_YIELD_ROLE,
		primary_yield_item_id,
		primary_yield_quantity_per_capacity_unit
	)
	configure_yield_rules([yield_rule])
	configure_semantic_references([
		ContentReference.new(
			content_id,
			PRESENTATION_ARCHETYPE_ROLE,
			presentation_archetype_id,
			"archetype",
			true
		),
	])
