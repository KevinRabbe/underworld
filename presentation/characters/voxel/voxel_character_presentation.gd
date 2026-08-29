extends "res://presentation/characters/runtime/humanoid_character_presentation.gd"
class_name UnderworldVoxelCharacterPresentation

const CompilerScript := preload("res://presentation/characters/voxel/voxel_module_compiler.gd")
const BaselineFactoryScript := preload("res://presentation/characters/voxel/baseline_survivor_factory.gd")

const ROLE_TO_BONE := {
	"rig_role.root": "root", "rig_role.pelvis": "pelvis",
	"rig_role.spine.lower": "spine_01", "rig_role.spine.upper": "spine_02",
	"rig_role.chest": "chest", "rig_role.neck": "neck", "rig_role.head": "head",
	"rig_role.clavicle.left": "clavicle_l", "rig_role.upper_arm.left": "upperarm_l",
	"rig_role.forearm.left": "forearm_l", "rig_role.hand.left": "hand_l",
	"rig_role.clavicle.right": "clavicle_r", "rig_role.upper_arm.right": "upperarm_r",
	"rig_role.forearm.right": "forearm_r", "rig_role.hand.right": "hand_r",
	"rig_role.thigh.left": "thigh_l", "rig_role.calf.left": "calf_l", "rig_role.foot.left": "foot_l",
	"rig_role.thigh.right": "thigh_r", "rig_role.calf.right": "calf_r", "rig_role.foot.right": "foot_r",
}

static var _mesh_data_cache: Dictionary = {}

var character_definition: Resource
var mesh_metrics: Dictionary = {}
var module_fingerprint: String = ""
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var current_animation_state: StringName = &"idle"
var death_pose_active: bool = false


func _init(definition: Resource = null) -> void:
	character_definition = definition if definition != null else BaselineFactoryScript.build()


func build() -> void:
	if character_definition == null:
		push_error("Voxel character requires definition")
		return
	var failures: Array[String] = character_definition.validate_definition()
	if not failures.is_empty():
		for failure in failures: push_error("Voxel character: %s" % failure)
		return
	super.build()
	# The mannequin fixture carries a strongly diagonal primitive-tool socket.
	# Voxel tools author their complete handle/head relationship in module space,
	# so keep that authored silhouette visibly outboard and diagonal at the hand.
	if tool_visual_root != null:
		tool_visual_root.position = Vector3(0.13, 0.02, 0.01)
		tool_visual_root.rotation_degrees = Vector3(0.0, 0.0, -35.0)
	_build_animation_graph()


func _build_presentation_materials() -> void:
	# Palette materials are created per compiled surface during realization.
	pass


func _build_presentation_visuals() -> void:
	var character_fingerprint: String = character_definition.canonical_fingerprint()
	var palette_fingerprint: String = character_definition.palette.canonical_fingerprint()
	var totals := {"parts": 0, "cells": 0, "triangles": 0, "vertices": 0, "estimated_bytes": 0, "compilation_usec": 0, "resource_creation_usec": 0, "cache_hits": 0}
	var part_fingerprints: Array[String] = []
	for module in character_definition.modules:
		if module.slot_id == &"held_item":
			continue
		var module_fingerprint_value: String = module.canonical_fingerprint()
		for part_value in module.resolved_parts():
			var part: Dictionary = part_value
			var cache_key := "%s|%s|%s|%.6f|%.6f|%d" % [module_fingerprint_value, str(part.get("part_id", "")), palette_fingerprint, character_definition.voxel_size, character_definition.presentation_scale, CompilerScript.COMPILER_REVISION]
			var mesh_data = _mesh_data_cache.get(cache_key)
			if mesh_data == null:
				mesh_data = CompilerScript.compile_part(part, character_definition.voxel_size, character_definition.palette, module_fingerprint_value)
				if mesh_data.success: _mesh_data_cache[cache_key] = mesh_data
			else:
				totals["cache_hits"] += 1
			if not mesh_data.success:
				for diagnostic in mesh_data.diagnostics: push_error("Voxel part %s: %s" % [mesh_data.part_id, diagnostic])
				continue
			var realization_started_usec: int = Time.get_ticks_usec()
			_realize_part(part, mesh_data)
			totals["resource_creation_usec"] += Time.get_ticks_usec() - realization_started_usec
			part_fingerprints.append(mesh_data.source_fingerprint)
			totals["parts"] += 1
			totals["cells"] += int(mesh_data.metrics.get("occupied_cells", 0))
			totals["triangles"] += int(mesh_data.metrics.get("triangles", 0))
			totals["vertices"] += int(mesh_data.metrics.get("vertices", 0))
			totals["estimated_bytes"] += int(mesh_data.metrics.get("estimated_bytes", 0))
			totals["compilation_usec"] += int(mesh_data.metrics.get("compilation_usec", 0))
	part_fingerprints.sort()
	module_fingerprint = "vpresentation1:sha256:" + (character_fingerprint + "|" + ";".join(part_fingerprints)).sha256_text()
	mesh_metrics = totals


