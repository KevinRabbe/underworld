extends RefCounted

const WALK_SPEED := 6.0
const SPRINT_SPEED := 10.0
const BLOCK_MOVE_SPEED := 2.4
const GROUND_ACCELERATION := 30.0
const GROUND_DECELERATION := 38.0
const AIR_ACCELERATION := 7.0
const JUMP_VELOCITY := 7.0
const GRAVITY := 24.0
const TERMINAL_VELOCITY := 55.0
const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12
const PARRY_DECELERATION_MULTIPLIER := 1.4

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0


func reset() -> void:
	coyote_timer = 0.0
	jump_buffer_timer = 0.0


func clear_jump_buffer() -> void:
	jump_buffer_timer = 0.0


func update_jump_timers(
	delta: float,
	on_floor: bool,
	input_allowed: bool,
	jump_buffer_requested: bool
) -> void:
	if on_floor:
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)

	if not input_allowed:
		jump_buffer_timer = 0.0
	elif jump_buffer_requested:
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)


func update_vertical_velocity(
	current_velocity_y: float,
	delta: float,
	on_floor: bool,
	input_allowed: bool,
	action_free: bool
) -> float:
	if (
		input_allowed
		and jump_buffer_timer > 0.0
		and coyote_timer > 0.0
		and action_free
	):
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		return JUMP_VELOCITY

	if not on_floor:
		return maxf(current_velocity_y - GRAVITY * delta, -TERMINAL_VELOCITY)
	if current_velocity_y < 0.0:
		return 0.0
	return current_velocity_y


func update_horizontal_velocity(
	current_velocity: Vector3,
	delta: float,
	on_floor: bool,
	move_direction: Vector3,
	blocking: bool,
	sprint_granted: bool,
	dodging: bool,
	dodge_direction: Vector3,
	dodge_speed: float,
	parrying: bool
) -> Vector3:
	var next_velocity := current_velocity
	if dodging:
		var dodge_velocity: Vector3 = dodge_direction * dodge_speed
		next_velocity.x = dodge_velocity.x
		next_velocity.z = dodge_velocity.z
		return next_velocity

	if parrying:
		var deceleration: float = GROUND_DECELERATION * PARRY_DECELERATION_MULTIPLIER * delta
		next_velocity.x = move_toward(next_velocity.x, 0.0, deceleration)
		next_velocity.z = move_toward(next_velocity.z, 0.0, deceleration)
		return next_velocity

	var target_speed: float = BLOCK_MOVE_SPEED if blocking else WALK_SPEED
	if sprint_granted:
		target_speed = SPRINT_SPEED
	var target_velocity: Vector3 = move_direction * target_speed
	var acceleration: float = GROUND_ACCELERATION if on_floor else AIR_ACCELERATION
	if on_floor and move_direction.is_zero_approx():
		acceleration = GROUND_DECELERATION

	next_velocity.x = move_toward(next_velocity.x, target_velocity.x, acceleration * delta)
	next_velocity.z = move_toward(next_velocity.z, target_velocity.z, acceleration * delta)
	return next_velocity
