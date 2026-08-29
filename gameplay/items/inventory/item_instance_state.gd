extends RefCounted

const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const InventoryStateCodec := preload("res://gameplay/items/inventory/inventory_state_codec.gd")

var item_content_id: String = ""
var per_copy_state: Dictionary = {}


func configure(definition, p_per_copy_state: Dictionary = {}) -> RefCounted:
	item_content_id = str(definition.content_id) if definition != null else ""
	per_copy_state = p_per_copy_state.duplicate(true)
	return self


func validate_against(definition) -> Array[String]:
	var failures: Array[String] = []
	if definition == null or not definition is ItemDefinition:
		return ["ItemInstanceState requires an ItemDefinition"]
	if str(definition.content_id) != item_content_id:
		failures.append(
			"instance item id does not match definition: %s != %s" % [item_content_id, definition.content_id]
		)
	if definition.stack_limit != 1:
		failures.append("stackable item must use ItemStackState: %s" % item_content_id)
	for failure in InventoryStateCodec.validate_state(per_copy_state, "per_copy_state"):
		failures.append(failure)
	failures.sort()
	return failures


func snapshot() -> Dictionary:
	return {
		"item_id": item_content_id,
		"per_copy_state": InventoryStateCodec.canonicalize(per_copy_state),
	}
