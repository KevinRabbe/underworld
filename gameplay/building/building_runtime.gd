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
const SNAPSHOT_SCHEMA := "gameplay.building.v1"

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

func durable_snapshot() -> Dictionary:
	return {
		"schema": SNAPSHOT_SCHEMA,
		"build_tool_active": _build_tool_active,
		"workbench_used": _workbench_used,
		"placed_shelters": _placed_shelters.duplicate(true),
	}

func restore_from_durable(snapshot: Dictionary) -> Dictionary:
	var failures: Array[String] = validate_durable_snapshot(snapshot)
	if not failures.is_empty():
		return {"success": false, "diagnostics": failures}
	for child in get_children():
		if child is StaticBody3D and child != _workbench:
			child.queue_free()
	_build_tool_active = bool(snapshot.get("build_tool_active", false))
	_workbench_used = bool(snapshot.get("workbench_used", false))
	_placed_shelters.clear()
	for raw_record in snapshot.get("placed_shelters", []):
		var record: Dictionary = raw_record.duplicate(true)
		_placed_shelters.append(record)
		_realize_shelter(record)
	return {"success": true, "diagnostics": []}

static func validate_durable_snapshot(snapshot: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var expected := ["build_tool_active", "placed_shelters", "schema", "workbench_used"]
	var actual: Array[String] = []
	for key in snapshot.keys():
		actual.append(str(key))
	actual.sort()
	if actual != expected:
		failures.append("building snapshot keys must be exact expected=%s actual=%s" % [expected, actual])
	if str(snapshot.get("schema", "")) != SNAPSHOT_SCHEMA:
		failures.append("building snapshot schema is unsupported")
	if typeof(snapshot.get("build_tool_active", null)) != TYPE_BOOL:
		failures.append("building snapshot build_tool_active must be bool")
	if typeof(snapshot.get("workbench_used", null)) != TYPE_BOOL:
		failures.append("building snapshot workbench_used must be bool")
	var shelters: Variant = snapshot.get("placed_shelters", null)
	if not shelters is Array:
		failures.append("building snapshot placed_shelters must be Array")
	else:
		var seen: Dictionary = {}
		for index in range(shelters.size()):
			var record: Variant = shelters[index]
			if not record is Dictionary:
				failures.append("building snapshot shelter %d must be Dictionary" % index)
				continue
			var shelter: Dictionary = record
			var record_keys: Array[String] = []
			for key in shelter.keys():
				record_keys.append(str(key))
			record_keys.sort()
			if record_keys != ["building_id", "position", "stable_id", "stone", "wood"]:
				failures.append("building snapshot shelter %d keys are invalid" % index)
			var building_id: Variant = shelter.get("building_id", null)
			if typeof(building_id) != TYPE_STRING or str(building_id) != BUILDING_SHELTER_ID:
				failures.append("building snapshot shelter %d building_id must be canonical shelter String" % index)
			var stable_id_variant: Variant = shelter.get("stable_id", null)
			var stable_id := str(stable_id_variant)
			var stable_suffix := stable_id.trim_prefix("building.shelter.basic.")
			var stable_id_canonical := (
				typeof(stable_id_variant) == TYPE_STRING
				and stable_id.begins_with("building.shelter.basic.")
				and stable_suffix.is_valid_int()
				and int(stable_suffix) > 0
				and stable_id == "building.shelter.basic.%03d" % int(stable_suffix)
			)
			if not stable_id_canonical or seen.has(stable_id):
				failures.append("building snapshot shelter %d has duplicate/empty stable_id" % index)
			seen[stable_id] = true
			var position: Variant = shelter.get("position", null)
			if not position is Vector3 or not _is_finite_vector3(position):
				failures.append("building snapshot shelter %d position must be finite Vector3" % index)
			for material in ["wood", "stone"]:
				var amount: Variant = shelter.get(material, null)
				var expected_amount: int = SHELTER_WOOD_COST if material == "wood" else SHELTER_STONE_COST
				if typeof(amount) != TYPE_INT or int(amount) != expected_amount:
					failures.append(
						"building snapshot shelter %d %s must be canonical int value %d" % [
							index, material, expected_amount,
						]
					)
	return failures

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
	add_child(_workbench)
	# Detached contract fixtures do not have a SceneTree, so assigning
	# global_position before attachment is invalid and can collapse the saved
	# transform. Attach first, then use the local transform for detached roots.
	if is_inside_tree():
		_workbench.global_position = position
	else:
		_workbench.position = position
	_add_box(_workbench, Vector3(1.2, 0.9, 0.8), Color("6d432b"))

func _realize_shelter(record: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = str(record["stable_id"])
	body.set_meta("building_id", record["building_id"])
	body.set_meta("stable_id", record["stable_id"])
	add_child(body)
	if is_inside_tree():
		body.global_position = record["position"]
	else:
		body.position = record["position"]
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
