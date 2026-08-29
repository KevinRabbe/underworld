extends "res://gameplay/resources/definitions/resource_definition.gd"

@export var excavation_step_units: float = 1.0


func configure_deposit(
	p_content_id: String,
	p_capacity_units: float,
	p_excavation_step_units: float,
	p_schema_revision: int = 1
) -> Resource:
	configure_resource(p_content_id, p_capacity_units, p_schema_revision)
	excavation_step_units = p_excavation_step_units
	return self


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if excavation_step_units <= 0.0:
		failures.append("deposit excavation step units must be > 0 for %s" % content_id)
	if excavation_step_units > capacity_units:
		failures.append("deposit excavation step units cannot exceed authored capacity for %s" % content_id)
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["excavation_step_units"] = excavation_step_units
	return descriptor
