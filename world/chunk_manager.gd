extends Node3D

const TerrainGeneratorScript := preload("res://world/terrain_generator.gd")
const TerrainChunkScript := preload("res://world/terrain_chunk.gd")

var settings: UnderworldWorldSettings
var main_generator
var worker_generator
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

# Terrain data is generated on one background worker. Scene-tree, mesh, and
# physics objects are still created exclusively on the main thread.
var worker_task_id: int = -1
var worker_coord: Vector2i = Vector2i.ZERO
var worker_mutex: Mutex = Mutex.new()
var worker_result_coord: Vector2i = Vector2i.ZERO
var worker_result_data: Dictionary = {}
var worker_result_ms: float = 0.0

var terrain_material: StandardMaterial3D = StandardMaterial3D.new()
var decoration_assets: Dictionary = {}


func configure(world_settings: UnderworldWorldSettings) -> void:
	settings = world_settings

	# Keep separate noise resources for main-thread probes and background chunk
	# generation so no FastNoiseLite instance crosses a thread boundary.
	main_generator = TerrainGeneratorScript.new()
	main_generator.configure(settings)
	worker_generator = TerrainGeneratorScript.new()
	worker_generator.configure(settings)

	terrain_material.albedo_color = Color.WHITE
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 1.0

	_create_prototype_decoration_assets()


func _create_prototype_decoration_assets() -> void:
	# These are deliberately low-cost placeholder shapes. They let us judge
	# generated forest/rock distribution before spending time on art assets.
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

	decoration_assets = {
		"tree_mesh": tree_mesh,
		"tree_material": tree_material,
		"rock_mesh": rock_mesh,
		"rock_material": rock_material,
	}


func generate_initial(world_position: Vector3) -> void:
	var center: Vector2i = world_to_chunk(world_position)
	current_player_chunk = center

	# The spawn chunk stays synchronous so the player always has ground on the
	# very first frame. All subsequently streamed chunks use the worker.
	_create_chunk_sync(center)
	_update_desired_chunks(center)


func set_player(player_node: Node3D) -> void:
	player = player_node
	current_player_chunk = world_to_chunk(player.global_position)
	_update_desired_chunks(current_player_chunk)


func _process(_delta: float) -> void:
	if player != null:
		var player_chunk: Vector2i = world_to_chunk(player.global_position)
		if player_chunk != current_player_chunk:
			current_player_chunk = player_chunk
			_update_desired_chunks(current_player_chunk)

	_collect_completed_worker_task()
	_start_next_worker_task()


func _exit_tree() -> void:
	if worker_task_id != -1:
		WorkerThreadPool.wait_for_task_completion(worker_task_id)
		worker_task_id = -1


func world_to_chunk(world_position: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_position.x / settings.chunk_size),
		floori(world_position.z / settings.chunk_size)
	)


func get_height_at_world(world_x: float, world_z: float) -> float:
	return main_generator.get_height(world_x, world_z)


func get_surface_sample_at_world(world_x: float, world_z: float) -> Dictionary:
	return main_generator.get_surface_sample(world_x, world_z)


func find_spawn_xz(preferred: Vector3) -> Vector3:
	# The new macro terrain can legitimately put the preferred origin under
	# water or on a ridge. Probe a few chunks around it and choose a nearby,
	# dry, relatively flat location rather than forcing every seed to have the
	# same hand-shaped spawn island.
	var search_step: float = maxf(settings.chunk_size * 0.25, 16.0)
	var search_radius: float = settings.chunk_size * 3.0
	var half_steps: int = ceili(search_radius / search_step)
	var best_position: Vector3 = preferred
	var best_score: float = -1.0e20

	for z_index in range(-half_steps, half_steps + 1):
		for x_index in range(-half_steps, half_steps + 1):
			var candidate_x: float = preferred.x + float(x_index) * search_step
			var candidate_z: float = preferred.z + float(z_index) * search_step
			var sample: Dictionary = main_generator.get_surface_sample(candidate_x, candidate_z)
			var height: float = float(sample["height"])
			if height <= settings.sea_level + 1.5:
				continue

			var buildability: float = float(sample["buildability"])
			var rockiness: float = float(sample["rockiness"])
			var moisture: float = float(sample["moisture"])
			var distance: float = Vector2(
				candidate_x - preferred.x,
				candidate_z - preferred.z
			).length()
			var distance_penalty: float = distance / maxf(search_radius, 1.0)
			var score: float = (
				buildability * 6.0
				- rockiness * 0.35
				+ moisture * 0.15
				- distance_penalty * 1.15
			)

			if score > best_score:
				best_score = score
				best_position = Vector3(candidate_x, 0.0, candidate_z)

	return best_position


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
	chunk.build(coord, data, terrain_material, decoration_assets, needs_collision)
	add_child(chunk)
	chunks[coord] = chunk

	last_chunk_build_ms = float(Time.get_ticks_usec() - build_started_usec) / 1000.0
	max_chunk_build_ms = maxf(max_chunk_build_ms, last_chunk_build_ms)
	last_generation_ms = data_ms + last_chunk_build_ms
	max_generation_ms = maxf(max_generation_ms, last_generation_ms)
	total_chunks_generated += 1


func _update_collision_radius(center: Vector2i) -> void:
	for key in chunks.keys():
		var coord: Vector2i = key
		chunks[coord].set_collision_enabled(
			_is_within_collision_radius(coord, center)
		)


func _is_within_collision_radius(coord: Vector2i, center: Vector2i) -> bool:
	return _is_within_square_radius(coord, center, settings.collision_radius)


func _is_within_square_radius(coord: Vector2i, center: Vector2i, radius: int) -> bool:
	var delta: Vector2i = coord - center
	return abs(delta.x) <= radius and abs(delta.y) <= radius
