extends Node3D
class_name UnderworldCombatResolver

var player
var last_combat_message: String = "No threat nearby"


func configure(player_node) -> void:
	player = player_node


func try_attack(execution: Dictionary) -> void:
	if player == null or execution.is_empty():
		return

	var source_position: Vector3 = execution.get("source_position", player.global_position)
	var forward: Vector3 = execution.get("direction", Vector3.ZERO)
	forward.y = 0.0
	if forward.is_zero_approx():
		last_combat_message = "Attack missed"
		return
	forward = forward.normalized()

	var damage: int = clampi(int(execution.get("damage", 0)), 0, 10000)
	var reach: float = clampf(float(execution.get("reach", 0.0)), 0.1, 8.0)
	var center_distance: float = clampf(
		float(execution.get("center_distance", 0.0)),
		0.0,
		reach
	)
	var radius: float = clampf(float(execution.get("radius", 0.0)), 0.05, 3.0)
	var minimum_dot: float = clampf(float(execution.get("minimum_dot", 0.0)), -1.0, 1.0)
	if damage <= 0:
		last_combat_message = "Attack failed"
		return

	var source_chest: Vector3 = source_position + Vector3(0.0, 1.0, 0.0)
	var attack_center: Vector3 = source_chest + forward * center_distance

	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var shape_query := PhysicsShapeQueryParameters3D.new()
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
		var to_enemy: Vector3 = enemy_node.global_position - source_position
		var planar_to_enemy: Vector3 = Vector3(to_enemy.x, 0.0, to_enemy.z)
		var distance: float = planar_to_enemy.length()
		if distance > reach:
			continue
		if distance > 0.001 and forward.dot(planar_to_enemy / distance) < minimum_dot:
			continue
		if not _has_clear_attack_path(source_chest, enemy_node):
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

	var remaining_health: int = int(best_enemy.call("apply_damage", damage, source_position))
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


func get_last_combat_message() -> String:
	return last_combat_message


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