func _build_presentation_face_details() -> void:
	# Face cells are authored as part of the voxel head module.
	pass


func _realize_part(part: Dictionary, mesh_data) -> void:
	var bone_name: String = str(ROLE_TO_BONE.get(str(part.get("rig_role", "")), ""))
	if bone_name.is_empty(): return
	var attachment := BoneAttachment3D.new()
	attachment.name = "Voxel%sAttachment" % str(part.get("part_id", "")).to_pascal_case()
	skeleton.add_child(attachment)
	attachment.bone_idx = skeleton.find_bone(bone_name)
	attachment.on_skeleton_update()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Voxel%s" % str(part.get("part_id", "")).to_pascal_case()
	var array_mesh := ArrayMesh.new()
	for surface in mesh_data.surfaces:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surface["vertices"]
		arrays[Mesh.ARRAY_NORMAL] = surface["normals"]
		arrays[Mesh.ARRAY_COLOR] = surface["colors"]
		arrays[Mesh.ARRAY_INDEX] = surface["indices"]
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		array_mesh.surface_set_material(array_mesh.get_surface_count() - 1, _material_for_palette(int(surface["palette_index"])))
	mesh_instance.mesh = array_mesh
	mesh_instance.scale = Vector3.ONE * character_definition.presentation_scale
	attachment.add_child(mesh_instance)


func set_held_item(tool_id: String, attachment_root: Node3D = null) -> bool:
	var resolved_root: Node3D = attachment_root if attachment_root != null else tool_visual_root
	if resolved_root == null or resolved_root != tool_visual_root:
		return false
	for child in resolved_root.get_children():
		resolved_root.remove_child(child)
		child.queue_free()
	if tool_id == "hands":
		return true
	var module = character_definition.module_for_slot(&"held_item")
	if module == null:
		return false
	var module_fingerprint_value: String = module.canonical_fingerprint()
	var realized_parts: int = 0
	for part_value in module.resolved_parts():
		var part: Dictionary = part_value
		if str(part.get("variant_id", "")) != tool_id:
			continue
		var mesh_data = CompilerScript.compile_part(part, character_definition.voxel_size, character_definition.palette, module_fingerprint_value)
		if not mesh_data.success:
			continue
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "VoxelHeld%s" % str(part.get("part_id", "")).to_pascal_case()
		mesh_instance.mesh = _array_mesh_for_data(mesh_data)
		mesh_instance.scale = Vector3.ONE * character_definition.presentation_scale
		resolved_root.add_child(mesh_instance)
		realized_parts += 1
	return realized_parts > 0


func _array_mesh_for_data(mesh_data) -> ArrayMesh:
	var array_mesh := ArrayMesh.new()
	for surface in mesh_data.surfaces:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surface["vertices"]
		arrays[Mesh.ARRAY_NORMAL] = surface["normals"]
		arrays[Mesh.ARRAY_COLOR] = surface["colors"]
		arrays[Mesh.ARRAY_INDEX] = surface["indices"]
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		array_mesh.surface_set_material(array_mesh.get_surface_count() - 1, _material_for_palette(int(surface["palette_index"])))
	return array_mesh


func _material_for_palette(palette_index: int) -> StandardMaterial3D:
	var entry: Dictionary = character_definition.palette.entry(palette_index)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = float(entry.get("roughness", 0.8))
	material.metallic = float(entry.get("metallic", 0.0))
	var emission_strength: float = float(entry.get("emission", 0.0))
	if emission_strength > 0.0:
		material.emission_enabled = true
		material.emission = Color(entry.get("color", Color.WHITE)) * emission_strength
	return material


