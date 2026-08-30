extends CharacterBody3D

signal died(enemy_id: String)
signal attack_started(enemy_id: String, world_position: Vector3)
signal damage_committed(enemy_id: String, amount: int, remaining_health: int, world_position: Vector3)

const GRAVITY := 24.0
const TURN_SPEED := 8.0
const HIT_STAGGER_TIME := 0.20
const PARRY_STAGGER_TIME := 0.85
const HIT_FLASH_TIME := 0.12
const PARRY_FLASH_TIME := 0.20
const ATTACK_QUERY_HEIGHT := 0.65
const BODY_COLOR := Color(0.25, 0.16, 0.10)
const BODY_HIT_COLOR := Color(0.62, 0.25, 0.10)

var enemy_id: String = ""
var target: Node3D
var home_position: Vector3 = Vector3.ZERO
var max_health: int = 36
var health: int = 36
var move_speed: float = 3.3
var detection_range: float = 16.0
var attack_range: float = 1.80
var attack_damage: int = 10
var attack_cooldown: float = 1.20
var attack_windup_duration: float = 0.42
var attack_timer: float = 0.0
var attack_windup_timer: float = 0.0
var attack_pending: bool = false
var stagger_timer: float = 0.0
var parry_stagger_timer: float = 0.0
var hit_flash_timer: float = 0.0
var wander_timer: float = 0.0
var wander_target: Vector3 = Vector3.ZERO
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var dead: bool = false
var visual_root: Node3D
var body_material: StandardMaterial3D


func configure(
	id: String,
	player_target: Node3D,
	spawn_position: Vector3,
	stats: Dictionary = {}
) -> void:
	enemy_id = id
	target = player_target
	home_position = spawn_position
	position = spawn_position
	max_health = int(stats.get("health", max_health))
	health = max_health
	move_speed = float(stats.get("move_speed", move_speed))
	detection_range = float(stats.get("detection_range", detection_range))
	attack_range = float(stats.get("attack_range", attack_range))
	attack_damage = int(stats.get("attack_damage", attack_damage))
	attack_cooldown = float(stats.get("attack_cooldown", attack_cooldown))
	attack_windup_duration = float(stats.get("attack_windup", attack_windup_duration))
	rng.seed = enemy_id.hash()
	wander_target = home_position


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50.0)
	floor_stop_on_slope = true
	floor_block_on_wall = true
	set_meta("combat_enemy", true)
	set_meta("enemy_id", enemy_id)
	_build_placeholder_visual()
	_choose_wander_target()


func _physics_process(delta: float) -> void:
	if dead:
		return

	attack_timer = maxf(0.0, attack_timer - delta)
	wander_timer = maxf(0.0, wander_timer - delta)
	stagger_timer = maxf(0.0, stagger_timer - delta)
	parry_stagger_timer = maxf(0.0, parry_stagger_timer - delta)
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)

	if not is_on_floor():
		velocity.y = maxf(velocity.y - GRAVITY * delta, -45.0)
	elif velocity.y < 0.0:
		velocity.y = 0.0

	var desired_direction: Vector3 = Vector3.ZERO
	if stagger_timer > 0.0:
		_cancel_pending_attack()
	elif attack_pending:
		attack_windup_timer = maxf(0.0, attack_windup_timer - delta)
		_face_target(delta)
		if attack_windup_timer <= 0.0:
			_resolve_pending_attack()
	elif is_instance_valid(target):
		var to_target: Vector3 = target.global_position - global_position
		var horizontal_distance: float = Vector2(to_target.x, to_target.z).length()
		if horizontal_distance <= detection_range:
			if horizontal_distance <= attack_range:
				if attack_timer <= 0.0:
					_begin_attack()
			else:
				desired_direction = Vector3(to_target.x, 0.0, to_target.z).normalized()
		else:
			desired_direction = _get_wander_direction()
	else:
		desired_direction = _get_wander_direction()

	var target_velocity: Vector3 = desired_direction * move_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, 12.0 * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, 12.0 * delta)
	move_and_slide()
	if not attack_pending:
		_update_facing(delta)
	_update_visual_feedback(delta)


