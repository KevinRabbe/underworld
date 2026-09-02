extends CharacterBody3D

signal harvest_requested(origin: Vector3, direction: Vector3, max_distance: float)
signal attack_requested(execution: Dictionary)
signal hotbar_slot_requested(slot: int)
signal craft_requested(recipe_id: String)
signal parry_succeeded(source_position: Vector3)
signal damage_committed(amount: int, remaining_health: int, source_position: Vector3)
signal defeat_requested(reason: StringName)

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
const POST_RESPAWN_INVULNERABILITY := 1.0
const DEFEAT_REASON_DAMAGE: StringName = &"damage"
const DEFEAT_REASON_FALL: StringName = &"fall"
const TOOL_HAND_RIG_ROLE := "rig_role.socket.hand.right"

var look_sensitivity: float = 0.0025
var camera_pitch: float = deg_to_rad(-12.0)
var camera_distance: float = DEFAULT_CAMERA_DISTANCE
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var harvest_range: float = 4.5
var tool_use_cooldown_duration: float = 0.38
var tool_use_cooldown_timer: float = 0.0
var tool_swing_timer: float = 0.0
var damage_invulnerability_timer: float = 0.0
var health: int = MAX_HEALTH
var equipped_tool_visual: String = "hands"
var sprinting_this_frame: bool = false
var defeated: bool = false
var _defeat_reason: StringName = &""

var stamina := StaminaComponentScript.new(100.0, 0.75, 20.0)
var action_controller := PlayerActionControllerScript.new(stamina)
var input_buffer := PlayerInputBufferScript.new()
var pending_attack_definition
var pending_attack_direction: Vector3 = Vector3.ZERO
var equipped_weapon_definition
var equipped_weapon_attack_set
var equipped_weapon_attack_resolver

