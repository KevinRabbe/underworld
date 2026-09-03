extends Node3D
class_name UnderworldHumanoidCharacterPresentation

## Neutral visual-only humanoid rig and procedural pose runtime shared by
## concrete presentations. Gameplay collision and action authority stay in
## Player/PlayerActionController; subclasses only author visual realization.

const ACTION_NONE: StringName = &"none"
const ACTION_ATTACK: StringName = &"attack"
const ACTION_PARRY: StringName = &"parry"
const ACTION_DODGE: StringName = &"dodge"
const ACTION_HIT: StringName = &"hit"

const ATTACK_DURATION := 0.42
const PARRY_DURATION := 0.48
const DODGE_DURATION := 0.48
const HIT_DURATION := 0.28

var skeleton: Skeleton3D
var bone_indices: Dictionary = {}
var right_hand_socket: BoneAttachment3D
var left_hand_socket: BoneAttachment3D
var back_socket: BoneAttachment3D
var hip_right_socket: BoneAttachment3D
var hip_left_socket: BoneAttachment3D
var tool_visual_root: Node3D

var gait_phase: float = 0.0
var current_action: StringName = ACTION_NONE
var action_time: float = 0.0
var attack_duration: float = ATTACK_DURATION
var attack_kind: StringName = &"light"
var dodge_local_direction: Vector2 = Vector2(0.0, -1.0)
var blocking_pose_active: bool = false
var _built: bool = false


func build() -> void:
	if _built:
		return
	_built = true
	_build_presentation_materials()
	_build_skeleton()
	_build_presentation_visuals()
	_build_presentation_face_details()
	_build_sockets()
	reset_pose()


func _build_presentation_materials() -> void:
	pass


func _build_presentation_visuals() -> void:
	pass


func _build_presentation_face_details() -> void:
	pass


func update_visual(
	delta: float,
	local_horizontal_velocity: Vector3,
	grounded: bool,
	sprinting: bool
) -> void:
	if not _built or skeleton == null:
		return
	var speed: float = Vector2(local_horizontal_velocity.x, local_horizontal_velocity.z).length()
	var normalized_speed: float = clampf(speed / 10.0, 0.0, 1.0)
	if grounded and speed > 0.08:
		gait_phase = fmod(gait_phase + delta * lerpf(5.4, 10.0, normalized_speed), TAU)
	_apply_base_pose(local_horizontal_velocity, grounded, sprinting, normalized_speed)
	_update_action(delta)
	if blocking_pose_active and current_action == ACTION_NONE:
		_apply_block_pose()


func play_attack(duration: float = ATTACK_DURATION, kind: StringName = &"light") -> void:
	attack_duration = maxf(duration, 0.05)
	attack_kind = &"heavy" if kind == &"heavy" else &"light"
	_start_action(ACTION_ATTACK)


func play_parry() -> void:
	_start_action(ACTION_PARRY)


func play_dodge(local_direction: Vector2) -> void:
	dodge_local_direction = local_direction.normalized() if not local_direction.is_zero_approx() else Vector2(0.0, 1.0)
	_start_action(ACTION_DODGE)


func play_hit() -> void:
	_start_action(ACTION_HIT)


func set_blocking(active: bool) -> void:
	blocking_pose_active = active


func is_block_pose_active() -> bool:
	return blocking_pose_active


func reset_pose() -> void:
	if skeleton == null:
		return
	current_action = ACTION_NONE
	action_time = 0.0
	attack_duration = ATTACK_DURATION
	attack_kind = &"light"
	blocking_pose_active = false
	for bone_name_variant in bone_indices.keys():
		var bone_name: String = str(bone_name_variant)
		var bone_index: int = int(bone_indices[bone_name])
		skeleton.set_bone_pose_rotation(bone_index, Quaternion.IDENTITY)
		# This procedural skeleton has no imported bind pose. Its authored local
		# translations are also the active pose used by BoneAttachment3D.
		skeleton.set_bone_pose_position(bone_index, skeleton.get_bone_rest(bone_index).origin)
		skeleton.set_bone_pose_scale(bone_index, Vector3.ONE)


func get_tool_visual_root() -> Node3D:
	return tool_visual_root


func get_socket(socket_name: StringName) -> Node3D:
	match socket_name:
		&"hand_r": return right_hand_socket
		&"hand_l": return left_hand_socket
		&"back": return back_socket
		&"hip_r": return hip_right_socket
		&"hip_l": return hip_left_socket
	return null


