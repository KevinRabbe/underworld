extends MeshInstance3D

var chunk_coord := Vector2i.ZERO
var _collision_body: StaticBody3D


func build(
	coord: Vector2i,
	data: Dictionary,
	terrain_material: Material,
	with_collision: bool
) -> void:
	chunk_coord = coord
	name = "Chunk_%d_%d" % [coord.x, coord.y]

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_TEX_UV] = data["uvs"]
	arrays[Mesh.ARRAY_INDEX] = data["indices"]

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = array_mesh
	material_override = terrain_material

	set_collision_enabled(with_collision)


func set_collision_enabled(enabled: bool) -> void:
	if enabled and _collision_body == null:
		_create_collision()
	elif not enabled and _collision_body != null:
		_collision_body.queue_free()
		_collision_body = null


func _create_collision() -> void:
	if mesh == null:
		return

	var shape := mesh.create_trimesh_shape()
	if shape == null:
		return

	_collision_body = StaticBody3D.new()
	_collision_body.name = "TerrainCollision"
	_collision_body.collision_layer = 1
	_collision_body.collision_mask = 1

	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	_collision_body.add_child(collision_shape)
	add_child(_collision_body)