func _build_animation_graph() -> void:
	animation_player = AnimationPlayer.new()
	animation_player.name = "VoxelAnimationPlayer"
	add_child(animation_player)
	var library := AnimationLibrary.new()
	for clip_name in ["idle", "walk_forward", "walk_backward", "strafe_left", "strafe_right", "sprint", "jump", "fall", "dodge_forward", "dodge_backward", "dodge_left", "dodge_right", "attack_light", "attack_heavy", "block", "parry", "hit", "death", "tool_use"]:
		library.add_animation(clip_name, _build_pose_clip(clip_name))
	animation_player.add_animation_library("", library)
	animation_tree = AnimationTree.new()
	animation_tree.name = "VoxelAnimationTree"
	animation_tree.anim_player = NodePath("../VoxelAnimationPlayer")
	var state_machine := AnimationNodeStateMachine.new()
	var locomotion := AnimationNodeBlendSpace2D.new()
	locomotion.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_DISCRETE_CARRY
	for point_data in [["idle", Vector2.ZERO], ["walk_forward", Vector2(0,1)], ["walk_backward", Vector2(0,-1)], ["strafe_left", Vector2(-1,0)], ["strafe_right", Vector2(1,0)]]:
		var locomotion_node := AnimationNodeAnimation.new()
		locomotion_node.resource_name = point_data[0]
		locomotion_node.animation = point_data[0]
		locomotion.add_blend_point(locomotion_node, point_data[1], -1, StringName(point_data[0]))
	state_machine.add_node("locomotion", locomotion)
	for clip_name in ["sprint", "jump", "fall", "dodge_forward", "dodge_backward", "dodge_left", "dodge_right", "attack_light", "attack_heavy", "block", "parry", "hit", "death", "tool_use"]:
		var node := AnimationNodeAnimation.new()
		node.animation = clip_name
		state_machine.add_node(clip_name, node)
	animation_tree.tree_root = state_machine
	add_child(animation_tree)
	animation_tree.active = true
	_set_animation_state(&"locomotion")


func update_visual(delta: float, local_horizontal_velocity: Vector3, grounded: bool, sprinting: bool) -> void:
	update_voxel_visual(delta, local_horizontal_velocity, local_horizontal_velocity.y, grounded, sprinting)


func update_voxel_visual(delta: float, local_horizontal_velocity: Vector3, vertical_velocity: float, grounded: bool, sprinting: bool) -> void:
	super.update_visual(delta, local_horizontal_velocity, grounded, sprinting)
	if death_pose_active:
		return
	if current_action != ACTION_NONE or blocking_pose_active:
		return
	if not grounded:
		_set_animation_state(&"jump" if vertical_velocity > 0.2 else &"fall")
	elif Vector2(local_horizontal_velocity.x, local_horizontal_velocity.z).length() < 0.08:
		_set_locomotion_state(local_horizontal_velocity)
	else:
		if sprinting:
			_set_animation_state(&"sprint")
		else:
			_set_locomotion_state(local_horizontal_velocity)


func play_attack(duration: float = ATTACK_DURATION, kind: StringName = &"light") -> void:
	super.play_attack(duration, kind)
	_set_timed_animation_state(&"attack_heavy" if kind == &"heavy" else &"attack_light", duration)


func play_tool_use(duration: float = ATTACK_DURATION) -> void:
	super.play_attack(duration, &"light")
	_set_timed_animation_state(&"tool_use", duration)


func play_parry() -> void:
	super.play_parry()
	_set_timed_animation_state(&"parry", PARRY_DURATION)


func play_dodge(local_direction: Vector2) -> void:
	super.play_dodge(local_direction)
	_set_timed_animation_state(_dodge_state(local_direction), DODGE_DURATION)


func play_hit() -> void:
	super.play_hit()
	_set_timed_animation_state(&"hit", HIT_DURATION)


func set_blocking(active: bool) -> void:
	super.set_blocking(active)
	_set_animation_state(&"block" if active else &"locomotion")


func play_death() -> void:
	death_pose_active = true
	_set_animation_state(&"death")


func reset_pose() -> void:
	death_pose_active = false
	super.reset_pose()
	if animation_tree != null:
		_set_animation_state(&"locomotion")


