extends RefCounted

const COLOR_DRY_GRASS := Color(0.37, 0.48, 0.20)
const COLOR_LUSH_GRASS := Color(0.19, 0.42, 0.16)
const COLOR_ROCK := Color(0.39, 0.40, 0.37)
const COLOR_SHORE := Color(0.48, 0.43, 0.28)
const COLOR_SUBMERGED := Color(0.18, 0.28, 0.17)

var settings: UnderworldWorldSettings

var continental_noise: FastNoiseLite = FastNoiseLite.new()
var rolling_noise: FastNoiseLite = FastNoiseLite.new()
var flatland_noise: FastNoiseLite = FastNoiseLite.new()
var ridge_noise: FastNoiseLite = FastNoiseLite.new()
var ridge_region_noise: FastNoiseLite = FastNoiseLite.new()
var valley_noise: FastNoiseLite = FastNoiseLite.new()
var detail_noise: FastNoiseLite = FastNoiseLite.new()

var moisture_noise: FastNoiseLite = FastNoiseLite.new()
var forest_noise: FastNoiseLite = FastNoiseLite.new()
var rock_noise: FastNoiseLite = FastNoiseLite.new()


func configure(world_settings: UnderworldWorldSettings) -> void:
	settings = world_settings

	# Large-scale fields intentionally use only the octaves needed for their
	# job. Full detail at every scale is expensive and tends to turn terrain
	# back into homogeneous procedural noise.
	_configure_fbm(continental_noise, 101, settings.continental_frequency, 3)
	_configure_fbm(rolling_noise, 211, settings.rolling_frequency, 2)
	_configure_fbm(flatland_noise, 307, settings.flatland_frequency, 2)
	_configure_fbm(ridge_noise, 401, settings.ridge_frequency, 2)
	_configure_fbm(ridge_region_noise, 503, settings.ridge_region_frequency, 2)
	_configure_fbm(valley_noise, 601, settings.valley_frequency, 2)
	_configure_fbm(detail_noise, 701, settings.detail_frequency, 1)

	_configure_fbm(moisture_noise, 809, settings.moisture_frequency, 2)
	_configure_fbm(forest_noise, 907, settings.forest_frequency, 2)
	_configure_fbm(rock_noise, 1009, settings.rock_frequency, 1)


func _configure_fbm(
	noise: FastNoiseLite,
	seed_offset: int,
	frequency: float,
	octaves: int
) -> void:
	noise.seed = settings.world_seed + seed_offset
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.0


func get_height(world_x: float, world_z: float) -> float:
	return _sample_height_and_ridge(world_x, world_z).x


func _sample_height_and_ridge(world_x: float, world_z: float) -> Vector2:
	var continental_raw: float = continental_noise.get_noise_2d(world_x, world_z)
	var continental_height: float = continental_raw * settings.continental_amplitude

	var flat_mask: float = _get_flatland_mask(world_x, world_z, continental_raw)
	var relief_scale: float = 1.0 - flat_mask * settings.flatland_strength

	var rolling_height: float = (
		rolling_noise.get_noise_2d(world_x, world_z)
		* settings.rolling_amplitude
		* relief_scale
	)

	var ridge_influence: float = _get_ridge_influence(world_x, world_z)
	var ridge_height: float = (
		ridge_influence
		* settings.ridge_amplitude
		* (1.0 - flat_mask * 0.76)
	)

	var valley_depth: float = (
		_get_valley_influence(world_x, world_z)
		* settings.valley_depth
		* (1.0 - flat_mask * 0.42)
	)

	var detail_height: float = (
		detail_noise.get_noise_2d(world_x, world_z)
		* settings.detail_amplitude
		* (1.0 - flat_mask * 0.72)
	)

	var height: float = (
		settings.base_height
		+ continental_height
		+ rolling_height
		+ ridge_height
		- valley_depth
		+ detail_height
	)
	return Vector2(height, ridge_influence)


