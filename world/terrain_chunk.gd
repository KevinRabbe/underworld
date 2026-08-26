extends MeshInstance3D

var chunk_coord: Vector2i = Vector2i.ZERO
var _collision_body: StaticBody3D
var _collision_heights: PackedFloat32Array = PackedFloat32Array()
var _collision_resolution: int = 0
var _collision_spacing: float = 1.0
var _settings: UnderworldWorldSettings

# Kept with the chunk because these masks will drive deterministic vegetation,
# rocks, resources, creatures, and later cave-surface clues.
var moisture: PackedFloat32Array = PackedFloat32Array()
var forest_density: PackedFloat32Array = PackedFloat32Array()
var rockiness: PackedFloat32Array = PackedFloat32Array()
var buildability: PackedFloat32Array = PackedFloat32Array()

var tree_instance_count: int = 0
var rock_instance_count: int = 0
var _tree_transforms: Array = []
var _rock_transforms: Array = []
var _world_object_root: Node3D
var _active_tree_bodies: Dictionary = {}
var _active_rock_bodies: Dictionary = {}


func build(
	coord: Vector2i,
	data: Dictionary,
	terrain_material: Material,
	decoration_assets: Dictionary,
	world_settings: UnderworldWorldSettings,
	with_collision: bool
) -> void:
	chunk_coord = coord
	name = "Chunk_%d_%d" % [coord.x, coord.y]
	_settings = world_settings

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

	_world_object_root = Node3D.new()
	_world_object_root.name = "NearWorldObjects"
	add_child(_world_object_root)

	_build_decorations(data, decoration_assets)
	set_collision_enabled(with_collision)


func _build_decorations(data: Dictionary, assets: Dictionary) -> void:
	_tree_transforms = data.get("tree_transforms", [])
	_rock_transforms = data.get("rock_transforms", [])
	tree_instance_count = _tree_transforms.size()
	rock_instance_count = _rock_transforms.size()

	if tree_instance_count > 0:
		_create_multimesh_instances(
			"Trees",
			assets["tree_mesh"],
			assets["tree_material"],
			_tree_transforms
		)

	if rock_instance_count > 0:
		_create_multimesh_instances(
			"Rocks",
			assets["rock_mesh"],
			assets["rock_material"],
			_rock_transforms
		)


func _create_multimesh_instances(
	node_name: String,
	instance_mesh: Mesh,
	instance_material: Material,
	transforms: Array
) -> void:
	var multi_mesh: MultiMesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = instance_mesh
	multi_mesh.instance_count = transforms.size()

	for index in range(transforms.size()):
		var instance_transform: Transform3D = transforms[index]
		multi_mesh.set_instance_transform(index, instance_transform)

	var multi_mesh_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	multi_mesh_instance.name = node_name
	multi_mesh_instance.multimesh = multi_mesh
	multi_mesh_instance.material_override = instance_material
	add_child(multi_mesh_instance)


func update_world_object_physics(
	player_world_position: Vector3,
	activation_radius: float,
	release_radius: float
) -> void:
	if _world_object_root == null or _settings == null:
		return

	var player_local: Vector3 = to_local(player_world_position)
	var activation_sq: float = activation_radius * activation_radius
	var release_sq: float = release_radius * release_radius

	_update_proxy_set(
		_tree_transforms,
		_active_tree_bodies,
		"tree",
		player_local,
		activation_sq,
		release_sq
	)
	_update_proxy_set(
		_rock_transforms,
		_active_rock_bodies,
		"rock",
		player_local,
		activation_sq,
		release_sq
	)


func get_active_world_object_count() -> int:
	return _active_tree_bodies.size() + _active_rock_bodies.size()


func _update_proxy_set(
	transforms: Array,
	active_bodies: Dictionary,
	object_type: String,
	player_local: Vector3,
	activation_sq: float,
	release_sq: float
) -> void:
	# Release with a larger radius than activation so objects do not constantly
	# create/destroy when the player hovers on the boundary.
	for key in active_bodies.keys():
		var index: int = int(key)
		if index < 0 or index >= transforms.size():
			active_bodies[index].queue_free()
			active_bodies.erase(index)
			continue

		var existing_transform: Transform3D = transforms[index]
		if _horizontal_distance_squared(existing_transform.origin, player_local) > release_sq:
			active_bodies[index].queue_free()
			active_bodies.erase(index)

	for index in range(transforms.size()):
		if active_bodies.has(index):
			continue

		var instance_transform: Transform3D = transforms[index]
		if _horizontal_distance_squared(instance_transform.origin, player_local) > activation_sq:
			continue

		var body: StaticBody3D = _create_world_object_body(
			object_type,
			index,
			instance_transform
		)
		_world_object_root.add_child(body)
		active_bodies[index] = body


func _create_world_object_body(
	object_type: String,
	index: int,
	instance_transform: Transform3D
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "%s_%d" % [object_type.capitalize(), index]
	body.collision_layer = 1
	body.collision_mask = 1
	body.set_meta("world_object_type", object_type)
	body.set_meta("world_object_index", index)
	body.set_meta("world_object_chunk", chunk_coord)
	body.set_meta(
		"world_object_id",
		"%d:%d:%s:%d" % [chunk_coord.x, chunk_coord.y, object_type, index]
	)

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"

	if object_type == "tree":
		var uniform_scale: float = maxf(instance_transform.basis.x.length(), 0.05)
		var capsule: CapsuleShape3D = CapsuleShape3D.new()
		capsule.radius = _settings.tree_collider_radius * uniform_scale
		capsule.height = maxf(
			_settings.tree_collider_height * uniform_scale,
			capsule.radius * 2.0
		)
		collision.shape = capsule
		collision.position = instance_transform.origin
	else:
		var rock_scale: Vector3 = Vector3(
			maxf(instance_transform.basis.x.length(), 0.05),
			maxf(instance_transform.basis.y.length(), 0.05),
			maxf(instance_transform.basis.z.length(), 0.05)
		)
		var box: BoxShape3D = BoxShape3D.new()
		box.size = rock_scale
		collision.shape = box
		collision.transform = Transform3D(
			instance_transform.basis.orthonormalized(),
			instance_transform.origin
		)

	body.add_child(collision)
	return body


func _horizontal_distance_squared(a: Vector3, b: Vector3) -> float:
	var dx: float = a.x - b.x
	var dz: float = a.z - b.z
	return dx * dx + dz * dz


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

	# HeightMapShape3D uses one local unit between height samples. Scale the
	# whole static body uniformly by the terrain spacing, then divide the
	# stored heights by the same amount so X, Y and Z end up in world units.
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

	# HeightMapShape3D is centered around its origin, while our visual mesh
	# runs from local (0, 0) to (chunk_size, chunk_size).
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
