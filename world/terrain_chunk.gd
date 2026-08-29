extends MeshInstance3D

var chunk_coord: Vector2i = Vector2i.ZERO
var _collision_body: StaticBody3D
var _collision_heights: PackedFloat32Array = PackedFloat32Array()
var _collision_resolution: int = 0
var _collision_spacing: float = 1.0
var _settings
var _decoration_assets: Dictionary = {}

var moisture: PackedFloat32Array = PackedFloat32Array()
var forest_density: PackedFloat32Array = PackedFloat32Array()
var rockiness: PackedFloat32Array = PackedFloat32Array()
var buildability: PackedFloat32Array = PackedFloat32Array()

var tree_instance_count: int = 0
var rock_instance_count: int = 0
var branch_instance_count: int = 0
var loose_stone_instance_count: int = 0

var _tree_transforms: Array = []
var _rock_transforms: Array = []
var _branch_transforms: Array = []
var _loose_stone_transforms: Array = []

var _destroyed_tree_indices: Dictionary = {}
var _destroyed_rock_indices: Dictionary = {}
var _destroyed_branch_indices: Dictionary = {}
var _destroyed_loose_stone_indices: Dictionary = {}

var _tree_multimesh_instance: MultiMeshInstance3D
var _rock_multimesh_instance: MultiMeshInstance3D
var _branch_multimesh_instance: MultiMeshInstance3D
var _loose_stone_multimesh_instance: MultiMeshInstance3D

var _world_object_root: Node3D
var _active_tree_bodies: Dictionary = {}
var _active_rock_bodies: Dictionary = {}


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
	_settings = world_settings
	_decoration_assets = decoration_assets

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

	_build_decorations(data, destroyed_objects)
	set_collision_enabled(with_collision)


func _build_decorations(data: Dictionary, destroyed_objects: Dictionary) -> void:
	_tree_transforms = data.get("tree_transforms", [])
	_rock_transforms = data.get("rock_transforms", [])
	_branch_transforms = data.get("branch_transforms", [])
	_loose_stone_transforms = data.get("loose_stone_transforms", [])

	_destroyed_tree_indices.clear()
	_destroyed_rock_indices.clear()
	_destroyed_branch_indices.clear()
	_destroyed_loose_stone_indices.clear()

	_load_destroyed_indices("tree", _tree_transforms, _destroyed_tree_indices, destroyed_objects)
	_load_destroyed_indices("rock", _rock_transforms, _destroyed_rock_indices, destroyed_objects)
	_load_destroyed_indices("branch", _branch_transforms, _destroyed_branch_indices, destroyed_objects)
	_load_destroyed_indices(
		"loose_stone",
		_loose_stone_transforms,
		_destroyed_loose_stone_indices,
		destroyed_objects
	)

	_rebuild_visual_set("tree")
	_rebuild_visual_set("rock")
	_rebuild_visual_set("branch")
	_rebuild_visual_set("loose_stone")


func _load_destroyed_indices(
	object_type: String,
	transforms: Array,
	destroyed: Dictionary,
	world_destroyed: Dictionary
) -> void:
	for index in range(transforms.size()):
		if world_destroyed.has(_make_object_id(object_type, index)):
			destroyed[index] = true


func _rebuild_visual_set(object_type: String) -> void:
	var transforms: Array = []
	var destroyed: Dictionary = {}
	var node_name: String = ""
	var mesh_key: String = ""
	var material_key: String = ""

	match object_type:
		"tree":
			transforms = _tree_transforms
			destroyed = _destroyed_tree_indices
			node_name = "Trees"
			mesh_key = "tree_mesh"
			material_key = "tree_material"
		"rock":
			transforms = _rock_transforms
			destroyed = _destroyed_rock_indices
			node_name = "Rocks"
			mesh_key = "rock_mesh"
			material_key = "rock_material"
		"branch":
			transforms = _branch_transforms
			destroyed = _destroyed_branch_indices
			node_name = "LooseBranches"
			mesh_key = "branch_mesh"
			material_key = "branch_material"
		"loose_stone":
			transforms = _loose_stone_transforms
			destroyed = _destroyed_loose_stone_indices
			node_name = "LooseStones"
			mesh_key = "loose_stone_mesh"
			material_key = "loose_stone_material"
		_:
			return

	var visible_transforms: Array = []
	for index in range(transforms.size()):
		if not destroyed.has(index):
			visible_transforms.append(transforms[index])

	var replacement: MultiMeshInstance3D
	match object_type:
		"tree":
			replacement = _replace_multimesh_instance(
				_tree_multimesh_instance, node_name, _decoration_assets[mesh_key],
				_decoration_assets[material_key], visible_transforms
			)
			_tree_multimesh_instance = replacement
			tree_instance_count = visible_transforms.size()
		"rock":
			replacement = _replace_multimesh_instance(
				_rock_multimesh_instance, node_name, _decoration_assets[mesh_key],
				_decoration_assets[material_key], visible_transforms
			)
			_rock_multimesh_instance = replacement
			rock_instance_count = visible_transforms.size()
		"branch":
			replacement = _replace_multimesh_instance(
				_branch_multimesh_instance, node_name, _decoration_assets[mesh_key],
				_decoration_assets[material_key], visible_transforms
			)
			_branch_multimesh_instance = replacement
			branch_instance_count = visible_transforms.size()
		"loose_stone":
			replacement = _replace_multimesh_instance(
				_loose_stone_multimesh_instance, node_name, _decoration_assets[mesh_key],
				_decoration_assets[material_key], visible_transforms
			)
			_loose_stone_multimesh_instance = replacement
			loose_stone_instance_count = visible_transforms.size()


