extends RefCounted

const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const InventoryTransactionPlan := preload("res://gameplay/items/inventory/inventory_transaction_plan.gd")
const InventoryTransactionService := preload("res://gameplay/items/inventory/inventory_transaction_service.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_crafting_style_transaction_is_atomic(failures)
	_test_insufficient_ingredient_changes_nothing(failures)
	_test_destination_capacity_failure_changes_nothing(failures)
	_test_destination_weight_failure_changes_nothing(failures)
	_test_cross_container_stack_transfer_conserves_state(failures)
	_test_instance_transfer_conserves_mutable_state(failures)
	_test_authored_contract_mismatch_remains_fail_closed(failures)
	_test_equivalent_plan_order_is_deterministic(failures)
	return failures


static func _test_crafting_style_transaction_is_atomic(failures: Array[String]) -> void:
	var wood = _item("item.resource.tx_wood", 64, 0.10)
	var stone = _item("item.resource.tx_stone", 64, 0.20)
	var axe = _item("item.tool.tx_axe", 1, 2.00)
	var inventory = ItemContainerState.new().configure(2, 10.0)
	inventory.add_stack(wood, 2)
	inventory.add_stack(stone, 1)

	var plan = InventoryTransactionPlan.new()
	plan.bind_container("player", inventory)
	plan.remove_stack("player", wood, 2)
	plan.remove_stack("player", stone, 1)
	plan.add_instance("player", axe, {"durability": 100})

	var result: Dictionary = InventoryTransactionService.new().commit(plan)
	if not bool(result.get("success", false)):
		failures.append("valid crafting-style transaction failed: %s" % [result.get("diagnostics", [])])
		return
	_expect_equal(failures, "craft wood consumed", inventory.quantity_of(wood.content_id), 0)
	_expect_equal(failures, "craft stone consumed", inventory.quantity_of(stone.content_id), 0)
	_expect_equal(failures, "craft output produced", inventory.quantity_of(axe.content_id), 1)
	_expect_equal(failures, "craft transaction operation count", int(result.get("operation_count", 0)), 3)
	if str(result.get("transaction_fingerprint", "")).is_empty():
		failures.append("successful transaction omitted deterministic fingerprint")


static func _test_insufficient_ingredient_changes_nothing(failures: Array[String]) -> void:
	var wood = _item("item.resource.tx_insufficient_wood", 64, 0.10)
	var stone = _item("item.resource.tx_insufficient_stone", 64, 0.20)
	var axe = _item("item.tool.tx_insufficient_axe", 1, 2.00)
	var inventory = ItemContainerState.new().configure(3, 10.0)
	inventory.add_stack(wood, 2)
	inventory.add_stack(stone, 1)
	var before: String = inventory.canonical_json()

	var plan = InventoryTransactionPlan.new()
	plan.bind_container("player", inventory)
	plan.remove_stack("player", wood, 2)
	plan.remove_stack("player", stone, 2)
	plan.add_instance("player", axe, {"durability": 100})
	var result: Dictionary = InventoryTransactionService.new().commit(plan)

	if bool(result.get("success", false)):
		failures.append("transaction with insufficient ingredient unexpectedly succeeded")
	elif not _has_fragment(result, "insufficient compatible stack quantity"):
		failures.append("insufficient ingredient failure was not diagnostic: %s" % [result.get("diagnostics", [])])
	if inventory.canonical_json() != before:
		failures.append("insufficient ingredient transaction partially mutated inventory")


static func _test_destination_capacity_failure_changes_nothing(failures: Array[String]) -> void:
	var wood = _item("item.resource.tx_capacity_wood", 64, 0.10)
	var stone = _item("item.resource.tx_capacity_stone", 64, 0.20)
	var source = ItemContainerState.new().configure(2, 10.0)
	var destination = ItemContainerState.new().configure(1, 10.0)
	source.add_stack(wood, 4)
	destination.add_stack(stone, 1)
	var source_before: String = source.canonical_json()
	var destination_before: String = destination.canonical_json()

	var plan = InventoryTransactionPlan.new()
	plan.bind_container("source", source)
	plan.bind_container("destination", destination)
	plan.transfer_stack("source", "destination", wood, 2)
	var result: Dictionary = InventoryTransactionService.new().commit(plan)

	if bool(result.get("success", false)):
		failures.append("capacity-invalid cross-container transfer unexpectedly succeeded")
	elif not _has_fragment(result, "stack-slot capacity"):
		failures.append("capacity failure was not diagnostic: %s" % [result.get("diagnostics", [])])
	if source.canonical_json() != source_before:
		failures.append("failed destination-capacity transfer mutated source")
	if destination.canonical_json() != destination_before:
		failures.append("failed destination-capacity transfer mutated destination")


static func _test_destination_weight_failure_changes_nothing(failures: Array[String]) -> void:
	var ore = _item("item.resource.tx_weight_ore", 16, 1.50)
	var source = ItemContainerState.new().configure(2, 10.0)
	var destination = ItemContainerState.new().configure(2, 2.0)
	source.add_stack(ore, 2)
	var source_before: String = source.canonical_json()
	var destination_before: String = destination.canonical_json()

	var plan = InventoryTransactionPlan.new()
	plan.bind_container("source", source)
	plan.bind_container("destination", destination)
	plan.transfer_stack("source", "destination", ore, 2)
	var result: Dictionary = InventoryTransactionService.new().commit(plan)

	if bool(result.get("success", false)):
		failures.append("weight-invalid cross-container transfer unexpectedly succeeded")
	elif not _has_fragment(result, "weight capacity"):
		failures.append("weight failure was not diagnostic: %s" % [result.get("diagnostics", [])])
	if source.canonical_json() != source_before:
		failures.append("failed destination-weight transfer mutated source")
	if destination.canonical_json() != destination_before:
		failures.append("failed destination-weight transfer mutated destination")


static func _test_cross_container_stack_transfer_conserves_state(failures: Array[String]) -> void:
	var ore = _item("item.resource.tx_ore", 16, 0.30)
	var source = ItemContainerState.new().configure(2, 10.0)
	var destination = ItemContainerState.new().configure(2, 10.0)
	var stack_state := {"grade": "dense", "batch": 7}
	source.add_stack(ore, 4, stack_state)
	destination.add_stack(ore, 1, stack_state)
	var total_before: int = source.quantity_of(ore.content_id) + destination.quantity_of(ore.content_id)

	var plan = InventoryTransactionPlan.new()
	plan.bind_container("source", source)
	plan.bind_container("destination", destination)
	plan.transfer_stack("source", "destination", ore, 2, stack_state)
	var result: Dictionary = InventoryTransactionService.new().commit(plan)

	if not bool(result.get("success", false)):
		failures.append("valid stack transfer failed: %s" % [result.get("diagnostics", [])])
		return
	_expect_equal(failures, "stack transfer source quantity", source.stack_quantity(ore.content_id, stack_state), 2)
	_expect_equal(failures, "stack transfer destination quantity", destination.stack_quantity(ore.content_id, stack_state), 3)
	_expect_equal(
		failures,
		"stack transfer total conserved",
		source.quantity_of(ore.content_id) + destination.quantity_of(ore.content_id),
		total_before
	)


static func _test_instance_transfer_conserves_mutable_state(failures: Array[String]) -> void:
	var sword = _item("item.weapon.tx_sword", 1, 3.0)
	var source = ItemContainerState.new().configure(2, 10.0)
	var destination = ItemContainerState.new().configure(2, 10.0)
	var add_result: Dictionary = source.add_instance(sword, {"durability": 81, "modifier": "plain"})
	var source_slot: int = int(add_result.get("slot", -1))
	if source_slot < 0:
		failures.append("instance-transfer setup failed")
		return

	var plan = InventoryTransactionPlan.new()
	plan.bind_container("source", source)
	plan.bind_container("destination", destination)
	plan.transfer_instance("source", "destination", source_slot, sword)
	var result: Dictionary = InventoryTransactionService.new().commit(plan)

	if not bool(result.get("success", false)):
		failures.append("valid instance transfer failed: %s" % [result.get("diagnostics", [])])
		return
	_expect_equal(failures, "instance transfer source count", source.instance_count(sword.content_id), 0)
	_expect_equal(failures, "instance transfer destination count", destination.instance_count(sword.content_id), 1)
	var destination_state: Dictionary = destination.state_at(0).get("state", {}).get("per_copy_state", {})
	_expect_equal(failures, "instance durability conserved", int(destination_state.get("durability", 0)), 81)
	_expect_equal(failures, "instance modifier conserved", str(destination_state.get("modifier", "")), "plain")


static func _test_authored_contract_mismatch_remains_fail_closed(failures: Array[String]) -> void:
	var source_definition = _item("item.resource.tx_contract", 8, 0.25, 1)
	var destination_definition = _item("item.resource.tx_contract", 4, 0.25, 1)
	var source = ItemContainerState.new().configure(2, 10.0)
	var destination = ItemContainerState.new().configure(2, 10.0)
	source.add_stack(source_definition, 2)
	destination.add_stack(destination_definition, 2)
	var source_before: String = source.canonical_json()
	var destination_before: String = destination.canonical_json()

	var plan = InventoryTransactionPlan.new()
	plan.bind_container("source", source)
	plan.bind_container("destination", destination)
	plan.transfer_stack("source", "destination", source_definition, 1)
	var result: Dictionary = InventoryTransactionService.new().commit(plan)

	if bool(result.get("success", false)):
		failures.append("authored-contract-mismatched transfer unexpectedly succeeded")
	elif not _has_fragment(result, "authored item definition mismatch"):
		failures.append("authored-contract transfer failure was not diagnostic: %s" % [result.get("diagnostics", [])])
	if source.canonical_json() != source_before or destination.canonical_json() != destination_before:
		failures.append("authored-contract mismatch bypassed atomic transaction rejection")


static func _test_equivalent_plan_order_is_deterministic(failures: Array[String]) -> void:
	var definition_a = _item("item.resource.tx_order", 16, 0.10)
	var definition_b = _item("item.resource.tx_order", 16, 0.10)
	var source_a = ItemContainerState.new().configure(2, 10.0)
	var destination_a = ItemContainerState.new().configure(2, 10.0)
	var source_b = ItemContainerState.new().configure(2, 10.0)
	var destination_b = ItemContainerState.new().configure(2, 10.0)
	var state_a: Dictionary = {}
	state_a["grade"] = "dry"
	state_a["batch"] = 7
	var state_b: Dictionary = {}
	state_b["batch"] = 7
	state_b["grade"] = "dry"
	source_a.add_stack(definition_a, 5, state_a)
	source_b.add_stack(definition_b, 5, state_b)

	var plan_a = InventoryTransactionPlan.new()
	plan_a.bind_container("source", source_a)
	plan_a.bind_container("destination", destination_a)
	plan_a.remove_stack("source", definition_a, 2, state_a)
	plan_a.add_stack("destination", definition_a, 2, state_a)

	var plan_b = InventoryTransactionPlan.new()
	plan_b.bind_container("destination", destination_b)
	plan_b.bind_container("source", source_b)
	plan_b.add_stack("destination", definition_b, 2, state_b)
	plan_b.remove_stack("source", definition_b, 2, state_b)

	var service = InventoryTransactionService.new()
	var result_a: Dictionary = service.commit(plan_a)
	var result_b: Dictionary = service.commit(plan_b)
	if not bool(result_a.get("success", false)) or not bool(result_b.get("success", false)):
		failures.append(
			"equivalent transaction order proof failed: %s / %s" % [
				result_a.get("diagnostics", []),
				result_b.get("diagnostics", []),
			]
		)
		return
	_expect_equal(
		failures,
		"equivalent plan transaction fingerprint",
		str(result_a.get("transaction_fingerprint", "")),
		str(result_b.get("transaction_fingerprint", ""))
	)
	_expect_equal(failures, "equivalent source snapshot", source_a.canonical_json(), source_b.canonical_json())
	_expect_equal(
		failures,
		"equivalent destination snapshot",
		destination_a.canonical_json(),
		destination_b.canonical_json()
	)


static func _item(
	content_id: String,
	stack_limit: int,
	unit_weight: float,
	schema_revision: int = 1
):
	return ItemDefinition.new().configure_item(content_id, stack_limit, unit_weight, schema_revision)


static func _has_fragment(result: Dictionary, fragment: String) -> bool:
	for value in result.get("diagnostics", []):
		if str(value).contains(fragment):
			return true
	return false


static func _expect_equal(
	failures: Array[String],
	label: String,
	actual: Variant,
	expected: Variant
) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])