func has_required_rig() -> bool:
	var required: Array[String] = [
		"root", "pelvis", "spine_01", "spine_02", "chest", "neck", "head",
		"clavicle_l", "upperarm_l", "forearm_l", "hand_l",
		"clavicle_r", "upperarm_r", "forearm_r", "hand_r",
		"thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r",
	]
	for bone_name in required:
		if not bone_indices.has(bone_name):
			return false
	return right_hand_socket != null and left_hand_socket != null


func _build_skeleton() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)
	_add_bone("root", "", Vector3.ZERO)
	_add_bone("pelvis", "root", Vector3(0.0, 0.90, 0.0))
	_add_bone("spine_01", "pelvis", Vector3(0.0, 0.15, 0.0))
	_add_bone("spine_02", "spine_01", Vector3(0.0, 0.16, 0.0))
	_add_bone("chest", "spine_02", Vector3(0.0, 0.17, 0.0))
	_add_bone("neck", "chest", Vector3(0.0, 0.16, 0.0))
	_add_bone("head", "neck", Vector3(0.0, 0.12, 0.0))
	_add_bone("clavicle_l", "chest", Vector3(-0.18, 0.11, 0.0))
	_add_bone("upperarm_l", "clavicle_l", Vector3(-0.07, 0.0, 0.0))
	_add_bone("forearm_l", "upperarm_l", Vector3(-0.29, 0.0, 0.0))
	_add_bone("hand_l", "forearm_l", Vector3(-0.26, 0.0, 0.0))
	_add_bone("clavicle_r", "chest", Vector3(0.18, 0.11, 0.0))
	_add_bone("upperarm_r", "clavicle_r", Vector3(0.07, 0.0, 0.0))
	_add_bone("forearm_r", "upperarm_r", Vector3(0.29, 0.0, 0.0))
	_add_bone("hand_r", "forearm_r", Vector3(0.26, 0.0, 0.0))
	_add_bone("thigh_l", "pelvis", Vector3(-0.11, -0.12, 0.0))
	_add_bone("calf_l", "thigh_l", Vector3(0.0, -0.42, 0.0))
	_add_bone("foot_l", "calf_l", Vector3(0.0, -0.36, 0.0))
	_add_bone("thigh_r", "pelvis", Vector3(0.11, -0.12, 0.0))
	_add_bone("calf_r", "thigh_r", Vector3(0.0, -0.42, 0.0))
	_add_bone("foot_r", "calf_r", Vector3(0.0, -0.36, 0.0))


func _add_bone(bone_name: String, parent_name: String, local_offset: Vector3) -> void:
	var index: int = skeleton.add_bone(bone_name)
	bone_indices[bone_name] = index
	if not parent_name.is_empty():
		skeleton.set_bone_parent(index, int(bone_indices[parent_name]))
	skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, local_offset))
	skeleton.set_bone_pose_position(index, local_offset)


func _build_sockets() -> void:
	right_hand_socket = _make_socket("hand_r", "SocketHandR", Vector3(0.09, 0.0, 0.0))
	left_hand_socket = _make_socket("hand_l", "SocketHandL", Vector3(-0.09, 0.0, 0.0))
	back_socket = _make_socket("chest", "SocketBack", Vector3(0.0, 0.02, -0.18))
	hip_right_socket = _make_socket("pelvis", "SocketHipR", Vector3(0.22, -0.08, 0.0))
	hip_left_socket = _make_socket("pelvis", "SocketHipL", Vector3(-0.22, -0.08, 0.0))
	tool_visual_root = Node3D.new()
	tool_visual_root.name = "ToolVisual"
	tool_visual_root.position = Vector3(0.08, -0.03, 0.02)
	tool_visual_root.rotation_degrees = Vector3(0.0, 0.0, -78.0)
	right_hand_socket.add_child(tool_visual_root)


func _make_socket(bone_name: String, socket_name: String, local_offset: Vector3) -> BoneAttachment3D:
	var socket := BoneAttachment3D.new()
	socket.name = socket_name
	skeleton.add_child(socket)
	socket.bone_idx = skeleton.find_bone(bone_name)
	socket.on_skeleton_update()
	socket.position = local_offset
	return socket


