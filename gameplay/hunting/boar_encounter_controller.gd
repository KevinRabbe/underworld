extends Node3D

signal boar_spawned(boar_id: String, world_position: Vector3)
signal boar_died(boar_id: String, world_position: Vector3)
signal skinning_result(result: Dictionary)

const BoarScript := preload("res://gameplay/creatures/overworld/boar.gd")
const CarcassScript := preload("res://gameplay/hunting/carcass.gd")
const SkinningService := preload("res://gameplay/hunting/skinning/skinning_service.gd")
const SNAPSHOT_SCHEMA := "hunting.skinning.v1"

var world
var player
var settings
var active_boar: Node3D = null
var carcasses: Dictionary = {}
var _serial := 0
var _skinning_service = null


func configure(world_node, player_node, world_settings, survival_controller = null) -> void:
	world = world_node
	player = player_node
	settings = world_settings
	if survival_controller != null and survival_controller.has_method("get_inventory_state"):
		_skinning_service = SkinningService.new().configure(
			survival_controller.get_inventory_state(),
			survival_controller.get_equipment_state(),
			survival_controller.get_item_definitions()
		)
	_spawn_initial_boar()


func configure_skinning_service(survival_controller) -> void:
	if survival_controller == null or not survival_controller.has_method("get_inventory_state"):
		return
	_skinning_service = SkinningService.new().configure(
		survival_controller.get_inventory_state(),
		survival_controller.get_equipment_state(),
		survival_controller.get_item_definitions()
	)


func _process(_delta: float) -> void:
	if active_boar == null or not is_instance_valid(active_boar):
		return
	if player != null and active_boar.global_position.distance_to(player.global_position) > 90.0:
		active_boar.queue_free()
		active_boar = null


func get_active_boar_count() -> int:
	return 1 if active_boar != null and is_instance_valid(active_boar) else 0


func get_carcass(carcass_id: String):
	return carcasses.get(carcass_id, null)


func skin_carcass(carcass_id: String, distance: float = INF) -> Dictionary:
	var carcass = carcasses.get(carcass_id, null)
	if carcass == null or not is_instance_valid(carcass):
		return _failure(["carcass is not present: %s" % carcass_id])
	if distance > 3.0:
		return _failure(["carcass is out of skinning range"])
	if _skinning_service == null:
		return _failure(["skinning service is not configured"])
	var result: Dictionary = _skinning_service.skin_carcass(carcass_id, carcass.is_consumed())
	if bool(result.get("success", false)) and carcass.mark_skinned():
		skinning_result.emit(result)
	else:
		if bool(result.get("success", false)):
			return _failure(["carcass consumption changed before skinning commit"])
	return result


func progression_snapshot() -> Dictionary:
	return {} if _skinning_service == null else _skinning_service.progression_snapshot()


func durable_snapshot() -> Dictionary:
	var saved_carcasses: Array = []
	for key in carcasses.keys():
		var carcass = carcasses[key]
		if carcass == null or not is_instance_valid(carcass):
			continue
		saved_carcasses.append({
			"carcass_id": str(carcass.carcass_id),
			"x": carcass.global_position.x,
			"y": carcass.global_position.y,
			"z": carcass.global_position.z,
			"consumed": carcass.is_consumed(),
		})
	saved_carcasses.sort_custom(func(a, b): return str(a.get("carcass_id", "")) < str(b.get("carcass_id", "")))
	return {"schema": SNAPSHOT_SCHEMA, "boar_alive": active_boar != null and is_instance_valid(active_boar), "progression": progression_snapshot(), "carcasses": saved_carcasses}


func restore_durable_snapshot(snapshot: Dictionary) -> Dictionary:
	if str(snapshot.get("schema", SNAPSHOT_SCHEMA)) != SNAPSHOT_SCHEMA:
		return _failure(["unsupported hunting snapshot schema"])
	if _skinning_service != null:
		var progression: Dictionary = _skinning_service.restore_progression(snapshot.get("progression", {}))
		if not bool(progression.get("success", false)):
			return progression
	if snapshot.has("boar_alive") and not bool(snapshot.get("boar_alive", true)):
		if active_boar != null and is_instance_valid(active_boar):
			active_boar.queue_free()
		active_boar = null
	for raw_entry in snapshot.get("carcasses", []):
		if not raw_entry is Dictionary:
			return _failure(["hunting snapshot carcass entry must be Dictionary"])
		var id := str(raw_entry.get("carcass_id", ""))
		if id.is_empty() or carcasses.has(id):
			continue
		var carcass := CarcassScript.new()
		carcass.configure(id, Vector3(float(raw_entry.get("x", 0.0)), float(raw_entry.get("y", 0.0)), float(raw_entry.get("z", 0.0))))
		add_child(carcass)
		carcasses[id] = carcass
		if bool(raw_entry.get("consumed", false)):
			carcass.mark_skinned()
	return {"success": true, "diagnostics": []}


func _spawn_initial_boar() -> void:
	if player == null or world == null or active_boar != null:
		return
	var origin: Vector3 = player.global_position + Vector3(0.0, 0.0, -8.0)
	if world.has_method("get_height_at_world"):
		origin.y = float(world.get_height_at_world(origin.x, origin.z)) + 0.2
	_serial += 1
	var id := "boar_%d" % _serial
	var boar: CharacterBody3D = BoarScript.new()
	boar.configure(id, player, origin, {"health": 48, "move_speed": 2.6, "detection_range": 14.0, "attack_range": 1.7, "attack_damage": 8, "attack_cooldown": 1.4, "attack_windup": 0.5})
	boar.died.connect(_on_boar_died.bind(id))
	add_child(boar)
	active_boar = boar
	boar_spawned.emit(id, origin)


func _on_boar_died(boar_id: String, death_position: Vector3) -> void:
	if active_boar != null and is_instance_valid(active_boar):
		active_boar = null
	var carcass := CarcassScript.new()
	carcass.configure("carcass.%s" % boar_id, death_position)
	add_child(carcass)
	carcasses[carcass.carcass_id] = carcass
	boar_died.emit(boar_id, death_position)


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {"success": false, "diagnostics": diagnostics, "events": []}
