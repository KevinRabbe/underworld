extends RefCounted

const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const InventoryStateCodec := preload("res://gameplay/items/inventory/inventory_state_codec.gd")

var item_content_id: String = ""
var quantity: int = 0
var stack_state: Dictionary = {}


func configure(definition, p_quantity: int, p_stack_state: Dictionary = {}) -> RefCounted:
	item_content_id = str(definition.content_id) if definition != null else ""
	quantity = p_quantity
	stack_state = p_stack_state.duplicate(true)
	return self


func validate_against(definition) -> Array[String]:
	var failures: Array[String] = []
	if definition == null or not definition is ItemDefinition:
		return ["ItemStackState requires an ItemDefinition"]
	if str(definition.content_id) != item_content_id:
		failures.append(
			"stack item id does not match definition: %s != %s" % [item_content_id, definition.content_id]
		)
	if definition.stack_limit <= 1:
		failures.append("non-stackable item must use ItemInstanceState: %s" % item_content_id)
	if quantity < 1:
		failures.append("stack quantity must be >= 1 for %s" % item_content_id)
	elif quantity > definition.stack_limit:
		failures.append(
			"stack quantity exceeds authored stack limit for %s: %d > %d" % [
				item_content_id,
				quantity,
				definition.stack_limit,
			]
		)
	for failure in InventoryStateCodec.validate_state(stack_state, "stack_state"):
		failures.append(failure)
	failures.sort()
	return failures


func compatibility_key() -> String:
	return "%s|%s" % [item_content_id, InventoryStateCodec.canonical_json(stack_state)]


func is_compatible_with(other) -> bool:
	if other == null or other.get_script() != get_script():
		return false
	return compatibility_key() == other.compatibility_key()


func snapshot() -> Dictionary:
	return {
		"item_id": item_content_id,
		"quantity": quantity,
		"stack_state": InventoryStateCodec.canonicalize(stack_state),
	}
