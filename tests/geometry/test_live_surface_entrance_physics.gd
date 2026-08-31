extends RefCounted

const MAX_CHUNK_WAIT_FRAMES := 360
const MAX_GROUND_SETTLE_FRAMES := 240
const MAX_APPROACH_FRAMES := 900
const MAX_EXIT_FRAMES := 1200
const BELOW_SURFACE_THRESHOLD := 1.0
const EXIT_HORIZONTAL_TOLERANCE := 6.0


static func run_new(
	tree: SceneTree,
	game: Node,
	route: Dictionary,
	failures: Array[String]
) -> Dictionary:
	var world = game.get("world")
	var player = game.get("player")
	var settings = game.get("world_settings")
	if world == null or player == null or settings == null:
		failures.append("live/physics production entrance requires SurfaceWorld, Player and WorldSettings")
		return {}
	var surface_variant: Variant = route.get("surface_world_position", null)
	var opening_variant: Variant = route.get("required_opening_bounds", null)
	if not surface_variant is Vector3 or not opening_variant is AABB:
		failures.append("live/physics selected entrance lacks surface/opening truth")
		return {}
	var surface: Vector3 = surface_variant
	var opening: AABB = opening_variant
	var clearance: float = float(route.get("clearance_radius", 0.0))
	var coord: Vector2i = world.call("world_to_chunk", surface)
	var ready: bool = await _wait_for_composed_chunk(tree, world, coord)
	if not ready:
		failures.append("live/physics selected mouth chunk never realized with entrance composition")
		return {}
	var snapshot: Dictionary = world.call("get_entrance_surface_composition_snapshot", coord)
	var plan_fingerprint: String = str(snapshot.get("plan_fingerprint", ""))
	if plan_fingerprint.is_empty():
		failures.append("live/physics selected mouth chunk has no production surface-plan fingerprint")
	if str(snapshot.get("entrance_id", "")) != str(route.get("entrance_id", "")):
		failures.append("live/physics surface composition changed selected entrance identity")
	if int(snapshot.get("omitted_index_count", 0)) <= 0:
		failures.append("live/physics production mouth omitted no render indices")
	if int(snapshot.get("collision_hole_count", 0)) <= 0:
		failures.append("live/physics production mouth created no collision holes")
	var diagnostics_variant: Variant = world.call("entrance_surface_composition_diagnostics")
	if diagnostics_variant is Array and not diagnostics_variant.is_empty():
		failures.append("live/physics surface composition reported diagnostics: %s" % [diagnostics_variant])

	var chunk = world.get("chunks").get(coord, null)
	if chunk == null or not is_instance_valid(chunk):
		failures.append("live/physics selected mouth chunk is not realized")
		return {}
	_verify_realized_mesh(chunk, snapshot, failures)
	await tree.physics_frame
	_verify_realized_collision(player, chunk, snapshot, surface, opening.grow(clearance), failures)

	var start_position: Vector3 = player.global_position
	if not await _wait_for_grounded(tree, player, MAX_GROUND_SETTLE_FRAMES):
		failures.append("live/physics Player did not settle on ordinary approach terrain")
		return {"plan_fingerprint": plan_fingerprint, "chunk_coord": coord}
	start_position = player.global_position
	var crossed: bool = await _walk_into_mouth(tree, player, surface, opening.grow(clearance))
	_release_movement_actions()
	if not crossed:
		failures.append("live/physics real Player did not cross below the selected surface mouth")
		return {"plan_fingerprint": plan_fingerprint, "chunk_coord": coord}
	if player.has_method("is_defeated") and bool(player.call("is_defeated")):
		failures.append("live/physics entrance traversal incorrectly defeated Player")
		return {"plan_fingerprint": plan_fingerprint, "chunk_coord": coord}

	var returned: bool = await _walk_back_to_surface(tree, player, world, start_position)
	_release_movement_actions()
	if not returned:
		failures.append("live/physics real Player could enter but could not backtrack through the same surface entrance")
	elif player.has_method("is_defeated") and bool(player.call("is_defeated")):
		failures.append("live/physics backtrack incorrectly defeated Player")
	return {
		"plan_fingerprint": plan_fingerprint,
		"chunk_coord": coord,
		"start_position": start_position,
	}


