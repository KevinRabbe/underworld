extends CharacterBody3D

signal harvest_requested(origin: Vector3, direction: Vector3, max_distance: float)
signal attack_requested(execution: Dictionary)
signal hotbar_slot_requested(slot: int)
signal craft_requested(recipe_id: String)
signal parry_succeeded(source_position: Vector3)

const PrototypeMannequinScript := preload("res://presentation/characters/player/prototype_mannequin/prototype_mannequin.gd")
const StaminaComponentScript := preload("res://gameplay/player/components/stamina_component.gd")
const PlayerActionControllerScript := preload("res://gameplay/player/actions/player_action_controller.gd")
const PlayerInputBufferScript := preload("res://gameplay/player/input/player_input_buffer.gd")
const AttackCatalogScript := preload("res://gameplay/combat/attacks/player_attack_catalog.gd")

const WALK_SPEED := 6.0
const SPRINT_SPEED := 10.0
const SPRINT_STAMINA_DRAIN := 12.0
const BLOCK_MOVE_SPEED := 2.4
const BLOCK_FRONT_DOT := 0.342
const PARRY_FRONT_DOT := 0.174
const BLOCK_STAMINA_BASE := 5.0
const BLOCK_STAMINA_PER_DAMAGE := 1.25
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
const MAX_HEALTH := 100
const DAMAGE_INVULNERABILITY := 0.45

var look_sensitivity: float = 0.0025
var camera_pitch: float = deg_to_rad(-12.0)
var camera_distance: float = DEFAULT_CAMERA_DISTANCE
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var respawn_position: Vector3 = Vector3.ZERO
var harvest_range: float = 4.5
var tool_use_cooldown_duration: float = 0.38
var tool_use_cooldown_timer: float = 0.0
var tool_swing_timer: float = 0.0
var damage_invulnerability_timer: float = 0.0
var health: int = MAX_HEALTH
var equipped_tool_visual: String = "hands"
var sprinting_this_frame: bool = false

var stamina := StaminaComponentScript.new(100.0, 0.75, 20.0)
var action_controller := PlayerActionControllerScript.new(stamina)
var input_buffer := PlayerInputBufferScript.new()
var pending_attack_definition
var pending_attack_direction: Vector3 = Vector3.ZERO

var visual_root: Node3D
var mannequin
var tool_visual_root: Node3D
var camera_yaw: Node3D
var camera_pitch_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D


