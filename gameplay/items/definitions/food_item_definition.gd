extends "res://gameplay/items/definitions/item_definition.gd"

@export var food_value: float = 25.0


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if is_nan(food_value) or is_inf(food_value) or food_value <= 0.0:
		failures.append("food item value must be finite and > 0 for %s" % content_id)
	if not capability_ids.has("capability.consumable.food"):
		failures.append("food item must declare capability.consumable.food: %s" % content_id)
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["food_value"] = food_value
	return descriptor
