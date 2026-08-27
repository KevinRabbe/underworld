extends Node3D

const EnemyScript := preload("res://combat/enemy.gd")

const TARGET_ENEMY_COUNT := 4
const SPAWN_MIN_DISTANCE := 18.0
const SPAWN_MAX_DISTANCE := 34.0
const SPAWN_INTERVAL := 2.0
const PLAYER_ATTACK_REACH := 2.7

var world
var player
var settings: UnderworldWorldSettings
var active_enemies: Dictionary = {}
var spawn_timer: float = 0.0
var spawn_serial: int = 0
var last_combat_message: String = "No threat nearby"


func configure(world_node, player_node, world_settings: UnderworldWorldSettings) -> void:
	world = world_node
	player = player_node
	settings = world_settings
	spawn_timer = 0.25


func _process(delta: float) -> void:
	if world == null or player == null or settings == null:
		return

	spawn_timer = maxf(0.0, spawn_timer - delta)
	if active_enemies.size() < TARGET_ENEMY_COUNT and spawn_timer <= 0.0:
		spawn_timer = SPAWN_INTERVAL
		_spawn_enemy_near_player()


func try_attack(origin: Vector3, direction: Vector3, max_distance: float) -> void:
	if direction.is_zero_approx() or player == null:
		return

	var ray_end: Vector3 = origin + direction.normalized() * maxf(max_distance, 0.1)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin,
		ray_end,
		1 | 2
	)
	var player_collision: CollisionObject3D = player as CollisionObject3D
	if player_collision != null:
		query.exclude = [player_collision.get_rid()]

	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		last_combat_message = "Attack missed"
		return

	var collider: Object = result.get("collider")
	if collider == null or not collider.has_meta("combat_enemy"):
		last_combat_message = "Attack blocked"
		return

	var hit_position: Vector3 = result.get("position", collider.global_position)
	var player_chest: Vector3 = player.global_position + Vector3(0.0, 1.0, 0.0)
	if player_chest.distance_to(hit_position) > PLAYER_ATTACK_REACH + 0.8:
		last_combat_message = "Enemy out of reach"
		return

	if not collider.has_method("apply_damage"):
		last_combat_message = "Attack failed"
		return

	var damage: int = _get_player_attack_damage()
	var remaining_health: int = collider.apply_damage(damage, player.global_position)
	var enemy_name: String = "Enemy"
	if collider.has_method("get_display_name"):
		enemy_name = collider.get_display_name()

	if remaining_health <= 0:
		last_combat_message = "%s defeated" % enemy_name
	else:
		last_combat_message = "%s hit -%d  (%d HP)" % [
			enemy_name,
			damage,
			remaining_health,
		]


func get_active_enemy_count() -> int:
	return active_enemies.size()


func get_last_combat_message() -> String:
	return last_combat_message


func _get_player_attack_damage() -> int:
	if world == null or not world.has_method("get_equipped_tool"):
		return 7
	match world.get_equipped_tool():
		"stone_axe":
			return 16
		"stone_pickaxe":
			return 13
		_:
			return 7


func _spawn_enemy_near_player() -> void:
	if player == null or world == null:
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
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

		var spawn_position: Vector3 = Vector3(candidate_x, height + 0.2, candidate_z)
		if _is_too_close_to_other_enemy(spawn_position):
			continue

		var id: String = "burrower_%d" % spawn_serial
		var enemy = EnemyScript.new()
		enemy.configure(
			id,
			player,
			spawn_position,
			{
				"health": 36,
				"move_speed": 3.3,
				"detection_range": 16.0,
				"attack_range": 1.55,
				"attack_damage": 10,
				"attack_cooldown": 1.15,
			}
		)
		enemy.died.connect(_on_enemy_died)
		add_child(enemy)
		active_enemies[id] = enemy
		last_combat_message = "A Burrower is nearby"
		return


func _is_too_close_to_other_enemy(position: Vector3) -> bool:
	for enemy in active_enemies.values():
		if is_instance_valid(enemy) and enemy.global_position.distance_to(position) < 6.0:
			return true
	return false


func _on_enemy_died(enemy_id: String) -> void:
	active_enemies.erase(enemy_id)
	spawn_timer = maxf(spawn_timer, 6.0)
