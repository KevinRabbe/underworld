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
const BUILDING_CHEST_ID := "building.chest.basic"
const BUILDING_BED_ID := "building.bed.basic"
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
var _placed_chests: Array[Dictionary] = []
var _claimed_bed_stable_id: String = ""
var _selected_building_id: String = BUILDING_SHELTER_ID
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

func placed_chests() -> Array[Dictionary]:
	return _placed_chests.duplicate(true)

func store_in_chest(stable_id: String, item_id: String, quantity: int) -> Dictionary:
	if quantity <= 0 or item_id.is_empty():
		return _failure("chest storage requires positive quantity and item id")
	if _inventory == null or not _inventory.has_method("quantity_of") or not _inventory.has_method("remove_stack"):
		return _failure("chest storage requires canonical player inventory")
	for chest in _placed_chests:
		if str(chest.get("stable_id", "")) == stable_id:
			var definition = _definitions.get(item_id, null)
			if definition == null or not definition is ItemDefinition:
				return _failure("chest storage item definition is not owned/canonical: %s" % item_id)
			if _inventory.quantity_of(item_id) < quantity:
				return _failure("player does not own requested chest quantity: %s" % item_id)
			var removed: Dictionary = _inventory.remove_stack(item_id, quantity)
			if not bool(removed.get("success", false)):
				return _failure("chest storage inventory removal failed: %s" % [removed.get("diagnostics", [])])
			var contents: Dictionary = chest.get("contents", {})
			contents[item_id] = int(contents.get(item_id, 0)) + quantity
			chest["contents"] = contents
			return {"success": true, "stable_id": stable_id, "contents": contents.duplicate(true), "diagnostics": []}
	return _failure("unknown chest stable id: %s" % stable_id)

func chest_contents(stable_id: String) -> Dictionary:
	for chest in _placed_chests:
		if str(chest.get("stable_id", "")) == stable_id:
			return chest.get("contents", {}).duplicate(true)
	return {}

func durable_snapshot() -> Dictionary:
	return {
		"schema": SNAPSHOT_SCHEMA,
		"build_tool_active": _build_tool_active,
		"workbench_used": _workbench_used,
		"placed_shelters": _placed_shelters.duplicate(true),
		"placed_chests": _placed_chests.duplicate(true),
		"claimed_bed_stable_id": _claimed_bed_stable_id,
		"selected_building_id": _selected_building_id,
	}

func restore_from_durable(snapshot: Dictionary) -> Dictionary:
	var failures: Array[String] = validate_durable_snapshot(snapshot)
	if not failures.is_empty():
		return {"success": false, "diagnostics": failures}
	for child in get_children():
		if child is StaticBody3D and child != _workbench:
			child.queue_free()
	_build_tool_active = bool(snapshot.get("build_tool_active", false))
	_selected_building_id = str(snapshot.get("selected_building_id", BUILDING_SHELTER_ID))
	_workbench_used = bool(snapshot.get("workbench_used", false))
	_claimed_bed_stable_id = str(snapshot.get("claimed_bed_stable_id", ""))
	_placed_shelters.clear()
	for raw_record in snapshot.get("placed_shelters", []):
		var record: Dictionary = raw_record.duplicate(true)
		_placed_shelters.append(record)
		_realize_shelter(record)
	_placed_chests.clear()
	for raw_record in snapshot.get("placed_chests", []):
		var chest_record: Dictionary = raw_record.duplicate(true)
		_placed_chests.append(chest_record)
		_realize_chest(chest_record)
	return {"success": true, "diagnostics": []}