func _replace_multimesh_instance(
	existing: MultiMeshInstance3D,
	node_name: String,
	instance_mesh: Mesh,
	instance_material: Material,
	transforms: Array
) -> MultiMeshInstance3D:
	if existing != null:
		existing.queue_free()

	if transforms.is_empty():
		return null

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
	return multi_mesh_instance


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
		_destroyed_tree_indices,
		_active_tree_bodies,
		"tree",
		player_local,
		activation_sq,
		release_sq
	)
	_update_proxy_set(
		_rock_transforms,
		_destroyed_rock_indices,
		_active_rock_bodies,
		"rock",
		player_local,
		activation_sq,
		release_sq
	)


func find_nearby_pickups(player_world_position: Vector3, radius: float) -> Array:
	var found: Array = []
	var player_local: Vector3 = to_local(player_world_position)
	var radius_sq: float = radius * radius
	_find_pickup_set(
		_branch_transforms,
		_destroyed_branch_indices,
		"branch",
		player_local,
		radius_sq,
		found
	)
	_find_pickup_set(
		_loose_stone_transforms,
		_destroyed_loose_stone_indices,
		"loose_stone",
		player_local,
		radius_sq,
		found
	)
	found.sort_custom(func(a, b): return str(a.get("object_id", "")) < str(b.get("object_id", "")))
	return found


func _find_pickup_set(
	transforms: Array,
	destroyed: Dictionary,
	object_type: String,
	player_local: Vector3,
	radius_sq: float,
	found: Array
) -> void:
	for index in range(transforms.size()):
		if destroyed.has(index):
			continue
		var instance_transform: Transform3D = transforms[index]
		var delta: Vector3 = instance_transform.origin - player_local
		if delta.length_squared() > radius_sq:
			continue
		found.append({
			"object_id": _make_object_id(object_type, index),
			"object_type": object_type,
			"index": index,
		})


func collect_nearby_pickups(player_world_position: Vector3, radius: float) -> Array:
	var collected: Array = []
	var player_local: Vector3 = to_local(player_world_position)
	var radius_sq: float = radius * radius

	var branches_changed: bool = _collect_pickup_set(
		_branch_transforms,
		_destroyed_branch_indices,
		"branch",
		player_local,
		radius_sq,
		collected
	)
	var stones_changed: bool = _collect_pickup_set(
		_loose_stone_transforms,
		_destroyed_loose_stone_indices,
		"loose_stone",
		player_local,
		radius_sq,
		collected
	)

	if branches_changed:
		_rebuild_visual_set("branch")
	if stones_changed:
		_rebuild_visual_set("loose_stone")
	return collected


func _collect_pickup_set(
	transforms: Array,
	destroyed: Dictionary,
	object_type: String,
	player_local: Vector3,
	radius_sq: float,
	collected: Array
) -> bool:
	var changed: bool = false
	for index in range(transforms.size()):
		if destroyed.has(index):
			continue
		var instance_transform: Transform3D = transforms[index]
		var delta: Vector3 = instance_transform.origin - player_local
		if delta.length_squared() > radius_sq:
			continue
		destroyed[index] = true
		changed = true
		collected.append({
			"object_id": _make_object_id(object_type, index),
			"object_type": object_type,
			"index": index,
		})
	return changed


func get_active_world_object_count() -> int:
	return _active_tree_bodies.size() + _active_rock_bodies.size()


func get_pickup_counts() -> Vector2i:
	return Vector2i(branch_instance_count, loose_stone_instance_count)


func destroy_world_object(object_type: String, index: int) -> bool:
	var transforms: Array = []
	var destroyed: Dictionary = {}
	var active_bodies: Dictionary = {}

	match object_type:
		"tree":
			transforms = _tree_transforms
			destroyed = _destroyed_tree_indices
			active_bodies = _active_tree_bodies
		"rock":
			transforms = _rock_transforms
			destroyed = _destroyed_rock_indices
			active_bodies = _active_rock_bodies
		"branch":
			transforms = _branch_transforms
			destroyed = _destroyed_branch_indices
		"loose_stone":
			transforms = _loose_stone_transforms
			destroyed = _destroyed_loose_stone_indices
		_:
			return false

	if index < 0 or index >= transforms.size() or destroyed.has(index):
		return false

	destroyed[index] = true
	if active_bodies.has(index):
		var body: Node = active_bodies[index]
		active_bodies.erase(index)
		body.queue_free()

	_rebuild_visual_set(object_type)
	return true


func _update_proxy_set(
	transforms: Array,
	destroyed: Dictionary,
	active_bodies: Dictionary,
	object_type: String,
	player_local: Vector3,
	activation_sq: float,
	release_sq: float
) -> void:
	for key in active_bodies.keys():
		var index: int = int(key)
		if destroyed.has(index) or index < 0 or index >= transforms.size():
			active_bodies[index].queue_free()
			active_bodies.erase(index)
			continue

		var existing_transform: Transform3D = transforms[index]
		if _horizontal_distance_squared(existing_transform.origin, player_local) > release_sq:
			active_bodies[index].queue_free()
			active_bodies.erase(index)

	for index in range(transforms.size()):
		if destroyed.has(index) or active_bodies.has(index):
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
	body.set_meta("world_object_id", _make_object_id(object_type, index))

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


func _make_object_id(object_type: String, index: int) -> String:
	return "%d:%d:%s:%d" % [chunk_coord.x, chunk_coord.y, object_type, index]


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