func get_surface_sample(world_x: float, world_z: float) -> Dictionary:
	var sample_distance: float = settings.chunk_size / float(maxi(settings.vertices_per_side - 1, 1))
	var center_sample: Vector2 = _sample_height_and_ridge(world_x, world_z)
	var height: float = center_sample.x
	var left: float = get_height(world_x - sample_distance, world_z)
	var right: float = get_height(world_x + sample_distance, world_z)
	var back: float = get_height(world_x, world_z - sample_distance)
	var front: float = get_height(world_x, world_z + sample_distance)
	var normal: Vector3 = Vector3(
		left - right,
		2.0 * sample_distance,
		back - front
	).normalized()
	var slope: float = clampf(1.0 - normal.y, 0.0, 1.0)
	var moisture: float = _get_moisture(world_x, world_z, height)
	var rockiness: float = _get_rockiness(world_x, world_z, slope, center_sample.y)
	var forest_density: float = _get_forest_density(world_x, world_z, height, moisture, rockiness, slope)
	var buildability: float = _get_buildability(height, slope, rockiness)

	return {
		"height": height,
		"slope": slope,
		"moisture": moisture,
		"forest_density": forest_density,
		"rockiness": rockiness,
		"buildability": buildability,
	}


func generate_chunk_data(chunk_coord: Vector2i) -> Dictionary:
	var resolution: int = maxi(settings.vertices_per_side, 2)
	var spacing: float = settings.chunk_size / float(resolution - 1)
	var vertex_count: int = resolution * resolution
	var padded_resolution: int = resolution + 2

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var heights: PackedFloat32Array = PackedFloat32Array()
	var ridge_values: PackedFloat32Array = PackedFloat32Array()
	var collision_heights: PackedFloat32Array = PackedFloat32Array()
	var moisture_values: PackedFloat32Array = PackedFloat32Array()
	var forest_values: PackedFloat32Array = PackedFloat32Array()
	var rockiness_values: PackedFloat32Array = PackedFloat32Array()
	var buildability_values: PackedFloat32Array = PackedFloat32Array()

	vertices.resize(vertex_count)
	normals.resize(vertex_count)
	uvs.resize(vertex_count)
	colors.resize(vertex_count)
	heights.resize(padded_resolution * padded_resolution)
	ridge_values.resize(vertex_count)
	collision_heights.resize(vertex_count)
	moisture_values.resize(vertex_count)
	forest_values.resize(vertex_count)
	rockiness_values.resize(vertex_count)
	buildability_values.resize(vertex_count)

	var chunk_world_x: float = float(chunk_coord.x) * settings.chunk_size
	var chunk_world_z: float = float(chunk_coord.y) * settings.chunk_size

	# Cache a one-vertex border around the chunk. Neighboring chunks therefore
	# calculate the same border heights and normals without sharing any data.
	# Ridge influence is captured here too, so the environment pass does not
	# evaluate the two ridge fields a second time for every terrain vertex.
	for padded_z in range(padded_resolution):
		for padded_x in range(padded_resolution):
			var local_x_with_border: float = float(padded_x - 1) * spacing
			var local_z_with_border: float = float(padded_z - 1) * spacing
			var sample_world_x: float = chunk_world_x + local_x_with_border
			var sample_world_z: float = chunk_world_z + local_z_with_border
			var padded_index: int = padded_z * padded_resolution + padded_x
			var height_sample: Vector2 = _sample_height_and_ridge(sample_world_x, sample_world_z)
			heights[padded_index] = height_sample.x

			if (
				padded_x >= 1
				and padded_x <= resolution
				and padded_z >= 1
				and padded_z <= resolution
			):
				var vertex_x: int = padded_x - 1
				var vertex_z: int = padded_z - 1
				var vertex_index: int = vertex_z * resolution + vertex_x
				ridge_values[vertex_index] = height_sample.y

	# Moisture, forest-potential and rock-pattern fields vary at scales much
	# larger than the 2 m terrain vertex spacing. Sampling them every vertex is
	# wasted work, so create a deterministic coarse grid and interpolate it.
	var mask_step: int = maxi(settings.environment_mask_vertex_step, 1)
	var mask_grid_resolution: int = ceili(float(resolution - 1) / float(mask_step)) + 1
	var mask_grid_count: int = mask_grid_resolution * mask_grid_resolution
	var coarse_moisture: PackedFloat32Array = PackedFloat32Array()
	var coarse_forest: PackedFloat32Array = PackedFloat32Array()
	var coarse_rock: PackedFloat32Array = PackedFloat32Array()
	coarse_moisture.resize(mask_grid_count)
	coarse_forest.resize(mask_grid_count)
	coarse_rock.resize(mask_grid_count)

	for grid_z in range(mask_grid_resolution):
		for grid_x in range(mask_grid_resolution):
			var vertex_x: int = mini(grid_x * mask_step, resolution - 1)
			var vertex_z: int = mini(grid_z * mask_step, resolution - 1)
			var world_x: float = chunk_world_x + float(vertex_x) * spacing
			var world_z: float = chunk_world_z + float(vertex_z) * spacing
			var grid_index: int = grid_z * mask_grid_resolution + grid_x
			coarse_moisture[grid_index] = _to_unit(moisture_noise.get_noise_2d(world_x, world_z))
			coarse_forest[grid_index] = _to_unit(forest_noise.get_noise_2d(world_x, world_z))
			coarse_rock[grid_index] = _to_unit(rock_noise.get_noise_2d(world_x, world_z))

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
			var normal: Vector3 = Vector3(
				left - right,
				2.0 * spacing,
				back - front
			).normalized()
			var slope: float = clampf(1.0 - normal.y, 0.0, 1.0)

			var moisture_pattern: float = _sample_mask_grid(
				coarse_moisture,
				mask_grid_resolution,
				x,
				z,
				mask_step,
				resolution
			)
			var forest_pattern: float = _sample_mask_grid(
				coarse_forest,
				mask_grid_resolution,
				x,
				z,
				mask_step,
				resolution
			)
			var rock_pattern: float = _sample_mask_grid(
				coarse_rock,
				mask_grid_resolution,
				x,
				z,
				mask_step,
				resolution
			)

			var moisture: float = _get_moisture_from_pattern(moisture_pattern, height)
			var ridge: float = ridge_values[index]
			var rockiness: float = _get_rockiness_from_pattern(rock_pattern, slope, ridge)
			var forest_density: float = _get_forest_density_from_pattern(
				forest_pattern,
				height,
				moisture,
				rockiness,
				slope
			)
			var buildability: float = _get_buildability(height, slope, rockiness)

			vertices[index] = Vector3(local_x, height, local_z)
			normals[index] = normal
			collision_heights[index] = height
			uvs[index] = Vector2(world_x, world_z) * 0.02
			colors[index] = _get_surface_color(height, moisture, rockiness)
			moisture_values[index] = moisture
			forest_values[index] = forest_density
			rockiness_values[index] = rockiness
			buildability_values[index] = buildability

	for z in range(resolution - 1):
		for x in range(resolution - 1):
			var top_left: int = z * resolution + x
			var bottom_left: int = (z + 1) * resolution + x
			var top_right: int = top_left + 1
			var bottom_right: int = bottom_left + 1

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
		"colors": colors,
		"indices": indices,
		"collision_heights": collision_heights,
		"moisture": moisture_values,
		"forest_density": forest_values,
		"rockiness": rockiness_values,
		"buildability": buildability_values,
		"resolution": resolution,
		"spacing": spacing,
	}


