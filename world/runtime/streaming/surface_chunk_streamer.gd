extends Node3D

const TerrainGeneratorScript := preload("res://worldgen/surface/terrain_generator.gd")
const TerrainChunkScript := preload("res://world/terrain_chunk.gd")
const PickupGeneratorScript := preload("res://worldgen/surface/pickup_generator.gd")
const StableIdScript := preload("res://worldgen/identity/stable_id.gd")
const WorldDeltaStoreScript := preload("res://worldgen/persistence/world_delta_store.gd")
const PlayerPlacementProfileScript := preload("res://gameplay/player/player_placement_profile.gd")

const SPAWN_WATER_CLEARANCE: float = 1.5
const PLACEMENT_NEIGHBOR_CHUNK_RADIUS: int = 1
const LIVE_CAPSULE_QUERY_SHRINK: float = 0.01
const SURFACE_SOLID_COLLISION_MASK: int = 1

var settings
var main_generator
var worker_generator
var main_pickup_generator
var worker_pickup_generator
var player: Node3D

var chunks: Dictionary = {}
var pending_chunks: Array[Vector2i] = []
var desired_chunks: Dictionary = {}
var current_player_chunk: Vector2i = Vector2i(999999999, 999999999)

var last_generation_ms: float = 0.0
var max_generation_ms: float = 0.0
var last_data_generation_ms: float = 0.0
var max_data_generation_ms: float = 0.0
var last_chunk_build_ms: float = 0.0
var max_chunk_build_ms: float = 0.0
var total_chunks_generated: int = 0
var world_object_update_timer: float = 0.0

# WorldDeltaStore is the durable authority. This dictionary is only a derived
# surface-domain lookup cache used while realizing/reloading chunks.
var destroyed_object_ids: Dictionary = {}
var _world_delta_store = WorldDeltaStoreScript.new()

# Terrain + pickup transform data is generated on one background worker.
# Scene-tree, meshes, and physics remain main-thread only.
var worker_task_id: int = -1
var worker_coord: Vector2i = Vector2i.ZERO
var worker_mutex: Mutex = Mutex.new()
var worker_result_coord: Vector2i = Vector2i.ZERO
var worker_result_data: Dictionary = {}
var worker_result_ms: float = 0.0

var terrain_material: StandardMaterial3D = StandardMaterial3D.new()
var decoration_assets: Dictionary = {}


func bind_world_delta_store(store) -> bool:
	if (
		store == null
		or not store.has_method("replace_destroyed_object_ids")
		or not store.has_method("mark_generated_object_destroyed")
		or not store.has_method("is_generated_object_destroyed")
		or not store.has_method("snapshot")
	):
		return false
	_world_delta_store = store
	_refresh_destroyed_cache()
	return true


func configure(world_settings) -> void:
	settings = world_settings

	main_generator = TerrainGeneratorScript.new()
	main_generator.configure(settings)
	worker_generator = TerrainGeneratorScript.new()
	worker_generator.configure(settings)

	main_pickup_generator = PickupGeneratorScript.new()
	main_pickup_generator.configure(settings)
	worker_pickup_generator = PickupGeneratorScript.new()
	worker_pickup_generator.configure(settings)

	terrain_material.albedo_color = Color.WHITE
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 1.0

	_create_prototype_decoration_assets()


func _create_prototype_decoration_assets() -> void:
	var tree_mesh: CylinderMesh = CylinderMesh.new()
	tree_mesh.top_radius = 0.0
	tree_mesh.bottom_radius = 1.25
	tree_mesh.height = 4.5
	tree_mesh.radial_segments = 7

	var tree_material: StandardMaterial3D = StandardMaterial3D.new()
	tree_material.albedo_color = Color(0.10, 0.27, 0.08)
	tree_material.roughness = 1.0

	var rock_mesh: BoxMesh = BoxMesh.new()
	rock_mesh.size = Vector3.ONE
	var rock_material: StandardMaterial3D = StandardMaterial3D.new()
	rock_material.albedo_color = Color(0.31, 0.32, 0.29)
	rock_material.roughness = 1.0

	var branch_mesh: BoxMesh = BoxMesh.new()
	branch_mesh.size = Vector3.ONE
	var branch_material: StandardMaterial3D = StandardMaterial3D.new()
	branch_material.albedo_color = Color(0.30, 0.17, 0.07)
	branch_material.roughness = 1.0

	var loose_stone_mesh: BoxMesh = BoxMesh.new()
	loose_stone_mesh.size = Vector3.ONE
	var loose_stone_material: StandardMaterial3D = StandardMaterial3D.new()
	loose_stone_material.albedo_color = Color(0.48, 0.49, 0.46)
	loose_stone_material.roughness = 1.0

	decoration_assets = {
		"tree_mesh": tree_mesh,
		"tree_material": tree_material,
		"rock_mesh": rock_mesh,
		"rock_material": rock_material,
		"branch_mesh": branch_mesh,
		"branch_material": branch_material,
		"loose_stone_mesh": loose_stone_mesh,
		"loose_stone_material": loose_stone_material,
	}