func _ready() -> void:
	_ensure_default_input_actions()
	_configure_character_body()
	_build_character_visual()
	_build_camera()
	respawn_position = global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw.rotate_y(-event.relative.x * look_sensitivity)
		camera_pitch = clampf(
			camera_pitch - event.relative.y * look_sensitivity,
			CAMERA_MIN_PITCH,
			CAMERA_MAX_PITCH
		)
		camera_pitch_pivot.rotation.x = camera_pitch
		return

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				hotbar_slot_requested.emit(1)
				return
			KEY_2:
				hotbar_slot_requested.emit(2)
				return
			KEY_3:
				hotbar_slot_requested.emit(3)
				return
			KEY_C:
				craft_requested.emit("stone_axe")
				return
			KEY_V:
				craft_requested.emit("stone_pickaxe")
				return

	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			_request_harvest()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_request_attack()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_camera_distance(camera_distance - CAMERA_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_camera_distance(camera_distance + CAMERA_ZOOM_STEP)


func _physics_process(delta: float) -> void:
	damage_invulnerability_timer = maxf(0.0, damage_invulnerability_timer - delta)
	_handle_action_inputs()
	_update_jump_timers(delta)
	_update_vertical_velocity(delta)
	_update_horizontal_velocity(delta)
	move_and_slide()
	_update_visual_facing(delta)
	_update_mannequin(delta)
	_update_camera_fov(delta)
	_update_tool_use_feedback(delta)
	_check_fall_respawn()
	action_controller.tick(delta)
	_resolve_pending_attack_activation()
	input_buffer.tick(delta)
	_try_consume_buffered_action()
	stamina.tick(delta)


func set_respawn_position(position: Vector3) -> void:
	respawn_position = position


func set_harvest_range(distance: float) -> void:
	harvest_range = maxf(distance, 0.1)


func set_tool_use_cooldown(duration: float) -> void:
	tool_use_cooldown_duration = maxf(duration, 0.05)


func set_equipped_tool(tool_id: String) -> void:
	equipped_tool_visual = tool_id
	_rebuild_tool_visual()


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func get_health() -> int:
	return health


func get_max_health() -> int:
	return MAX_HEALTH


func get_stamina() -> float:
	return stamina.current_stamina


func get_max_stamina() -> float:
	return stamina.max_stamina


func get_action_state_name() -> String:
	return action_controller.state_name()


func get_buffered_action_name() -> String:
	return String(input_buffer.peek_action())


func is_dodge_iframe_active() -> bool:
	return action_controller.is_dodge_iframe_active()


func is_parry_active() -> bool:
	return action_controller.is_parry_active()


func is_blocking() -> bool:
	return action_controller.is_blocking()


func get_mannequin():
	return mannequin


func take_damage(amount: int, source_position: Vector3) -> void:
	receive_melee_attack(amount, source_position, true)


func receive_melee_attack(
	amount: int,
	source_position: Vector3,
	parryable: bool = true
) -> StringName:
	if amount <= 0:
		return &"ignored"
	if action_controller.is_dodge_iframe_active():
		return &"dodged"
	if (
		parryable
		and action_controller.is_parry_active()
		and _is_source_in_front_arc(source_position, PARRY_FRONT_DOT)
	):
		parry_succeeded.emit(source_position)
		return &"parried"
	if (
		action_controller.is_blocking()
		and _is_source_in_front_arc(source_position, BLOCK_FRONT_DOT)
	):
		var impact_cost: float = BLOCK_STAMINA_BASE + float(amount) * BLOCK_STAMINA_PER_DAMAGE
		if action_controller.try_absorb_block(impact_cost):
			return &"blocked"
	if damage_invulnerability_timer > 0.0:
		return &"ignored"
	_apply_damage(amount, source_position)
	return &"hit"


func _is_source_in_front_arc(source_position: Vector3, minimum_dot: float) -> bool:
	if visual_root == null:
		return false
	var to_source: Vector3 = source_position - global_position
	to_source.y = 0.0
	if to_source.is_zero_approx():
		return true
	var forward: Vector3 = visual_root.global_transform.basis.z
	forward.y = 0.0
	if forward.is_zero_approx():
		return false
	return forward.normalized().dot(to_source.normalized()) >= minimum_dot


func _apply_damage(amount: int, source_position: Vector3) -> void:
	damage_invulnerability_timer = DAMAGE_INVULNERABILITY
	health = maxi(health - amount, 0)
	if mannequin != null:
		mannequin.play_hit()

	var away: Vector3 = global_position - source_position
	away.y = 0.0
	if not away.is_zero_approx():
		away = away.normalized()
		velocity.x += away.x * 4.5
		velocity.z += away.z * 4.5

	if health <= 0:
		_respawn_after_defeat()


func _request_harvest() -> void:
	if not _begin_tool_action():
		return
	var ray: Dictionary = _get_camera_action_ray(harvest_range)
	harvest_requested.emit(ray["origin"], ray["direction"], ray["distance"])


func _request_attack() -> void:
	var intent: Dictionary = _build_attack_intent()
	if intent.is_empty():
		return
	if action_controller.is_free():
		_start_attack_from_intent(intent)
		return
	input_buffer.push(&"attack")


func _build_attack_intent() -> Dictionary:
	if camera == null:
		return {}
	var attack_definition = AttackCatalogScript.for_tool(equipped_tool_visual)
	if attack_definition == null or not bool(attack_definition.call("is_valid")):
		return {}
	var direction: Vector3 = _get_combat_forward()
	if direction.is_zero_approx():
		return {}
	return {
		"tool_id": equipped_tool_visual,
		"direction": direction,
	}


func _start_attack_from_intent(intent: Dictionary) -> bool:
	if not action_controller.is_free():
		return false
	var tool_id: String = str(intent.get("tool_id", "hands"))
	var direction: Vector3 = intent.get("direction", Vector3.ZERO)
	direction.y = 0.0
	if direction.is_zero_approx():
		return false
	direction = direction.normalized()

	var attack_definition = AttackCatalogScript.for_tool(tool_id)
	if attack_definition == null or not bool(attack_definition.call("is_valid")):
		return false
	if not action_controller.try_start_attack(
		float(attack_definition.get("startup")),
		float(attack_definition.get("active")),
		float(attack_definition.get("recovery"))
	):
		return false

	pending_attack_definition = attack_definition
	pending_attack_direction = direction
	_face_combat_direction(direction)
	var total_duration: float = float(attack_definition.call("total_duration"))
	tool_swing_timer = total_duration
	if mannequin != null:
		mannequin.play_attack(total_duration)
	return true


func _resolve_pending_attack_activation() -> void:
	if not action_controller.consume_attack_activation():
		return
	var attack_definition = pending_attack_definition
	var direction: Vector3 = pending_attack_direction
	pending_attack_definition = null
	pending_attack_direction = Vector3.ZERO
	if attack_definition == null:
		return
	var execution: Dictionary = attack_definition.call(
		"make_execution",
		global_position,
		direction
	)
	if execution.is_empty():
		return
	attack_requested.emit(execution)


func _try_consume_buffered_action() -> void:
	if not action_controller.is_free() or not input_buffer.has_pending():
		return
	var buffered_action: StringName = input_buffer.peek_action()
	if (
		(buffered_action == &"dodge" or buffered_action == &"parry")
		and not is_on_floor()
	):
		return

	var intent: Dictionary = input_buffer.consume()
	var payload: Dictionary = intent.get("payload", {})
	match StringName(intent.get("action", &"")):
		&"attack":
			var live_attack_intent: Dictionary = _build_attack_intent()
			if not live_attack_intent.is_empty():
				_start_attack_from_intent(live_attack_intent)
		&"dodge":
			_start_dodge(payload.get("direction", Vector3.ZERO))
		&"parry":
			_start_parry()


func _begin_tool_action() -> bool:
	if (
		camera == null
		or tool_use_cooldown_timer > 0.0
		or not action_controller.is_free()
	):
		return false
	if not action_controller.try_start_tool_action(tool_use_cooldown_duration):
		return false
	_face_combat_camera()
	tool_use_cooldown_timer = tool_use_cooldown_duration
	tool_swing_timer = tool_use_cooldown_duration
	if mannequin != null:
		mannequin.play_attack()
	return true


func _get_camera_action_ray(reach_from_player: float) -> Dictionary:
	var direction: Vector3 = -camera.global_transform.basis.z.normalized()
	var player_chest: Vector3 = global_position + Vector3(0.0, 1.0, 0.0)
	var camera_to_player: float = camera.global_position.distance_to(player_chest)
	return {
		"origin": camera.global_position,
		"direction": direction,
		"distance": camera_to_player + reach_from_player,
	}


func _handle_action_inputs() -> void:
	if action_controller.is_blocking():
		if not is_on_floor() or not Input.is_action_pressed("block"):
			action_controller.stop_block()
		if action_controller.is_blocking():
			_buffer_pressed_defensive_inputs()
			return

	if not action_controller.is_free():
		_buffer_pressed_defensive_inputs()
		return
	if not is_on_floor():
		return

	if Input.is_action_just_pressed("dodge"):
		if _start_dodge(_get_requested_dodge_direction()):
			return

	if Input.is_action_just_pressed("parry"):
		if _start_parry():
			return

	if Input.is_action_pressed("block") and action_controller.try_start_block():
		jump_buffer_timer = 0.0
		_face_combat_camera()


func _buffer_pressed_defensive_inputs() -> void:
	if not is_on_floor():
		return
	if Input.is_action_just_pressed("dodge"):
		var dodge_direction: Vector3 = _get_requested_dodge_direction()
		if not dodge_direction.is_zero_approx():
			input_buffer.push(&"dodge", {"direction": dodge_direction})
	if Input.is_action_just_pressed("parry"):
		input_buffer.push(&"parry")


func _get_requested_dodge_direction() -> Vector3:
	var input_vector: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_backward"
	)
	var dodge_direction: Vector3 = _camera_relative_direction(input_vector)
	if dodge_direction.is_zero_approx() and visual_root != null:
		dodge_direction = -visual_root.global_transform.basis.z
		dodge_direction.y = 0.0
	if dodge_direction.is_zero_approx():
		return Vector3.ZERO
	return dodge_direction.normalized()