func _sample_mask_grid(
	values: PackedFloat32Array,
	grid_resolution: int,
	vertex_x: int,
	vertex_z: int,
	step: int,
	terrain_resolution: int
) -> float:
	if grid_resolution <= 1 or values.is_empty():
		return values[0] if not values.is_empty() else 0.0

	var cell_x: int = mini(
		floori(float(vertex_x) / float(step)),
		grid_resolution - 2
	)
	var cell_z: int = mini(
		floori(float(vertex_z) / float(step)),
		grid_resolution - 2
	)

	var x0: int = cell_x * step
	var z0: int = cell_z * step
	var x1: int = mini((cell_x + 1) * step, terrain_resolution - 1)
	var z1: int = mini((cell_z + 1) * step, terrain_resolution - 1)
	var tx: float = 0.0 if x1 == x0 else float(vertex_x - x0) / float(x1 - x0)
	var tz: float = 0.0 if z1 == z0 else float(vertex_z - z0) / float(z1 - z0)

	var i00: int = cell_z * grid_resolution + cell_x
	var i10: int = i00 + 1
	var i01: int = (cell_z + 1) * grid_resolution + cell_x
	var i11: int = i01 + 1

	var top: float = lerpf(values[i00], values[i10], tx)
	var bottom: float = lerpf(values[i01], values[i11], tx)
	return lerpf(top, bottom, tz)


func _get_flatland_mask(world_x: float, world_z: float, continental_raw: float) -> float:
	var patch_value: float = _to_unit(flatland_noise.get_noise_2d(world_x, world_z))
	# Flatlands are less frequent than v0.02's first pass, but when they occur
	# they are deliberately calm enough to be recognizable build locations.
	var patch_mask: float = smoothstep(0.64, 0.86, patch_value)
	var continental_unit: float = _to_unit(continental_raw)
	var lowland_bias: float = 1.0 - smoothstep(0.42, 0.76, continental_unit)
	return clampf(patch_mask * lerpf(0.25, 1.0, lowland_bias), 0.0, 1.0)