static func validate_durable_snapshot(snapshot: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var expected := ["build_tool_active", "claimed_bed_stable_id", "placed_chests", "placed_shelters", "schema", "selected_building_id", "workbench_used"]
	var legacy_expected := ["build_tool_active", "placed_shelters", "schema", "workbench_used"]
	var actual: Array[String] = []
	for key in snapshot.keys():
		actual.append(str(key))
	actual.sort()
	if actual != expected and actual != legacy_expected:
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
			if str(shelter.get("building_id", "")) == BUILDING_BED_ID:
				var bed_keys: Array[String] = []
				for key in shelter.keys(): bed_keys.append(str(key))
				bed_keys.sort()
				if bed_keys != ["building_id", "position", "stable_id", "stone", "wood"]:
					failures.append("building snapshot bed %d keys are invalid" % index)
				var bed_id_variant: Variant = shelter.get("stable_id", null)
				var bed_id := str(bed_id_variant)
				var bed_suffix := bed_id.trim_prefix("building.bed.basic.")
				if typeof(bed_id_variant) != TYPE_STRING or not bed_id.begins_with("building.bed.basic.") or not bed_suffix.is_valid_int() or int(bed_suffix) <= 0 or bed_id != "building.bed.basic.%03d" % int(bed_suffix) or seen.has(bed_id):
					failures.append("building snapshot bed %d has duplicate/invalid stable_id" % index)
				seen[bed_id] = true
				if not shelter.get("position", null) is Vector3 or not _is_finite_vector3(shelter.position):
					failures.append("building snapshot bed %d position must be finite Vector3" % index)
				if typeof(shelter.get("wood", null)) != TYPE_INT or int(shelter.get("wood")) != 0 or typeof(shelter.get("stone", null)) != TYPE_INT or int(shelter.get("stone")) != 0:
					failures.append("building snapshot bed %d materials must be canonical zero integers" % index)
				continue
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
	if actual == legacy_expected:
		return failures
	var chests: Variant = snapshot.get("placed_chests", null)
	if not chests is Array:
		failures.append("building snapshot placed_chests must be Array")
	else:
		for index in range(chests.size()):
			var chest: Variant = chests[index]
			if not chest is Dictionary:
				failures.append("building snapshot chest %d must be Dictionary" % index)
				continue
			var chest_keys: Array[String] = []
			for key in chest.keys(): chest_keys.append(str(key))
			chest_keys.sort()
			if chest_keys != ["building_id", "contents", "position", "stable_id"]:
				failures.append("building snapshot chest %d keys are invalid" % index)
			if str(chest.get("building_id", "")) != BUILDING_CHEST_ID:
				failures.append("building snapshot chest %d building_id is not canonical" % index)
			var chest_id_variant: Variant = chest.get("stable_id", null)
			var chest_id := str(chest_id_variant)
			var chest_suffix := chest_id.trim_prefix("building.chest.basic.")
			if typeof(chest_id_variant) != TYPE_STRING or not chest_id.begins_with("building.chest.basic.") or not chest_suffix.is_valid_int() or int(chest_suffix) <= 0 or chest_id != "building.chest.basic.%03d" % int(chest_suffix):
				failures.append("building snapshot chest %d stable_id is not canonical" % index)
			var contents: Variant = chest.get("contents", null)
			if not contents is Dictionary:
				failures.append("building snapshot chest %d contents must be Dictionary" % index)
			else:
				for item_id in contents.keys():
					if typeof(item_id) != TYPE_STRING or typeof(contents[item_id]) != TYPE_INT or int(contents[item_id]) <= 0:
						failures.append("building snapshot chest %d contents are malformed" % index)
			if not chest.get("position", null) is Vector3 or not _is_finite_vector3(chest.position):
				failures.append("building snapshot chest %d position must be finite Vector3" % index)
	if typeof(snapshot.get("claimed_bed_stable_id", null)) != TYPE_STRING:
		failures.append("building snapshot claimed_bed_stable_id must be String")
	else:
		var claimed := str(snapshot.get("claimed_bed_stable_id", ""))
		if not claimed.is_empty():
			var claim_found := false
			if shelters is Array:
				for raw_bed in shelters:
					if raw_bed is Dictionary and str(raw_bed.get("building_id", "")) == BUILDING_BED_ID and str(raw_bed.get("stable_id", "")) == claimed:
						claim_found = true
			if not claim_found:
				failures.append("building snapshot claimed_bed_stable_id must reference a placed bed")
	if str(snapshot.get("selected_building_id", "")) not in [BUILDING_SHELTER_ID, BUILDING_CHEST_ID, BUILDING_BED_ID]:
		failures.append("building snapshot selected_building_id is not canonical")
	return failures

func workbench_position() -> Vector3:
	return Vector3.ZERO if _workbench == null else _workbench.global_position

func toggle_build_tool() -> Dictionary:
	if not _build_tool_active:
		_build_tool_active = true
		_selected_building_id = BUILDING_SHELTER_ID
	else:
		_selected_building_id = {
			BUILDING_SHELTER_ID: BUILDING_CHEST_ID,
			BUILDING_CHEST_ID: BUILDING_BED_ID,
			BUILDING_BED_ID: BUILDING_SHELTER_ID,
		}.get(_selected_building_id, BUILDING_SHELTER_ID)
	return {
		"success": true,
		"active": _build_tool_active,
		"building_id": _selected_building_id,
		"diagnostics": [],
	}

func interact_with_workbench() -> Dictionary:
	_ensure_workbench()
	if _player == null or _workbench == null:
		return _failure("building runtime has no player/workbench")
	# Detached runtime fixtures do not have a SceneTree transform hierarchy;
	# local position is the authoritative equivalent of global_position there.
	var player_position: Vector3 = _player.position if not _player.is_inside_tree() else _player.global_position
	var nearest_distance := INF
	var nearest_chest: Dictionary = {}
	for chest in _placed_chests:
		var chest_distance: float = player_position.distance_to(chest.get("position", Vector3.ZERO))
		if chest_distance <= WORKBENCH_INTERACT_RADIUS and chest_distance < nearest_distance:
			nearest_distance = chest_distance
			nearest_chest = chest
	for bed in _placed_shelters:
		var bed_distance: float = player_position.distance_to(bed.get("position", Vector3.ZERO))
		if str(bed.get("building_id", "")) == BUILDING_BED_ID and bed_distance <= WORKBENCH_INTERACT_RADIUS and bed_distance < nearest_distance:
			_claimed_bed_stable_id = str(bed.get("stable_id", ""))
			return {"success": true, "active": true, "bed_claimed": _claimed_bed_stable_id, "diagnostics": []}
	if not nearest_chest.is_empty():
		return {"success": true, "active": true, "chest_opened": nearest_chest.stable_id, "contents": nearest_chest.contents.duplicate(true), "diagnostics": []}
	var workbench_position := _workbench.position if not _workbench.is_inside_tree() else _workbench.global_position
	if player_position.distance_to(workbench_position) > WORKBENCH_INTERACT_RADIUS:
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
	if _selected_building_id == BUILDING_CHEST_ID:
		return _place_chest_at(position)
	if _selected_building_id == BUILDING_BED_ID:
		return _place_bed_at(position)
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

func _place_chest_at(position: Vector3) -> Dictionary:
	var admission := _validate_placement_admission(position)
	if not admission.is_empty():
		return _failure(admission)
	var record := {"building_id": BUILDING_CHEST_ID, "stable_id": "building.chest.basic.%03d" % (_placed_chests.size() + 1), "position": position, "contents": {}}
	_placed_chests.append(record)
	_realize_chest(record)
	return {"success": true, "building_id": BUILDING_CHEST_ID, "stable_id": record.stable_id, "position": position, "diagnostics": []}

func _place_bed_at(position: Vector3) -> Dictionary:
	var admission := _validate_placement_admission(position)
	if not admission.is_empty():
		return _failure(admission)
	var record := {"building_id": BUILDING_BED_ID, "stable_id": "building.bed.basic.%03d" % (_placed_shelters.size() + 1), "position": position, "wood": 0, "stone": 0}
	_placed_shelters.append(record)
	_realize_shelter(record)
	return {"success": true, "building_id": BUILDING_BED_ID, "stable_id": record.stable_id, "position": position, "diagnostics": []}

func get_claimed_bed_respawn_position() -> Variant:
	if _claimed_bed_stable_id.is_empty():
		return null
	for bed in _placed_shelters:
		if str(bed.get("building_id", "")) == BUILDING_BED_ID and str(bed.get("stable_id", "")) == _claimed_bed_stable_id:
			var position: Variant = bed.get("position", null)
			return position if position is Vector3 and _is_finite_vector3(position) else null
	return null

func _validate_placement_admission(position: Vector3) -> Array[String]:
	var failures: Array[String] = []
	if not _build_tool_active or not _workbench_used:
		failures.append("use the workbench before selecting a building piece")
	if not _is_finite_vector3(position):
		failures.append("building placement position is not finite")
	return failures

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

func _realize_chest(record: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = str(record["stable_id"])
	body.set_meta("building_id", BUILDING_CHEST_ID)
	body.set_meta("stable_id", record["stable_id"])
	add_child(body)
	if is_inside_tree(): body.global_position = record["position"]
	else: body.position = record["position"]
	_add_box(body, Vector3(1.0, 0.8, 0.8), Color("70472e"))

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