func generate_initial(world_position: Vector3) -> void:
	var center: Vector2i = world_to_chunk(world_position)
	current_player_chunk = center
	_create_chunk_sync(center)
	_update_desired_chunks(center)


func set_player(player_node: Node3D) -> void:
	player = player_node
	current_player_chunk = world_to_chunk(player.global_position)
	_update_desired_chunks(current_player_chunk)
	_update_world_object_physics()


func _process(delta: float) -> void:
	if player != null:
		var player_chunk: Vector2i = world_to_chunk(player.global_position)
		if player_chunk != current_player_chunk:
			current_player_chunk = player_chunk
			_update_desired_chunks(current_player_chunk)

		world_object_update_timer -= delta
		if world_object_update_timer <= 0.0:
			world_object_update_timer = maxf(settings.world_object_update_interval, 0.05)
			_update_world_object_physics()

	_collect_completed_worker_task()
	_start_next_worker_task()


func _exit_tree() -> void:
	if worker_task_id != -1:
		WorkerThreadPool.wait_for_task_completion(worker_task_id)
		worker_task_id = -1


func load_destroyed_object_ids(object_ids: Array) -> void:
	if _world_delta_store == null:
		return
	var canonical_surface_ids: Array = []
	for object_id_variant in object_ids:
		var object_id: String = str(object_id_variant)
		if _is_valid_surface_object_id(object_id):
			canonical_surface_ids.append(object_id)
	_world_delta_store.replace_destroyed_object_ids(canonical_surface_ids)
	_refresh_destroyed_cache()


func get_destroyed_object_ids() -> Array:
	_refresh_destroyed_cache()
	var result: Array = destroyed_object_ids.keys()
	result.sort()
	return result


func get_destroyed_object_count() -> int:
	return get_destroyed_object_ids().size()


func is_world_object_destroyed(object_id: String) -> bool:
	if not _is_valid_surface_object_id(object_id) or _world_delta_store == null:
		return false
	return _world_delta_store.is_generated_object_destroyed(object_id)


func destroy_world_object(
	object_id: String,
	object_type: String,
	object_index: int,
	object_chunk: Vector2i
) -> bool:
	if (
		_world_delta_store == null
		or not _is_valid_surface_object_id(object_id, object_type)
		or _world_delta_store.is_generated_object_destroyed(object_id)
	):
		return false

	var loaded_chunk = chunks.get(object_chunk, null)
	if loaded_chunk != null:
		if not loaded_chunk.has_method("_make_object_id"):
			return false
		if str(loaded_chunk._make_object_id(object_type, object_index)) != object_id:
			return false

	# Durable state is committed before any local realization mutation. HARVEST
	# callers already compensate inventory if this authority rejects the request.
	if not _world_delta_store.mark_generated_object_destroyed(object_id):
		return false
	_refresh_destroyed_cache()

	if loaded_chunk != null:
		# The StableId/index match was established before the durable commit. If the
		# realization is unexpectedly stale now, the durable state still wins and
		# the next rebuild/reload will suppress the candidate.
		loaded_chunk.destroy_world_object(object_type, object_index)
	return true


func find_nearby_pickups(player_world_position: Vector3, radius: float) -> Array:
	var found: Array = []
	var chunk_coords: Array = chunks.keys()
	chunk_coords.sort_custom(func(a, b):
		var left: Vector2i = a
		var right: Vector2i = b
		return left.x < right.x or (left.x == right.x and left.y < right.y)
	)
	for chunk_coord_variant in chunk_coords:
		var chunk_coord: Vector2i = chunk_coord_variant
		var chunk = chunks[chunk_coord]
		var chunk_pickups: Array = chunk.find_nearby_pickups(player_world_position, radius)
		for pickup_variant in chunk_pickups:
			var pickup: Dictionary = pickup_variant.duplicate(true)
			var object_id: String = str(pickup.get("object_id", ""))
			var object_type: String = str(pickup.get("object_type", ""))
			if (
				not _is_valid_surface_object_id(object_id, object_type)
				or is_world_object_destroyed(object_id)
			):
				continue
			pickup["object_chunk"] = chunk_coord
			found.append(pickup)
	found.sort_custom(func(a, b): return str(a.get("object_id", "")) < str(b.get("object_id", "")))
	return found