func _start_dodge(dodge_direction: Vector3) -> bool:
	var horizontal := Vector3(dodge_direction.x, 0.0, dodge_direction.z)
	if horizontal.is_zero_approx():
		return false
	horizontal = horizontal.normalized()
	if not action_controller.try_start_dodge(horizontal):
		return false
	jump_buffer_timer = 0.0
	if mannequin != null and visual_root != null:
		var local: Vector3 = visual_root.global_transform.basis.inverse() * horizontal
		mannequin.play_dodge(Vector2(local.x, local.z))
	return true


func _start_parry() -> bool:
	if not action_controller.try_start_parry():
		return false
	jump_buffer_timer = 0.0
	_face_combat_camera()
	if mannequin != null:
		mannequin.play_parry()
	return true


func _update_tool_use_feedback(delta: float) -> void:
	tool_use_cooldown_timer = maxf(0.0, tool_use_cooldown_timer - delta)
	tool_swing_timer = maxf(0.0, tool_swing_timer - delta)


func _configure_character_body() -> void:
	collision_layer = 1
	collision_mask = 1 | 2
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50.0)
	floor_stop_on_slope = true
	floor_block_on_wall = true


func _update_jump_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)

	if Input.is_action_just_pressed("jump") and action_controller.is_free():
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)