static func verify_continue(
	tree: SceneTree,
	game: Node,
	route: Dictionary,
	expected_plan_fingerprint: String,
	failures: Array[String]
) -> void:
	if expected_plan_fingerprint.is_empty():
		failures.append("live/continue has no NEW production surface-plan fingerprint to compare")
		return
	var world = game.get("world")
	var settings = game.get("world_settings")
	var surface_variant: Variant = route.get("surface_world_position", null)
	if world == null or settings == null or not surface_variant is Vector3:
		failures.append("live/continue cannot resolve production entrance surface chunk")
		return
	var surface: Vector3 = surface_variant
	var coord: Vector2i = world.call("world_to_chunk", surface)
	if not await _wait_for_composed_chunk(tree, world, coord):
		failures.append("live/continue selected mouth chunk did not reload through production streamer")
		return
	var snapshot: Dictionary = world.call("get_entrance_surface_composition_snapshot", coord)
	if str(snapshot.get("plan_fingerprint", "")) != expected_plan_fingerprint:
		failures.append("live/continue production surface opening fingerprint changed across reload")
	if str(snapshot.get("entrance_id", "")) != str(route.get("entrance_id", "")):
		failures.append("live/continue production surface opening changed selected entrance identity")
	var chunk = world.get("chunks").get(coord, null)
	if chunk == null or not is_instance_valid(chunk):
		failures.append("live/continue production entrance chunk was not realized after reload")
		return
	_verify_realized_mesh(chunk, snapshot, failures)
	await tree.physics_frame
	var player = game.get("player")
	var opening_variant: Variant = route.get("required_opening_bounds", null)
	if player != null and opening_variant is AABB:
		_verify_realized_collision(
			player,
			chunk,
			snapshot,
			surface,
			(opening_variant as AABB).grow(float(route.get("clearance_radius", 0.0))),
			failures
		)


static func _wait_for_composed_chunk(tree: SceneTree, world, coord: Vector2i) -> bool:
	for _frame in range(MAX_CHUNK_WAIT_FRAMES):
		var chunks_variant: Variant = world.get("chunks")
		if chunks_variant is Dictionary and chunks_variant.has(coord):
			var snapshot_variant: Variant = world.call("get_entrance_surface_composition_snapshot", coord)
			if snapshot_variant is Dictionary and not snapshot_variant.is_empty():
				return true
		await tree.process_frame
	return false


static func _verify_realized_mesh(chunk, snapshot: Dictionary, failures: Array[String]) -> void:
	var mesh_variant: Variant = chunk.get("mesh")
	if not mesh_variant is ArrayMesh:
		failures.append("live/physics selected surface chunk is not realized as ArrayMesh")
		return
	var array_mesh: ArrayMesh = mesh_variant
	if array_mesh.get_surface_count() != 1:
		failures.append("live/physics selected surface chunk has unexpected terrain surface count")
		return
	var arrays: Array = array_mesh.surface_get_arrays(0)
	var indices_variant: Variant = arrays[Mesh.ARRAY_INDEX]
	if not indices_variant is PackedInt32Array:
		failures.append("live/physics selected surface chunk has no indexed terrain mesh")
		return
	var indices: PackedInt32Array = indices_variant
	var expected_count: int = int(snapshot.get("realized_index_count", -1))
	if expected_count <= 0 or indices.size() != expected_count:
		failures.append("live/physics realized terrain index count does not match production opening snapshot")
	if int(snapshot.get("original_index_count", 0)) <= indices.size():
		failures.append("live/physics realized terrain mesh still contains the full surface cap")


static func _verify_realized_collision(
	player,
	chunk,
	snapshot: Dictionary,
	surface: Vector3,
	rim_bounds: AABB,
	failures: Array[String]
) -> void:
	var body: Node = chunk.get_node_or_null("TerrainCollision")
	if body == null or not body is StaticBody3D:
		failures.append("live/physics selected surface chunk has no terrain collision body")
		return
	var collision_node: Node = body.get_node_or_null("CollisionShape3D")
	if collision_node == null or not collision_node is CollisionShape3D:
		failures.append("live/physics selected surface chunk has no collision shape")
		return
	var shape_variant: Variant = collision_node.get("shape")
	if not shape_variant is HeightMapShape3D:
		failures.append("live/physics selected surface collision is not HeightMapShape3D")
		return
	var shape: HeightMapShape3D = shape_variant
	var nan_count: int = 0
	for value in shape.map_data:
		if is_nan(value):
			nan_count += 1
	if nan_count != int(snapshot.get("collision_hole_count", -1)) or nan_count <= 0:
		failures.append("live/physics HeightMapShape3D hole count does not match accepted production plan")

	var space_state = player.get_world_3d().direct_space_state
	var mouth_query := PhysicsRayQueryParameters3D.create(
		surface + Vector3.UP * 3.5,
		surface - Vector3.UP * 1.5,
		1
	)
	mouth_query.exclude = [player.get_rid()]
	var mouth_hit: Dictionary = space_state.intersect_ray(mouth_query)
	if not mouth_hit.is_empty():
		var mouth_collider = mouth_hit.get("collider", null)
		if mouth_collider != null and str(mouth_collider.name) == "TerrainCollision":
			failures.append("live/physics production terrain collision still caps the selected mouth")

	var outside_point: Vector3 = _outside_probe_point(rim_bounds, snapshot.get("chunk_bounds", AABB()), surface)
	if not _finite_vector3(outside_point):
		failures.append("live/physics could not choose bounded outside-collision probe")
		return
	var outside_query := PhysicsRayQueryParameters3D.create(
		outside_point + Vector3.UP * 32.0,
		outside_point - Vector3.UP * 32.0,
		1
	)
	outside_query.exclude = [player.get_rid()]
	var outside_hit: Dictionary = space_state.intersect_ray(outside_query)
	if outside_hit.is_empty():
		failures.append("live/physics collision immediately outside entrance opening is missing")
		return
	var outside_collider = outside_hit.get("collider", null)
	if outside_collider == null or str(outside_collider.name) != "TerrainCollision":
		failures.append("live/physics outside opening probe did not hit canonical terrain collision first")


