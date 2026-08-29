extends "res://gameplay/resources/definitions/resource_definition.gd"

@export var harvest_chunk_units: float = 1.0


func configure_node(
	p_content_id: String,
	p_capacity_units: float,
	p_harvest_chunk_units: float,
	p_schema_revision: int = 1
) -> Resource:
	configure_resource(p_content_id, p_capacity_units, p_schema_revision)
	harvest_chunk_units = p_harvest_chunk_units
	return self


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if harvest_chunk_units <= 0.0:
		failures.append("harvest node chunk units must be > 0 for %s" % content_id)
	if harvest_chunk_units > capacity_units:
		failures.append("harvest node chunk units cannot exceed authored capacity for %s" % content_id)
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["harvest_chunk_units"] = harvest_chunk_units
	return descriptor
