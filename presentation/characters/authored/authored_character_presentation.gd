extends "res://presentation/characters/runtime/humanoid_character_presentation.gd"
class_name UnderworldAuthoredCharacterPresentation

const MODEL_PATH := "res://presentation/characters/authored/v3/rigged/character2_authored_rig_v3.glb"

var model_root: Node3D
var grip_active: bool = false
var bind_pose_rotations: Dictionary = {}


func _build_skeleton() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var import_error := document.append_from_file(ProjectSettings.globalize_path(MODEL_PATH), state)
	if import_error != OK:
		push_error("Authored character GLB could not be loaded (%d): %s" % [import_error, MODEL_PATH])
		return
	model_root = document.generate_scene(state)
	if model_root == null:
		push_error("Authored character GLB generated no scene: %s" % MODEL_PATH)
		return
	model_root.name = "Character2AuthoredModel"
	add_child(model_root)
	# The Blender source faces Godot -Z. Rotate only the imported presentation so
	# current gameplay can retain its established +Z visual-root convention.
	model_root.rotation.y = PI
	skeleton = _find_skeleton(model_root)
	if skeleton == null:
		push_error("Authored character GLB contains no Skeleton3D")
		return
	bone_indices.clear()
	for bone_index in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(bone_index)
		bone_indices[bone_name] = bone_index
		bind_pose_rotations[bone_name] = skeleton.get_bone_pose_rotation(bone_index)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func reset_pose() -> void:
	if skeleton == null:
		return
	current_action = ACTION_NONE
	action_time = 0.0
	attack_duration = ATTACK_DURATION
	attack_kind = &"light"
	blocking_pose_active = false
	skeleton.reset_bone_poses()
	set_tool_grip(false)


func _build_sockets() -> void:
	super._build_sockets()
	# Imported hand bones already carry their authored orientation. The
	# procedural rig's corrective -78 degree rotation would turn the handle
	# sideways. A modest authored-roll keeps the haft in the palm while exposing
	# the head outside the arm silhouette at gameplay distance.
	# The generic socket adds an outward offset for the procedural mannequin.
	# This imported hand bone already runs through the palm, so that offset leaves
	# the handle floating beside the fingers.
	right_hand_socket.position = Vector3.ZERO
	tool_visual_root.position = Vector3(-0.035, 0.0, 0.0)
	tool_visual_root.rotation_degrees = Vector3.ZERO


func set_tool_grip(active: bool) -> void:
	grip_active = active
	if skeleton == null:
		return
	for suffix in ["l", "r"]:
		for finger in ["index", "middle", "ring", "little"]:
			_set_internal_bone_rotation(
				"finger_%s_01_%s" % [finger, suffix],
				Vector3(deg_to_rad(-22.0 if active else 0.0), 0.0, 0.0)
			)
			_set_internal_bone_rotation(
				"finger_%s_02_%s" % [finger, suffix],
				Vector3(deg_to_rad(-34.0 if active else 0.0), 0.0, 0.0)
			)
		_set_internal_bone_rotation(
			"thumb_01_%s" % suffix,
			Vector3(deg_to_rad(-16.0 if active else 0.0), deg_to_rad(12.0 if active else 0.0), 0.0)
		)
		_set_internal_bone_rotation(
			"thumb_02_%s" % suffix,
			Vector3(deg_to_rad(-20.0 if active else 0.0), 0.0, 0.0)
		)


func is_tool_grip_active() -> bool:
	return grip_active


func _set_internal_bone_rotation(bone_name: String, euler: Vector3) -> void:
	var bone_index := skeleton.find_bone(bone_name)
	if bone_index >= 0:
		var baseline: Quaternion = bind_pose_rotations.get(bone_name, Quaternion.IDENTITY)
		skeleton.set_bone_pose_rotation(bone_index, Quaternion.from_euler(euler) * baseline)


func set_bone_rotation_delta(bone_name: String, euler: Vector3) -> void:
	_set_rot(bone_name, euler)


func _set_rot(bone_name: String, euler: Vector3) -> void:
	if skeleton == null or not bone_indices.has(bone_name):
		return
	var baseline: Quaternion = bind_pose_rotations.get(bone_name, Quaternion.IDENTITY)
	skeleton.set_bone_pose_rotation(
		int(bone_indices[bone_name]),
		Quaternion.from_euler(euler) * baseline
	)


