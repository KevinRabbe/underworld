extends Resource

const ContentId := preload("res://core/content/identity/content_id.gd")

@export var item_content_id: String = ""
@export var quantity: int = 1


func configure(p_item_content_id: String, p_quantity: int) -> Resource:
	item_content_id = p_item_content_id
	quantity = p_quantity
	return self


func validate_amount(label: String = "recipe item amount") -> Array[String]:
	var failures: Array[String] = []
	for failure in ContentId.validate(item_content_id):
		failures.append("%s item id: %s" % [label, failure])
	if ContentId.is_valid(item_content_id) and ContentId.family_of(item_content_id) != "item":
		failures.append("%s must reference item.* content: %s" % [label, item_content_id])
	if quantity <= 0:
		failures.append("%s quantity must be > 0 for %s" % [label, item_content_id])
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	return {
		"item_id": item_content_id,
		"quantity": quantity,
	}