func _set_locomotion_state(local_velocity: Vector3) -> void:
	if animation_tree != null:
		var horizontal := Vector2(local_velocity.x, local_velocity.z)
		var blend := horizontal.normalized() if horizontal.length() > 0.08 else Vector2.ZERO
		animation_tree.set("parameters/locomotion/blend_position", blend)
	_set_animation_state(&"locomotion")


func _set_timed_animation_state(state_name: StringName, duration: float) -> void:
	if animation_player != null:
		animation_player.speed_scale = 1.0 / maxf(duration, 0.05)
	_set_animation_state(state_name)


func _dodge_state(local_direction: Vector2) -> StringName:
	if absf(local_direction.x) > absf(local_direction.y):
		return &"dodge_right" if local_direction.x > 0.0 else &"dodge_left"
	return &"dodge_forward" if local_direction.y >= 0.0 else &"dodge_backward"


func _set_animation_state(state_name: StringName) -> void:
	if current_animation_state == state_name and state_name in [&"locomotion", &"sprint"]:
		return
	current_animation_state = state_name
	if animation_player != null and state_name in [&"locomotion", &"sprint"]:
		animation_player.speed_scale = 1.0
	if animation_tree == null or not animation_tree.active:
		return
	var playback = animation_tree.get("parameters/playback")
	if playback != null and playback.has_method("start"):
		playback.start(state_name)


