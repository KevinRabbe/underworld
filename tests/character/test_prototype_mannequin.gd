extends RefCounted

const MannequinScript := preload("res://player/prototype_mannequin.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var mannequin = MannequinScript.new()
	mannequin.build()

	_expect_true(failures, "mannequin builds required rig", mannequin.has_required_rig())
	_expect_true(failures, "mannequin creates Skeleton3D", mannequin.skeleton != null)
	if mannequin.skeleton == null:
		mannequin.free()
		return failures

	_expect_equal(failures, "prototype bone count", mannequin.skeleton.get_bone_count(), 21)
	var required_bones: Array[String] = [
		"root", "pelvis", "spine_01", "spine_02", "chest", "neck", "head",
		"clavicle_l", "upperarm_l", "forearm_l", "hand_l",
		"clavicle_r", "upperarm_r", "forearm_r", "hand_r",
		"thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r",
	]
	for bone_name in required_bones:
		_expect_true(
			failures,
			"required bone exists: " + bone_name,
			mannequin.skeleton.find_bone(bone_name) >= 0
		)

	_expect_socket(failures, mannequin, &"hand_r", "hand_r")
	_expect_socket(failures, mannequin, &"hand_l", "hand_l")
	_expect_socket(failures, mannequin, &"back", "chest")
	_expect_socket(failures, mannequin, &"hip_r", "pelvis")
	_expect_socket(failures, mannequin, &"hip_l", "pelvis")
	_expect_true(
		failures,
		"tool visual root is parented to right-hand socket",
		mannequin.get_tool_visual_root() != null
		and mannequin.get_tool_visual_root().get_parent() == mannequin.get_socket(&"hand_r")
	)

	# Exercise every placeholder pose in headless Godot. These are contract tests,
	# not visual-quality tests.
	mannequin.play_attack()
	_advance(mannequin, 0.50)
	_expect_equal(failures, "attack pose returns to neutral", mannequin.current_action, mannequin.ACTION_NONE)

	# Combat definitions may supply different total durations. The mannequin must
	# consume that duration instead of owning a second copy of attack timing.
	mannequin.play_attack(0.70)
	_advance(mannequin, 0.45)
	_expect_equal(
		failures,
		"custom-duration attack remains active before supplied end",
		mannequin.current_action,
		mannequin.ACTION_ATTACK
	)
	_advance(mannequin, 0.30)
	_expect_equal(
		failures,
		"custom-duration attack ends after supplied duration",
		mannequin.current_action,
		mannequin.ACTION_NONE
	)

	mannequin.play_parry()
	_advance(mannequin, 0.55)
	_expect_equal(failures, "parry pose returns to neutral", mannequin.current_action, mannequin.ACTION_NONE)

	mannequin.play_dodge(Vector2(1.0, 0.0))
	_advance(mannequin, 0.55)
	_expect_equal(failures, "dodge pose returns to neutral", mannequin.current_action, mannequin.ACTION_NONE)

	mannequin.play_hit()
	_advance(mannequin, 0.35)
	_expect_equal(failures, "hit pose returns to neutral", mannequin.current_action, mannequin.ACTION_NONE)

	# Guard is a held visual layer, not a timed action. It survives locomotion
	# updates until the gameplay layer releases it.
	mannequin.set_blocking(true)
	mannequin.update_visual(1.0 / 60.0, Vector3(1.0, 0.0, 2.0), true, false)
	_expect_true(failures, "held guard pose becomes active", mannequin.is_block_pose_active())
	_expect_equal(
		failures,
		"held guard does not become a timed action",
		mannequin.current_action,
		mannequin.ACTION_NONE
	)
	mannequin.set_blocking(false)
	mannequin.update_visual(1.0 / 60.0, Vector3.ZERO, true, false)
	_expect_true(failures, "held guard pose clears", not mannequin.is_block_pose_active())

	# Locomotion updates must also tolerate grounded/airborne and sprint states.
	mannequin.update_visual(1.0 / 60.0, Vector3(0.0, 0.0, 6.0), true, false)
	mannequin.update_visual(1.0 / 60.0, Vector3(1.0, 0.0, 9.0), true, true)
	mannequin.update_visual(1.0 / 60.0, Vector3.ZERO, false, false)

	mannequin.free()
	return failures


static func _advance(mannequin, seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds:
		var delta: float = 1.0 / 60.0
		mannequin.update_visual(delta, Vector3.ZERO, true, false)
		elapsed += delta


static func _expect_socket(
	failures: Array[String],
	mannequin,
	socket_name: StringName,
	expected_bone: String
) -> void:
	var socket: Node3D = mannequin.get_socket(socket_name)
	_expect_true(failures, "socket exists: %s" % socket_name, socket != null)
	if socket == null:
		return
	_expect_equal(
		failures,
		"socket bone binding: %s" % socket_name,
		str(socket.bone_name),
		expected_bone
	)


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(
	failures: Array[String],
	label: String,
	actual: Variant,
	expected: Variant
) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])