var visual_root: Node3D
var character_presentation_provider
var character_presentation
var animation_controller
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
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if defeated:
		return
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

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if event.is_action_pressed("attack_light"):
		_request_attack(false)
		return
	if event.is_action_pressed("attack_heavy"):
		_request_attack(true)
		return
	if event.is_action_pressed("hotbar_slot_1"):
		hotbar_slot_requested.emit(1)
		return
	if event.is_action_pressed("hotbar_slot_2"):
		hotbar_slot_requested.emit(2)
		return
	if event.is_action_pressed("hotbar_slot_3"):
		hotbar_slot_requested.emit(3)
		return
	if event.is_action_pressed("hotbar_slot_4"):
		hotbar_slot_requested.emit(4)
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_C:
				craft_requested.emit("stone_axe")
				return
			KEY_V:
				craft_requested.emit("stone_pickaxe")
				return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_request_harvest()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_camera_distance(camera_distance - CAMERA_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_camera_distance(camera_distance + CAMERA_ZOOM_STEP)


func _physics_process(delta: float) -> void:
	if defeated:
		velocity = Vector3.ZERO
		sprinting_this_frame = false
		return
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


func set_harvest_range(distance: float) -> void:
	harvest_range = maxf(distance, 0.1)


func set_tool_use_cooldown(duration: float) -> void:
	tool_use_cooldown_duration = maxf(duration, 0.05)


func set_equipped_tool(tool_id: String) -> void:
	equipped_tool_visual = tool_id
	configure_equipped_weapon_attack_source(null, null, null)
	_rebuild_tool_visual()


func configure_equipped_weapon_attack_source(weapon, attack_set, resolver) -> void:
	equipped_weapon_definition = weapon
	equipped_weapon_attack_set = attack_set
	equipped_weapon_attack_resolver = resolver


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


func is_defeated() -> bool:
	return defeated


func get_defeat_reason() -> StringName:
	return _defeat_reason


func get_mannequin():
	# Compatibility name retained for existing gameplay/regression callers.
	return character_presentation


func take_damage(amount: int, source_position: Vector3) -> void:
	receive_melee_attack(amount, source_position, true)


func receive_melee_attack(
	amount: int,
	source_position: Vector3,
	parryable: bool = true
) -> StringName:
	if defeated or amount <= 0:
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
	# Gameplay front-arc follows the authored character face: local -Z.
	var forward: Vector3 = -visual_root.global_transform.basis.z
	forward.y = 0.0
	if forward.is_zero_approx():
		return false
	return forward.normalized().dot(to_source.normalized()) >= minimum_dot


func _apply_damage(amount: int, source_position: Vector3) -> void:
	if defeated:
		return
	damage_invulnerability_timer = DAMAGE_INVULNERABILITY
	var previous_health: int = health
	health = maxi(health - amount, 0)
	var committed_damage: int = previous_health - health
	if committed_damage > 0:
		damage_committed.emit(committed_damage, health, source_position)
	if animation_controller != null:
		animation_controller.present_hit()

	var away: Vector3 = global_position - source_position
	away.y = 0.0
	if not away.is_zero_approx():
		away = away.normalized()
		velocity.x += away.x * 4.5
		velocity.z += away.z * 4.5

	if health <= 0:
		_enter_defeated(DEFEAT_REASON_DAMAGE)


func _request_harvest() -> void:
	if defeated or not _begin_tool_action():
		return
	var ray: Dictionary = _get_camera_action_ray(harvest_range)
	harvest_requested.emit(ray["origin"], ray["direction"], ray["distance"])


func _request_attack(heavy: bool = false) -> void:
	if defeated:
		return
	var intent: Dictionary = _build_attack_intent(heavy)
	if intent.is_empty():
		return
	if action_controller.is_free():
		_start_attack_from_intent(intent)
		return
	_queue_buffered_action(&"attack", intent, 0.16)


func _build_attack_intent(heavy: bool = false) -> Dictionary:
	if defeated or camera == null:
		return {}
	var attack_kind: StringName = &"heavy" if heavy else &"light"
	var attack_definition = _resolve_attack_definition(equipped_tool_visual, attack_kind)
	if attack_definition == null or not bool(attack_definition.call("is_valid")):
		return {}
	var direction: Vector3 = _get_combat_forward()
	if direction.is_zero_approx():
		return {}
	var source_signature: String = _current_attack_source_signature()
	if source_signature.is_empty():
		return {}
	return {
		"tool_id": equipped_tool_visual,
		"direction": direction,
		"attack_kind": attack_kind,
		"attack_definition": attack_definition,
		"source_signature": source_signature,
	}


func _start_attack_from_intent(intent: Dictionary, require_current_source: bool = false) -> bool:
	if defeated or not action_controller.is_free():
		return false
	var source_signature: String = str(intent.get("source_signature", ""))
	if require_current_source and (
		source_signature.is_empty()
		or source_signature != _current_attack_source_signature()
	):
		return false
	var direction: Vector3 = intent.get("direction", Vector3.ZERO)
	var attack_kind: StringName = StringName(intent.get("attack_kind", &"light"))
	direction.y = 0.0
	if direction.is_zero_approx():
		return false
	direction = direction.normalized()

	var attack_definition = intent.get("attack_definition", null)
	if attack_definition == null or not bool(attack_definition.call("is_valid")):
		return false
	if not action_controller.try_start_attack_profile(
		float(attack_definition.get("startup")),
		float(attack_definition.get("active")),
		float(attack_definition.get("recovery")),
		attack_kind,
		float(attack_definition.get("stamina_cost"))
	):
		return false

	pending_attack_definition = attack_definition
	pending_attack_direction = direction
	_face_combat_direction(direction)
	var total_duration: float = float(attack_definition.call("total_duration"))
	tool_swing_timer = total_duration
	if animation_controller != null:
		animation_controller.present_attack(total_duration, attack_kind)
	return true


func _resolve_pending_attack_activation() -> void:
	if defeated or not action_controller.consume_attack_activation():
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


func _resolve_attack_definition(tool_id: String, attack_kind: StringName):
	if (
		equipped_weapon_definition != null
		and equipped_weapon_attack_set != null
		and equipped_weapon_attack_resolver != null
	):
		var technique_role: String = str(equipped_weapon_definition.primary_technique_role)
		if attack_kind == &"heavy":
			technique_role = "weapon_technique.heavy.primary"
		var resolved: Dictionary = equipped_weapon_attack_resolver.resolve_attack(
			equipped_weapon_definition,
			equipped_weapon_attack_set,
			technique_role
		)
		return resolved.get("attack_definition", null)
	return AttackCatalogScript.for_tool(tool_id, attack_kind)


func _current_attack_source_signature() -> String:
	if (
		equipped_weapon_definition != null
		and equipped_weapon_attack_set != null
		and equipped_weapon_attack_resolver != null
	):
		var weapon_id: String = str(equipped_weapon_definition.get("content_id"))
		var attack_set_id: String = str(equipped_weapon_attack_set.get("content_id"))
		if weapon_id.is_empty() or attack_set_id.is_empty():
			return ""
		return "weapon:%s|attack_set:%s" % [weapon_id, attack_set_id]
	if equipped_tool_visual.is_empty():
		return ""
	return "tool:%s" % equipped_tool_visual


func _queue_buffered_action(
	action: StringName,
	payload: Dictionary = {},
	lifetime: float = PlayerInputBufferScript.DEFAULT_LIFETIME
) -> bool:
	if defeated or not action_controller.can_replace_buffered_action(action, input_buffer.peek_action()):
		return false
	return input_buffer.push(action, payload, lifetime)


func _try_consume_buffered_action() -> void:
	if defeated or not action_controller.is_free() or not input_buffer.has_pending():
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
			_start_attack_from_intent(payload, true)
		&"dodge":
			_start_dodge(payload.get("direction", Vector3.ZERO))
		&"parry":
			_start_parry()


func _begin_tool_action() -> bool:
	if (
		defeated
		or camera == null
		or tool_use_cooldown_timer > 0.0
		or not action_controller.is_free()
	):
		return false
	if not action_controller.try_start_tool_action(tool_use_cooldown_duration):
		return false
	_face_combat_camera()
	tool_use_cooldown_timer = tool_use_cooldown_duration
	tool_swing_timer = tool_use_cooldown_duration
	if animation_controller != null:
		animation_controller.present_tool_use(tool_use_cooldown_duration)
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
	if defeated:
		return
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
	if defeated or not is_on_floor():
		return
	if Input.is_action_just_pressed("dodge"):
		var dodge_direction: Vector3 = _get_requested_dodge_direction()
		if not dodge_direction.is_zero_approx():
			_queue_buffered_action(&"dodge", {"direction": dodge_direction})
	if Input.is_action_just_pressed("parry"):
		_queue_buffered_action(&"parry")


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
	if defeated:
		return false
	var horizontal := Vector3(dodge_direction.x, 0.0, dodge_direction.z)
	if horizontal.is_zero_approx():
		return false
	horizontal = horizontal.normalized()
	if not action_controller.try_start_dodge(horizontal):
		return false
	jump_buffer_timer = 0.0
	if animation_controller != null and visual_root != null:
		var local: Vector3 = visual_root.global_transform.basis.inverse() * horizontal
		# Presentation dodge space uses +Y for forward; Godot character forward is local -Z.
		animation_controller.present_dodge(Vector2(local.x, -local.z))
	return true


func _start_parry() -> bool:
	if defeated or not action_controller.try_start_parry():
		return false
	jump_buffer_timer = 0.0
	_face_combat_camera()
	if animation_controller != null:
		animation_controller.present_parry()
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
	# Map requested world-facing onto authored local -Z without changing gameplay direction.
	visual_root.rotation.y = atan2(-forward.x, -forward.z)


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

	var target_yaw: float = atan2(-velocity.x, -velocity.z)
	visual_root.rotation.y = lerp_angle(
		visual_root.rotation.y,
		target_yaw,
		clampf(TURN_SPEED * delta, 0.0, 1.0)
	)


func _update_mannequin(delta: float) -> void:
	if animation_controller == null or visual_root == null:
		return
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var local_velocity: Vector3 = visual_root.global_transform.basis.inverse() * horizontal_velocity
	animation_controller.set_blocking(action_controller.is_blocking())
	animation_controller.update_locomotion(
		delta,
		local_velocity,
		velocity.y,
		is_on_floor(),
		sprinting_this_frame
	)


func _update_camera_fov(delta: float) -> void:
	var target_fov: float = SPRINT_FOV if sprinting_this_frame else NORMAL_FOV
	camera.fov = lerpf(camera.fov, target_fov, clampf(6.0 * delta, 0.0, 1.0))


func _check_fall_respawn() -> void:
	if defeated or global_position.y >= RESPAWN_FALL_HEIGHT:
		return
	_enter_defeated(DEFEAT_REASON_FALL)


func _enter_defeated(reason: StringName) -> bool:
	if defeated or (reason != DEFEAT_REASON_DAMAGE and reason != DEFEAT_REASON_FALL):
		return false
	defeated = true
	_defeat_reason = reason
	velocity = Vector3.ZERO
	sprinting_this_frame = false
	defeat_requested.emit(reason)
	return true


func commit_respawn(position: Vector3) -> bool:
	if not defeated or not _is_finite_vector3(position):
		return false
	global_position = position
	velocity = Vector3.ZERO
	health = MAX_HEALTH
	damage_invulnerability_timer = POST_RESPAWN_INVULNERABILITY
	stamina.reset()
	action_controller.reset()
	input_buffer.reset()
	pending_attack_definition = null
	pending_attack_direction = Vector3.ZERO
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	tool_use_cooldown_timer = 0.0
	tool_swing_timer = 0.0
	sprinting_this_frame = false
	defeated = false
	_defeat_reason = &""
	if animation_controller != null:
		animation_controller.reset_presentation()
	elif character_presentation != null:
		character_presentation.reset_pose()
	return true


static func _is_finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)


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

	if character_presentation_provider == null:
		push_error("Player requires an injected character presentation provider before entering the tree")
		return
	character_presentation = character_presentation_provider.create_presentation()
	if character_presentation == null:
		push_error("Character presentation provider returned no presentation")
		return
	visual_root.add_child(character_presentation)
	character_presentation.build()

	var animation_runtime: Dictionary = character_presentation_provider.build_animation_runtime(character_presentation)
	if bool(animation_runtime.get("success", false)):
		animation_controller = animation_runtime.get("controller")
	else:
		animation_controller = null
		for failure in animation_runtime.get("diagnostics", []):
			push_error("Character animation runtime: %s" % failure)

	if animation_controller != null:
		tool_visual_root = animation_controller.attachment_root(TOOL_HAND_RIG_ROLE)
	if tool_visual_root == null:
		# Explicit presentation-only fallback keeps the prototype tool visible if
		# semantic animation configuration fails; diagnostics above remain loud.
		tool_visual_root = character_presentation.get_tool_visual_root()
	_rebuild_tool_visual()


func _rebuild_tool_visual() -> void:
	if tool_visual_root == null or character_presentation_provider == null or character_presentation == null:
		return
	if not character_presentation_provider.realize_held_item(character_presentation, tool_visual_root, equipped_tool_visual):
		push_error("Character presentation provider could not realize held item: %s" % equipped_tool_visual)


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
	_add_mouse_action("attack_light", MOUSE_BUTTON_RIGHT)
	_add_remappable_key_action("attack_heavy", KEY_E)
	_add_remappable_key_action("hotbar_slot_1", KEY_1)
	_add_remappable_key_action("hotbar_slot_2", KEY_2)
	_add_remappable_key_action("hotbar_slot_3", KEY_3)
	_add_remappable_key_action("hotbar_slot_4", KEY_4)


func _add_key_action(action_name: StringName, physical_key: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventKey and existing_event.physical_keycode == physical_key:
			return

	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_key
	InputMap.action_add_event(action_name, key_event)


func _add_mouse_action(action_name: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)

	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = button
	InputMap.action_add_event(action_name, mouse_event)


func _add_remappable_key_action(action_name: StringName, physical_key: Key) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_key
	InputMap.action_add_event(action_name, key_event)