extends RefCounted

const BuildingRuntime := preload("res://gameplay/building/building_runtime.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	var inventory = ItemContainerState.new().configure(8)
	var wood = ItemDefinition.new().configure_item("item.resource.wood", 99, 0.1, 1)
	var stone = ItemDefinition.new().configure_item("item.resource.stone", 99, 0.1, 1)
	inventory.add_stack(wood, 10)
	inventory.add_stack(stone, 10)
	var runtime = BuildingRuntime.new().configure(null, inventory, {"item.resource.wood": wood, "item.resource.stone": stone})
	var player := Node3D.new()
	runtime.set_player(player)
	# Normal G interaction authorizes the workbench before selecting a piece.
	var workbench_result: Dictionary = runtime.interact_with_workbench()
	_expect(failures, "workbench interaction authorizes building", bool(workbench_result.get("success", false)))

	# B selects the authored chest piece, and placement stays in the runtime seam.
	runtime.toggle_build_tool()
	runtime.toggle_build_tool()
	var chest_result: Dictionary = runtime.place_shelter_at(Vector3(2.0, 0.0, 0.0))
	_expect(failures, "chest placement succeeds through selected build piece", bool(chest_result.get("success", false)))
	var chest_id := str(chest_result.get("stable_id", ""))
	_expect(failures, "chest receives canonical stable identity", chest_id == "building.chest.basic.001")
	_expect(failures, "chest placement consumes no nonexistent position", runtime.place_shelter_at(Vector3(NAN, 0.0, 0.0)).get("success", false) == false)
	var store_result: Dictionary = runtime.store_in_chest(chest_id, "item.resource.wood", 3)
	_expect(failures, "chest stores canonical item quantity", bool(store_result.get("success", false)) and runtime.chest_contents(chest_id).get("item.resource.wood", 0) == 3)
	_expect(failures, "chest storage removes cargo from player inventory", inventory.quantity_of("item.resource.wood") == 7)
	_expect(failures, "chest rejects cargo not owned by player", not bool(runtime.store_in_chest(chest_id, "item.resource.wood", 99).get("success", false)))

	# B cycles to the bed piece; G-style interaction claims the placed bed.
	runtime.toggle_build_tool()
	var bed_result: Dictionary = runtime.place_shelter_at(Vector3(4.0, 0.0, 0.0))
	_expect(failures, "bed placement succeeds through selected build piece", bool(bed_result.get("success", false)))
	_expect(failures, "unclaimed bed is not a respawn anchor", runtime.get_claimed_bed_respawn_position() == null)
	player.global_position = Vector3(4.0, 0.0, 0.0)
	var claim_result: Dictionary = runtime.interact_with_workbench()
	print("[BUILDING DIAG] bed result=%s player=%s bed_position=%s" % [str(bed_result), str(player.position), str(bed_result.get("position", null))])
	_expect(failures, "bed interaction claims canonical bed", str(claim_result.get("bed_claimed", "")) == str(bed_result.get("stable_id", "")))

	var snapshot: Dictionary = runtime.durable_snapshot()
	var restored = BuildingRuntime.new().configure(null, inventory, {"item.resource.wood": wood, "item.resource.stone": stone})
	var restored_player := Node3D.new()
	restored.set_player(restored_player)
	var hydration: Dictionary = restored.restore_from_durable(snapshot)
	_expect(failures, "chest/bed durable snapshot restores", bool(hydration.get("success", false)))
	_expect(failures, "chest contents survive Continue hydration", restored.chest_contents(chest_id).get("item.resource.wood", 0) == 3)
	_expect(failures, "bed claim survives Continue hydration", str(restored.durable_snapshot().get("claimed_bed_stable_id", "")) == str(bed_result.get("stable_id", "")))
	_expect(failures, "hydrated claim resolves only to referenced bed", restored.get_claimed_bed_respawn_position() is Vector3)
	return failures

static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
