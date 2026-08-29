extends RefCounted

const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemStackState := preload("res://gameplay/items/inventory/item_stack_state.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_m3_inventory_proof(failures)
	_test_stack_compatibility_and_limits(failures)
	_test_authored_stack_contract_mismatch_is_atomic(failures)
	_test_instance_state_is_separate(failures)
	_test_failed_operations_are_atomic(failures)
	_test_capacity_resize_is_atomic(failures)
	_test_canonical_serialization_shape(failures)
	return failures


static func _test_m3_inventory_proof(failures: Array[String]) -> void:
	var container = ItemContainerState.new().configure(12, 50.0)
	var wood = _item("item.resource.wood", 64, 0.10)
	var stone = _item("item.resource.stone", 64, 0.20)
	var ore = _item("item.resource.underworld_ore", 32, 0.30)
	var axe = _item("item.tool.stone_axe", 1, 2.50)
	var pickaxe = _item("item.tool.stone_pickaxe", 1, 3.00)
	var sword = _item("item.weapon.iron_sword", 1, 3.50)

	for result in [
		container.add_stack(wood, 30),
		container.add_stack(stone, 20),
		container.add_stack(ore, 12),
		container.add_instance(axe, {"durability": 100}),
		container.add_instance(pickaxe, {"durability": 100}),
		container.add_instance(sword, {"durability": 100}),
	]:
		if not bool(result.get("success", false)):
			failures.append("M3 inventory proof operation failed: %s" % [result.get("diagnostics", [])])

	_expect_equal(failures, "wood quantity", container.quantity_of(wood.content_id), 30)
	_expect_equal(failures, "stone quantity", container.quantity_of(stone.content_id), 20)
	_expect_equal(failures, "underground ore quantity", container.quantity_of(ore.content_id), 12)
	_expect_equal(failures, "stone axe count", container.quantity_of(axe.content_id), 1)
	_expect_equal(failures, "stone pickaxe count", container.quantity_of(pickaxe.content_id), 1)
	_expect_equal(failures, "sword count", container.quantity_of(sword.content_id), 1)
	_expect_equal(failures, "M3 occupied slots", container.occupied_slot_count(), 6)
	_expect_close(failures, "M3 occupied weight", container.current_weight(), 19.60)
	if not container.validate_container().is_empty():
		failures.append("valid M3 inventory state failed local validation: %s" % [container.validate_container()])


static func _test_stack_compatibility_and_limits(failures: Array[String]) -> void:
	var definition = _item("item.resource.stack_probe", 4, 0.25)
	var container = ItemContainerState.new().configure(3, -1.0)
	var dry_a: Dictionary = {}
	dry_a["grade"] = "dry"
	dry_a["batch"] = 7
	var dry_b: Dictionary = {}
	dry_b["batch"] = 7
	dry_b["grade"] = "dry"
	var wet := {"grade": "wet", "batch": 7}

	if not bool(container.add_stack(definition, 3, dry_a).get("success", false)):
		failures.append("first compatible stack add failed")
	if not bool(container.add_stack(definition, 3, dry_b).get("success", false)):
		failures.append("second compatible stack add failed")
	if not bool(container.add_stack(definition, 2, wet).get("success", false)):
		failures.append("distinct compatibility-state stack add failed")

	_expect_equal(failures, "canonical compatible stack quantity", container.stack_quantity(definition.content_id, dry_a), 6)
	_expect_equal(failures, "distinct stack-state quantity", container.stack_quantity(definition.content_id, wet), 2)
	_expect_equal(failures, "three stack slots used", container.occupied_slot_count(), 3)
	_expect_equal(failures, "first stack topped to authored limit", int(container.state_at(0).get("state", {}).get("quantity", 0)), 4)
	_expect_equal(failures, "second stack retains overflow", int(container.state_at(1).get("state", {}).get("quantity", 0)), 2)

	var invalid_stack = ItemStackState.new().configure(definition, 5, {})
	if not _array_has_fragment(invalid_stack.validate_against(definition), "exceeds authored stack limit"):
		failures.append("ItemStackState accepted quantity above ItemDefinition.stack_limit")


static func _test_authored_stack_contract_mismatch_is_atomic(failures: Array[String]) -> void:
	var item_id := "item.resource.stack_contract_probe"
	var stored_definition = _item(item_id, 4, 0.25, 1)
	var container = ItemContainerState.new().configure(2, -1.0)
	var initial: Dictionary = container.add_stack(stored_definition, 2)
	if not bool(initial.get("success", false)):
		failures.append("stack-contract mismatch setup add failed: %s" % [initial.get("diagnostics", [])])
		return

	var baseline_json: String = container.canonical_json()
	var mismatched_definitions := [
		_item(item_id, 8, 0.25, 1),
		_item(item_id, 4, 0.50, 1),
		_item(item_id, 4, 0.25, 2),
	]
	for mismatch in mismatched_definitions:
		var result: Dictionary = container.add_stack(mismatch, 1)
		if bool(result.get("success", false)):
			failures.append("authored item definition mismatch was accepted for %s" % item_id)
		elif not _has_fragment(result, "authored item definition mismatch"):
			failures.append("authored item definition mismatch did not fail clearly: %s" % [result.get("diagnostics", [])])
		if container.canonical_json() != baseline_json:
			failures.append("authored item definition mismatch mutated canonical inventory state")

	var different_state_mismatch = _item(item_id, 8, 0.25, 1)
	var different_state_result: Dictionary = container.add_stack(
		different_state_mismatch,
		1,
		{"grade": "different"}
	)
	if bool(different_state_result.get("success", false)):
		failures.append("different stack-state bypassed same-ContentId authored-contract guard")
	elif not _has_fragment(different_state_result, "authored item definition mismatch"):
		failures.append(
			"different stack-state mismatch did not fail through authored-contract guard: %s" % [
				different_state_result.get("diagnostics", []),
			]
		)
	if container.canonical_json() != baseline_json:
		failures.append("different stack-state authored-contract rejection mutated canonical inventory state")

	var instance_definition = _item(item_id, 1, 0.25, 1)
	var instance_result: Dictionary = container.add_instance(instance_definition, {"durability": 100})
	if bool(instance_result.get("success", false)):
		failures.append("non-stackable instance bypassed same-ContentId authored-contract guard")
	elif not _has_fragment(instance_result, "authored item definition mismatch"):
		failures.append(
			"stack-vs-instance mismatch did not fail through authored-contract guard: %s" % [
				instance_result.get("diagnostics", []),
			]
		)
	if container.canonical_json() != baseline_json:
		failures.append("stack-vs-instance authored-contract rejection mutated canonical inventory state")

	var compatible_clone = _item(item_id, 4, 0.25, 1)
	var compatible_result: Dictionary = container.add_stack(compatible_clone, 1)
	if not bool(compatible_result.get("success", false)):
		failures.append("equivalent authored item definition object failed to merge: %s" % [compatible_result.get("diagnostics", [])])
	_expect_equal(failures, "equivalent authored contract merged quantity", container.quantity_of(item_id), 3)


static func _test_instance_state_is_separate(failures: Array[String]) -> void:
	var sword = _item("item.weapon.instance_probe_sword", 1, 3.0)
	var shared_before: Dictionary = sword.canonical_descriptor().duplicate(true)
	var state_input := {"durability": 81, "modifier": "plain"}
	var container = ItemContainerState.new().configure(4, 20.0)
	var result: Dictionary = container.add_instance(sword, state_input)
	if not bool(result.get("success", false)):
		failures.append("non-stackable item instance add failed: %s" % [result.get("diagnostics", [])])
		return

	state_input["durability"] = 1
	var slot: int = int(result.get("slot", -1))
	var snapshot: Dictionary = container.state_at(slot)
	_expect_equal(
		failures,
		"per-copy state was deep-copied",
		int(snapshot.get("state", {}).get("per_copy_state", {}).get("durability", 0)),
		81
	)
	if sword.canonical_descriptor() != shared_before:
		failures.append("container/item-instance mutation changed shared ItemDefinition Resource")
	if snapshot.get("state", {}).has("instance_id"):
		failures.append("INV-001 invented a final persistent per-copy instance ID encoding")

	var before_failed_stack: String = container.canonical_json()
	var wrong_path: Dictionary = container.add_stack(sword, 1)
	if bool(wrong_path.get("success", false)) or container.canonical_json() != before_failed_stack:
		failures.append("non-stackable sword entered stack path or mutated container on rejection")


static func _test_failed_operations_are_atomic(failures: Array[String]) -> void:
	var heavy = _item("item.resource.heavy_probe", 5, 1.0)
	var container = ItemContainerState.new().configure(2, 2.0)
	if not bool(container.add_stack(heavy, 1).get("success", false)):
		failures.append("atomic-failure setup add failed")
		return

	var before_weight_failure: String = container.canonical_json()
	var overweight: Dictionary = container.add_stack(heavy, 2)
	if bool(overweight.get("success", false)) or not _has_fragment(overweight, "weight capacity"):
		failures.append("overweight stack add did not fail clearly")
	if container.canonical_json() != before_weight_failure:
		failures.append("overweight stack add partially mutated inventory")

	var before_remove_failure: String = container.canonical_json()
	var overremove: Dictionary = container.remove_stack(heavy.content_id, 2)
	if bool(overremove.get("success", false)) or not _has_fragment(overremove, "requested compatible stack quantity"):
		failures.append("over-remove did not fail clearly")
	if container.canonical_json() != before_remove_failure:
		failures.append("failed stack remove partially mutated inventory")

	var unsupported := {"runtime_object": Node.new()}
	var before_state_failure: String = container.canonical_json()
	var invalid_state: Dictionary = container.add_stack(heavy, 1, unsupported)
	unsupported["runtime_object"].free()
	if bool(invalid_state.get("success", false)) or not _has_fragment(invalid_state, "unsupported serialization type"):
		failures.append("runtime Object leaked into stack serialization state")
	if container.canonical_json() != before_state_failure:
		failures.append("invalid serialization-state add partially mutated inventory")


static func _test_capacity_resize_is_atomic(failures: Array[String]) -> void:
	var resource = _item("item.resource.resize_probe", 8, 0.5)
	var sword = _item("item.weapon.resize_probe", 1, 2.0)
	var container = ItemContainerState.new().configure(3, 10.0)
	container.add_stack(resource, 4)
	container.add_instance(sword, {"durability": 50})

	var before_slot_shrink: String = container.canonical_json()
	var shrink_slots: Dictionary = container.resize_capacity(1, 10.0)
	if bool(shrink_slots.get("success", false)) or container.canonical_json() != before_slot_shrink:
		failures.append("occupied-slot capacity shrink was not rejected atomically")

	var before_weight_shrink: String = container.canonical_json()
	var shrink_weight: Dictionary = container.resize_capacity(3, 3.0)
	if bool(shrink_weight.get("success", false)) or container.canonical_json() != before_weight_shrink:
		failures.append("weight capacity shrink below occupied weight was not rejected atomically")

	var grow: Dictionary = container.resize_capacity(5, 20.0)
	if not bool(grow.get("success", false)):
		failures.append("valid inventory capacity growth failed")
	_expect_equal(failures, "grown slot capacity", container.slot_capacity(), 5)
	_expect_close(failures, "grown weight capacity", container.max_weight(), 20.0)


static func _test_canonical_serialization_shape(failures: Array[String]) -> void:
	var definition = _item("item.resource.serialization_probe", 16, 0.1)
	var first_state: Dictionary = {}
	first_state["zeta"] = 2
	first_state["alpha"] = 1
	var second_state: Dictionary = {}
	second_state["alpha"] = 1
	second_state["zeta"] = 2

	var first = ItemContainerState.new().configure(4, -1.0)
	var second = ItemContainerState.new().configure(4, -1.0)
	first.add_stack(definition, 3, first_state)
	second.add_stack(definition, 3, second_state)

	var first_json: String = first.canonical_json()
	var second_json: String = second.canonical_json()
	if first_json != second_json:
		failures.append("logically identical inventory state produced order-dependent serialization")
	if not first_json.contains("inventory.container.v1"):
		failures.append("inventory snapshot omitted versioned serialization schema")
	for forbidden in ["resource_path", ".tres", "instance_id"]:
		if first_json.contains(forbidden):
			failures.append("inventory serialization leaked forbidden representation detail: %s" % forbidden)
	var snapshot: Dictionary = first.canonical_snapshot()
	_expect_equal(failures, "serialization slot address", int(snapshot.get("slots", [])[0].get("slot", -1)), 0)
	_expect_equal(failures, "serialization state kind", str(snapshot.get("slots", [])[0].get("kind", "")), "stack")


static func _item(
	content_id: String,
	stack_limit: int,
	unit_weight: float,
	schema_revision: int = 1
):
	return ItemDefinition.new().configure_item(content_id, stack_limit, unit_weight, schema_revision)


static func _has_fragment(result: Dictionary, fragment: String) -> bool:
	return _array_has_fragment(result.get("diagnostics", []), fragment)


static func _array_has_fragment(values: Array, fragment: String) -> bool:
	for value in values:
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


static func _expect_close(
	failures: Array[String],
	label: String,
	actual: float,
	expected: float
) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s — expected %.6f, got %.6f" % [label, expected, actual])