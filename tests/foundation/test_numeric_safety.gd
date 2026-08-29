extends RefCounted

const FiniteNumber := preload("res://core/content/validation/finite_number.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const ResourceDefinition := preload("res://gameplay/resources/definitions/resource_definition.gd")
const ResourceYieldRule := preload("res://gameplay/resources/definitions/resource_yield_rule.gd")
const ResourceDepletionState := preload("res://gameplay/resources/state/resource_depletion_state.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_shared_finite_predicate(failures)
	_test_item_definition_weight_boundary(failures)
	_test_resource_definition_boundaries(failures)
	_test_resource_depletion_fail_closed(failures)
	_test_inventory_weight_boundaries(failures)
	return failures


static func _test_shared_finite_predicate(failures: Array[String]) -> void:
	for value in [0.0, -1.0, 1.0, 1.0e308]:
		if not FiniteNumber.is_finite_number(value):
			failures.append("shared finite predicate rejected finite value: %s" % str(value))
	for value in _non_finite_values():
		if FiniteNumber.is_finite_number(value):
			failures.append("shared finite predicate accepted non-finite value")


static func _test_item_definition_weight_boundary(failures: Array[String]) -> void:
	var finite = _item("item.resource.numeric_finite", 8, 0.25)
	if not finite.validate_definition().is_empty():
		failures.append("finite ItemDefinition unit_weight failed accepted validation")

	for value in _non_finite_values():
		var invalid = _item("item.resource.numeric_invalid", 8, value)
		if not _array_has_fragment(invalid.validate_definition(), "unit_weight must be finite"):
			failures.append("ItemDefinition accepted non-finite unit_weight")


static func _test_resource_definition_boundaries(failures: Array[String]) -> void:
	var finite_yield = _yield("resource.node.numeric_finite", 0.5)
	var finite = ResourceDefinition.new().configure_resource("resource.node.numeric_finite", 10.0, 1)
	finite.configure_yield_rules([finite_yield])
	if not finite.validate_definition().is_empty():
		failures.append("finite ResourceDefinition/ResourceYieldRule values failed accepted validation")

	for value in _non_finite_values():
		var invalid_capacity = ResourceDefinition.new().configure_resource(
			"resource.node.numeric_capacity_invalid",
			value,
			1
		)
		invalid_capacity.configure_yield_rules([
			_yield("resource.node.numeric_capacity_invalid", 0.5)
		])
		if not _array_has_fragment(
			invalid_capacity.validate_definition(),
			"capacity_units must be finite"
		):
			failures.append("ResourceDefinition accepted non-finite capacity_units")

		var invalid_yield = _yield("resource.node.numeric_yield_invalid", value)
		if not _array_has_fragment(
			invalid_yield.validate_rule(),
			"quantity_per_capacity_unit must be finite"
		):
			failures.append("ResourceYieldRule accepted non-finite quantity_per_capacity_unit")


static func _test_resource_depletion_fail_closed(failures: Array[String]) -> void:
	var valid = ResourceDepletionState.new().configure("resource.node.numeric_state", 5.0)
	if not valid.validate_state().is_empty():
		failures.append("finite ResourceDepletionState failed accepted validation")

	for value in _non_finite_values():
		var invalid = ResourceDepletionState.new().configure(
			"resource.node.numeric_state_invalid",
			value
		)
		if not _array_has_fragment(
			invalid.validate_state(),
			"remaining_capacity_units must be finite"
		):
			failures.append("ResourceDepletionState accepted non-finite remaining capacity")

		var request_state = ResourceDepletionState.new().configure(
			"resource.node.numeric_request",
			5.0
		)
		var before: float = request_state.remaining_capacity_units
		var consumed: float = request_state.consume_capacity(value)
		if consumed != 0.0:
			failures.append("non-finite depletion request consumed capacity")
		if request_state.remaining_capacity_units != before:
			failures.append("non-finite depletion request mutated remaining capacity")

	var invalid_remaining = ResourceDepletionState.new().configure(
		"resource.node.numeric_existing_invalid",
		INF
	)
	if invalid_remaining.consume_capacity(1.0) != 0.0:
		failures.append("consume_capacity mutated from non-finite existing remaining capacity")
	if invalid_remaining.remaining_capacity_units != INF:
		failures.append("failed consume changed existing non-finite remaining capacity")


static func _test_inventory_weight_boundaries(failures: Array[String]) -> void:
	var finite = ItemContainerState.new().configure(2, 10.0)
	if not finite.validate_container().is_empty():
		failures.append("finite inventory max_weight failed accepted validation")

	for value in _non_finite_values():
		var invalid_config = ItemContainerState.new().configure(2, value)
		if not _array_has_fragment(invalid_config.validate_container(), "max_weight must be finite"):
			failures.append("inventory configure accepted non-finite max_weight")

	var resize_container = ItemContainerState.new().configure(2, 10.0)
	var resize_item = _item("item.resource.numeric_resize", 8, 0.5)
	var setup: Dictionary = resize_container.add_stack(resize_item, 2)
	if not bool(setup.get("success", false)):
		failures.append("inventory numeric resize setup failed")
		return
	var resize_baseline: String = resize_container.canonical_json()
	for value in _non_finite_values():
		var resize_result: Dictionary = resize_container.resize_capacity(3, value)
		if bool(resize_result.get("success", false)):
			failures.append("inventory resize accepted non-finite max_weight")
		elif not _result_has_fragment(resize_result, "max_weight must be finite"):
			failures.append("inventory resize non-finite diagnostic did not identify max_weight")
		if resize_container.canonical_json() != resize_baseline:
			failures.append("failed non-finite inventory resize mutated canonical state")

	var overflow_container = ItemContainerState.new().configure(2, -1.0)
	var huge = _item("item.resource.numeric_overflow", 4, 1.0e308)
	if not huge.validate_definition().is_empty():
		failures.append("finite huge unit_weight unexpectedly failed authored validation")
	else:
		var overflow_before: String = overflow_container.canonical_json()
		var overflow_result: Dictionary = overflow_container.add_stack(huge, 2)
		if bool(overflow_result.get("success", false)):
			failures.append("finite arithmetic overflow produced accepted infinite projected_weight")
		elif not _result_has_fragment(overflow_result, "projected_weight must be finite"):
			failures.append("overflow rejection did not identify projected_weight")
		if overflow_container.canonical_json() != overflow_before:
			failures.append("overflowing projected_weight partially mutated inventory")

	var current_container = ItemContainerState.new().configure(2, -1.0)
	var mutable_definition = _item("item.resource.numeric_current", 4, 1.0)
	var current_setup: Dictionary = current_container.add_stack(mutable_definition, 2)
	if not bool(current_setup.get("success", false)):
		failures.append("inventory current_weight setup failed")
		return
	var current_baseline: String = current_container.canonical_json()
	mutable_definition.unit_weight = INF
	if not _array_has_fragment(current_container.validate_container(), "current_weight must be finite"):
		failures.append("inventory validation accepted non-finite computed current_weight")
	var blocked_remove: Dictionary = current_container.remove_stack(mutable_definition.content_id, 1)
	if bool(blocked_remove.get("success", false)):
		failures.append("inventory mutation proceeded from non-finite current_weight state")
	if current_container.canonical_json() != current_baseline:
		failures.append("rejected mutation from non-finite current_weight changed canonical state")


static func _item(content_id: String, stack_limit: int, unit_weight: float):
	return ItemDefinition.new().configure_item(content_id, stack_limit, unit_weight, 1)


static func _yield(source_id: String, quantity: float):
	return ResourceYieldRule.new().configure(
		source_id,
		"yield.primary",
		"item.resource.numeric_probe",
		quantity
	)


static func _non_finite_values() -> Array:
	return [NAN, INF, -INF]


static func _result_has_fragment(result: Dictionary, fragment: String) -> bool:
	return _array_has_fragment(result.get("diagnostics", []), fragment)


static func _array_has_fragment(values: Array, fragment: String) -> bool:
	for value in values:
		if str(value).contains(fragment):
			return true
	return false