func _get_ridge_influence(world_x: float, world_z: float) -> float:
	var ridge_raw: float = ridge_noise.get_noise_2d(world_x, world_z)
	var ridge_line: float = 1.0 - absf(ridge_raw)
	var ridge_shape: float = pow(clampf((ridge_line - 0.50) / 0.50, 0.0, 1.0), 2.0)
	var region_value: float = _to_unit(ridge_region_noise.get_noise_2d(world_x, world_z))
	var region_mask: float = smoothstep(0.46, 0.70, region_value)
	return ridge_shape * region_mask


func _get_valley_influence(world_x: float, world_z: float) -> float:
	var valley_raw: float = valley_noise.get_noise_2d(world_x, world_z)
	var valley_line: float = 1.0 - absf(valley_raw)
	# Narrower than the first pass: valleys can form waterways/depressions
	# without turning huge portions of the biome into equally broad channels.
	return pow(clampf((valley_line - 0.72) / 0.28, 0.0, 1.0), 2.4)


func _get_moisture(world_x: float, world_z: float, height: float) -> float:
	var base_moisture: float = _to_unit(moisture_noise.get_noise_2d(world_x, world_z))
	return _get_moisture_from_pattern(base_moisture, height)


func _get_moisture_from_pattern(base_moisture: float, height: float) -> float:
	var water_bonus: float = 1.0 - smoothstep(
		settings.sea_level + 1.0,
		settings.sea_level + 12.0,
		height
	)
	return clampf(base_moisture * 0.82 + water_bonus * 0.28, 0.0, 1.0)


func _get_rockiness(
	world_x: float,
	world_z: float,
	slope: float,
	ridge_influence: float
) -> float:
	var rock_pattern: float = _to_unit(rock_noise.get_noise_2d(world_x, world_z))
	return _get_rockiness_from_pattern(rock_pattern, slope, ridge_influence)


func _get_rockiness_from_pattern(
	rock_pattern: float,
	slope: float,
	ridge_influence: float
) -> float:
	var exposed_rock: float = smoothstep(0.67, 0.90, rock_pattern)
	var slope_rock: float = smoothstep(0.06, 0.30, slope)
	return clampf(
		slope_rock * 0.72 + ridge_influence * 0.55 + exposed_rock * 0.38,
		0.0,
		1.0
	)


func _get_forest_density(
	world_x: float,
	world_z: float,
	height: float,
	moisture: float,
	rockiness: float,
	slope: float
) -> float:
	var forest_pattern: float = _to_unit(forest_noise.get_noise_2d(world_x, world_z))
	return _get_forest_density_from_pattern(
		forest_pattern,
		height,
		moisture,
		rockiness,
		slope
	)


func _get_forest_density_from_pattern(
	forest_pattern: float,
	height: float,
	moisture: float,
	rockiness: float,
	slope: float
) -> float:
	if height <= settings.sea_level + 0.5:
		return 0.0

	var pattern_mask: float = smoothstep(0.34, 0.74, forest_pattern)
	var slope_penalty: float = smoothstep(0.08, 0.30, slope)
	var shore_penalty: float = 1.0 - smoothstep(
		settings.sea_level + 0.5,
		settings.sea_level + settings.shore_band + 2.0,
		height
	)
	return clampf(
		pattern_mask * (0.42 + moisture * 0.72)
		- rockiness * 0.55
		- slope_penalty * 0.42
		- shore_penalty * 0.35,
		0.0,
		1.0
	)


func _get_buildability(height: float, slope: float, rockiness: float) -> float:
	if height <= settings.sea_level + 1.0:
		return 0.0
	var slope_score: float = 1.0 - smoothstep(0.015, 0.11, slope)
	var rock_score: float = 1.0 - smoothstep(0.35, 0.82, rockiness)
	return clampf(slope_score * rock_score, 0.0, 1.0)


func _get_surface_color(height: float, moisture: float, rockiness: float) -> Color:
	var grass: Color = COLOR_DRY_GRASS.lerp(COLOR_LUSH_GRASS, moisture)
	var rock_blend: float = smoothstep(0.42, 0.82, rockiness)
	var color: Color = grass.lerp(COLOR_ROCK, rock_blend)

	if height < settings.sea_level:
		return color.lerp(COLOR_SUBMERGED, 0.72)

	var shore_factor: float = 1.0 - smoothstep(
		settings.sea_level + 0.15,
		settings.sea_level + settings.shore_band,
		height
	)
	return color.lerp(COLOR_SHORE, shore_factor * 0.82)


func _to_unit(value: float) -> float:
	return value * 0.5 + 0.5
