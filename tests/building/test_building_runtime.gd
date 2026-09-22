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
	return failures
