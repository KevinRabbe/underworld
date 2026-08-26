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
	var padded_resolution: int = resolution + 2

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var heights: PackedFloat32Array = PackedFloat32Array()
	var collision_heights: PackedFloat32Array = PackedFloat32Array()

	vertices.resize(vertex_count)
	normals.resize(vertex_count)
	uvs.resize(vertex_count)
	heights.resize(padded_resolution * padded_resolution)
	collision_heights.resize(vertex_count)

	var chunk_world_x: float = float(chunk_coord.x) * settings.chunk_size
	var chunk_world_z: float = float(chunk_coord.y) * settings.chunk_size

	# Cache a one-vertex border around the chunk. This gives seamless edge
	# normals while reducing noise sampling from roughly five calls per vertex
	# to one call per cached height sample.
	for padded_z in range(padded_resolution):
		for padded_x in range(padded_resolution):
			var local_x_with_border: float = float(padded_x - 1) * spacing
			var local_z_with_border: float = float(padded_z - 1) * spacing
			var sample_world_x: float = chunk_world_x + local_x_with_border
			var sample_world_z: float = chunk_world_z + local_z_with_border
			var padded_index: int = padded_z * padded_resolution + padded_x
			heights[padded_index] = get_height(sample_world_x, sample_world_z)

	for z in range(resolution):
		for x in range(resolution):
			var index: int = z * resolution + x
			var padded_x: int = x + 1
			var padded_z: int = z + 1
			var padded_index: int = padded_z * padded_resolution + padded_x

			var local_x: float = float(x) * spacing
			var local_z: float = float(z) * spacing
			var world_x: float = chunk_world_x + local_x
			var world_z: float = chunk_world_z + local_z
			var height: float = heights[padded_index]

			var left: float = heights[padded_index - 1]
			var right: float = heights[padded_index + 1]
			var back: float = heights[padded_index - padded_resolution]
			var front: float = heights[padded_index + padded_resolution]

			vertices[index] = Vector3(local_x, height, local_z)
			collision_heights[index] = height
			uvs[index] = Vector2(world_x, world_z) * 0.02
			normals[index] = Vector3(
				left - right,
				2.0 * spacing,
				back - front
			).normalized()

	for z in range(resolution - 1):
		for x in range(resolution - 1):
			var top_left: int = z * resolution + x
			var bottom_left: int = (z + 1) * resolution + x
			var top_right: int = top_left + 1
			var bottom_right: int = bottom_left + 1

			# Godot treats clockwise triangle winding as front-facing.
			indices.append(top_left)
			indices.append(top_right)
			indices.append(bottom_left)

			indices.append(top_right)
			indices.append(bottom_right)
			indices.append(bottom_left)

	return {
		"vertices": vertices,
		"normals": normals,
		"uvs": uvs,
		"indices": indices,
		"collision_heights": collision_heights,
		"resolution": resolution,
		"spacing": spacing,
	}
