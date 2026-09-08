extends RefCounted

const LocomotionScript := preload("res://gameplay/player/movement/player_locomotion_controller.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_constants(failures)
	_test_horizontal_traces(failures)
	_test_jump_and_gravity_traces(failures)
	return failures


static func _test_constants(failures: Array[String]) -> void:
	_expect_float(failures, "walk speed", LocomotionScript.WALK_SPEED, 6.0)
	_expect_float(failures, "sprint speed", LocomotionScript.SPRINT_SPEED, 10.0)
	_expect_float(failures, "block speed", LocomotionScript.BLOCK_MOVE_SPEED, 2.4)
	_expect_float(failures, "ground acceleration", LocomotionScript.GROUND_ACCELERATION, 30.0)
	_expect_float(failures, "ground deceleration", LocomotionScript.GROUND_DECELERATION, 38.0)
	_expect_float(failures, "air acceleration", LocomotionScript.AIR_ACCELERATION, 7.0)
	_expect_float(failures, "jump velocity", LocomotionScript.JUMP_VELOCITY, 7.0)
	_expect_float(failures, "gravity", LocomotionScript.GRAVITY, 24.0)
	_expect_float(failures, "terminal velocity", LocomotionScript.TERMINAL_VELOCITY, 55.0)
	_expect_float(failures, "coyote time", LocomotionScript.COYOTE_TIME, 0.12)
	_expect_float(failures, "jump buffer time", LocomotionScript.JUMP_BUFFER_TIME, 0.12)


static func _test_horizontal_traces(failures: Array[String]) -> void:
	var locomotion = LocomotionScript.new()
	var forward := Vector3(0.0, 0.0, -1.0)

	var idle := locomotion.update_horizontal_velocity(
		Vector3(3.0, 2.0, -2.0), 0.1, true, Vector3.ZERO,
		false, false, false, Vector3.ZERO, 0.0, false
	)
	_expect_vector(failures, "idle ground deceleration", idle, Vector3(0.0, 2.0, 0.0))

	var walk := locomotion.update_horizontal_velocity(
		Vector3.ZERO, 0.4, true, forward,
		false, false, false, Vector3.ZERO, 0.0, false
	)
	_expect_vector(failures, "walk reaches walk target", walk, Vector3(0.0, 0.0, -6.0))

	var sprint := locomotion.update_horizontal_velocity(
		Vector3.ZERO, 0.4, true, forward,
		false, true, false, Vector3.ZERO, 0.0, false
	)
	_expect_vector(failures, "sprint reaches sprint target", sprint, Vector3(0.0, 0.0, -10.0))

	var blocked := locomotion.update_horizontal_velocity(
		Vector3.ZERO, 0.4, true, forward,
		true, false, false, Vector3.ZERO, 0.0, false
	)
	_expect_vector(failures, "blocking uses block move speed", blocked, Vector3(0.0, 0.0, -2.4))

	var airborne := locomotion.update_horizontal_velocity(
		Vector3.ZERO, 0.5, false, forward,
		false, false, false, Vector3.ZERO, 0.0, false
	)
	_expect_vector(failures, "air steering uses air acceleration", airborne, Vector3(0.0, 0.0, -3.5))

	var parry := locomotion.update_horizontal_velocity(
		Vector3(10.0, -4.0, -10.0), 0.1, true, Vector3.ZERO,
		false, false, false, Vector3.ZERO, 0.0, true
	)
	_expect_vector(failures, "parry deceleration", parry, Vector3(4.68, -4.0, -4.68))

	var dodge_direction := Vector3(0.6, 0.0, -0.8)
	var dodge := locomotion.update_horizontal_velocity(
		Vector3(1.0, 3.0, 2.0), 0.1, true, Vector3.ZERO,
		false, false, true, dodge_direction, 12.0, false
	)
	_expect_vector(failures, "dodge overrides horizontal velocity only", dodge, Vector3(7.2, 3.0, -9.6))


static func _test_jump_and_gravity_traces(failures: Array[String]) -> void:
	var locomotion = LocomotionScript.new()
	locomotion.update_jump_timers(0.016, true, true, false)
	_expect_float(failures, "ground refreshes coyote timer", locomotion.coyote_timer, 0.12)
	locomotion.update_jump_timers(0.05, false, true, false)
	_expect_float(failures, "air decrements coyote timer", locomotion.coyote_timer, 0.07)

	locomotion.update_jump_timers(0.01, false, true, true)
	_expect_float(failures, "jump press fills jump buffer", locomotion.jump_buffer_timer, 0.12)
	var jumped: float = locomotion.update_vertical_velocity(0.0, 0.01, false, true, true)
	_expect_float(failures, "coyote jump applies exact jump velocity", jumped, 7.0)
	_expect_float(failures, "jump consumes coyote timer", locomotion.coyote_timer, 0.0)
	_expect_float(failures, "jump consumes jump buffer", locomotion.jump_buffer_timer, 0.0)

	locomotion.reset()
	locomotion.update_jump_timers(0.016, false, true, true)
	_expect_float(failures, "airborne jump press buffers without coyote", locomotion.jump_buffer_timer, 0.12)
	var falling: float = locomotion.update_vertical_velocity(-1.0, 0.016, false, true, true)
	_expect_float(failures, "buffered airborne press still receives gravity", falling, -1.384)
	locomotion.update_jump_timers(0.016, true, true, false)
	var buffered_jump: float = locomotion.update_vertical_velocity(falling, 0.016, true, true, true)
	_expect_float(failures, "landing consumes buffered jump", buffered_jump, 7.0)

	locomotion.reset()
	locomotion.update_jump_timers(0.016, true, true, true)
	var gated: float = locomotion.update_vertical_velocity(0.0, 0.016, true, false, true)
	_expect_float(failures, "suppressed input cannot trigger jump", gated, 0.0)
	locomotion.update_jump_timers(0.016, true, false, false)
	_expect_float(failures, "suppressed input clears jump buffer", locomotion.jump_buffer_timer, 0.0)

	var terminal: float = locomotion.update_vertical_velocity(-54.0, 1.0, false, true, true)
	_expect_float(failures, "gravity clamps terminal fall", terminal, -55.0)
	var grounded: float = locomotion.update_vertical_velocity(-3.0, 0.1, true, true, true)
	_expect_float(failures, "grounded negative velocity clears", grounded, 0.0)

	locomotion.coyote_timer = 0.08
	locomotion.jump_buffer_timer = 0.06
	locomotion.reset()
	_expect_float(failures, "reset clears coyote state", locomotion.coyote_timer, 0.0)
	_expect_float(failures, "reset clears jump-buffer state", locomotion.jump_buffer_timer, 0.0)


static func _expect_float(
	failures: Array[String],
	label: String,
	actual: float,
	expected: float
) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s expected %.6f, got %.6f" % [label, expected, actual])


static func _expect_vector(
	failures: Array[String],
	label: String,
	actual: Vector3,
	expected: Vector3
) -> void:
	if not actual.is_equal_approx(expected):
		failures.append("%s expected %s, got %s" % [label, expected, actual])
