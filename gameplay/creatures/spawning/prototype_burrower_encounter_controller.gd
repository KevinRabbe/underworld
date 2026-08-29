extends Node3D
class_name UnderworldPrototypeBurrowerEncounterController

const EnemyScript := preload("res://gameplay/creatures/underworld/burrower/burrower.gd")
const CreatureDefinition := preload("res://gameplay/creatures/definitions/creature_definition.gd")
const BurrowerDefinition := preload("res://content/characters/creatures/prototype_burrower_definition.tres")

const TARGET_ENEMY_COUNT := 4
const SPAWN_MIN_DISTANCE := 18.0
const SPAWN_MAX_DISTANCE := 34.0
const SPAWN_INTERVAL := 2.0
const RELEASE_DISTANCE := 72.0

var world
var player
var settings
var active_enemies: Dictionary = {}
var spawn_timer: float = 0.0
var spawn_serial: int = 0
var creature_definition_ready: bool = false


func configure(world_node, player_node, world_settings) -> void:
	world = world_node
	player = player_node
	settings = world_settings
	spawn_timer = 0.25
	creature_definition_ready = _validate_burrower_definition()


func _process(delta: float) -> void:
	if world == null or player == null or settings == null or not creature_definition_ready:
		return

	_release_distant_or_invalid_enemies()
	spawn_timer = maxf(0.0, spawn_timer - delta)
	if active_enemies.size() < TARGET_ENEMY_COUNT and spawn_timer <= 0.0:
		spawn_timer = SPAWN_INTERVAL
		_spawn_enemy_near_player()


func get_active_enemy_count() -> int:
	return active_enemies.size()


func _spawn_enemy_near_player() -> void:
	if player == null or world == null or not creature_definition_ready:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = settings.world_seed + 9109 + spawn_serial * 7919
	spawn_serial += 1

	for _attempt in range(16):
		var angle: float = rng.randf_range(0.0, TAU)
		var distance: float = rng.randf_range(SPAWN_MIN_DISTANCE, SPAWN_MAX_DISTANCE)
		var candidate_x: float = player.global_position.x + cos(angle) * distance
		var candidate_z: float = player.global_position.z + sin(angle) * distance
		var sample: Dictionary = world.get_surface_sample_at_world(candidate_x, candidate_z)
		var height: float = float(sample["height"])
		var slope: float = float(sample["slope"])
		if height <= settings.sea_level + 1.0 or slope > 0.12:
			continue

		var spawn_position := Vector3(candidate_x, height + 0.2, candidate_z)
		if _is_too_close_to_other_enemy(spawn_position):
			continue

		var id: String = "burrower_%d" % spawn_serial
		var enemy = EnemyScript.new()
		enemy.configure(
			id,
			player,
			spawn_position,
			BurrowerDefinition.runtime_stats()
		)
		enemy.died.connect(_on_enemy_died)
		add_child(enemy)
		active_enemies[id] = enemy
		return


func _validate_burrower_definition() -> bool:
	if BurrowerDefinition == null or not BurrowerDefinition is CreatureDefinition:
		push_error("Burrower authored creature definition did not load as CreatureDefinition")
		return false
	var failures: Array[String] = BurrowerDefinition.validate_definition()
	if not failures.is_empty():
		push_error("Burrower authored creature definition is invalid: %s" % [failures])
		return false
	return true


func _release_distant_or_invalid_enemies() -> void:
	for id_variant in active_enemies.keys():
		var id: String = str(id_variant)
		var enemy_node: Node3D = active_enemies[id] as Node3D
		if enemy_node == null or not is_instance_valid(enemy_node):
			active_enemies.erase(id)
			continue
		if enemy_node.global_position.distance_to(player.global_position) > RELEASE_DISTANCE:
			enemy_node.queue_free()
			active_enemies.erase(id)


func _is_too_close_to_other_enemy(position: Vector3) -> bool:
	for enemy_variant in active_enemies.values():
		var enemy_node: Node3D = enemy_variant as Node3D
		if enemy_node != null and is_instance_valid(enemy_node):
			if enemy_node.global_position.distance_to(position) < 6.0:
				return true
	return false


func _on_enemy_died(enemy_id: String) -> void:
	active_enemies.erase(enemy_id)
	spawn_timer = maxf(spawn_timer, 6.0)