static func _outside_probe_point(rim: AABB, chunk_bounds_variant: Variant, surface: Vector3) -> Vector3:
	if not chunk_bounds_variant is AABB:
		return Vector3.INF
	var chunk_bounds: AABB = chunk_bounds_variant
	var margin: float = 4.0
	var candidates: Array[Vector3] = [
		Vector3(rim.end.x + margin, surface.y, surface.z),
		Vector3(rim.position.x - margin, surface.y, surface.z),
		Vector3(surface.x, surface.y, rim.end.z + margin),
		Vector3(surface.x, surface.y, rim.position.z - margin),
	]
	for candidate in candidates:
		if (
			candidate.x > chunk_bounds.position.x + 1.0
			and candidate.x < chunk_bounds.end.x - 1.0
			and candidate.z > chunk_bounds.position.z + 1.0
			and candidate.z < chunk_bounds.end.z - 1.0
		):
			return candidate
	return Vector3.INF


static func _wait_for_grounded(tree: SceneTree, player, frame_limit: int) -> bool:
	for _frame in range(frame_limit):
		if player.has_method("is_defeated") and bool(player.call("is_defeated")):
			return false
		if bool(player.call("is_on_floor")):
			return true
		await tree.physics_frame
	return false


static func _walk_into_mouth(
	tree: SceneTree,
	player,
	surface: Vector3,
	rim_bounds: AABB
) -> bool:
	Input.action_press("move_forward")
	for _frame in range(MAX_APPROACH_FRAMES):
		if player.has_method("is_defeated") and bool(player.call("is_defeated")):
			return false
		var position: Vector3 = player.global_position
		var to_surface := Vector3(surface.x - position.x, 0.0, surface.z - position.z)
		if to_surface.length_squared() > 0.01:
			_face_camera(player, to_surface)
		await tree.physics_frame
		position = player.global_position
		if (
			_contains_xz(rim_bounds, position)
			and position.y < surface.y - BELOW_SURFACE_THRESHOLD
		):
			return true
	return false


static func _walk_back_to_surface(
	tree: SceneTree,
	player,
	world,
	start_position: Vector3
) -> bool:
	Input.action_press("move_forward")
	for frame in range(MAX_EXIT_FRAMES):
		if player.has_method("is_defeated") and bool(player.call("is_defeated")):
			return false
		var position: Vector3 = player.global_position
		var to_start := Vector3(start_position.x - position.x, 0.0, start_position.z - position.z)
		if to_start.length_squared() > 0.01:
			_face_camera(player, to_start)
		if bool(player.call("is_on_floor")) and frame % 18 == 0:
			Input.action_press("jump")
		else:
			Input.action_release("jump")
		await tree.physics_frame
		position = player.global_position
		var horizontal_distance: float = Vector2(
			position.x - start_position.x,
			position.z - start_position.z
		).length()
		var terrain_height: float = float(world.call("get_height_at_world", position.x, position.z))
		if (
			horizontal_distance <= EXIT_HORIZONTAL_TOLERANCE
			and position.y >= terrain_height - 0.25
			and bool(player.call("is_on_floor"))
		):
			return true
	return false


static func _face_camera(player, horizontal_direction: Vector3) -> void:
	var camera_yaw = player.get("camera_yaw")
	if camera_yaw == null or not camera_yaw is Node3D:
		return
	var direction := Vector3(horizontal_direction.x, 0.0, horizontal_direction.z)
	if direction.is_zero_approx():
		return
	camera_yaw.look_at(camera_yaw.global_position + direction.normalized(), Vector3.UP)


static func _release_movement_actions() -> void:
	for action in ["move_forward", "move_backward", "move_left", "move_right", "sprint", "jump"]:
		Input.action_release(action)


static func _contains_xz(bounds: AABB, point: Vector3) -> bool:
	return (
		point.x >= bounds.position.x
		and point.x <= bounds.end.x
		and point.z >= bounds.position.z
		and point.z <= bounds.end.z
	)


static func _finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)
