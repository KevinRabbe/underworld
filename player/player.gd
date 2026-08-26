extends CharacterBody3D

signal harvest_requested(origin: Vector3, direction: Vector3, max_distance: float)

const WALK_SPEED := 6.0
const SPRINT_SPEED := 10.0
const GROUND_ACCELERATION := 30.0
const GROUND_DECELERATION := 38.0
const AIR_ACCELERATION := 7.0
const JUMP_VELOCITY := 7.0
const GRAVITY := 24.0
const TERMINAL_VELOCITY := 55.0
const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12
const TURN_SPEED := 12.0
const CAMERA_MIN_PITCH := deg_to_rad(-70.0)
const CAMERA_MAX_PITCH := deg_to_rad(45.0)
const CAMERA_MIN_DISTANCE := 2.5
const CAMERA_MAX_DISTANCE := 7.0
const CAMERA_ZOOM_STEP := 0.5
const DEFAULT_CAMERA_DISTANCE := 4.5
const NORMAL_FOV := 75.0
const SPRINT_FOV := 79.0
const RESPAWN_FALL_HEIGHT := -100.0

var look_sensitivity := 0.0025
var camera_pitch := deg_to_rad(-12.0)
var camera_distance := DEFAULT_CAMERA_DISTANCE
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var respawn_position := Vector3.ZERO
var harvest_range: float = 4.5

var visual_root: Node3D
var camera_yaw: Node3D
var camera_pitch_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D


func _ready() -> void:
	_ensure_default_input_actions()
	_configure_character_body()
	_build_placeholder_body()
	_build_camera()
	respawn_position = global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw.rotate_y(-event.relative.x * look_sensitivity)
		camera_pitch = clamp(
			camera_pitch - event.relative.y * look_sensitivity,
			CAMERA_MIN_PITCH,
			CAMERA_MAX_PITCH
		)
		camera_pitch_pivot.rotation.x = camera_pitch
		return

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			_request_harvest()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_camera_distance(camera_distance - CAMERA_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_camera_distance(camera_distance + CAMERA_ZOOM_STEP)


func _physics_process(delta: float) -> void:
	_update_jump_timers(delta)
	_update_vertical_velocity(delta)
	_update_horizontal_velocity(delta)
	move_and_slide()
	_update_visual_facing(delta)
	_update_camera_fov(delta)
	_check_fall_respawn()


func set_respawn_position(position: Vector3) -> void:
	respawn_position = position


func set_harvest_range(distance: float) -> void:
	harvest_range = maxf(distance, 0.1)


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _request_harvest() -> void:
	if camera == null:
		return
	var direction: Vector3 = -camera.global_transform.basis.z.normalized()
	harvest_requested.emit(camera.global_position, direction, harvest_range)


func _configure_character_body() -> void:
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50.0)
	floor_stop_on_slope = true
	floor_block_on_wall = true


func _update_jump_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)


func _update_vertical_velocity(delta: float) -> void:
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		return

	if not is_on_floor():
		velocity.y = maxf(velocity.y - GRAVITY * delta, -TERMINAL_VELOCITY)
	elif velocity.y < 0.0:
		velocity.y = 0.0


func _update_horizontal_velocity(delta: float) -> void:
	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)
	var move_direction := _camera_relative_direction(input_vector)
	var target_speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var target_velocity := move_direction * target_speed

	var acceleration := GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	if is_on_floor() and move_direction.is_zero_approx():
		acceleration = GROUND_DECELERATION

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)


func _camera_relative_direction(input_vector: Vector2) -> Vector3:
	if input_vector.is_zero_approx():
		return Vector3.ZERO

	var forward := -camera_yaw.global_transform.basis.z
	var right := camera_yaw.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	return (right * input_vector.x + forward * -input_vector.y).normalized()


func _update_visual_facing(delta: float) -> void:
	var horizontal_velocity := Vector2(velocity.x, velocity.z)
	if horizontal_velocity.length_squared() < 0.04:
		return

	var target_yaw := atan2(velocity.x, velocity.z)
	visual_root.rotation.y = lerp_angle(
		visual_root.rotation.y,
		target_yaw,
		clampf(TURN_SPEED * delta, 0.0, 1.0)
	)


func _update_camera_fov(delta: float) -> void:
	var sprinting := Input.is_action_pressed("sprint") and get_horizontal_speed() > WALK_SPEED
	var target_fov := SPRINT_FOV if sprinting else NORMAL_FOV
	camera.fov = lerpf(camera.fov, target_fov, clampf(6.0 * delta, 0.0, 1.0))


func _check_fall_respawn() -> void:
	if global_position.y >= RESPAWN_FALL_HEIGHT:
		return

	global_position = respawn_position
	velocity = Vector3.ZERO


func _build_placeholder_body() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.45
	capsule_shape.height = 1.8
	collision.shape = capsule_shape
	collision.position.y = 0.9
	add_child(collision)

	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)

	var body_mesh := MeshInstance3D.new()
	body_mesh.name = "PlaceholderBody"
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.45
	capsule_mesh.height = 1.8
	body_mesh.mesh = capsule_mesh
	body_mesh.position.y = 0.9

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.65, 0.67, 0.72)
	body_mesh.material_override = material
	visual_root.add_child(body_mesh)

	# A small forward marker makes movement/facing obvious while we still use a capsule.
	var facing_marker := MeshInstance3D.new()
	facing_marker.name = "FacingMarker"
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.18, 0.18, 0.5)
	facing_marker.mesh = marker_mesh
	facing_marker.position = Vector3(0.0, 1.1, 0.45)
	facing_marker.material_override = material
	visual_root.add_child(facing_marker)


func _build_camera() -> void:
	camera_yaw = Node3D.new()
	camera_yaw.name = "CameraYaw"
	camera_yaw.position = Vector3(0.0, 1.55, 0.0)
	add_child(camera_yaw)

	camera_pitch_pivot = Node3D.new()
	camera_pitch_pivot.name = "CameraPitch"
	camera_pitch_pivot.rotation.x = camera_pitch
	camera_yaw.add_child(camera_pitch_pivot)

	spring_arm = SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	spring_arm.spring_length = camera_distance
	spring_arm.margin = 0.15
	spring_arm.collision_mask = 1
	var camera_collision_shape := SphereShape3D.new()
	camera_collision_shape.radius = 0.2
	spring_arm.shape = camera_collision_shape
	spring_arm.add_excluded_object(get_rid())
	camera_pitch_pivot.add_child(spring_arm)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.fov = NORMAL_FOV
	spring_arm.add_child(camera)


func _set_camera_distance(distance: float) -> void:
	camera_distance = clampf(distance, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
	if spring_arm != null:
		spring_arm.spring_length = camera_distance


func _ensure_default_input_actions() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_backward", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("sprint", KEY_SHIFT)


func _add_key_action(action_name: StringName, physical_key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventKey and existing_event.physical_keycode == physical_key:
			return

	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_key
	InputMap.action_add_event(action_name, key_event)
