extends "res://gameplay/items/definitions/item_definition.gd"

@export var harvest_power: float = 1.0


func configure_tool(
	p_content_id: String,
	p_harvest_power: float = 1.0,
	p_schema_revision: int = 1
) -> Resource:
	configure_item(p_content_id, 1, 2.0, p_schema_revision)
	configure_schema_declarations(
		["category.item.equipment.tool"],
		["capability.harvest_tool"]
	)
	harvest_power = p_harvest_power
	return self


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if harvest_power <= 0.0:
		failures.append("prototype tool harvest power must be > 0 for %s" % content_id)
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["harvest_power"] = harvest_power
	return descriptor