func collect_nearby_pickups(player_world_position: Vector3, radius: float) -> Array:
	var collected: Array = []
	var candidates: Array = find_nearby_pickups(player_world_position, radius)
	for pickup_variant in candidates:
		if not pickup_variant is Dictionary:
			continue
		var pickup: Dictionary = pickup_variant
		var object_id: String = str(pickup.get("object_id", ""))
		var object_type: String = str(pickup.get("object_type", ""))
		var object_index: int = int(pickup.get("index", -1))
		var object_chunk: Vector2i = pickup.get("object_chunk", Vector2i.ZERO) as Vector2i
		if destroy_world_object(object_id, object_type, object_index, object_chunk):
			collected.append(pickup)
	return collected


func world_to_chunk(world_position: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_position.x / settings.chunk_size),
		floori(world_position.z / settings.chunk_size)
	)


func get_height_at_world(world_x: float, world_z: float) -> float:
	return main_generator.get_height(world_x, world_z)


func get_surface_sample_at_world(world_x: float, world_z: float) -> Dictionary:
	return main_generator.get_surface_sample(world_x, world_z)


func query_player_placement_xz(candidate: Vector3, player_profile = null) -> Dictionary:
	var profile = _resolve_player_profile(player_profile)
	if profile == null:
		return _placement_failure(["surface placement requires valid Player placement profile"])
	var decoration_cache: Dictionary = {}
	return _query_player_placement_xz(candidate, decoration_cache, profile)


func resolve_spawn_xz(preferred: Vector3, player_profile = null) -> Dictionary:
	if settings == null or main_generator == null:
		return _placement_failure(["surface placement requires configured generation authority"])
	if not _is_finite_number(preferred.x) or not _is_finite_number(preferred.z):
		return _placement_failure(["surface placement preferred XZ must be finite"])
	var profile = _resolve_player_profile(player_profile)
	if profile == null:
		return _placement_failure(["surface placement requires valid Player placement profile"])

	var search_step: float = maxf(settings.chunk_size * 0.25, 16.0)
	var search_radius: float = settings.chunk_size * 3.0
	var half_steps: int = ceili(search_radius / search_step)
	var decoration_cache: Dictionary = {}
	var best_result: Dictionary = {}
	var best_score: float = -1.0e20

	for z_index in range(-half_steps, half_steps + 1):
		for x_index in range(-half_steps, half_steps + 1):
			var candidate := Vector3(
				preferred.x + float(x_index) * search_step,
				0.0,
				preferred.z + float(z_index) * search_step
			)
			var placement: Dictionary = _query_player_placement_xz(candidate, decoration_cache, profile)
			if not bool(placement.get("success", false)):
				continue
			var sample: Dictionary = placement.get("sample", {})
			var buildability: float = float(sample.get("buildability", 0.0))
			var rockiness: float = float(sample.get("rockiness", 0.0))
			var moisture: float = float(sample.get("moisture", 0.0))
			var forest_density: float = float(sample.get("forest_density", 0.0))
			var distance: float = Vector2(
				candidate.x - preferred.x,
				candidate.z - preferred.z
			).length()
			var distance_penalty: float = distance / maxf(search_radius, 1.0)
			var score: float = (
				buildability * 6.0
				- forest_density * 1.35
				- rockiness * 0.35
				+ moisture * 0.15
				- distance_penalty * 1.15
			)
			if score > best_score:
				best_score = score
				best_result = placement

	if best_result.is_empty():
		return _placement_failure(["surface placement search found no viable Player target"])
	best_result["search_used"] = true
	best_result["preferred"] = Vector3(preferred.x, 0.0, preferred.z)
	return best_result


func find_spawn_xz(preferred: Vector3) -> Vector3:
	var resolved: Dictionary = resolve_spawn_xz(preferred)
	if bool(resolved.get("success", false)):
		return resolved.get("xz", preferred)
	# Legacy callers require a Vector3. Recovery and other safety-critical consumers
	# use resolve_spawn_xz/prepare_player_placement so failed placement is not committed.
	return preferred