func _build_pose_clip(clip_name: String) -> Animation:
	var animation := Animation.new()
	animation.length = 1.0
	animation.loop_mode = Animation.LOOP_LINEAR if clip_name in ["idle", "walk_forward", "walk_backward", "strafe_left", "strafe_right", "sprint", "block"] else Animation.LOOP_NONE
	match clip_name:
		"idle":
			_add_rotation_keys(animation, "chest", [[0.0, Vector3.ZERO], [0.5, Vector3(deg_to_rad(2),0,0)], [1.0, Vector3.ZERO]])
			_add_rotation_keys(animation, "head", [[0.0, Vector3(0,deg_to_rad(-2),0)], [0.5, Vector3(0,deg_to_rad(2),0)], [1.0, Vector3(0,deg_to_rad(-2),0)]])
			_add_relaxed_arm_keys(animation)
		"walk_forward", "walk_backward":
			_add_gait_keys(animation, 24.0 if clip_name == "walk_forward" else -20.0, 0.08)
		"strafe_left", "strafe_right":
			var sign_value := -1.0 if clip_name == "strafe_left" else 1.0
			_add_rotation_keys(animation, "pelvis", [[0.0, Vector3(0,0,deg_to_rad(7)*sign_value)], [1.0, Vector3(0,0,deg_to_rad(7)*sign_value)]])
			_add_gait_keys(animation, 16.0, 0.04)
		"sprint":
			_add_gait_keys(animation, 42.0, 0.18)
			_add_rotation_keys(animation, "spine_01", [[0.0, Vector3(deg_to_rad(10),0,0)], [1.0, Vector3(deg_to_rad(10),0,0)]])
		"jump":
			_add_rotation_keys(animation, "thigh_l", [[0.0, Vector3(-0.3,0,0)], [1.0, Vector3(-0.3,0,0)]])
			_add_rotation_keys(animation, "thigh_r", [[0.0, Vector3(0.25,0,0)], [1.0, Vector3(0.25,0,0)]])
			_add_rotation_keys(animation, "calf_l", [[0.0, Vector3(0.45,0,0)], [1.0, Vector3(0.45,0,0)]])
			_add_rotation_keys(animation, "upperarm_l", [[0.0, Vector3(-0.25,0,deg_to_rad(54))], [1.0, Vector3(-0.25,0,deg_to_rad(54))]])
			_add_rotation_keys(animation, "upperarm_r", [[0.0, Vector3(-0.25,0,deg_to_rad(-54))], [1.0, Vector3(-0.25,0,deg_to_rad(-54))]])
		"fall":
			_add_rotation_keys(animation, "upperarm_l", [[0.0, Vector3(0,0,deg_to_rad(40))], [1.0, Vector3(0,0,deg_to_rad(40))]])
			_add_rotation_keys(animation, "upperarm_r", [[0.0, Vector3(0,0,deg_to_rad(-40))], [1.0, Vector3(0,0,deg_to_rad(-40))]])
			_add_rotation_keys(animation, "thigh_l", [[0.0, Vector3(-0.12,0,0)], [1.0, Vector3(-0.12,0,0)]])
			_add_rotation_keys(animation, "thigh_r", [[0.0, Vector3(0.16,0,0)], [1.0, Vector3(0.16,0,0)]])
		"dodge_forward", "dodge_backward":
			var pitch_sign := 1.0 if clip_name == "dodge_forward" else -1.0
			_add_rotation_keys(animation, "spine_01", [[0.0, Vector3.ZERO], [0.45, Vector3(deg_to_rad(32) * pitch_sign,0,0)], [1.0, Vector3.ZERO]])
			_add_dodge_limb_keys(animation)
		"dodge_left", "dodge_right":
			var roll_sign := -1.0 if clip_name == "dodge_left" else 1.0
			_add_rotation_keys(animation, "spine_01", [[0.0, Vector3.ZERO], [0.45, Vector3(0,0,deg_to_rad(32) * roll_sign)], [1.0, Vector3.ZERO]])
			_add_dodge_limb_keys(animation)
		"attack_light": _add_light_attack_clip(animation)
		"attack_heavy": _add_heavy_attack_clip(animation)
		"tool_use": _add_tool_use_clip(animation)
		"block":
			_add_rotation_keys(animation, "chest", [[0.0, Vector3(0.08,-0.10,0)], [1.0, Vector3(0.08,-0.10,0)]])
			_add_rotation_keys(animation, "upperarm_r", [[0.0, Vector3(-0.30,0.72,deg_to_rad(-24))], [1.0, Vector3(-0.30,0.72,deg_to_rad(-24))]])
			_add_rotation_keys(animation, "upperarm_l", [[0.0, Vector3(-0.22,-0.56,deg_to_rad(34))], [1.0, Vector3(-0.22,-0.56,deg_to_rad(34))]])
			_add_rotation_keys(animation, "forearm_r", [[0.0, Vector3(-0.35,0,deg_to_rad(82))], [1.0, Vector3(-0.35,0,deg_to_rad(82))]])
			_add_rotation_keys(animation, "forearm_l", [[0.0, Vector3(-0.28,0,deg_to_rad(-72))], [1.0, Vector3(-0.28,0,deg_to_rad(-72))]])
		"parry": _add_parry_clip(animation)
		"hit": _add_hit_clip(animation)
		"death":
			_add_rotation_keys(animation, "root", [[0.0, Vector3.ZERO], [0.55, Vector3(0,0,deg_to_rad(42))], [1.0, Vector3(0,0,deg_to_rad(82))]])
			_add_rotation_keys(animation, "spine_01", [[0.0, Vector3.ZERO], [0.55, Vector3(deg_to_rad(24),0,0)], [1.0, Vector3(deg_to_rad(34),0,0)]])
			_add_rotation_keys(animation, "upperarm_l", [[0.0, _relaxed_upper_l()], [1.0, Vector3(0,0,deg_to_rad(-55))]])
			_add_rotation_keys(animation, "upperarm_r", [[0.0, _relaxed_upper_r()], [1.0, Vector3(0,0,deg_to_rad(48))]])
	return animation


