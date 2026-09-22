extends Node3D

## Minimal production building seam for the survival vertical slice.
## Inventory remains authoritative: placement is committed only after the
## existing InventoryTransactionService accepts the authored material cost.

const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const InventoryTransactionPlan := preload("res://gameplay/items/inventory/inventory_transaction_plan.gd")
const InventoryTransactionService := preload("res://gameplay/items/inventory/inventory_transaction_service.gd")

const WOOD_ID := "item.resource.wood"
const STONE_ID := "item.resource.stone"
const BUILDING_SHELTER_ID := "building.shelter.basic"
const BUILD_TOOL_ID := "item.tool.build"
const WORKBENCH_INTERACT_RADIUS := 3.25
const SHELTER_WOOD_COST := 4
const SHELTER_STONE_COST := 2
const INVENTORY_KEY := "survival_inventory"

var _world = null
var _inventory = null
var _definitions: Dictionary = {}
var _player: Node3D = null
var _workbench: StaticBody3D = null
var _build_tool_active := false
var _workbench_used := false
var _placed_shelters: Array[Dictionary] = []
var _transactions := InventoryTransactionService.new()

func configure(world, inventory, definitions: Dictionary) -> Node:
	_world = world
	_inventory = inventory
	_definitions = definitions.duplicate()
	return self

func set_player(player: Node3D) -> void:
	_player = player
	_ensure_workbench()

func build_tool_active() -> bool:
	return _build_tool_active

func placed_shelters() -> Array[Dictionary]:
	return _placed_shelters.duplicate(true)

func workbench_position() -> Vector3:
	return Vector3.ZERO if _workbench == null else _workbench.global_position

func toggle_build_tool() -> Dictionary:
	_build_tool_active = not _build_tool_active
	return {
		"success": true,
		"active": _build_tool_active,
		"building_id": BUILDING_SHELTER_ID,
		"diagnostics": [],
	}

func interact_with_workbench() -> Dictionary:
	_ensure_workbench()
	if _player == null or _workbench == null:
		return _failure("building runtime has no player/workbench")
	if _player.global_position.distance_to(_workbench.global_position) > WORKBENCH_INTERACT_RADIUS:
		return _failure("player is too far from the workbench")
	_workbench_used = true
	_build_tool_active = true
	return {
		"success": true,
		"active": true,
		"building_id": BUILDING_SHELTER_ID,
		"events": [{"type": "building.workbench_used", "building_id": BUILDING_SHELTER_ID}],
		"diagnostics": [],
	}

func place_shelter_from_ray(origin: Vector3, direction: Vector3, max_distance: float) -> Dictionary:
	if not _build_tool_active or not _workbench_used:
		return _failure("use the workbench before selecting a building piece")
	if direction.is_zero_approx():
		return _failure("building placement direction is zero")
	var target := origin + direction.normalized() * maxf(max_distance, 0.1)
	if _world != null and _world.has_method("get_world_3d"):
		var space := get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, target, 1))
		if not hit.is_empty():
			target = hit.get("position", target)
	return place_shelter_at(target)

func place_shelter_at(position: Vector3) -> Dictionary:
	if not _build_tool_active or not _workbench_used:
		return _failure("use the workbench before selecting a building piece")
	if not _is_finite_vector3(position):
		return _failure("building placement position is not finite")
	if _inventory == null:
		return _failure("building runtime has no canonical inventory")
	var wood = _definitions.get(WOOD_ID, null)
	var stone = _definitions.get(STONE_ID, null)
	if wood == null or stone == null or not wood is ItemDefinition or not stone is ItemDefinition:
		return _failure("building material definitions are unavailable")
	var plan = InventoryTransactionPlan.new().bind_container(INVENTORY_KEY, _inventory)
	plan.remove_stack(INVENTORY_KEY, wood, SHELTER_WOOD_COST)
	plan.remove_stack(INVENTORY_KEY, stone, SHELTER_STONE_COST)
	var committed: Dictionary = _transactions.commit(plan)
	if not bool(committed.get("success", false)):
		return _failure("shelter materials unavailable: %s" % [committed.get("diagnostics", [])])
	var record := {
		"building_id": BUILDING_SHELTER_ID,
		"stable_id": "building.shelter.basic.%03d" % (_placed_shelters.size() + 1),
		"position": position,
		"wood": SHELTER_WOOD_COST,
		"stone": SHELTER_STONE_COST,
	}
	_placed_shelters.append(record)
	_realize_shelter(record)
	return {
		"success": true,
		"building_id": BUILDING_SHELTER_ID,
		"stable_id": record["stable_id"],
		"position": position,
		"events": [{"type": "building.shelter_placed", "stable_id": record["stable_id"]}],
		"diagnostics": [],
	}

func _ensure_workbench() -> void:
	if _workbench != null or _player == null:
		return
	_workbench = StaticBody3D.new()
	_workbench.name = "Workbench"
	_workbench.set_meta("building_id", "building.workbench.basic")
	var forward := -_player.global_transform.basis.z
	forward.y = 0.0
	if forward.is_zero_approx():
		forward = Vector3.FORWARD
	var position := _player.global_position + forward.normalized() * 2.0
	position.y = _player.global_position.y - 0.8
	_workbench.global_position = position
	add_child(_workbench)
	_add_box(_workbench, Vector3(1.2, 0.9, 0.8), Color("6d432b"))

func _realize_shelter(record: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = str(record["stable_id"])
	body.global_position = record["position"]
	body.set_meta("building_id", record["building_id"])
	body.set_meta("stable_id", record["stable_id"])
	add_child(body)
	_add_box(body, Vector3(2.4, 1.6, 0.35), Color("9b6b3e"))

func _add_box(parent: StaticBody3D, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	parent.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	parent.add_child(collision)

static func _is_finite_vector3(value: Vector3) -> bool:
	return not is_nan(value.x) and not is_inf(value.x) and not is_nan(value.y) and not is_inf(value.y) and not is_nan(value.z) and not is_inf(value.z)

static func _failure(message: String) -> Dictionary:
	return {"success": false, "diagnostics": [message], "events": []}