func _apply_base_pose(local_velocity: Vector3, grounded: bool, sprinting: bool, normalized_speed: float) -> void:
	var movement_blend: float = clampf(normalized_speed * 1.15, 0.0, 1.0)
	var stride: float = sin(gait_phase)
	var opposite_stride: float = sin(gait_phase + PI)
	var stride_amplitude: float = lerpf(0.32, 0.62, 1.0 if sprinting else 0.0) * movement_blend
	var arm_amplitude: float = stride_amplitude * 0.78
	var forward_lean: float = deg_to_rad(8.0 if sprinting and movement_blend > 0.15 else 2.0 * movement_blend)
	var strafe_lean: float = clampf(local_velocity.x / 10.0, -1.0, 1.0) * deg_to_rad(-6.0)
	var idle_breathe: float = sin(Time.get_ticks_msec() * 0.0018) * deg_to_rad(1.2) * (1.0 - movement_blend)
	_set_rot("pelvis", Vector3(0.0, 0.0, strafe_lean * 0.35))
	_set_rot("spine_01", Vector3(forward_lean * 0.45, 0.0, strafe_lean * 0.45))
	_set_rot("spine_02", Vector3(forward_lean * 0.35 + idle_breathe, 0.0, strafe_lean * 0.25))
	_set_rot("chest", Vector3(forward_lean * 0.20 - idle_breathe, 0.0, strafe_lean * 0.20))
	_set_rot("neck", Vector3.ZERO)
	_set_rot("head", Vector3(-forward_lean * 0.35, 0.0, -strafe_lean * 0.4))
	if grounded:
		_set_rot("thigh_l", Vector3(stride * stride_amplitude, 0.0, 0.0))
		_set_rot("thigh_r", Vector3(opposite_stride * stride_amplitude, 0.0, 0.0))
		_set_rot("calf_l", Vector3(maxf(-stride, 0.0) * stride_amplitude * 0.55, 0.0, 0.0))
		_set_rot("calf_r", Vector3(maxf(-opposite_stride, 0.0) * stride_amplitude * 0.55, 0.0, 0.0))
	else:
		_set_rot("thigh_l", Vector3(-0.18, 0.0, 0.0))
		_set_rot("thigh_r", Vector3(0.22, 0.0, 0.0))
		_set_rot("calf_l", Vector3(0.28, 0.0, 0.0))
		_set_rot("calf_r", Vector3(0.18, 0.0, 0.0))
	_set_rot("upperarm_l", Vector3(opposite_stride * arm_amplitude, 0.0, deg_to_rad(68.0)))
	_set_rot("upperarm_r", Vector3(stride * arm_amplitude, 0.0, deg_to_rad(-68.0)))
	_set_rot("forearm_l", Vector3(-0.12, 0.0, deg_to_rad(16.0)))
	_set_rot("forearm_r", Vector3(-0.12, 0.0, deg_to_rad(-16.0)))
	_set_rot("hand_l", Vector3.ZERO)
	_set_rot("hand_r", Vector3.ZERO)


func _update_action(delta: float) -> void:
	if current_action == ACTION_NONE:
		return
	action_time += delta
	match current_action:
		ACTION_ATTACK:
			_apply_attack_pose(action_time / attack_duration)
			if action_time >= attack_duration: _end_action()
		ACTION_PARRY:
			_apply_parry_pose(action_time / PARRY_DURATION)
			if action_time >= PARRY_DURATION: _end_action()
		ACTION_DODGE:
			_apply_dodge_pose(action_time / DODGE_DURATION)
			if action_time >= DODGE_DURATION: _end_action()
		ACTION_HIT:
			_apply_hit_pose(action_time / HIT_DURATION)
			if action_time >= HIT_DURATION: _end_action()


func _apply_attack_pose(t_raw: float) -> void:
	var t: float = clampf(t_raw, 0.0, 1.0)
	var intensity: float = 1.25 if attack_kind == &"heavy" else 1.0
	var windup: float = smoothstep(0.0, 0.32, t)
	var strike: float = smoothstep(0.28, 0.72, t)
	var recover: float = smoothstep(0.70, 1.0, t)
	var swing: float = strike - recover
	_set_rot("chest", Vector3(deg_to_rad(-6.0) * swing * intensity, deg_to_rad(-24.0) * windup * intensity + deg_to_rad(44.0) * swing * intensity, 0.0))
	_set_rot("upperarm_r", Vector3(deg_to_rad(-55.0) * windup + deg_to_rad(38.0) * swing, deg_to_rad(-18.0), deg_to_rad(58.0) - deg_to_rad(82.0) * swing))
	_set_rot("forearm_r", Vector3(deg_to_rad(-48.0) * windup + deg_to_rad(22.0) * swing, 0.0, deg_to_rad(18.0)))
	_set_rot("upperarm_l", Vector3(deg_to_rad(-18.0) * windup, 0.0, deg_to_rad(-18.0)))