func _add_gait_keys(animation: Animation, degrees: float, forward_lean: float) -> void:
	var amount := deg_to_rad(degrees)
	_add_rotation_keys(animation, "thigh_l", [[0.0, Vector3(amount,0,0)], [0.5, Vector3(-amount,0,0)], [1.0, Vector3(amount,0,0)]])
	_add_rotation_keys(animation, "thigh_r", [[0.0, Vector3(-amount,0,0)], [0.5, Vector3(amount,0,0)], [1.0, Vector3(-amount,0,0)]])
	_add_rotation_keys(animation, "calf_l", [[0.0, Vector3(0,0,0)], [0.5, Vector3(amount*0.55,0,0)], [1.0, Vector3(0,0,0)]])
	_add_rotation_keys(animation, "calf_r", [[0.0, Vector3(amount*0.55,0,0)], [0.5, Vector3(0,0,0)], [1.0, Vector3(amount*0.55,0,0)]])
	_add_rotation_keys(animation, "upperarm_l", [[0.0, Vector3(-amount*0.7,0,deg_to_rad(68))], [0.5, Vector3(amount*0.7,0,deg_to_rad(68))], [1.0, Vector3(-amount*0.7,0,deg_to_rad(68))]])
	_add_rotation_keys(animation, "upperarm_r", [[0.0, Vector3(amount*0.7,0,deg_to_rad(-68))], [0.5, Vector3(-amount*0.7,0,deg_to_rad(-68))], [1.0, Vector3(amount*0.7,0,deg_to_rad(-68))]])
	_add_rotation_keys(animation, "forearm_l", [[0.0, Vector3(-0.12,0,deg_to_rad(16))], [1.0, Vector3(-0.12,0,deg_to_rad(16))]])
	_add_rotation_keys(animation, "forearm_r", [[0.0, Vector3(-0.12,0,deg_to_rad(-16))], [1.0, Vector3(-0.12,0,deg_to_rad(-16))]])
	_add_rotation_keys(animation, "chest", [[0.0, Vector3(forward_lean,-amount*0.08,0)], [0.5, Vector3(forward_lean,amount*0.08,0)], [1.0, Vector3(forward_lean,-amount*0.08,0)]])


func _add_relaxed_arm_keys(animation: Animation) -> void:
	_add_rotation_keys(animation, "upperarm_l", [[0.0, Vector3(0,0,deg_to_rad(68))], [1.0, Vector3(0,0,deg_to_rad(68))]])
	_add_rotation_keys(animation, "upperarm_r", [[0.0, Vector3(0,0,deg_to_rad(-68))], [1.0, Vector3(0,0,deg_to_rad(-68))]])
	_add_rotation_keys(animation, "forearm_l", [[0.0, Vector3(-0.12,0,deg_to_rad(16))], [1.0, Vector3(-0.12,0,deg_to_rad(16))]])
	_add_rotation_keys(animation, "forearm_r", [[0.0, Vector3(-0.12,0,deg_to_rad(-16))], [1.0, Vector3(-0.12,0,deg_to_rad(-16))]])


func _add_light_attack_clip(animation: Animation) -> void:
	_add_rotation_keys(animation, "chest", [[0.0, Vector3.ZERO], [0.28, Vector3(0,-0.42,0)], [0.62, Vector3(-0.08,0.62,0)], [1.0, Vector3.ZERO]])
	_add_rotation_keys(animation, "upperarm_r", [[0.0, _relaxed_upper_r()], [0.28, Vector3(-0.32,0.72,deg_to_rad(-32))], [0.62, Vector3(0.28,-0.48,deg_to_rad(-18))], [1.0, _relaxed_upper_r()]])
	_add_rotation_keys(animation, "forearm_r", [[0.0, _relaxed_forearm_r()], [0.28, Vector3(-0.42,0,deg_to_rad(-68))], [0.62, Vector3(0.16,0,deg_to_rad(18))], [1.0, _relaxed_forearm_r()]])
	_add_rotation_keys(animation, "upperarm_l", [[0.0, _relaxed_upper_l()], [0.28, Vector3(-0.10,-0.18,deg_to_rad(56))], [0.62, Vector3(0.12,0.22,deg_to_rad(48))], [1.0, _relaxed_upper_l()]])
	_add_rotation_keys(animation, "forearm_l", [[0.0, _relaxed_forearm_l()], [1.0, _relaxed_forearm_l()]])