func prepare_player_placement(target: Vector3, player_profile = null) -> Dictionary:
	if not is_inside_tree() or get_world_3d() == null:
		return _placement_failure(["surface placement readiness requires live physics world"])
	if not _is_finite_vector3(target):
		return _placement_failure(["surface placement readiness target must be finite"])
	var profile = _resolve_player_profile(player_profile)
	if profile == null:
		return _placement_failure(["surface placement readiness requires valid Player profile"])

	var semantic: Dictionary = query_player_placement_xz(
		Vector3(target.x, 0.0, target.z),
		profile
	)
	if not bool(semantic.get("success", false)):
		return _placement_prefixed_failure("semantic", semantic.get("diagnostics", []))
	var semantic_height: float = float(semantic.get("surface_height", NAN))
	if not _is_finite_number(semantic_height):
		return _placement_failure(["surface placement readiness requires finite semantic height"])
	var expected_body_y: float = float(profile.body_origin_y_for_support(semantic_height))
	var allowed_vertical_delta: float = float(profile.floor_snap_length())
	if absf(target.y - expected_body_y) > allowed_vertical_delta:
		return _placement_failure(["surface placement readiness target is outside Player settlement envelope"])

	var center_coord: Vector2i = world_to_chunk(target)
	var newly_created: Array[Vector2i] = []
	for z_offset in range(-PLACEMENT_NEIGHBOR_CHUNK_RADIUS, PLACEMENT_NEIGHBOR_CHUNK_RADIUS + 1):
		for x_offset in range(-PLACEMENT_NEIGHBOR_CHUNK_RADIUS, PLACEMENT_NEIGHBOR_CHUNK_RADIUS + 1):
			var coord: Vector2i = center_coord + Vector2i(x_offset, z_offset)
			var existed: bool = chunks.has(coord)
			_create_chunk_sync(coord)
			if not chunks.has(coord):
				_rollback_player_placement_preparation(newly_created)
				return _placement_failure(["surface placement readiness could not realize target chunk %s" % coord])
			if not existed:
				newly_created.append(coord)
			chunks[coord].set_collision_enabled(true)

	# Activate target-local solid proxies directly from the target rather than from
	# the defeated Player's old observer position. This keeps Player state untouched.
	_update_world_object_physics_at(target)

	var exclude_rids: Array[RID] = []
	if player != null and is_instance_valid(player) and player is CollisionObject3D:
		exclude_rids.append(player.get_rid())
	var space = get_world_3d().direct_space_state
	if space == null:
		_rollback_player_placement_preparation(newly_created)
		return _placement_failure(["surface placement readiness has no direct physics state"])

	var support_distance: float = float(profile.floor_snap_length())
	var ray := PhysicsRayQueryParameters3D.new()
	ray.from = Vector3(target.x, semantic_height + support_distance, target.z)
	ray.to = Vector3(target.x, semantic_height - support_distance, target.z)
	ray.collision_mask = SURFACE_SOLID_COLLISION_MASK
	ray.collide_with_bodies = true
	ray.collide_with_areas = false
	ray.exclude = exclude_rids
	var support: Dictionary = space.intersect_ray(ray)
	if support.is_empty():
		_rollback_player_placement_preparation(newly_created)
		return _placement_failure(["surface placement readiness found no realized support"])
	var support_collider = support.get("collider", null)
	if support_collider != null and support_collider.has_meta("world_object_type"):
		_rollback_player_placement_preparation(newly_created)
		return _placement_failure(["surface placement readiness support is a world object"])
	var support_position_variant: Variant = support.get("position", null)
	var support_normal_variant: Variant = support.get("normal", null)
	if not support_position_variant is Vector3 or not support_normal_variant is Vector3:
		_rollback_player_placement_preparation(newly_created)
		return _placement_failure(["surface placement readiness returned invalid support geometry"])
	var support_position: Vector3 = support_position_variant
	var support_normal: Vector3 = support_normal_variant
	if not _is_finite_vector3(support_position) or not _is_finite_vector3(support_normal):
		_rollback_player_placement_preparation(newly_created)
		return _placement_failure(["surface placement readiness support geometry must be finite"])
	if absf(support_position.y - semantic_height) > support_distance:
		_rollback_player_placement_preparation(newly_created)
		return _placement_failure(["surface placement readiness support exceeds Player snap tolerance"])
	if support_normal.is_zero_approx():
		_rollback_player_placement_preparation(newly_created)
		return _placement_failure(["surface placement readiness support normal is zero"])
	support_normal = support_normal.normalized()
	if support_normal.dot(Vector3.UP) < cos(float(profile.floor_max_angle())):
		_rollback_player_placement_preparation(newly_created)
		return _placement_failure(["surface placement readiness support exceeds Player floor angle"])

	var prepared_target := Vector3(
		target.x,
		float(profile.body_origin_y_for_support(support_position.y)),
		target.z
	)
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = profile.make_capsule_shape(LIVE_CAPSULE_QUERY_SHRINK)
	shape_query.transform = Transform3D(
		Basis.IDENTITY,
		prepared_target + Vector3(0.0, float(profile.capsule_center_y()), 0.0)
	)
	shape_query.collision_mask = int(profile.collision_mask())
	shape_query.collide_with_bodies = true
	shape_query.collide_with_areas = false
	shape_query.exclude = exclude_rids
	var overlaps: Array[Dictionary] = space.intersect_shape(shape_query, 32)
	if not overlaps.is_empty():
		_rollback_player_placement_preparation(newly_created)
		return _placement_failure(["surface placement readiness capsule overlaps realized physics"])

	return {
		"success": true,
		"ready": true,
		"target": prepared_target,
		"support_position": support_position,
		"support_normal": support_normal,
		"diagnostics": [],
	}


