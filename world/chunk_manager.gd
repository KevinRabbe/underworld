extends Node3D

const TerrainGeneratorScript := preload("res://world/terrain_generator.gd")
const TerrainChunkScript := preload("res://world/terrain_chunk.gd")

var settings: Resource
var generator
var player: Node3D

var chunks: Dictionary = {}
var pending_chunks: Array[Vector2i] = []
var pending_lookup: Dictionary = {}
var desired_chunks: Dictionary = {}
var current_player_chunk := Vector2i(999999999, 999999999)

var last_generation_ms := 0.0
var max_generation_ms := 0.0
var total_chunks_generated := 0

var terrain_material := StandardMaterial3D.new()


func configure(world_settings: Resource) -> void:
	settings = world_settings
	generator = TerrainGeneratorScript.new()
	generator.configure(settings)

	terrain_material.albedo_color = Color(0.24, 0.43, 0.18)
	terrain_material.roughness = 1.0


func generate_initial(world_position: Vector3) -> void:
	var center := world_to_chunk(world_position)
	current_player_chunk = center

	# The spawn chunk is immediate so the player always has ground.
	_create_chunk(center)
	_update_desired_chunks(center)


func set_player(player_node: Node3D) -> void:
	player = player_node
	current_player_chunk = world_to_chunk(player.global_position)
	_update_desired_chunks(current_player_chunk)


func _process(_delta: float) -> void:
	_process_generation_queue()

	if player == null:
		return

	var player_chunk := world_to_chunk(player.global_position)
	if player_chunk != current_player_chunk:
		current_player_chunk = player_chunk
		_update_desired_chunks(current_player_chunk)


func world_to_chunk(world_position: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_position.x / settings.chunk_size),
		floori(world_position.z / settings.chunk_size)
	)


func get_height_at_world(world_x: float, world_z: float) -> float:
	return generator.get_height(world_x, world_z)


func get_loaded_chunk_count() -> int:
	return chunks.size()


func get_pending_chunk_count() -> int:
	return pending_chunks.size()


func get_current_player_chunk() -> Vector2i:
	return current_player_chunk


func get_last_generation_ms() -> float:
	return last_generation_ms


func get_max_generation_ms() -> float:
	return max_generation_ms


func get_total_chunks_generated() -> int:
	return total_chunks_generated


func _update_desired_chunks(center: Vector2i) -> void:
	desired_chunks.clear()

	for z_offset in range(-settings.load_radius, settings.load_radius + 1):
		for x_offset in range(-settings.load_radius, settings.load_radius + 1):
			var coord := center + Vector2i(x_offset, z_offset)
			desired_chunks[coord] = true

	# Keep a retention ring outside the load radius. This prevents rapid
	# destroy/regenerate thrashing when the player hovers around a chunk edge.
	var retention_radius: int = maxi(settings.load_radius, settings.unload_radius)
	for coord in chunks.keys():
		if not _is_within_square_radius(coord, center, retention_radius):
			chunks[coord].queue_free()
			chunks.erase(coord)

	_rebuild_generation_queue(center)
	_update_collision_radius(center)


func _rebuild_generation_queue(center: Vector2i) -> void:
	pending_chunks.clear()
	pending_lookup.clear()

	for coord in desired_chunks.keys():
		if chunks.has(coord):
			continue
		pending_chunks.append(coord)
		pending_lookup[coord] = true

	current_player_chunk = center
	pending_chunks.sort_custom(_compare_pending_chunks)


func _compare_pending_chunks(a: Vector2i, b: Vector2i) -> bool:
	return _chunk_distance_squared(a, current_player_chunk) < _chunk_distance_squared(b, current_player_chunk)


func _chunk_distance_squared(a: Vector2i, b: Vector2i) -> int:
	var delta := a - b
	return delta.x * delta.x + delta.y * delta.y


func _process_generation_queue() -> void:
	if pending_chunks.is_empty():
		return

	var generation_budget := maxi(1, settings.max_chunks_generated_per_frame)
	for _index in range(generation_budget):
		if pending_chunks.is_empty():
			break

		var coord := pending_chunks.pop_front()
		pending_lookup.erase(coord)

		if desired_chunks.has(coord) and not chunks.has(coord):
			_create_chunk(coord)


func _create_chunk(coord: Vector2i) -> void:
	if chunks.has(coord):
		return

	var started_usec := Time.get_ticks_usec()
	var data := generator.generate_chunk_data(coord)
	var chunk = TerrainChunkScript.new()
	chunk.position = Vector3(
		float(coord.x) * settings.chunk_size,
		0.0,
		float(coord.y) * settings.chunk_size
	)

	var needs_collision := _is_within_collision_radius(coord, current_player_chunk)
	chunk.build(coord, data, terrain_material, needs_collision)
	add_child(chunk)
	chunks[coord] = chunk

	last_generation_ms = float(Time.get_ticks_usec() - started_usec) / 1000.0
	max_generation_ms = maxf(max_generation_ms, last_generation_ms)
	total_chunks_generated += 1


func _update_collision_radius(center: Vector2i) -> void:
	for coord in chunks.keys():
		chunks[coord].set_collision_enabled(
			_is_within_collision_radius(coord, center)
		)


func _is_within_collision_radius(coord: Vector2i, center: Vector2i) -> bool:
	return _is_within_square_radius(coord, center, settings.collision_radius)


func _is_within_square_radius(coord: Vector2i, center: Vector2i, radius: int) -> bool:
	var delta := coord - center
	return abs(delta.x) <= radius and abs(delta.y) <= radius
