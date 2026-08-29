extends "res://gameplay/resources/definitions/resource_definition.gd"

const DEFINITION_FAMILY := "resource_node"

@export var harvest_capacity_cost: float = 1.0
@export var interaction_radius: float = 1.5


func configure_node(
	p_content_id: String,
	p_capacity_units: float = 1.0,
	p_harvest_capacity_cost: float = 1.0,
	p_interaction_radius: float = 1.5,
	p_schema_revision: int = 1
) -> Resource:
	configure_resource(p_content_id, DEFINITION_FAMILY, p_capacity_units, p_schema_revision)
	harvest_capacity_cost = p_harvest_capacity_cost
	interaction_radius = p_interaction_radius
	return self


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if definition_family != DEFINITION_FAMILY:
		failures.append("resource node definition family must be '%s': %s" % [DEFINITION_FAMILY, definition_family])
	if harvest_capacity_cost <= 0.0:
		failures.append("resource node harvest_capacity_cost must be > 0 for %s" % content_id)
	if interaction_radius <= 0.0:
		failures.append("resource node interaction_radius must be > 0 for %s" % content_id)
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["harvest_capacity_cost"] = harvest_capacity_cost
	descriptor["interaction_radius"] = interaction_radius
	return descriptor