func _query_player_placement_xz(
	candidate: Vector3,
	decoration_cache: Dictionary,
	profile
) -> Dictionary:
	if settings == null or main_generator == null:
		return _placement_failure(["surface placement requires configured generation authority"])
	if not _is_finite_number(candidate.x) or not _is_finite_number(candidate.z):
		return _placement_failure(["surface placement candidate XZ must be finite"])

	var sample_variant: Variant = main_generator.get_surface_sample(candidate.x, candidate.z)
	if not sample_variant is Dictionary:
		return _placement_failure(["surface placement generator returned invalid sample"])
	var sample: Dictionary = sample_variant
	var height_variant: Variant = sample.get("height", null)
	var slope_variant: Variant = sample.get("slope", null)
	if not _is_finite_number(height_variant) or not _is_finite_number(slope_variant):
		return _placement_failure(["surface placement sample must contain finite height/slope"])
	var height: float = float(height_variant)
	var slope: float = float(slope_variant)
	if height <= float(settings.sea_level) + SPAWN_WATER_CLEARANCE:
		return _placement_failure(["surface placement target is not safely above water"])
	var max_slope: float = 1.0 - cos(float(profile.floor_max_angle()))
	if slope > max_slope:
		return _placement_failure(["surface placement target exceeds Player floor angle"])

	var blocker: Dictionary = _find_player_placement_blocker(
		candidate.x,
		candidate.z,
		height,
		decoration_cache,
		profile
	)
	if not blocker.is_empty():
		return _placement_failure([
			"surface placement blocked by %s %s" % [
				str(blocker.get("type", "world object")),
				str(blocker.get("stable_id", "")),
			]
		])
	return {
		"success": true,
		"xz": Vector3(candidate.x, 0.0, candidate.z),
		"surface_height": height,
		"sample": sample.duplicate(true),
		"search_used": false,
		"diagnostics": [],
	}


func _find_player_placement_blocker(
	world_x: float,
	world_z: float,
	surface_height: float,
	decoration_cache: Dictionary,
	profile
) -> Dictionary:
	var center_coord: Vector2i = world_to_chunk(Vector3(world_x, 0.0, world_z))
	for z_offset in range(-PLACEMENT_NEIGHBOR_CHUNK_RADIUS, PLACEMENT_NEIGHBOR_CHUNK_RADIUS + 1):
		for x_offset in range(-PLACEMENT_NEIGHBOR_CHUNK_RADIUS, PLACEMENT_NEIGHBOR_CHUNK_RADIUS + 1):
			var coord: Vector2i = center_coord + Vector2i(x_offset, z_offset)
			var data: Dictionary = _placement_chunk_data(coord, decoration_cache)
			var tree_blocker: Dictionary = _find_tree_placement_blocker(
				world_x, world_z, surface_height, coord, data, profile
			)
			if not tree_blocker.is_empty():
				return tree_blocker
			var rock_blocker: Dictionary = _find_rock_placement_blocker(
				world_x, world_z, surface_height, coord, data, profile
			)
			if not rock_blocker.is_empty():
				return rock_blocker
	return {}


func _placement_chunk_data(coord: Vector2i, decoration_cache: Dictionary) -> Dictionary:
	if decoration_cache.has(coord):
		return decoration_cache[coord]
	var generated_variant: Variant = main_generator.generate_chunk_data(coord)
	var generated: Dictionary = generated_variant if generated_variant is Dictionary else {}
	decoration_cache[coord] = generated
	return generated


func _find_tree_placement_blocker(
	world_x: float,
	world_z: float,
	surface_height: float,
	chunk_coord: Vector2i,
	data: Dictionary,
	profile
) -> Dictionary:
	var transforms: Array = data.get("tree_transforms", [])
	var stable_ids: Array = data.get("tree_stable_ids", [])
	var count: int = mini(transforms.size(), stable_ids.size())
	var chunk_origin := Vector3(
		float(chunk_coord.x) * float(settings.chunk_size),
		0.0,
		float(chunk_coord.y) * float(settings.chunk_size)
	)
	var body_min: float = float(profile.body_origin_y_for_support(surface_height))
	var body_max: float = body_min + float(profile.capsule_height())
	for index in range(count):
		if not transforms[index] is Transform3D:
			continue
		var stable_id: String = str(stable_ids[index])
		if _world_delta_store != null and _world_delta_store.is_generated_object_destroyed(stable_id):
			continue
		var local_transform: Transform3D = transforms[index]
		var world_origin: Vector3 = local_transform.origin + chunk_origin
		var uniform_scale: float = maxf(local_transform.basis.x.length(), 0.05)
		var collider_radius: float = float(settings.tree_collider_radius) * uniform_scale
		var collider_height: float = maxf(
			float(settings.tree_collider_height) * uniform_scale,
			collider_radius * 2.0
		)
		if not _vertical_intervals_overlap(
			body_min,
			body_max,
			world_origin.y - collider_height * 0.5,
			world_origin.y + collider_height * 0.5
		):
			continue
		var radius_sum: float = float(profile.capsule_radius()) + collider_radius
		var delta := Vector2(world_x - world_origin.x, world_z - world_origin.z)
		if delta.length_squared() <= radius_sum * radius_sum:
			return {"type": "tree", "stable_id": stable_id}
	return {}