func _add_heavy_attack_clip(animation: Animation) -> void:
	_add_rotation_keys(animation, "pelvis", [[0.0, Vector3.ZERO], [0.38, Vector3(0,-0.12,deg_to_rad(-5))], [0.72, Vector3(0,0.18,deg_to_rad(6))], [1.0, Vector3.ZERO]])
	_add_rotation_keys(animation, "spine_01", [[0.0, Vector3.ZERO], [0.38, Vector3(-0.22,0,0)], [0.72, Vector3(0.28,0,0)], [1.0, Vector3.ZERO]])
	_add_rotation_keys(animation, "chest", [[0.0, Vector3.ZERO], [0.38, Vector3(-0.18,-0.45,0)], [0.72, Vector3(0.28,0.72,0)], [1.0, Vector3.ZERO]])
	_add_rotation_keys(animation, "upperarm_r", [[0.0, _relaxed_upper_r()], [0.38, Vector3(-0.12,0.18,deg_to_rad(72))], [0.72, Vector3(0.46,-0.28,deg_to_rad(-36))], [1.0, _relaxed_upper_r()]])
	_add_rotation_keys(animation, "forearm_r", [[0.0, _relaxed_forearm_r()], [0.38, Vector3(-0.28,0,deg_to_rad(24))], [0.72, Vector3(0.25,0,deg_to_rad(-42))], [1.0, _relaxed_forearm_r()]])
	_add_rotation_keys(animation, "upperarm_l", [[0.0, _relaxed_upper_l()], [0.38, Vector3(-0.24,-0.34,deg_to_rad(46))], [0.72, Vector3(0.18,0.24,deg_to_rad(58))], [1.0, _relaxed_upper_l()]])
	_add_rotation_keys(animation, "forearm_l", [[0.0, _relaxed_forearm_l()], [0.38, Vector3(-0.18,0,deg_to_rad(-34))], [0.72, Vector3(0.12,0,deg_to_rad(30))], [1.0, _relaxed_forearm_l()]])


func _add_tool_use_clip(animation: Animation) -> void:
	_add_rotation_keys(animation, "spine_01", [[0.0, Vector3.ZERO], [0.42, Vector3(-0.16,0,0)], [0.72, Vector3(0.3,0,0)], [1.0, Vector3.ZERO]])
	_add_rotation_keys(animation, "upperarm_r", [[0.0, _relaxed_upper_r()], [0.42, Vector3(-0.18,0.12,deg_to_rad(58))], [0.72, Vector3(0.52,-0.12,deg_to_rad(-44))], [1.0, _relaxed_upper_r()]])
	_add_rotation_keys(animation, "forearm_r", [[0.0, _relaxed_forearm_r()], [0.42, Vector3(-0.38,0,deg_to_rad(18))], [0.72, Vector3(0.18,0,deg_to_rad(-36))], [1.0, _relaxed_forearm_r()]])
	_add_rotation_keys(animation, "upperarm_l", [[0.0, _relaxed_upper_l()], [0.42, Vector3(-0.16,-0.28,deg_to_rad(48))], [0.72, Vector3(0.10,0.18,deg_to_rad(58))], [1.0, _relaxed_upper_l()]])
	_add_rotation_keys(animation, "forearm_l", [[0.0, _relaxed_forearm_l()], [1.0, _relaxed_forearm_l()]])
	_add_rotation_keys(animation, "head", [[0.0, Vector3.ZERO], [0.72, Vector3(0.18,0,0)], [1.0, Vector3.ZERO]])


func _add_parry_clip(animation: Animation) -> void:
	_add_rotation_keys(animation, "chest", [[0.0, Vector3.ZERO], [0.22, Vector3(0,-0.18,0)], [0.68, Vector3(0,0.16,0)], [1.0, Vector3.ZERO]])
	_add_rotation_keys(animation, "upperarm_r", [[0.0, _relaxed_upper_r()], [0.22, Vector3(-0.26,0.58,deg_to_rad(-18))], [0.68, Vector3(-0.18,0.34,deg_to_rad(-34))], [1.0, _relaxed_upper_r()]])
	_add_rotation_keys(animation, "forearm_r", [[0.0, _relaxed_forearm_r()], [0.22, Vector3(-0.42,0,deg_to_rad(-78))], [0.68, Vector3(-0.30,0,deg_to_rad(-54))], [1.0, _relaxed_forearm_r()]])
	_add_rotation_keys(animation, "upperarm_l", [[0.0, _relaxed_upper_l()], [0.22, Vector3(-0.18,-0.42,deg_to_rad(38))], [0.68, Vector3(-0.08,-0.20,deg_to_rad(52))], [1.0, _relaxed_upper_l()]])
	_add_rotation_keys(animation, "forearm_l", [[0.0, _relaxed_forearm_l()], [0.22, Vector3(-0.22,0,deg_to_rad(-58))], [0.68, _relaxed_forearm_l()], [1.0, _relaxed_forearm_l()]])


func _relaxed_upper_l() -> Vector3:
	return Vector3(0.0, 0.0, deg_to_rad(68.0))