func _apply_parry_pose(t_raw: float) -> void:
	var t: float = clampf(t_raw, 0.0, 1.0)
	var hold: float = smoothstep(0.0, 0.20, t) - smoothstep(0.68, 1.0, t)
	_set_rot("chest", Vector3(0.0, deg_to_rad(-9.0) * hold, 0.0))
	_set_rot("upperarm_r", Vector3(deg_to_rad(-50.0) * hold, deg_to_rad(-18.0) * hold, deg_to_rad(56.0) * hold))
	_set_rot("forearm_r", Vector3(deg_to_rad(-70.0) * hold, 0.0, deg_to_rad(20.0) * hold))
	_set_rot("upperarm_l", Vector3(deg_to_rad(-32.0) * hold, deg_to_rad(8.0) * hold, deg_to_rad(-42.0) * hold))
	_set_rot("forearm_l", Vector3(deg_to_rad(-45.0) * hold, 0.0, deg_to_rad(-10.0) * hold))


func _apply_block_pose() -> void:
	_set_rot("spine_01", Vector3(deg_to_rad(4.0), 0.0, 0.0))
	_set_rot("spine_02", Vector3(deg_to_rad(3.0), 0.0, 0.0))
	_set_rot("chest", Vector3(deg_to_rad(2.0), deg_to_rad(-4.0), 0.0))
	_set_rot("upperarm_r", Vector3(deg_to_rad(-46.0), deg_to_rad(-14.0), deg_to_rad(52.0)))
	_set_rot("forearm_r", Vector3(deg_to_rad(-72.0), 0.0, deg_to_rad(18.0)))
	_set_rot("upperarm_l", Vector3(deg_to_rad(-38.0), deg_to_rad(10.0), deg_to_rad(-50.0)))
	_set_rot("forearm_l", Vector3(deg_to_rad(-60.0), 0.0, deg_to_rad(-14.0)))
	_set_rot("head", Vector3(deg_to_rad(-3.0), 0.0, 0.0))


func _apply_dodge_pose(t_raw: float) -> void:
	var t: float = clampf(t_raw, 0.0, 1.0)
	var compression: float = sin(t * PI)
	var forward_component: float = -dodge_local_direction.y
	var side_component: float = dodge_local_direction.x
	_set_rot("pelvis", Vector3(deg_to_rad(18.0) * forward_component * compression, 0.0, deg_to_rad(-20.0) * side_component * compression))
	_set_rot("spine_01", Vector3(deg_to_rad(24.0) * forward_component * compression, 0.0, deg_to_rad(-18.0) * side_component * compression))
	_set_rot("thigh_l", Vector3(deg_to_rad(-26.0) * compression, 0.0, 0.0))
	_set_rot("thigh_r", Vector3(deg_to_rad(-18.0) * compression, 0.0, 0.0))
	_set_rot("calf_l", Vector3(deg_to_rad(42.0) * compression, 0.0, 0.0))
	_set_rot("calf_r", Vector3(deg_to_rad(34.0) * compression, 0.0, 0.0))


func _apply_hit_pose(t_raw: float) -> void:
	var recoil: float = sin(clampf(t_raw, 0.0, 1.0) * PI)
	_set_rot("spine_01", Vector3(deg_to_rad(-14.0) * recoil, 0.0, 0.0))
	_set_rot("chest", Vector3(deg_to_rad(-18.0) * recoil, deg_to_rad(8.0) * recoil, 0.0))
	_set_rot("upperarm_l", Vector3(deg_to_rad(20.0) * recoil, 0.0, deg_to_rad(-10.0)))
	_set_rot("upperarm_r", Vector3(deg_to_rad(20.0) * recoil, 0.0, deg_to_rad(10.0)))


func _start_action(action: StringName) -> void:
	current_action = action
	action_time = 0.0


func _end_action() -> void:
	var ended_action: StringName = current_action
	current_action = ACTION_NONE
	action_time = 0.0
	if ended_action == ACTION_ATTACK:
		attack_duration = ATTACK_DURATION
		attack_kind = &"light"


func _set_rot(bone_name: String, euler: Vector3) -> void:
	if skeleton == null or not bone_indices.has(bone_name):
		return
	skeleton.set_bone_pose_rotation(int(bone_indices[bone_name]), Quaternion.from_euler(euler))