func _find_rock_placement_blocker(
	world_x: float,
	world_z: float,
	surface_height: float,
	chunk_coord: Vector2i,
	data: Dictionary,
	profile
) -> Dictionary:
	var transforms: Array = data.get("rock_transforms", [])
	var stable_ids: Array = data.get("rock_stable_ids", [])
	var count: int = mini(transforms.size(), stable_ids.size())
	var chunk_origin := Vector3(
		float(chunk_coord.x) * float(settings.chunk_size),
		0.0,
		float(chunk_coord.y) * float(settings.chunk_size)
	)
	var body_min: float = float(profile.body_origin_y_for_support(surface_height))
	var body_max: float = body_min + float(profile.capsule_height())
	for index in range(count):
		if not transforms[index] is Transform3D:
			continue
		var stable_id: String = str(stable_ids[index])
		if _world_delta_store != null and _world_delta_store.is_generated_object_destroyed(stable_id):
			continue
		var local_transform: Transform3D = transforms[index]
		var world_origin: Vector3 = local_transform.origin + chunk_origin
		var box_size := Vector3(
			maxf(local_transform.basis.x.length(), 0.05),
			maxf(local_transform.basis.y.length(), 0.05),
			maxf(local_transform.basis.z.length(), 0.05)
		)
		if not _vertical_intervals_overlap(
			body_min,
			body_max,
			world_origin.y - box_size.y * 0.5,
			world_origin.y + box_size.y * 0.5
		):
			continue
		var orientation: Basis = local_transform.basis.orthonormalized()
		var local_delta: Vector3 = orientation.inverse() * Vector3(
			world_x - world_origin.x,
			0.0,
			world_z - world_origin.z
		)
		var half_x: float = box_size.x * 0.5
		var half_z: float = box_size.z * 0.5
		var closest_x: float = clampf(local_delta.x, -half_x, half_x)
		var closest_z: float = clampf(local_delta.z, -half_z, half_z)
		var dx: float = local_delta.x - closest_x
		var dz: float = local_delta.z - closest_z
		var capsule_radius: float = float(profile.capsule_radius())
		if dx * dx + dz * dz <= capsule_radius * capsule_radius:
			return {"type": "rock", "stable_id": stable_id}
	return {}


func _resolve_player_profile(profile_variant):
	var profile = profile_variant
	if profile == null:
		profile = PlayerPlacementProfileScript.new()
	if (
		not profile.has_method("validate")
		or not profile.has_method("capsule_radius")
		or not profile.has_method("capsule_height")
		or not profile.has_method("capsule_center_y")
		or not profile.has_method("floor_max_angle")
		or not profile.has_method("floor_snap_length")
		or not profile.has_method("collision_mask")
		or not profile.has_method("settlement_margin")
		or not profile.has_method("body_origin_y_for_support")
		or not profile.has_method("make_capsule_shape")
	):
		return null
	var failures_variant: Variant = profile.validate()
	if not failures_variant is Array or not failures_variant.is_empty():
		return null
	return profile


func _rollback_player_placement_preparation(newly_created: Array[Vector2i]) -> void:
	if player != null and is_instance_valid(player):
		_update_world_object_physics_at(player.global_position)
		_update_collision_radius(world_to_chunk(player.global_position))
	else:
		_update_collision_radius(current_player_chunk)
	for coord in newly_created:
		if chunks.has(coord) and not desired_chunks.has(coord):
			chunks[coord].queue_free()
			chunks.erase(coord)


func _vertical_intervals_overlap(a_min: float, a_max: float, b_min: float, b_max: float) -> bool:
	return a_max >= b_min and b_max >= a_min


func _placement_prefixed_failure(prefix: String, messages: Array) -> Dictionary:
	var prefixed: Array[String] = []
	for message in messages:
		prefixed.append("%s: %s" % [prefix, str(message)])
	return _placement_failure(prefixed)


func _placement_failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {"success": false, "ready": false, "diagnostics": diagnostics}


func _is_finite_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number: float = float(value)
	return not is_nan(number) and not is_inf(number)


func _is_finite_vector3(value: Vector3) -> bool:
	return (
		_is_finite_number(value.x)
		and _is_finite_number(value.y)
		and _is_finite_number(value.z)
	)


