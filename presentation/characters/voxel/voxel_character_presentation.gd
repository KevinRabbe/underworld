extends "res://presentation/characters/player/prototype_mannequin/prototype_mannequin.gd"
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
	_build_animation_graph()


func _build_materials() -> void:
	# Palette materials are created per compiled surface. Parent fields remain
	# initialized for inherited socket/tool helpers and regression compatibility.
	super._build_materials()


func _build_body_boxes() -> void:
	var character_fingerprint: String = character_definition.canonical_fingerprint()
	var totals := {"parts": 0, "cells": 0, "triangles": 0, "vertices": 0, "estimated_bytes": 0}
	var part_fingerprints: Array[String] = []
	for module in character_definition.modules:
		if module.slot_id == &"held_item":
			continue
		var module_fingerprint_value: String = module.canonical_fingerprint()
		for part_value in module.parts:
			var part: Dictionary = part_value
			var cache_key := "%s|%s|%.6f" % [module_fingerprint_value, str(part.get("part_id", "")), character_definition.voxel_size]
			var mesh_data = _mesh_data_cache.get(cache_key)
			if mesh_data == null:
				mesh_data = CompilerScript.compile_part(part, character_definition.voxel_size, character_definition.palette, module_fingerprint_value)
				if mesh_data.success: _mesh_data_cache[cache_key] = mesh_data
			if not mesh_data.success:
				for diagnostic in mesh_data.diagnostics: push_error("Voxel part %s: %s" % [mesh_data.part_id, diagnostic])
				continue
			_realize_part(part, mesh_data)
			part_fingerprints.append(mesh_data.source_fingerprint)
			totals["parts"] += 1
			totals["cells"] += int(mesh_data.metrics.get("occupied_cells", 0))
			totals["triangles"] += int(mesh_data.metrics.get("triangles", 0))
			totals["vertices"] += int(mesh_data.metrics.get("vertices", 0))
			totals["estimated_bytes"] += int(mesh_data.metrics.get("estimated_bytes", 0))
	part_fingerprints.sort()
	module_fingerprint = "vpresentation1:sha256:" + (character_fingerprint + "|" + ";".join(part_fingerprints)).sha256_text()
	mesh_metrics = totals


func _build_face_details() -> void:
	# Face cells are authored as part of the voxel head module.
	pass


func _realize_part(part: Dictionary, mesh_data) -> void:
	var bone_name: String = str(ROLE_TO_BONE.get(str(part.get("rig_role", "")), ""))
	if bone_name.is_empty(): return
	var attachment := BoneAttachment3D.new()
	attachment.name = "Voxel%sAttachment" % str(part.get("part_id", "")).to_pascal_case()
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
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


func set_held_item(tool_id: String) -> void:
	if tool_visual_root == null:
		return
	for child in tool_visual_root.get_children():
		child.queue_free()
	if tool_id == "hands":
		return
	var module = character_definition.module_for_slot(&"held_item")
	if module == null:
		return
	var module_fingerprint_value: String = module.canonical_fingerprint()
	for part_value in module.parts:
		var part: Dictionary = part_value
		if str(part.get("variant_id", "")) != tool_id:
			continue
		var mesh_data = CompilerScript.compile_part(part, character_definition.voxel_size, character_definition.palette, module_fingerprint_value)
		if not mesh_data.success:
			continue
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "VoxelHeld%s" % str(part.get("part_id", "")).to_pascal_case()
		mesh_instance.mesh = _array_mesh_for_data(mesh_data)
		tool_visual_root.add_child(mesh_instance)


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
	for clip_name in ["idle", "walk", "sprint", "jump", "fall", "dodge", "attack_light", "attack_heavy", "block", "parry", "hit", "death", "tool_use"]:
		var animation := Animation.new()
		animation.length = 1.0
		animation.loop_mode = Animation.LOOP_LINEAR if clip_name in ["idle", "walk", "sprint"] else Animation.LOOP_NONE
		library.add_animation(clip_name, animation)
	animation_player.add_animation_library("", library)
	animation_tree = AnimationTree.new()
	animation_tree.name = "VoxelAnimationTree"
	animation_tree.anim_player = NodePath("../VoxelAnimationPlayer")
	var state_machine := AnimationNodeStateMachine.new()
	for clip_name in library.get_animation_list():
		var node := AnimationNodeAnimation.new()
		node.animation = clip_name
		state_machine.add_node(clip_name, node)
	animation_tree.tree_root = state_machine
	add_child(animation_tree)
	animation_tree.active = true
	_set_animation_state(&"idle")


func update_visual(delta: float, local_horizontal_velocity: Vector3, grounded: bool, sprinting: bool) -> void:
	super.update_visual(delta, local_horizontal_velocity, grounded, sprinting)
	if current_action != ACTION_NONE or blocking_pose_active:
		return
	if not grounded:
		_set_animation_state(&"jump" if local_horizontal_velocity.y > 0.2 else &"fall")
	elif Vector2(local_horizontal_velocity.x, local_horizontal_velocity.z).length() < 0.08:
		_set_animation_state(&"idle")
	else:
		_set_animation_state(&"sprint" if sprinting else &"walk")


func play_attack(duration: float = ATTACK_DURATION, kind: StringName = &"light") -> void:
	super.play_attack(duration, kind)
	_set_animation_state(&"attack_heavy" if kind == &"heavy" else &"attack_light")


func play_tool_use(duration: float = ATTACK_DURATION) -> void:
	super.play_attack(duration, &"light")
	_set_animation_state(&"tool_use")


func play_parry() -> void:
	super.play_parry()
	_set_animation_state(&"parry")


func play_dodge(local_direction: Vector2) -> void:
	super.play_dodge(local_direction)
	_set_animation_state(&"dodge")


func play_hit() -> void:
	super.play_hit()
	_set_animation_state(&"hit")


func set_blocking(active: bool) -> void:
	super.set_blocking(active)
	_set_animation_state(&"block" if active else &"idle")


func _set_animation_state(state_name: StringName) -> void:
	if current_animation_state == state_name and state_name in [&"idle", &"walk", &"sprint"]:
		return
	current_animation_state = state_name
	if animation_tree == null or not animation_tree.active:
		return
	var playback = animation_tree.get("parameters/playback")
	if playback != null and playback.has_method("start"):
		playback.start(state_name)


func presentation_fingerprint() -> String:
	return module_fingerprint


func get_animation_tree() -> AnimationTree:
	return animation_tree
