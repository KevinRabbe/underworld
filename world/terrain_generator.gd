extends RefCounted

var settings: UnderworldWorldSettings
var macro_noise: FastNoiseLite = FastNoiseLite.new()
var detail_noise: FastNoiseLite = FastNoiseLite.new()


func configure(world_settings: UnderworldWorldSettings) -> void:
	settings = world_settings

	macro_noise.seed = settings.world_seed
	macro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	macro_noise.frequency = settings.macro_frequency
	macro_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	macro_noise.fractal_octaves = 4
	macro_noise.fractal_gain = 0.5
	macro_noise.fractal_lacunarity = 2.0

	detail_noise.seed = settings.world_seed + 7919
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.frequency = settings.detail_frequency
	detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail_noise.fractal_octaves = 3
	detail_noise.fractal_gain = 0.5
	detail_noise.fractal_lacunarity = 2.0


func get_height(world_x: float, world_z: float) -> float:
	var macro_height: float = macro_noise.get_noise_2d(world_x, world_z) * settings.macro_amplitude
	var detail_height: float = detail_noise.get_noise_2d(world_x, world_z) * settings.detail_amplitude
	return macro_height + detail_height


func generate_chunk_data(chunk_coord: Vector2i) -> Dictionary:
	var resolution: int = maxi(settings.vertices_per_side, 2)
	var spacing: float = settings.chunk_size / float(resolution - 1)
	var vertex_count: int = resolution * resolution

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()

	vertices.resize(vertex_count)
	normals.resize(vertex_count)
	uvs.resize(vertex_count)

	var chunk_world_x: float = float(chunk_coord.x) * settings.chunk_size
	var chunk_world_z: float = float(chunk_coord.y) * settings.chunk_size

	for z: int in range(resolution):
		for x: int in range(resolution):
			var index: int = z * resolution + x
			var local_x: float = float(x) * spacing
			var local_z: float = float(z) * spacing
			var world_x: float = chunk_world_x + local_x
			var world_z: float = chunk_world_z + local_z
			var height: float = get_height(world_x, world_z)

			vertices[index] = Vector3(local_x, height, local_z)
			uvs[index] = Vector2(world_x, world_z) * 0.02
			normals[index] = _get_normal(world_x, world_z, spacing)

	for z: int in range(resolution - 1):
		for x: int in range(resolution - 1):
			var top_left: int = z * resolution + x
			var bottom_left: int = (z + 1) * resolution + x
			var top_right: int = top_left + 1
			var bottom_right: int = bottom_left + 1

			indices.append(top_left)
			indices.append(bottom_left)
			indices.append(top_right)

			indices.append(top_right)
			indices.append(bottom_left)
			indices.append(bottom_right)

	return {
		"vertices": vertices,
		"normals": normals,
		"uvs": uvs,
		"indices": indices,
	}


func _get_normal(world_x: float, world_z: float, sample_distance: float) -> Vector3:
	var left: float = get_height(world_x - sample_distance, world_z)
	var right: float = get_height(world_x + sample_distance, world_z)
	var back: float = get_height(world_x, world_z - sample_distance)
	var front: float = get_height(world_x, world_z + sample_distance)

	return Vector3(
		left - right,
		2.0 * sample_distance,
		back - front
	).normalized()