func get_loaded_chunk_count() -> int:
	return chunks.size()


func get_pending_chunk_count() -> int:
	return pending_chunks.size() + (1 if worker_task_id != -1 else 0)


func get_current_player_chunk() -> Vector2i:
	return current_player_chunk


func get_current_decoration_counts() -> Vector2i:
	if not chunks.has(current_player_chunk):
		return Vector2i.ZERO
	var chunk = chunks[current_player_chunk]
	return Vector2i(chunk.tree_instance_count, chunk.rock_instance_count)


func get_current_pickup_counts() -> Vector2i:
	if not chunks.has(current_player_chunk):
		return Vector2i.ZERO
	return chunks[current_player_chunk].get_pickup_counts()


func get_active_world_object_count() -> int:
	var total: int = 0
	for chunk in chunks.values():
		total += chunk.get_active_world_object_count()
	return total


func get_last_generation_ms() -> float:
	return last_generation_ms


func get_max_generation_ms() -> float:
	return max_generation_ms


func get_last_data_generation_ms() -> float:
	return last_data_generation_ms


func get_max_data_generation_ms() -> float:
	return max_data_generation_ms


func get_last_chunk_build_ms() -> float:
	return last_chunk_build_ms


func get_max_chunk_build_ms() -> float:
	return max_chunk_build_ms


func get_total_chunks_generated() -> int:
	return total_chunks_generated


func is_worker_busy() -> bool:
	return worker_task_id != -1


func _update_desired_chunks(center: Vector2i) -> void:
	desired_chunks.clear()

	for z_offset in range(-settings.load_radius, settings.load_radius + 1):
		for x_offset in range(-settings.load_radius, settings.load_radius + 1):
			var coord: Vector2i = center + Vector2i(x_offset, z_offset)
			desired_chunks[coord] = true

	var retention_radius: int = maxi(settings.load_radius, settings.unload_radius)
	for key in chunks.keys():
		var coord: Vector2i = key
		if not _is_within_square_radius(coord, center, retention_radius):
			chunks[coord].queue_free()
			chunks.erase(coord)

	_rebuild_generation_queue(center)
	_update_collision_radius(center)


func _rebuild_generation_queue(center: Vector2i) -> void:
	pending_chunks.clear()

	for key in desired_chunks.keys():
		var coord: Vector2i = key
		if chunks.has(coord):
			continue
		if worker_task_id != -1 and coord == worker_coord:
			continue
		pending_chunks.append(coord)

	current_player_chunk = center
	pending_chunks.sort_custom(_compare_pending_chunks)


func _compare_pending_chunks(a: Vector2i, b: Vector2i) -> bool:
	return _chunk_distance_squared(a, current_player_chunk) < _chunk_distance_squared(b, current_player_chunk)


func _chunk_distance_squared(a: Vector2i, b: Vector2i) -> int:
	var delta: Vector2i = a - b
	return delta.x * delta.x + delta.y * delta.y


func _start_next_worker_task() -> void:
	if worker_task_id != -1:
		return

	while not pending_chunks.is_empty():
		var coord: Vector2i = pending_chunks.pop_front()
		if not desired_chunks.has(coord) or chunks.has(coord):
			continue
		if worker_task_id != -1 and coord == worker_coord:
			continue

		worker_coord = coord
		var task_callable: Callable = Callable(self, "_worker_generate_chunk").bind(coord)
		worker_task_id = WorkerThreadPool.add_task(
			task_callable,
			false,
			"Underworld terrain %d,%d" % [coord.x, coord.y]
		)

		if worker_task_id < 0:
			worker_task_id = -1
			_create_chunk_sync(coord)
			continue
		return


func _worker_generate_chunk(coord: Vector2i) -> void:
	var started_usec: int = Time.get_ticks_usec()
	var data: Dictionary = worker_generator.generate_chunk_data(coord)
	worker_pickup_generator.add_pickups_to_chunk_data(coord, data)
	var elapsed_ms: float = float(Time.get_ticks_usec() - started_usec) / 1000.0

	worker_mutex.lock()
	worker_result_coord = coord
	worker_result_data = data
	worker_result_ms = elapsed_ms
	worker_mutex.unlock()


func _collect_completed_worker_task() -> void:
	if worker_task_id == -1:
		return
	if not WorkerThreadPool.is_task_completed(worker_task_id):
		return

	var finished_task_id: int = worker_task_id
	WorkerThreadPool.wait_for_task_completion(finished_task_id)
	worker_task_id = -1

	worker_mutex.lock()
	var coord: Vector2i = worker_result_coord
	var data: Dictionary = worker_result_data
	var data_ms: float = worker_result_ms
	worker_result_data = {}
	worker_result_ms = 0.0
	worker_mutex.unlock()

	last_data_generation_ms = data_ms
	max_data_generation_ms = maxf(max_data_generation_ms, data_ms)

	if desired_chunks.has(coord) and not chunks.has(coord):
		_build_chunk_from_data(coord, data, data_ms)