func apply_damage(amount: int, source_position: Vector3) -> int:
	if dead or amount <= 0:
		return health

	var previous_health: int = health
	health = maxi(health - amount, 0)
	var committed_damage: int = previous_health - health
	stagger_timer = HIT_STAGGER_TIME
	parry_stagger_timer = 0.0
	hit_flash_timer = HIT_FLASH_TIME
	_cancel_pending_attack()
	if committed_damage > 0:
		damage_committed.emit(enemy_id, committed_damage, health, global_position)

	var away: Vector3 = global_position - source_position
	away.y = 0.0
	if not away.is_zero_approx():
		away = away.normalized()
		velocity.x += away.x * 4.8
		velocity.z += away.z * 4.8

	if health <= 0:
		dead = true
		died.emit(enemy_id)
		queue_free()
	return health


func get_health() -> int:
	return health


func get_display_name() -> String:
	return "Burrower"


func is_winding_up_attack() -> bool:
	return attack_pending


func is_staggered() -> bool:
	return stagger_timer > 0.0


func is_parry_staggered() -> bool:
	return parry_stagger_timer > 0.0


func get_stagger_remaining() -> float:
	return stagger_timer


func _begin_attack() -> void:
	if not is_instance_valid(target):
		return
	attack_pending = true
	attack_windup_timer = maxf(attack_windup_duration, 0.05)
	attack_timer = attack_cooldown
	_face_target(1.0)
	attack_started.emit(enemy_id, global_position)


func _resolve_pending_attack() -> void:
	if not attack_pending:
		return
	attack_pending = false
	if not is_instance_valid(target):
		return
	var to_target: Vector3 = target.global_position - global_position
	var horizontal_distance: float = Vector2(to_target.x, to_target.z).length()
	if horizontal_distance > attack_range + 0.35:
		return
	if not _attack_path_is_clear():
		return

	if target.has_method("receive_melee_attack"):
		var result: Variant = target.call(
			"receive_melee_attack",
			attack_damage,
			global_position,
			true
		)
		if StringName(result) == &"parried":
			_apply_parry_reaction(target.global_position)
		return

	# Compatibility path for targets that predate the defensive melee contract.
	if target.has_method("take_damage"):
		target.call("take_damage", attack_damage, global_position)


func _attack_path_is_clear() -> bool:
	var query: PhysicsRayQueryParameters3D = _build_attack_ray_query()
	if query == null:
		return false
	var world := get_world_3d()
	if world == null or world.direct_space_state == null:
		return false
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return _collider_belongs_to_target(hit.get("collider", null))


func _build_attack_ray_query() -> PhysicsRayQueryParameters3D:
	if not is_inside_tree() or not is_instance_valid(target):
		return null
	var origin: Vector3 = global_position + Vector3.UP * ATTACK_QUERY_HEIGHT
	var target_point: Vector3 = target.global_position + Vector3.UP * ATTACK_QUERY_HEIGHT
	if origin.is_equal_approx(target_point):
		target_point += Vector3.FORWARD * 0.001
	var query := PhysicsRayQueryParameters3D.create(origin, target_point)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return query


func _collider_belongs_to_target(collider: Variant) -> bool:
	if collider == target:
		return true
	if collider is Node and target != null and target is Node:
		return target.is_ancestor_of(collider)
	return false


func _apply_parry_reaction(source_position: Vector3) -> void:
	stagger_timer = maxf(stagger_timer, PARRY_STAGGER_TIME)
	parry_stagger_timer = PARRY_STAGGER_TIME
	hit_flash_timer = maxf(hit_flash_timer, PARRY_FLASH_TIME)
	attack_timer = maxf(attack_timer, PARRY_STAGGER_TIME)
	_cancel_pending_attack()

	var away: Vector3 = global_position - source_position
	away.y = 0.0
	if not away.is_zero_approx():
		away = away.normalized()
		velocity.x += away.x * 6.2
		velocity.z += away.z * 6.2


func _cancel_pending_attack() -> void:
	attack_pending = false
	attack_windup_timer = 0.0


func _get_wander_direction() -> Vector3:
	if wander_timer <= 0.0 or global_position.distance_to(wander_target) < 1.4:
		_choose_wander_target()

	var to_wander: Vector3 = wander_target - global_position
	to_wander.y = 0.0
	if to_wander.length() < 0.4:
		return Vector3.ZERO
	return to_wander.normalized() * 0.55


