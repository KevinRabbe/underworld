extends RefCounted

const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const InventoryTransactionPlan := preload("res://gameplay/items/inventory/inventory_transaction_plan.gd")
const InventoryTransactionPreflight := preload("res://gameplay/items/inventory/transactions/inventory_transaction_preflight.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_successful_projection_does_not_mutate_live_container(failures)
	_test_failed_projection_does_not_mutate_live_container(failures)
	return failures


static func _test_successful_projection_does_not_mutate_live_container(failures: Array[String]) -> void:
	var wood = _item("item.resource.tx_preflight_wood", 16, 0.25)
	var tool = _item("item.tool.tx_preflight_tool", 1, 1.0)
	var inventory = ItemContainerState.new().configure(2, 10.0)
	inventory.add_stack(wood, 3, {"grade": "dry"})
	var before: String = inventory.canonical_json()

	var plan = InventoryTransactionPlan.new()
	plan.bind_container("player", inventory)
	plan.remove_stack("player", wood, 2, {"grade": "dry"})
	plan.add_instance("player", tool, {"durability": 100})

	var result: Dictionary = InventoryTransactionPreflight.new().analyze(plan)
	if not bool(result.get("success", false)):
		failures.append("direct transaction preflight rejected valid plan: %s" % [result.get("diagnostics", [])])
	if inventory.canonical_json() != before:
		failures.append("successful direct transaction preflight mutated live container")
	if int(result.get("operation_count", 0)) != 2:
		failures.append("direct transaction preflight operation count changed")
	if str(result.get("transaction_fingerprint", "")).is_empty():
		failures.append("direct transaction preflight omitted deterministic fingerprint")
	if not result.get("events", []).is_empty():
		failures.append("direct transaction preflight emitted live commit events")


static func _test_failed_projection_does_not_mutate_live_container(failures: Array[String]) -> void:
	var ore = _item("item.resource.tx_preflight_ore", 16, 0.5)
	var inventory = ItemContainerState.new().configure(2, 10.0)
	inventory.add_stack(ore, 1)
	var before: String = inventory.canonical_json()

	var plan = InventoryTransactionPlan.new()
	plan.bind_container("player", inventory)
	plan.remove_stack("player", ore, 2)

	var result: Dictionary = InventoryTransactionPreflight.new().analyze(plan)
	if bool(result.get("success", false)):
		failures.append("direct transaction preflight accepted insufficient quantity")
	if not _has_fragment(result, "insufficient compatible stack quantity"):
		failures.append("direct transaction preflight changed insufficient-quantity diagnostic")
	if inventory.canonical_json() != before:
		failures.append("failed direct transaction preflight mutated live container")


static func _item(content_id: String, stack_limit: int, unit_weight: float):
	return ItemDefinition.new().configure_item(content_id, stack_limit, unit_weight, 1)


static func _has_fragment(result: Dictionary, fragment: String) -> bool:
	for value in result.get("diagnostics", []):
		if str(value).contains(fragment):
			return true
	return false