func _relaxed_upper_r() -> Vector3:
	return Vector3(0.0, 0.0, deg_to_rad(-68.0))


func _relaxed_forearm_r() -> Vector3:
	return Vector3(-0.12, 0.0, deg_to_rad(-16.0))


func _relaxed_forearm_l() -> Vector3:
	return Vector3(-0.12, 0.0, deg_to_rad(16.0))


func _add_hit_clip(animation: Animation) -> void:
	_add_rotation_keys(animation, "chest", [[0.0, Vector3.ZERO], [0.45, Vector3(-0.45,0.15,0)], [1.0, Vector3.ZERO]])
	_add_rotation_keys(animation, "upperarm_l", [[0.0, _relaxed_upper_l()], [0.45, Vector3(0.28,-0.18,deg_to_rad(40))], [1.0, _relaxed_upper_l()]])
	_add_rotation_keys(animation, "upperarm_r", [[0.0, _relaxed_upper_r()], [0.45, Vector3(0.32,0.20,deg_to_rad(-42))], [1.0, _relaxed_upper_r()]])
	_add_rotation_keys(animation, "forearm_l", [[0.0, _relaxed_forearm_l()], [0.45, Vector3(0.18,0,deg_to_rad(36))], [1.0, _relaxed_forearm_l()]])
	_add_rotation_keys(animation, "forearm_r", [[0.0, _relaxed_forearm_r()], [0.45, Vector3(0.18,0,deg_to_rad(-36))], [1.0, _relaxed_forearm_r()]])


func _add_dodge_limb_keys(animation: Animation) -> void:
	_add_rotation_keys(animation, "thigh_l", [[0.0, Vector3.ZERO], [0.45, Vector3(-0.48,0,0)], [1.0, Vector3.ZERO]])
	_add_rotation_keys(animation, "thigh_r", [[0.0, Vector3.ZERO], [0.45, Vector3(-0.32,0,0)], [1.0, Vector3.ZERO]])
	_add_rotation_keys(animation, "calf_l", [[0.0, Vector3.ZERO], [0.45, Vector3(0.72,0,0)], [1.0, Vector3.ZERO]])
	_add_rotation_keys(animation, "calf_r", [[0.0, Vector3.ZERO], [0.45, Vector3(0.58,0,0)], [1.0, Vector3.ZERO]])
	_add_rotation_keys(animation, "upperarm_l", [[0.0, _relaxed_upper_l()], [0.45, Vector3(-0.38,-0.16,deg_to_rad(44))], [1.0, _relaxed_upper_l()]])
	_add_rotation_keys(animation, "upperarm_r", [[0.0, _relaxed_upper_r()], [0.45, Vector3(-0.38,0.16,deg_to_rad(-44))], [1.0, _relaxed_upper_r()]])
	_add_rotation_keys(animation, "forearm_l", [[0.0, _relaxed_forearm_l()], [0.45, Vector3(-0.18,0,deg_to_rad(42))], [1.0, _relaxed_forearm_l()]])
	_add_rotation_keys(animation, "forearm_r", [[0.0, _relaxed_forearm_r()], [0.45, Vector3(-0.18,0,deg_to_rad(-42))], [1.0, _relaxed_forearm_r()]])


func _add_rotation_keys(animation: Animation, bone_name: String, keys: Array) -> void:
	if not bone_indices.has(bone_name): return
	var track: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("Skeleton3D:bones/%d/rotation" % int(bone_indices[bone_name])))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	for key_data in keys:
		animation.track_insert_key(track, float(key_data[0]), Quaternion.from_euler(key_data[1]))


func presentation_fingerprint() -> String:
	return module_fingerprint


func get_animation_tree() -> AnimationTree:
	return animation_tree


func realized_visual_bounds() -> AABB:
	var bounds := AABB()
	var has_bounds := false
	var presentation_inverse := global_transform.affine_inverse()
	for child in find_children("Voxel*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = child
		if mesh_instance.name.begins_with("VoxelHeld") or mesh_instance.mesh == null:
			continue
		var local_transform: Transform3D = presentation_inverse * mesh_instance.global_transform
		var transformed_bounds: AABB = local_transform * mesh_instance.mesh.get_aabb()
		bounds = bounds.merge(transformed_bounds) if has_bounds else transformed_bounds
		has_bounds = true
	return bounds
