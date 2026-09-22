extends Node3D

signal consumed(carcass_id: String)

var carcass_id: String = ""
var consumed_state: bool = false
var _body: StaticBody3D


func configure(id: String, world_position: Vector3) -> void:
	carcass_id = id
	global_position = world_position
	set_meta("carcass_id", carcass_id)
	set_meta("carcass_type", "boar")


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.name = "CarcassBody"
	_body.collision_layer = 1
	_body.collision_mask = 1
	add_child(_body)
	_body.set_meta("carcass_id", carcass_id)
	_body.set_meta("carcass_type", "boar")
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.65
	shape.height = 0.75
	collision.shape = shape
	collision.rotation_degrees.z = 90.0
	collision.position.y = 0.35
	_body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.65
	mesh.height = 0.75
	visual.mesh = mesh
	visual.rotation_degrees.z = 90.0
	visual.position.y = 0.35
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.10, 0.06)
	material.roughness = 1.0
	visual.material_override = material
	add_child(visual)


func mark_skinned() -> bool:
	if consumed_state:
		return false
	consumed_state = true
	set_meta("consumed", true)
	if _body != null:
		_body.collision_layer = 0
		_body.collision_mask = 0
	visible = false
	consumed.emit(carcass_id)
	return true


func is_consumed() -> bool:
	return consumed_state