func _choose_wander_target() -> void:
	wander_timer = rng.randf_range(2.5, 6.0)
	var angle: float = rng.randf_range(0.0, TAU)
	var distance: float = rng.randf_range(2.0, 8.0)
	wander_target = home_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)


func _face_target(delta: float) -> void:
	if not is_instance_valid(target) or visual_root == null:
		return
	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.001:
		return
	var target_yaw: float = atan2(to_target.x, to_target.z)
	visual_root.rotation.y = lerp_angle(
		visual_root.rotation.y,
		target_yaw,
		clampf(TURN_SPEED * delta, 0.0, 1.0)
	)


func _update_facing(delta: float) -> void:
	var planar_velocity: Vector2 = Vector2(velocity.x, velocity.z)
	if planar_velocity.length_squared() < 0.05 or visual_root == null:
		return
	var target_yaw: float = atan2(velocity.x, velocity.z)
	visual_root.rotation.y = lerp_angle(
		visual_root.rotation.y,
		target_yaw,
		clampf(TURN_SPEED * delta, 0.0, 1.0)
	)


func _update_visual_feedback(delta: float) -> void:
	if visual_root == null:
		return

	var target_scale: Vector3 = Vector3.ONE
	var target_pitch: float = 0.0
	if attack_pending:
		var progress: float = 1.0 - (
			attack_windup_timer / maxf(attack_windup_duration, 0.05)
		)
		progress = clampf(progress, 0.0, 1.0)
		target_scale = Vector3(1.0 + progress * 0.16, 1.0 - progress * 0.12, 1.0 + progress * 0.16)
		target_pitch = -12.0 * progress
	elif parry_stagger_timer > 0.0:
		target_scale = Vector3(0.86, 1.12, 0.90)
		target_pitch = 16.0
	elif stagger_timer > 0.0:
		target_scale = Vector3(0.92, 1.08, 0.92)
		target_pitch = 7.0

	visual_root.scale = visual_root.scale.lerp(
		target_scale,
		clampf(delta * 18.0, 0.0, 1.0)
	)
	visual_root.rotation_degrees.x = lerpf(
		visual_root.rotation_degrees.x,
		target_pitch,
		clampf(delta * 20.0, 0.0, 1.0)
	)

	if body_material != null:
		body_material.albedo_color = BODY_HIT_COLOR if hit_flash_timer > 0.0 else BODY_COLOR


func _build_placeholder_visual() -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 1.15
	collision.shape = capsule
	collision.position.y = 0.58
	add_child(collision)

	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)

	var body: MeshInstance3D = MeshInstance3D.new()
	var body_mesh: CapsuleMesh = CapsuleMesh.new()
	body_mesh.radius = 0.55
	body_mesh.height = 1.15
	body.mesh = body_mesh
	body.position.y = 0.58
	body.scale = Vector3(1.18, 0.72, 1.30)
	body_material = StandardMaterial3D.new()
	body_material.albedo_color = BODY_COLOR
	body_material.roughness = 1.0
	body.material_override = body_material
	visual_root.add_child(body)

	var eye_material: StandardMaterial3D = StandardMaterial3D.new()
	eye_material.albedo_color = Color(0.78, 0.18, 0.06)
	eye_material.emission_enabled = true
	eye_material.emission = Color(0.55, 0.06, 0.02)
	eye_material.emission_energy_multiplier = 1.6

	for side in [-1.0, 1.0]:
		var eye: MeshInstance3D = MeshInstance3D.new()
		var eye_mesh: SphereMesh = SphereMesh.new()
		eye_mesh.radius = 0.09
		eye_mesh.height = 0.18
		eye.mesh = eye_mesh
		eye.position = Vector3(0.23 * side, 0.78, 0.58)
		eye.material_override = eye_material
		visual_root.add_child(eye)

	for side in [-1.0, 1.0]:
		var claw: MeshInstance3D = MeshInstance3D.new()
		var claw_mesh: BoxMesh = BoxMesh.new()
		claw_mesh.size = Vector3(0.16, 0.12, 0.72)
		claw.mesh = claw_mesh
		claw.position = Vector3(0.62 * side, 0.28, 0.15)
		claw.rotation_degrees.y = 18.0 * side
		claw.material_override = body_material
		visual_root.add_child(claw)