func _apply_base_pose(
	local_velocity: Vector3,
	grounded: bool,
	sprinting: bool,
	normalized_speed: float
) -> void:
	var movement_blend := clampf(normalized_speed * 1.15, 0.0, 1.0)
	var stride := sin(gait_phase)
	var opposite_stride := sin(gait_phase + PI)
	var stride_amplitude := lerpf(0.14, 0.22, 1.0 if sprinting else 0.0) * movement_blend
	var knee_amplitude := stride_amplitude * 0.52
	var arm_amplitude := stride_amplitude * 0.40
	var elbow_flex := deg_to_rad(-4.0 if sprinting else -3.0) * movement_blend
	var forward_lean := deg_to_rad(5.0 if sprinting else 1.5) * movement_blend
	var torso_twist := deg_to_rad(2.0) * stride * movement_blend

	# Imported Blender bones retain their authored local orientation in
	# bind_pose_rotations. These values are animation deltas composed by _set_rot.
	# Keep the cycle restrained because this faceted mesh intentionally has broad,
	# low-density joint loops rather than a high-resolution deformation cage.
	if grounded:
		_set_rot("thigh_l", Vector3(stride * stride_amplitude, 0.0, 0.0))
		_set_rot("thigh_r", Vector3(opposite_stride * stride_amplitude, 0.0, 0.0))
		_set_rot("calf_l", Vector3(0.0, 0.0, maxf(-stride, 0.0) * knee_amplitude))
		_set_rot("calf_r", Vector3(0.0, 0.0, maxf(-opposite_stride, 0.0) * knee_amplitude))
	else:
		_set_rot("thigh_l", Vector3(-0.10, 0.0, 0.0))
		_set_rot("thigh_r", Vector3(0.12, 0.0, 0.0))
		_set_rot("calf_l", Vector3(0.0, 0.0, 0.16))
		_set_rot("calf_r", Vector3(0.0, 0.0, 0.10))

	var strafe_lean := clampf(local_velocity.x / 10.0, -1.0, 1.0) * deg_to_rad(-3.0)
	_set_rot("pelvis", Vector3(0.0, 0.0, strafe_lean))
	_set_rot("spine_01", Vector3(forward_lean * 0.55, torso_twist * 0.40, 0.0))
	_set_rot("spine_02", Vector3(forward_lean * 0.30, torso_twist * 0.35, 0.0))
	_set_rot("chest", Vector3(forward_lean * 0.15, torso_twist * 0.25, 0.0))
	_set_rot("neck", Vector3.ZERO)
	_set_rot("head", Vector3(-forward_lean * 0.25, -torso_twist * 0.20, 0.0))
	_set_rot("upperarm_l", Vector3(opposite_stride * arm_amplitude, 0.0, 0.0))
	_set_rot("upperarm_r", Vector3(stride * arm_amplitude, 0.0, 0.0))
	_set_rot("forearm_l", Vector3(elbow_flex, 0.0, 0.0))
	_set_rot("forearm_r", Vector3(elbow_flex, 0.0, 0.0))
	_set_rot("hand_l", Vector3.ZERO)
	_set_rot("hand_r", Vector3.ZERO)


func _apply_attack_pose(t_raw: float) -> void:
	var t := clampf(t_raw, 0.0, 1.0)
	var heavy_scale := 1.12 if attack_kind == &"heavy" else 1.0
	# Separate anticipation and strike weights create a directional weapon arc.
	# Shoulder Y carries the arm backward/forward and elbow X controls flexion on
	# this imported rig; keeping other axes quiet preserves the repaired joints.
	var windup := smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.28, 0.48, t))
	var strike := smoothstep(0.24, 0.50, t) * (1.0 - smoothstep(0.58, 0.76, t))
	var follow := smoothstep(0.54, 0.74, t) * (1.0 - smoothstep(0.78, 1.0, t))
	_set_rot(
		"spine_02",
		Vector3(
			0.0,
			deg_to_rad(3.0) * windup - deg_to_rad(4.0) * strike + deg_to_rad(2.0) * follow,
			0.0
		)
	)
	_set_rot(
		"chest",
		Vector3(
			0.0,
			(
				deg_to_rad(8.0) * windup
				- deg_to_rad(10.0) * strike
				+ deg_to_rad(4.0) * follow
			) * heavy_scale,
			0.0
		)
	)
	_set_rot(
		"upperarm_r",
		Vector3(
			(
				deg_to_rad(5.0) * windup
				- deg_to_rad(6.0) * strike
				+ deg_to_rad(4.0) * follow
			) * heavy_scale,
			(
				deg_to_rad(22.0) * windup
				- deg_to_rad(32.0) * strike
				- deg_to_rad(12.0) * follow
			) * heavy_scale,
			0.0
		)
	)
	_set_rot(
		"forearm_r",
		Vector3(
			-deg_to_rad(28.0) * windup
			- deg_to_rad(18.0) * strike
			- deg_to_rad(6.0) * follow,
			0.0,
			0.0
		)
	)
	_set_rot("upperarm_l", Vector3(deg_to_rad(2.0) * (strike + follow), 0.0, 0.0))