func _create_chunk_sync(coord: Vector2i) -> void:
	if chunks.has(coord):
		return

	var data_started_usec: int = Time.get_ticks_usec()
	var data: Dictionary = main_generator.generate_chunk_data(coord)
	main_pickup_generator.add_pickups_to_chunk_data(coord, data)
	var data_ms: float = float(Time.get_ticks_usec() - data_started_usec) / 1000.0
	last_data_generation_ms = data_ms
	max_data_generation_ms = maxf(max_data_generation_ms, data_ms)
	_build_chunk_from_data(coord, data, data_ms)


func _build_chunk_from_data(coord: Vector2i, data: Dictionary, data_ms: float) -> void:
	if chunks.has(coord):
		return

	var build_started_usec: int = Time.get_ticks_usec()
	var chunk = TerrainChunkScript.new()
	chunk.position = Vector3(
		float(coord.x) * settings.chunk_size,
		0.0,
		float(coord.y) * settings.chunk_size
	)

	var needs_collision: bool = _is_within_collision_radius(coord, current_player_chunk)
	chunk.call("build",
		coord,
		data,
		terrain_material,
		decoration_assets,
		settings,
		_destroyed_object_lookup(),
		needs_collision
	)
	add_child(chunk)
	chunks[coord] = chunk

	last_chunk_build_ms = float(Time.get_ticks_usec() - build_started_usec) / 1000.0
	max_chunk_build_ms = maxf(max_chunk_build_ms, last_chunk_build_ms)
	last_generation_ms = data_ms + last_chunk_build_ms
	max_generation_ms = maxf(max_generation_ms, last_generation_ms)
	total_chunks_generated += 1


func _update_world_object_physics() -> void:
	if player == null:
		return
	_update_world_object_physics_at(player.global_position)


func _update_world_object_physics_at(observer_position: Vector3) -> void:
	var activation_radius: float = settings.world_object_physics_radius
	var release_radius: float = activation_radius + settings.world_object_release_margin
	for chunk in chunks.values():
		chunk.update_world_object_physics(
			observer_position,
			activation_radius,
			release_radius
		)


func _update_collision_radius(center: Vector2i) -> void:
	for key in chunks.keys():
		var coord: Vector2i = key
		chunks[coord].set_collision_enabled(
			_is_within_collision_radius(coord, center)
		)


func _is_within_collision_radius(coord: Vector2i, center: Vector2i, radius: int = -1) -> bool:
	var resolved_radius: int = settings.collision_radius if radius < 0 else radius
	return _is_within_square_radius(coord, center, resolved_radius)


func _is_within_square_radius(coord: Vector2i, center: Vector2i, radius: int) -> bool:
	var delta: Vector2i = coord - center
	return abs(delta.x) <= radius and abs(delta.y) <= radius


func _refresh_destroyed_cache() -> void:
	destroyed_object_ids.clear()
	if _world_delta_store == null:
		return
	var snapshot_variant = _world_delta_store.snapshot()
	if not snapshot_variant is Dictionary:
		return
	var snapshot: Dictionary = snapshot_variant
	var destroyed: Array = snapshot.get("destroyed_objects", [])
	for id_variant in destroyed:
		var object_id: String = str(id_variant)
		if _is_valid_surface_object_id(object_id):
			destroyed_object_ids[object_id] = true


func _destroyed_object_lookup() -> Dictionary:
	_refresh_destroyed_cache()
	return destroyed_object_ids.duplicate()


func _is_valid_surface_object_id(object_id: String, object_type: String = "") -> bool:
	var stable_id = StableIdScript.parse(object_id)
	if stable_id == null:
		return false
	var segments: Array[String] = stable_id.address().segments()
	if segments.size() != 8:
		return false
	if segments[0] != "surface" or segments[1] != "candidate":
		return false
	if segments[3] != "cell" or segments[6] != "slot":
		return false
	if not _is_canonical_signed_int(segments[4]) or not _is_canonical_signed_int(segments[5]):
		return false

	var domain: String = segments[2]
	var expected_domain: String = _surface_domain_for_object_type(object_type)
	if not object_type.is_empty():
		return not expected_domain.is_empty() and domain == expected_domain
	return domain in ["tree", "rock", "branch", "loose-stone"]


func _surface_domain_for_object_type(object_type: String) -> String:
	match object_type:
		"tree", "rock", "branch":
			return object_type
		"loose_stone":
			return "loose-stone"
		_:
			return ""


func _is_canonical_signed_int(value: String) -> bool:
	return value.is_valid_int() and str(int(value)) == value
