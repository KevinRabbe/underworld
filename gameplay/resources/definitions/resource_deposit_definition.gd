extends "res://gameplay/resources/definitions/resource_definition.gd"

const DEFINITION_FAMILY := "resource_deposit"

@export var capacity_units_per_cubic_meter: float = 1.0
@export var minimum_excavation_volume: float = 0.1


func configure_deposit(
	p_content_id: String,
	p_capacity_units: float = 1.0,
	p_capacity_units_per_cubic_meter: float = 1.0,
	p_minimum_excavation_volume: float = 0.1,
	p_schema_revision: int = 1
) -> Resource:
	configure_resource(p_content_id, DEFINITION_FAMILY, p_capacity_units, p_schema_revision)
	capacity_units_per_cubic_meter = p_capacity_units_per_cubic_meter
	minimum_excavation_volume = p_minimum_excavation_volume
	return self


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if definition_family != DEFINITION_FAMILY:
		failures.append("resource deposit definition family must be '%s': %s" % [DEFINITION_FAMILY, definition_family])
	if capacity_units_per_cubic_meter <= 0.0:
		failures.append("resource deposit capacity_units_per_cubic_meter must be > 0 for %s" % content_id)
	if minimum_excavation_volume <= 0.0:
		failures.append("resource deposit minimum_excavation_volume must be > 0 for %s" % content_id)
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["capacity_units_per_cubic_meter"] = capacity_units_per_cubic_meter
	descriptor["minimum_excavation_volume"] = minimum_excavation_volume
	return descriptor
