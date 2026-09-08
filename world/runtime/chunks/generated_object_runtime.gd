extends RefCounted

const StableIdScript := preload("res://worldgen/identity/stable_id.gd")

var tree_instance_count: int = 0
var rock_instance_count: int = 0
var branch_instance_count: int = 0
var loose_stone_instance_count: int = 0

var _host_ref: WeakRef
var _chunk_coord: Vector2i = Vector2i.ZERO
var _settings
var _decoration_assets: Dictionary = {}

var _tree_transforms: Array = []
var _tree_stable_ids: Array = []
var _rock_transforms: Array = []
var _rock_stable_ids: Array = []
var _branch_transforms: Array = []
var _branch_stable_ids: Array = []
var _loose_stone_transforms: Array = []
var _loose_stone_stable_ids: Array = []

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
	host: Node3D,
	coord: Vector2i,
	data: Dictionary,
	decoration_assets: Dictionary,
	world_settings,
	destroyed_objects: Dictionary
) -> void:
	_host_ref = weakref(host)
	_chunk_coord = coord
	_settings = world_settings
	_decoration_assets = decoration_assets

	_world_object_root = Node3D.new()
	_world_object_root.name = "NearWorldObjects"
	host.add_child(_world_object_root)

	_tree_transforms = data.get("tree_transforms", [])
	_tree_stable_ids = data.get("tree_stable_ids", [])
	_rock_transforms = data.get("rock_transforms", [])
	_rock_stable_ids = data.get("rock_stable_ids", [])
	_branch_transforms = data.get("branch_transforms", [])
	_branch_stable_ids = data.get("branch_stable_ids", [])
	_loose_stone_transforms = data.get("loose_stone_transforms", [])
	_loose_stone_stable_ids = data.get("loose_stone_stable_ids", [])

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


func update_world_object_physics(
	player_local_position: Vector3,
	activation_radius: float,
	release_radius: float
) -> void:
	if _world_object_root == null or _settings == null:
		return

	var activation_sq: float = activation_radius * activation_radius
	var release_sq: float = release_radius * release_radius
	_update_proxy_set(
		_tree_transforms,
		_destroyed_tree_indices,
		_active_tree_bodies,
		"tree",
		player_local_position,
		activation_sq,
		release_sq
	)
	_update_proxy_set(
		_rock_transforms,
		_destroyed_rock_indices,
		_active_rock_bodies,
		"rock",
		player_local_position,
		activation_sq,
		release_sq
	)


func find_nearby_pickups(player_local_position: Vector3, radius: float) -> Array:
	var found: Array = []
	var radius_sq: float = radius * radius
	_find_pickup_set(
		_branch_transforms,
		_destroyed_branch_indices,
		"branch",
		player_local_position,
		radius_sq,
		found
	)
	_find_pickup_set(
		_loose_stone_transforms,
		_destroyed_loose_stone_indices,
		"loose_stone",
		player_local_position,
		radius_sq,
		found
	)
	found.sort_custom(func(a, b): return str(a.get("object_id", "")) < str(b.get("object_id", "")))
	return found


func collect_nearby_pickups(player_local_position: Vector3, radius: float) -> Array:
	var collected: Array = []
	var radius_sq: float = radius * radius
	var branches_changed: bool = _collect_pickup_set(
		_branch_transforms,
		_destroyed_branch_indices,
		"branch",
		player_local_position,
		radius_sq,
		collected
	)
	var stones_changed: bool = _collect_pickup_set(
		_loose_stone_transforms,
		_destroyed_loose_stone_indices,
		"loose_stone",
		player_local_position,
		radius_sq,
		collected
	)

	if branches_changed:
		_rebuild_visual_set("branch")
	if stones_changed:
		_rebuild_visual_set("loose_stone")
	return collected


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


func make_object_id(object_type: String, index: int) -> String:
	var stable_ids: Array = []
	match object_type:
		"tree":
			stable_ids = _tree_stable_ids
		"rock":
			stable_ids = _rock_stable_ids
		"branch":
			stable_ids = _branch_stable_ids
		"loose_stone":
			stable_ids = _loose_stone_stable_ids
		_:
			return ""

	if index < 0 or index >= stable_ids.size():
		return ""
	var stable_id: String = str(stable_ids[index])
	if StableIdScript.parse(stable_id) == null:
		return ""
	return stable_id


func _load_destroyed_indices(
	object_type: String,
	transforms: Array,
	destroyed: Dictionary,
	world_destroyed: Dictionary
) -> void:
	for index in range(transforms.size()):
		var object_id: String = make_object_id(object_type, index)
		if not object_id.is_empty() and world_destroyed.has(object_id):
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
				_tree_multimesh_instance,
				node_name,
				_decoration_assets[mesh_key],
				_decoration_assets[material_key],
				visible_transforms
			)
			_tree_multimesh_instance = replacement
			tree_instance_count = visible_transforms.size()
		"rock":
			replacement = _replace_multimesh_instance(
				_rock_multimesh_instance,
				node_name,
				_decoration_assets[mesh_key],
				_decoration_assets[material_key],
				visible_transforms
			)
			_rock_multimesh_instance = replacement
			rock_instance_count = visible_transforms.size()
		"branch":
			replacement = _replace_multimesh_instance(
				_branch_multimesh_instance,
				node_name,
				_decoration_assets[mesh_key],
				_decoration_assets[material_key],
				visible_transforms
			)
			_branch_multimesh_instance = replacement
			branch_instance_count = visible_transforms.size()
		"loose_stone":
			replacement = _replace_multimesh_instance(
				_loose_stone_multimesh_instance,
				node_name,
				_decoration_assets[mesh_key],
				_decoration_assets[material_key],
				visible_transforms
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

	var host = _host_ref.get_ref() if _host_ref != null else null
	if host == null:
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
	host.add_child(multi_mesh_instance)
	return multi_mesh_instance


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
		var object_id: String = make_object_id(object_type, index)
		if object_id.is_empty():
			continue
		found.append({
			"object_id": object_id,
			"object_type": object_type,
			"index": index,
		})


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
		var object_id: String = make_object_id(object_type, index)
		if object_id.is_empty():
			continue
		destroyed[index] = true
		changed = true
		collected.append({
			"object_id": object_id,
			"object_type": object_type,
			"index": index,
		})
	return changed


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

		var object_id: String = make_object_id(object_type, index)
		if object_id.is_empty():
			continue
		var body: StaticBody3D = _create_world_object_body(
			object_type,
			index,
			instance_transform,
			object_id
		)
		_world_object_root.add_child(body)
		active_bodies[index] = body


func _create_world_object_body(
	object_type: String,
	index: int,
	instance_transform: Transform3D,
	object_id: String
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "%s_%d" % [object_type.capitalize(), index]
	body.collision_layer = 1
	body.collision_mask = 1
	body.set_meta("world_object_type", object_type)
	body.set_meta("world_object_index", index)
	body.set_meta("world_object_chunk", _chunk_coord)
	body.set_meta("world_object_id", object_id)

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
