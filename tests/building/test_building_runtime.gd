extends RefCounted

const BuildingRuntime := preload("res://gameplay/building/building_runtime.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	var inventory = ItemContainerState.new().configure(8)
	var wood = ItemDefinition.new().configure_item("item.resource.wood", 99, 0.1, 1)
	var stone = ItemDefinition.new().configure_item("item.resource.stone", 99, 0.1, 1)
	inventory.add_stack(wood, 4)
	inventory.add_stack(stone, 2)
	var runtime = BuildingRuntime.new().configure(null, inventory, {
		"item.resource.wood": wood,
		"item.resource.stone": stone,
	})
	var player := Node3D.new()
	player.global_position = Vector3.ZERO
	runtime.set_player(player)
	var too_far: Dictionary = runtime.interact_with_workbench()
	if not bool(too_far.get("success", false)):
		failures.append("workbench should be reachable at the authored player start")
	var first: Dictionary = runtime.place_shelter_at(Vector3(2.0, 0.0, 0.0))
	if not bool(first.get("success", false)):
		failures.append("shelter placement failed: %s" % first.get("diagnostics", []))
	if inventory.quantity_of("item.resource.wood") != 0 or inventory.quantity_of("item.resource.stone") != 0:
		failures.append("placement did not consume canonical shelter materials")
	var second: Dictionary = runtime.place_shelter_at(Vector3(4.0, 0.0, 0.0))
	if bool(second.get("success", false)):
		failures.append("insufficient canonical materials unexpectedly placed a second shelter")
	if runtime.placed_shelters().size() != 1:
		failures.append("runtime did not retain exactly one authoritative placement record")
	var durable: Dictionary = runtime.durable_snapshot()
	var restored = BuildingRuntime.new().configure(null, inventory, {
		"item.resource.wood": wood,
		"item.resource.stone": stone,
	})
	var restored_player := Node3D.new()
	restored_player.global_position = Vector3.ZERO
	restored.set_player(restored_player)
	var hydration: Dictionary = restored.restore_from_durable(durable)
	if not bool(hydration.get("success", false)):
		failures.append("building durable snapshot restore failed: %s" % hydration.get("diagnostics", []))
	elif restored.placed_shelters() != runtime.placed_shelters():
		failures.append("shelter placement did not survive building snapshot/restore")
	elif not restored.build_tool_active():
		failures.append("build tool state did not survive building snapshot/restore")
	var record: Dictionary = durable["placed_shelters"][0]
	for field_case in [
		{"field": "building_id", "value": 7},
		{"field": "stable_id", "value": 9},
		{"field": "wood", "value": 4.0},
		{"field": "stone", "value": 2.0},
		{"field": "position", "value": [2.0, 0.0, 0.0]},
	]:
		var malformed: Dictionary = durable.duplicate(true)
		malformed["placed_shelters"][0][field_case["field"]] = field_case["value"]
		if BuildingRuntime.validate_durable_snapshot(malformed).is_empty():
			failures.append("building durable validation accepted malformed %s type" % field_case["field"])
	var bad_value: Dictionary = durable.duplicate(true)
	bad_value["placed_shelters"][0]["building_id"] = "building.wall.basic"
	if BuildingRuntime.validate_durable_snapshot(bad_value).is_empty():
		failures.append("building durable validation accepted unsupported building_id")
	bad_value = durable.duplicate(true)
	bad_value["placed_shelters"][0]["wood"] = 3
	if BuildingRuntime.validate_durable_snapshot(bad_value).is_empty():
		failures.append("building durable validation accepted unsupported wood cost")
	bad_value = durable.duplicate(true)
	bad_value["placed_shelters"][0]["stable_id"] = "building.shelter.basic.1"
	if BuildingRuntime.validate_durable_snapshot(bad_value).is_empty():
		failures.append("building durable validation accepted non-canonical stable_id")
	return failures
