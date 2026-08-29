extends RefCounted

const ContentId := preload("res://core/content/identity/content_id.gd")

var item_content_id: String = ""
var quantity: int = 1
var compatibility_state: Dictionary = {}


func configure(
	p_item_content_id: String,
	p_quantity: int = 1,
	p_compatibility_state: Dictionary = {}
) -> RefCounted:
	item_content_id = p_item_content_id
	quantity = p_quantity
	compatibility_state = p_compatibility_state.duplicate(true)
	return self


func validate_state() -> Array[String]:
	var failures: Array[String] = []
	for failure in ContentId.validate(item_content_id):
		failures.append("item content id: %s" % failure)
	if ContentId.is_valid(item_content_id) and ContentId.family_of(item_content_id) != "item":
		failures.append("stack state must reference an item.* definition: %s" % item_content_id)
	if quantity < 1:
		failures.append("item stack quantity must be >= 1 for %s" % item_content_id)
	failures.sort()
	return failures


func is_compatible_with(other) -> bool:
	return (
		other != null
		and other is get_script()
		and item_content_id == str(other.item_content_id)
		and compatibility_state == other.compatibility_state
	)


func canonical_descriptor() -> Dictionary:
	return {
		"item_content_id": item_content_id,
		"quantity": quantity,
		"compatibility_state": compatibility_state.duplicate(true),
	}
