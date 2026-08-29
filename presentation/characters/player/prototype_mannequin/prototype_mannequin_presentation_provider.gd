extends "res://presentation/characters/runtime/character_presentation_provider.gd"
class_name UnderworldPrototypeMannequinPresentationProvider

const PrototypeMannequin := preload("res://presentation/characters/player/prototype_mannequin/prototype_mannequin.gd")
const PrototypeAnimationRuntimeFactory := preload("res://presentation/characters/player/prototype_mannequin/prototype_animation_runtime_factory.gd")


func create_presentation():
	var mannequin = PrototypeMannequin.new()
	mannequin.name = "PrototypeMannequin"
	return mannequin


func build_animation_runtime(presentation) -> Dictionary:
	return PrototypeAnimationRuntimeFactory.build(presentation)


func realize_held_item(_presentation, attachment_root: Node3D, tool_id: String) -> bool:
	if attachment_root == null:
		return false
	for child in attachment_root.get_children():
		child.queue_free()
	if tool_id == "hands":
		return true
	var handle_material := StandardMaterial3D.new()
	handle_material.albedo_color = Color(0.30, 0.17, 0.07)
	var stone_material := StandardMaterial3D.new()
	stone_material.albedo_color = Color(0.36, 0.37, 0.34)
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.10, 0.72, 0.10)
	handle.mesh = handle_mesh
	handle.material_override = handle_material
	attachment_root.add_child(handle)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.38, 0.28, 0.13) if tool_id == "stone_axe" else Vector3(0.62, 0.16, 0.13)
	head.mesh = head_mesh
	head.material_override = stone_material
	head.position = Vector3(-0.10, 0.31, 0.0)
	head.rotation_degrees.z = -18.0
	attachment_root.add_child(head)
	return true