func _update_vertical_velocity(delta: float) -> void:
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0 and action_controller.is_free():
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		return

	if not is_on_floor():
		velocity.y = maxf(velocity.y - GRAVITY * delta, -TERMINAL_VELOCITY)
	elif velocity.y < 0.0:
		velocity.y = 0.0


func _update_horizontal_velocity(delta: float) -> void:
	sprinting_this_frame = false

	if action_controller.is_dodging():
		var dodge_velocity: Vector3 = (
			action_controller.dodge_direction_world
			* action_controller.get_dodge_speed()
		)
		velocity.x = dodge_velocity.x
		velocity.z = dodge_velocity.z
		return

	if action_controller.is_parrying():
		velocity.x = move_toward(velocity.x, 0.0, GROUND_DECELERATION * 1.4 * delta)
		velocity.z = move_toward(velocity.z, 0.0, GROUND_DECELERATION * 1.4 * delta)
		return

	var input_vector: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)
	var move_direction: Vector3 = _camera_relative_direction(input_vector)
	var target_speed: float = BLOCK_MOVE_SPEED if action_controller.is_blocking() else WALK_SPEED
	if (
		is_on_floor()
		and action_controller.is_free()
		and not move_direction.is_zero_approx()
		and Input.is_action_pressed("sprint")
		and stamina.spend(SPRINT_STAMINA_DRAIN * delta)
	):
		target_speed = SPRINT_SPEED
		sprinting_this_frame = true

	var target_velocity: Vector3 = move_direction * target_speed
	var acceleration: float = GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	if is_on_floor() and move_direction.is_zero_approx():
		acceleration = GROUND_DECELERATION

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)


func _camera_relative_direction(input_vector: Vector2) -> Vector3:
	if input_vector.is_zero_approx():
		return Vector3.ZERO

	var forward: Vector3 = -camera_yaw.global_transform.basis.z
	var right: Vector3 = camera_yaw.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	return (right * input_vector.x + forward * -input_vector.y).normalized()


