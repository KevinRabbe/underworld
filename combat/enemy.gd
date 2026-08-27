extends CharacterBody3D

signal died(enemy_id: String)

const GRAVITY := 24.0
const TURN_SPEED := 8.0

var enemy_id: String = ""
var target: Node3D
var home_position: Vector3 = Vector3.ZERO
var max_health: int = 36
var health: int = 36
var move_speed: float = 3.3
var detection_range: float = 16.0
var attack_range: float = 1.55
var attack_damage: int = 10
var attack_cooldown: float = 1.15
var attack_timer: float = 0.0
var wander_timer: float = 0.0
var wander_target: Vector3 = Vector3.ZERO
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var dead: bool = false
var visual_root: Node3D


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

	if not is_on_floor():
		velocity.y = maxf(velocity.y - GRAVITY * delta, -45.0)
	elif velocity.y < 0.0:
		velocity.y = 0.0

	var desired_direction: Vector3 = Vector3.ZERO
	if is_instance_valid(target):
		var to_target: Vector3 = target.global_position - global_position
		var horizontal_distance: float = Vector2(to_target.x, to_target.z).length()
		if horizontal_distance <= detection_range:
			if horizontal_distance <= attack_range:
				_try_attack_target()
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
	_update_facing(delta)


func apply_damage(amount: int, source_position: Vector3) -> int:
	if dead or amount <= 0:
		return health

	health = maxi(health - amount, 0)
	var away: Vector3 = global_position - source_position
	away.y = 0.0
	if not away.is_zero_approx():
		away = away.normalized()
		velocity.x += away.x * 4.0
		velocity.z += away.z * 4.0

	if health <= 0:
		dead = true
		died.emit(enemy_id)
		queue_free()
	return health


func get_health() -> int:
	return health


func get_display_name() -> String:
	return "Burrower"


func _try_attack_target() -> void:
	if attack_timer > 0.0 or not is_instance_valid(target):
		return
	attack_timer = attack_cooldown
	if target.has_method("take_damage"):
		target.take_damage(attack_damage, global_position)


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
	body.scale = Vector3(1.25, 0.72, 1.45)
	var body_material: StandardMaterial3D = StandardMaterial3D.new()
	body_material.albedo_color = Color(0.25, 0.16, 0.10)
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
