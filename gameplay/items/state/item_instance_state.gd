extends RefCounted

const ContentId := preload("res://core/content/identity/content_id.gd")

var item_content_id: String = ""
var mutable_state: Dictionary = {}


func configure(
	p_item_content_id: String,
	p_mutable_state: Dictionary = {}
) -> RefCounted:
	item_content_id = p_item_content_id
	mutable_state = p_mutable_state.duplicate(true)
	return self


func validate_state() -> Array[String]:
	var failures: Array[String] = []
	for failure in ContentId.validate(item_content_id):
		failures.append("item content id: %s" % failure)
	if ContentId.is_valid(item_content_id) and ContentId.family_of(item_content_id) != "item":
		failures.append("instance state must reference an item.* definition: %s" % item_content_id)
	failures.sort()
	return failures


func set_value(key: String, value: Variant) -> void:
	mutable_state[key] = value


func get_value(key: String, default_value: Variant = null) -> Variant:
	return mutable_state.get(key, default_value)


func canonical_descriptor() -> Dictionary:
	return {
		"item_content_id": item_content_id,
		"mutable_state": mutable_state.duplicate(true),
	}
