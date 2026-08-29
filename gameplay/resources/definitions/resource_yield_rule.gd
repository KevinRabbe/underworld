extends RefCounted

const ContentReference := preload("res://core/content/references/content_reference.gd")

const ITEM_FAMILY := "item"
const YIELD_ROLE_PREFIX := "yield."

var item_reference = null
var quantity_per_capacity_unit: float = 1.0


func configure(
	p_source_resource_id: String,
	p_role: String,
	p_item_content_id: String,
	p_quantity_per_capacity_unit: float = 1.0
) -> RefCounted:
	item_reference = ContentReference.new(
		p_source_resource_id,
		p_role,
		p_item_content_id,
		ITEM_FAMILY,
		true
	)
	quantity_per_capacity_unit = p_quantity_per_capacity_unit
	return self


func validate_rule() -> Array[String]:
	var failures: Array[String] = []
	if item_reference == null or not item_reference is ContentReference:
		failures.append("resource yield must contain a ContentReference")
	else:
		for failure in item_reference.validate_reference():
			failures.append("yield reference: %s" % failure)
		if not str(item_reference.role).begins_with(YIELD_ROLE_PREFIX):
			failures.append(
				"resource yield role must begin with '%s': %s" % [
					YIELD_ROLE_PREFIX,
					item_reference.role,
				]
			)
		if str(item_reference.expected_family) != ITEM_FAMILY:
			failures.append(
				"resource yield must expect item family '%s': %s" % [
					ITEM_FAMILY,
					item_reference.expected_family,
				]
			)
	if quantity_per_capacity_unit <= 0.0:
		failures.append("resource yield quantity per capacity unit must be > 0")
	failures.sort()
	return failures


func validation_reference():
	return item_reference


func canonical_descriptor() -> Dictionary:
	if item_reference == null or not item_reference is ContentReference:
		return {
			"reference": "<invalid-reference>",
			"quantity_per_capacity_unit": quantity_per_capacity_unit,
		}
	return {
		"source_id": str(item_reference.source_id),
		"role": str(item_reference.role),
		"target_id": str(item_reference.target_id),
		"expected_family": str(item_reference.expected_family),
		"required": bool(item_reference.required),
		"quantity_per_capacity_unit": quantity_per_capacity_unit,
	}
