extends "res://presentation/characters/runtime/character_presentation_provider.gd"
class_name UnderworldAuthoredCharacterPresentationProvider

const AuthoredCharacter := preload("res://presentation/characters/authored/authored_character_presentation.gd")
const AuthoredAnimationRuntimeFactory := preload("res://presentation/characters/authored/authored_character_animation_runtime_factory.gd")
const PrototypeMannequinProvider := preload("res://presentation/characters/player/prototype_mannequin/prototype_mannequin_presentation_provider.gd")
const MODEL_PATH := AuthoredCharacter.MODEL_PATH
const SUPPORTED_TOOLS: Array[String] = ["hands", "stone_axe", "stone_pickaxe"]

var fallback_provider = PrototypeMannequinProvider.new()
var last_create_used_fallback: bool = false
var model_path: String = MODEL_PATH


func _init(model_path_override: String = MODEL_PATH) -> void:
	model_path = model_path_override


func create_presentation():
	last_create_used_fallback = not FileAccess.file_exists(ProjectSettings.globalize_path(model_path))
	if last_create_used_fallback:
		return fallback_provider.create_presentation()
	var character = AuthoredCharacter.new()
	character.name = "Character2Authored"
	return character


func build_animation_runtime(presentation) -> Dictionary:
	if presentation != null and presentation.has_method("set_tool_grip"):
		return AuthoredAnimationRuntimeFactory.build(presentation)
	return fallback_provider.build_animation_runtime(presentation)


func realize_held_item(presentation, attachment_root: Node3D, tool_id: String) -> bool:
	if presentation == null or not presentation.has_method("set_tool_grip"):
		return fallback_provider.realize_held_item(presentation, attachment_root, tool_id)
	if attachment_root == null or not SUPPORTED_TOOLS.has(tool_id):
		presentation.set_tool_grip(false)
		return false
	for child in attachment_root.get_children():
		attachment_root.remove_child(child)
		child.queue_free()
	if tool_id == "hands":
		presentation.set_tool_grip(false)
		return true
	presentation.set_tool_grip(true)
	_build_tool(attachment_root, tool_id)
	return true


func _build_tool(attachment_root: Node3D, tool_id: String) -> void:
	var handle_material := StandardMaterial3D.new()
	handle_material.albedo_color = Color(0.30, 0.17, 0.07)
	var stone_material := StandardMaterial3D.new()
	stone_material.albedo_color = Color(0.32, 0.34, 0.33)

	var handle := MeshInstance3D.new()
	handle.name = "ToolHandle"
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.020
	handle_mesh.bottom_radius = 0.023
	handle_mesh.height = 0.62
	handle_mesh.radial_segments = 8
	handle.mesh = handle_mesh
	handle.material_override = handle_material
	attachment_root.add_child(handle)

	var head := MeshInstance3D.new()
	head.name = "ToolHead"
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.34, 0.18, 0.10) if tool_id == "stone_axe" else Vector3(0.52, 0.12, 0.10)
	head.mesh = head_mesh
	head.material_override = stone_material
	head.position = Vector3(-0.08, -0.28, 0.0)
	head.rotation_degrees.z = -15.0
	attachment_root.add_child(head)


func used_fallback() -> bool:
	return last_create_used_fallback
