extends "res://presentation/characters/runtime/humanoid_character_presentation.gd"
class_name UnderworldPrototypeMannequin

## Primitive regression presentation for the neutral humanoid runtime.
## Gameplay collision remains owned by Player; this node is visual-only.

var torso_material: StandardMaterial3D
var limb_material: StandardMaterial3D
var head_material: StandardMaterial3D
var accent_material: StandardMaterial3D
var face_material: StandardMaterial3D


func _build_presentation_materials() -> void:
	torso_material = _material(Color(0.22, 0.28, 0.36))
	limb_material = _material(Color(0.43, 0.49, 0.58))
	head_material = _material(Color(0.68, 0.58, 0.45))
	accent_material = _material(Color(0.18, 0.35, 0.52))
	face_material = _material(Color(0.035, 0.045, 0.06))


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material


func _build_presentation_visuals() -> void:
	_attach_box("pelvis", "Pelvis", Vector3(0.34, 0.22, 0.24), Vector3.ZERO, torso_material)
	_attach_box("spine_01", "Torso", Vector3(0.38, 0.34, 0.23), Vector3(0.0, 0.14, 0.0), torso_material)
	_attach_box("chest", "Chest", Vector3(0.48, 0.22, 0.25), Vector3(0.0, 0.03, 0.0), torso_material)
	_attach_box("head", "Head", Vector3(0.23, 0.26, 0.22), Vector3(0.0, 0.10, 0.0), head_material)
	_attach_box("upperarm_l", "UpperArmL", Vector3(0.29, 0.13, 0.14), Vector3(-0.145, 0.0, 0.0), limb_material)
	_attach_box("forearm_l", "ForearmL", Vector3(0.26, 0.12, 0.12), Vector3(-0.13, 0.0, 0.0), limb_material)
	_attach_box("hand_l", "HandL", Vector3(0.14, 0.14, 0.11), Vector3(-0.06, 0.0, 0.0), accent_material)
	_attach_box("upperarm_r", "UpperArmR", Vector3(0.29, 0.13, 0.14), Vector3(0.145, 0.0, 0.0), limb_material)
	_attach_box("forearm_r", "ForearmR", Vector3(0.26, 0.12, 0.12), Vector3(0.13, 0.0, 0.0), limb_material)
	_attach_box("hand_r", "HandR", Vector3(0.14, 0.14, 0.11), Vector3(0.06, 0.0, 0.0), accent_material)
	_attach_box("thigh_l", "ThighL", Vector3(0.17, 0.42, 0.19), Vector3(0.0, -0.21, 0.0), limb_material)
	_attach_box("calf_l", "CalfL", Vector3(0.15, 0.36, 0.16), Vector3(0.0, -0.18, 0.0), limb_material)
	_attach_box("foot_l", "FootL", Vector3(0.16, 0.12, 0.29), Vector3(0.0, -0.04, 0.10), accent_material)
	_attach_box("thigh_r", "ThighR", Vector3(0.17, 0.42, 0.19), Vector3(0.0, -0.21, 0.0), limb_material)
	_attach_box("calf_r", "CalfR", Vector3(0.15, 0.36, 0.16), Vector3(0.0, -0.18, 0.0), limb_material)
	_attach_box("foot_r", "FootR", Vector3(0.16, 0.12, 0.29), Vector3(0.0, -0.04, 0.10), accent_material)
	_add_round_detail("clavicle_l", "ShoulderL", 0.16, accent_material)
	_add_round_detail("clavicle_r", "ShoulderR", 0.16, accent_material)
	_add_belt_detail()


func _add_round_detail(bone_name: String, visual_name: String, radius: float, material: Material) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.name = visual_name + "Attachment"
	skeleton.add_child(attachment)
	attachment.bone_idx = skeleton.find_bone(bone_name)
	attachment.on_skeleton_update()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = visual_name
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_instance.mesh = sphere
	mesh_instance.material_override = material
	attachment.add_child(mesh_instance)


func _add_belt_detail() -> void:
	var pelvis_attachment := skeleton.get_node_or_null("PelvisAttachment")
	if pelvis_attachment == null:
		return
	var belt := MeshInstance3D.new()
	belt.name = "Belt"
	var belt_mesh := CylinderMesh.new()
	belt_mesh.top_radius = 0.21
	belt_mesh.bottom_radius = 0.21
	belt_mesh.height = 0.08
	belt.mesh = belt_mesh
	belt.position = Vector3(0.0, 0.03, 0.0)
	belt.material_override = accent_material
	pelvis_attachment.add_child(belt)


func _build_presentation_face_details() -> void:
	var head_attachment := skeleton.get_node_or_null("HeadAttachment")
	if head_attachment == null:
		return
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.035
	eye_mesh.height = 0.07
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.name = "EyeL" if side < 0.0 else "EyeR"
		eye.mesh = eye_mesh
		eye.position = Vector3(0.075 * side, 0.12, -0.205)
		eye.material_override = face_material
		head_attachment.add_child(eye)


func _attach_box(
	bone_name: String,
	visual_name: String,
	size: Vector3,
	offset: Vector3,
	material: Material
) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.name = visual_name + "Attachment"
	skeleton.add_child(attachment)
	attachment.bone_idx = skeleton.find_bone(bone_name)
	attachment.on_skeleton_update()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = visual_name
	if visual_name == "Head":
		var head := SphereMesh.new()
		head.radius = maxf(size.x, size.z)
		head.height = size.y * 1.45
		mesh_instance.mesh = head
	elif visual_name in ["Pelvis", "Torso", "Chest", "UpperArmL", "UpperArmR", "ForearmL", "ForearmR", "ThighL", "ThighR", "CalfL", "CalfR"]:
		var capsule := CapsuleMesh.new()
		capsule.radius = maxf(minf(size.x, size.z) * 0.52, 0.04)
		capsule.height = maxf(size.y, capsule.radius * 2.0 + 0.02)
		mesh_instance.mesh = capsule
		if visual_name in ["UpperArmL", "UpperArmR", "ForearmL", "ForearmR"]:
			mesh_instance.rotation.z = PI * 0.5
	else:
		var box := BoxMesh.new()
		box.size = size
		mesh_instance.mesh = box
	mesh_instance.position = offset
	mesh_instance.material_override = material
	attachment.add_child(mesh_instance)
