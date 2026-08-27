extends Node3D

const EnemyScript := preload("res://combat/enemy.gd")

const TARGET_ENEMY_COUNT := 4
const SPAWN_MIN_DISTANCE := 18.0
const SPAWN_MAX_DISTANCE := 34.0
const SPAWN_INTERVAL := 2.0
const RELEASE_DISTANCE := 72.0
const PLAYER_ATTACK_REACH := 2.8
const PLAYER_ATTACK_CENTER_DISTANCE := 1.65
const PLAYER_ATTACK_RADIUS := 1.05
const PLAYER_ATTACK_MIN_DOT := 0.10

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

	_release_distant_or_invalid_enemies()
	spawn_timer = maxf(0.0, spawn_timer - delta)
	if active_enemies.size() < TARGET_ENEMY_COUNT and spawn_timer <= 0.0:
		spawn_timer = SPAWN_INTERVAL
		_spawn_enemy_near_player()


func try_attack(_origin: Vector3, direction: Vector3, _max_distance: float) -> void:
	if direction.is_zero_approx() or player == null:
		return

	var forward: Vector3 = direction.normalized()
	forward.y = 0.0
	if forward.is_zero_approx():
		last_combat_message = "Attack missed"
		return
	forward = forward.normalized()

	var player_chest: Vector3 = player.global_position + Vector3(0.0, 1.0, 0.0)
	var attack_center: Vector3 = player_chest + forward * PLAYER_ATTACK_CENTER_DISTANCE

	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = PLAYER_ATTACK_RADIUS
	var shape_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	shape_query.shape = sphere
	shape_query.transform = Transform3D(Basis.IDENTITY, attack_center)
	shape_query.collision_mask = 2
	shape_query.collide_with_bodies = true
	shape_query.collide_with_areas = false

	var player_collision: CollisionObject3D = player as CollisionObject3D
	if player_collision != null:
		shape_query.exclude = [player_collision.get_rid()]

	var candidates: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(
		shape_query,
		12
	)
	var best_enemy: Object = null
	var best_distance: float = 1.0e20

	for candidate in candidates:
		var collider: Object = candidate.get("collider")
		if collider == null or not collider.has_meta("combat_enemy"):
			continue
		if not collider is Node3D:
			continue

		var enemy_node: Node3D = collider as Node3D
		var to_enemy: Vector3 = enemy_node.global_position - player.global_position
		var planar_to_enemy: Vector3 = Vector3(to_enemy.x, 0.0, to_enemy.z)
		var distance: float = planar_to_enemy.length()
		if distance > PLAYER_ATTACK_REACH:
			continue
		if distance > 0.001 and forward.dot(planar_to_enemy / distance) < PLAYER_ATTACK_MIN_DOT:
			continue
		if not _has_clear_attack_path(player_chest, enemy_node):
			continue
		if distance < best_distance:
			best_distance = distance
			best_enemy = collider

	if best_enemy == null:
		last_combat_message = "Attack missed"
		return
	if not best_enemy.has_method("apply_damage"):
		last_combat_message = "Attack failed"
		return

	var damage: int = _get_player_attack_damage()
	var remaining_health: int = int(best_enemy.call("apply_damage", damage, player.global_position))
	var enemy_name: String = "Enemy"
	if best_enemy.has_method("get_display_name"):
		enemy_name = str(best_enemy.call("get_display_name"))

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


func _has_clear_attack_path(origin: Vector3, enemy: Node3D) -> bool:
	var target_position: Vector3 = enemy.global_position + Vector3(0.0, 0.65, 0.0)
	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin,
		target_position,
		1 | 2
	)
	var player_collision: CollisionObject3D = player as CollisionObject3D
	if player_collision != null:
		ray_query.exclude = [player_collision.get_rid()]
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray_query)
	if result.is_empty():
		return true
	return result.get("collider") == enemy


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
				"attack_range": 1.80,
				"attack_damage": 10,
				"attack_cooldown": 1.20,
				"attack_windup": 0.42,
			}
		)
		enemy.died.connect(_on_enemy_died)
		add_child(enemy)
		active_enemies[id] = enemy
		last_combat_message = "A Burrower is nearby"
		return


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
