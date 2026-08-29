extends Resource

const ContentId := preload("res://core/content/identity/content_id.gd")
const ContentReference := preload("res://core/content/references/content_reference.gd")

@export var item_content_id: String = ""
@export var quantity_per_capacity_unit: float = 1.0
@export var minimum_event_quantity: int = 1
@export var maximum_event_quantity: int = 1


func configure(
	p_item_content_id: String,
	p_quantity_per_capacity_unit: float = 1.0,
	p_minimum_event_quantity: int = 1,
	p_maximum_event_quantity: int = 1
) -> Resource:
	item_content_id = p_item_content_id
	quantity_per_capacity_unit = p_quantity_per_capacity_unit
	minimum_event_quantity = p_minimum_event_quantity
	maximum_event_quantity = p_maximum_event_quantity
	return self


func validate_yield() -> Array[String]:
	var failures: Array[String] = []
	for failure in ContentId.validate(item_content_id):
		failures.append("yield item id: %s" % failure)
	if ContentId.is_valid(item_content_id) and ContentId.family_of(item_content_id) != "item":
		failures.append("resource yield must reference an item.* definition: %s" % item_content_id)
	if quantity_per_capacity_unit <= 0.0:
		failures.append("yield quantity_per_capacity_unit must be > 0 for %s" % item_content_id)
	if minimum_event_quantity < 0:
		failures.append("yield minimum_event_quantity must be >= 0 for %s" % item_content_id)
	if maximum_event_quantity < minimum_event_quantity:
		failures.append("yield maximum_event_quantity must be >= minimum_event_quantity for %s" % item_content_id)
	failures.sort()
	return failures


func content_reference(owner_content_id: String, index: int):
	return ContentReference.new(
		owner_content_id,
		"yield.item.%03d" % index,
		item_content_id,
		"item",
		true
	)


func canonical_descriptor() -> Dictionary:
	return {
		"item_content_id": item_content_id,
		"quantity_per_capacity_unit": quantity_per_capacity_unit,
		"minimum_event_quantity": minimum_event_quantity,
		"maximum_event_quantity": maximum_event_quantity,
	}
