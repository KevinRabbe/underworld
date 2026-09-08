extends MeshInstance3D

const GeneratedObjectRuntimeScript := preload("res://world/runtime/chunks/generated_object_runtime.gd")

var chunk_coord: Vector2i = Vector2i.ZERO
var _collision_body: StaticBody3D
var _collision_heights: PackedFloat32Array = PackedFloat32Array()
var _collision_resolution: int = 0
var _collision_spacing: float = 1.0
var _generated_objects := GeneratedObjectRuntimeScript.new()

var moisture: PackedFloat32Array = PackedFloat32Array()
var forest_density: PackedFloat32Array = PackedFloat32Array()
var rockiness: PackedFloat32Array = PackedFloat32Array()
var buildability: PackedFloat32Array = PackedFloat32Array()

var tree_instance_count: int:
	get:
		return _generated_objects.tree_instance_count
var rock_instance_count: int:
	get:
		return _generated_objects.rock_instance_count
var branch_instance_count: int:
	get:
		return _generated_objects.branch_instance_count
var loose_stone_instance_count: int:
	get:
		return _generated_objects.loose_stone_instance_count


func build(
	coord: Vector2i,
	data: Dictionary,
	terrain_material: Material,
	decoration_assets: Dictionary,
	world_settings,
	destroyed_objects: Dictionary,
	with_collision: bool
) -> void:
	chunk_coord = coord
	name = "Chunk_%d_%d" % [coord.x, coord.y]

	_collision_heights = data["collision_heights"]
	_collision_resolution = data["resolution"]
	_collision_spacing = data["spacing"]
	moisture = data["moisture"]
	forest_density = data["forest_density"]
	rockiness = data["rockiness"]
	buildability = data["buildability"]

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_TEX_UV] = data["uvs"]
	arrays[Mesh.ARRAY_COLOR] = data["colors"]
	arrays[Mesh.ARRAY_INDEX] = data["indices"]

	var array_mesh: ArrayMesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = array_mesh
	material_override = terrain_material

	_generated_objects.build(
		self,
		coord,
		data,
		decoration_assets,
		world_settings,
		destroyed_objects
	)
	set_collision_enabled(with_collision)


func update_world_object_physics(
	player_world_position: Vector3,
	activation_radius: float,
	release_radius: float
) -> void:
	_generated_objects.update_world_object_physics(
		to_local(player_world_position),
		activation_radius,
		release_radius
	)


func find_nearby_pickups(player_world_position: Vector3, radius: float) -> Array:
	return _generated_objects.find_nearby_pickups(to_local(player_world_position), radius)


func collect_nearby_pickups(player_world_position: Vector3, radius: float) -> Array:
	return _generated_objects.collect_nearby_pickups(to_local(player_world_position), radius)


func get_active_world_object_count() -> int:
	return _generated_objects.get_active_world_object_count()


func get_pickup_counts() -> Vector2i:
	return _generated_objects.get_pickup_counts()


func destroy_world_object(object_type: String, index: int) -> bool:
	return _generated_objects.destroy_world_object(object_type, index)


func _make_object_id(object_type: String, index: int) -> String:
	return _generated_objects.make_object_id(object_type, index)


func set_collision_enabled(enabled: bool) -> void:
	if enabled and _collision_body == null:
		_create_collision()
	elif not enabled and _collision_body != null:
		_collision_body.queue_free()
		_collision_body = null


func _create_collision() -> void:
	if _collision_resolution < 2 or _collision_heights.is_empty():
		return

	var spacing: float = maxf(_collision_spacing, 0.001)
	var scaled_heights: PackedFloat32Array = PackedFloat32Array()
	scaled_heights.resize(_collision_heights.size())

	for index in range(_collision_heights.size()):
		scaled_heights[index] = _collision_heights[index] / spacing

	var shape: HeightMapShape3D = HeightMapShape3D.new()
	shape.map_width = _collision_resolution
	shape.map_depth = _collision_resolution
	shape.map_data = scaled_heights

	_collision_body = StaticBody3D.new()
	_collision_body.name = "TerrainCollision"
	_collision_body.collision_layer = 1
	_collision_body.collision_mask = 1
	_collision_body.scale = Vector3.ONE * spacing

	var local_extent: float = float(_collision_resolution - 1)
	_collision_body.position = Vector3(
		local_extent * 0.5 * spacing,
		0.0,
		local_extent * 0.5 * spacing
	)

	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.shape = shape
	_collision_body.add_child(collision_shape)
	add_child(_collision_body)