func _get_combat_forward() -> Vector3:
	if camera_yaw == null:
		return Vector3.ZERO
	var forward: Vector3 = -camera_yaw.global_transform.basis.z
	forward.y = 0.0
	if forward.is_zero_approx():
		return Vector3.ZERO
	return forward.normalized()


func _face_combat_camera() -> void:
	_face_combat_direction(_get_combat_forward())


func _face_combat_direction(direction: Vector3) -> void:
	if visual_root == null:
		return
	var forward := Vector3(direction.x, 0.0, direction.z)
	if forward.is_zero_approx():
		return
	forward = forward.normalized()
	visual_root.rotation.y = atan2(forward.x, forward.z)


func _update_visual_facing(delta: float) -> void:
	if (
		action_controller.is_dodging()
		or action_controller.is_parrying()
		or action_controller.is_blocking()
		or action_controller.is_attacking()
	):
		return
	var horizontal_velocity: Vector2 = Vector2(velocity.x, velocity.z)
	if horizontal_velocity.length_squared() < 0.04:
		return

	var target_yaw: float = atan2(velocity.x, velocity.z)
	visual_root.rotation.y = lerp_angle(
		visual_root.rotation.y,
		target_yaw,
		clampf(TURN_SPEED * delta, 0.0, 1.0)
	)


func _update_mannequin(delta: float) -> void:
	if mannequin == null or visual_root == null:
		return
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var local_velocity: Vector3 = visual_root.global_transform.basis.inverse() * horizontal_velocity
	mannequin.set_blocking(action_controller.is_blocking())
	mannequin.update_visual(delta, local_velocity, is_on_floor(), sprinting_this_frame)


func _update_camera_fov(delta: float) -> void:
	var target_fov: float = SPRINT_FOV if sprinting_this_frame else NORMAL_FOV
	camera.fov = lerpf(camera.fov, target_fov, clampf(6.0 * delta, 0.0, 1.0))


func _check_fall_respawn() -> void:
	if global_position.y >= RESPAWN_FALL_HEIGHT:
		return
	_respawn_after_defeat()


func _respawn_after_defeat() -> void:
	global_position = respawn_position
	velocity = Vector3.ZERO
	health = MAX_HEALTH
	damage_invulnerability_timer = 1.0
	stamina.reset()
	action_controller.reset()
	input_buffer.reset()
	pending_attack_definition = null
	pending_attack_direction = Vector3.ZERO
	if mannequin != null:
		mannequin.reset_pose()


func _build_character_visual() -> void:
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

	mannequin = PrototypeMannequinScript.new()
	mannequin.name = "PrototypeMannequin"
	visual_root.add_child(mannequin)
	mannequin.build()
	tool_visual_root = mannequin.get_tool_visual_root()
	_rebuild_tool_visual()


func _rebuild_tool_visual() -> void:
	if tool_visual_root == null:
		return
	for child in tool_visual_root.get_children():
		child.queue_free()

	if equipped_tool_visual == "hands":
		return

	var handle_material := StandardMaterial3D.new()
	handle_material.albedo_color = Color(0.30, 0.17, 0.07)
	var stone_material := StandardMaterial3D.new()
	stone_material.albedo_color = Color(0.36, 0.37, 0.34)

	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.10, 0.72, 0.10)
	handle.mesh = handle_mesh
	handle.material_override = handle_material
	tool_visual_root.add_child(handle)

	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	if equipped_tool_visual == "stone_axe":
		head_mesh.size = Vector3(0.38, 0.28, 0.13)
	else:
		head_mesh.size = Vector3(0.62, 0.16, 0.13)
	head.mesh = head_mesh
	head.material_override = stone_material
	head.position = Vector3(-0.10, 0.31, 0.0)
	head.rotation_degrees.z = -18.0
	tool_visual_root.add_child(head)


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
	_add_key_action("dodge", KEY_CTRL)
	_add_key_action("parry", KEY_Q)
	_add_key_action("block", KEY_F)


func _add_key_action(action_name: StringName, physical_key: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventKey and existing_event.physical_keycode == physical_key:
			return

	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_key
	InputMap.action_add_event(action_name, key_event)