func _apply_parry_pose(t_raw: float) -> void:
	var t := clampf(t_raw, 0.0, 1.0)
	# A parry snaps into its intercept early, holds for a readable contact beat,
	# then releases. This stays distinct from the sustained block guard.
	var intercept := smoothstep(0.0, 0.24, t) * (1.0 - smoothstep(0.62, 1.0, t))
	var recoil := smoothstep(0.48, 0.68, t) * (1.0 - smoothstep(0.78, 1.0, t))
	_set_rot("spine_02", Vector3(0.0, deg_to_rad(-3.0) * intercept, 0.0))
	_set_rot(
		"chest",
		Vector3(0.0, deg_to_rad(-8.0) * intercept + deg_to_rad(3.0) * recoil, 0.0)
	)
	_set_rot(
		"upperarm_r",
		Vector3(
			deg_to_rad(-8.0) * intercept,
			deg_to_rad(-30.0) * intercept + deg_to_rad(8.0) * recoil,
			0.0
		)
	)
	_set_rot("forearm_r", Vector3(deg_to_rad(-42.0) * intercept, 0.0, 0.0))
	_set_rot("upperarm_l", Vector3(deg_to_rad(3.0) * intercept, 0.0, 0.0))
	_set_rot("forearm_l", Vector3(deg_to_rad(-6.0) * intercept, 0.0, 0.0))


func _apply_block_pose() -> void:
	_set_rot("spine_01", Vector3(deg_to_rad(2.0), 0.0, 0.0))
	_set_rot("spine_02", Vector3(deg_to_rad(1.0), deg_to_rad(-2.0), 0.0))
	_set_rot("chest", Vector3(0.0, deg_to_rad(-5.0), 0.0))
	_set_rot("upperarm_r", Vector3(deg_to_rad(-7.0), deg_to_rad(-27.0), 0.0))
	_set_rot("forearm_r", Vector3(deg_to_rad(-40.0), 0.0, 0.0))
	_set_rot("upperarm_l", Vector3(deg_to_rad(2.0), 0.0, 0.0))
	_set_rot("forearm_l", Vector3(deg_to_rad(-5.0), 0.0, 0.0))


func _apply_dodge_pose(t_raw: float) -> void:
	var t := clampf(t_raw, 0.0, 1.0)
	var weight := sin(t * PI)
	var forward_component := -dodge_local_direction.y
	var side_component := dodge_local_direction.x
	_set_rot("pelvis", Vector3(deg_to_rad(8.0) * weight, 0.0, 0.0))
	_set_rot(
		"spine_01",
		Vector3(
			deg_to_rad(-12.0) * forward_component * weight,
			0.0,
			deg_to_rad(-8.0) * side_component * weight
		)
	)
	_set_rot(
		"spine_02",
		Vector3(deg_to_rad(-7.0) * forward_component * weight, 0.0, 0.0)
	)
	_set_rot("chest", Vector3(deg_to_rad(-4.0) * forward_component * weight, 0.0, 0.0))
	_set_rot("head", Vector3(deg_to_rad(5.0) * forward_component * weight, 0.0, 0.0))
	_set_rot("upperarm_r", Vector3(0.0, deg_to_rad(-10.0) * weight, 0.0))
	_set_rot("forearm_r", Vector3(deg_to_rad(-14.0) * weight, 0.0, 0.0))
	_set_rot("upperarm_l", Vector3(0.0, deg_to_rad(-8.0) * weight, 0.0))
	_set_rot("forearm_l", Vector3(deg_to_rad(-10.0) * weight, 0.0, 0.0))
	_set_rot("thigh_l", Vector3(deg_to_rad(-12.0) * weight, 0.0, 0.0))
	_set_rot("thigh_r", Vector3(deg_to_rad(-8.0) * weight, 0.0, 0.0))
	_set_rot("calf_l", Vector3(0.0, 0.0, deg_to_rad(10.0) * weight))
	_set_rot("calf_r", Vector3(0.0, 0.0, deg_to_rad(8.0) * weight))


func _apply_hit_pose(t_raw: float) -> void:
	var t := clampf(t_raw, 0.0, 1.0)
	# The initial recoil lands quickly, then the torso and arms settle at
	# different rates so the reaction reads as impact rather than a single hinge.
	var impact := smoothstep(0.0, 0.16, t) * (1.0 - smoothstep(0.42, 0.92, t))
	var settle := smoothstep(0.34, 0.58, t) * (1.0 - smoothstep(0.72, 1.0, t))
	_set_rot("pelvis", Vector3(deg_to_rad(-1.0) * impact, 0.0, 0.0))
	_set_rot("spine_01", Vector3(deg_to_rad(-4.0) * impact, 0.0, 0.0))
	_set_rot("spine_02", Vector3(deg_to_rad(-3.0) * impact, deg_to_rad(2.0) * settle, 0.0))
	_set_rot(
		"chest",
		Vector3(
			deg_to_rad(-5.0) * impact + deg_to_rad(1.0) * settle,
			deg_to_rad(6.0) * impact - deg_to_rad(2.0) * settle,
			0.0
		)
	)
	_set_rot("head", Vector3(deg_to_rad(2.5) * impact, deg_to_rad(-2.0) * settle, 0.0))
	_set_rot("upperarm_r", Vector3(0.0, deg_to_rad(8.0) * impact, 0.0))
	_set_rot("forearm_r", Vector3(deg_to_rad(-8.0) * impact, 0.0, 0.0))
	_set_rot("upperarm_l", Vector3(0.0, deg_to_rad(-6.0) * impact, 0.0))
	_set_rot("forearm_l", Vector3(deg_to_rad(-6.0) * impact, 0.0, 0.0))
