extends RefCounted

const COLOR_DRY_GRASS := Color(0.37, 0.48, 0.20)
const COLOR_LUSH_GRASS := Color(0.19, 0.42, 0.16)
const COLOR_ROCK := Color(0.39, 0.40, 0.37)
const COLOR_SHORE := Color(0.48, 0.43, 0.28)
const COLOR_SUBMERGED := Color(0.18, 0.28, 0.17)

var settings

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


func configure(world_settings) -> void:
	settings = world_settings

	# Large-scale fields do not need many fractal octaves. Keeping these lean
	# matters because height is sampled thousands of times for every chunk.
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
	# Keep the hot height path mostly inline. The previous helper-heavy version
	# performed fewer noise calls but was slower in GDScript due to call and
	# interpolation overhead.
	var continental_raw: float = continental_noise.get_noise_2d(world_x, world_z)
	var continental_height: float = continental_raw * settings.continental_amplitude

	var patch_value: float = flatland_noise.get_noise_2d(world_x, world_z) * 0.5 + 0.5
	var patch_mask: float = smoothstep(0.58, 0.88, patch_value)
	var continental_unit: float = continental_raw * 0.5 + 0.5
	var lowland_bias: float = 1.0 - smoothstep(0.48, 0.82, continental_unit)
	var flat_mask: float = clampf(
		patch_mask * lerpf(0.45, 1.0, lowland_bias),
		0.0,
		1.0
	)
	var relief_scale: float = 1.0 - flat_mask * settings.flatland_strength

	var rolling_height: float = (
		rolling_noise.get_noise_2d(world_x, world_z)
		* settings.rolling_amplitude
		* relief_scale
	)

	var ridge_raw: float = ridge_noise.get_noise_2d(world_x, world_z)
	var ridge_line: float = 1.0 - absf(ridge_raw)
	var ridge_shape: float = pow(
		clampf((ridge_line - 0.56) / 0.44, 0.0, 1.0),
		2.6
	)
	var ridge_region_value: float = ridge_region_noise.get_noise_2d(world_x, world_z) * 0.5 + 0.5
	var ridge_region_mask: float = smoothstep(0.54, 0.78, ridge_region_value)
	var ridge_influence: float = ridge_shape * ridge_region_mask
	var ridge_height: float = (
		ridge_influence
		* settings.ridge_amplitude
		* (1.0 - flat_mask * 0.76)
	)

	var valley_raw: float = valley_noise.get_noise_2d(world_x, world_z)
	var valley_line: float = 1.0 - absf(valley_raw)
	var valley_influence: float = pow(
		clampf((valley_line - 0.69) / 0.31, 0.0, 1.0),
		2.2
	)
	var valley_depth: float = (
		valley_influence
		* settings.valley_depth
		* (1.0 - flat_mask * 0.42)
	)

	var detail_height: float = (
		detail_noise.get_noise_2d(world_x, world_z)
		* settings.detail_amplitude
		* (1.0 - flat_mask * 0.72)
	)

	return (
		settings.base_height
		+ continental_height
		+ rolling_height
		+ ridge_height
		- valley_depth
		+ detail_height
	)


func get_surface_sample(world_x: float, world_z: float) -> Dictionary:
	var sample_distance: float = settings.chunk_size / float(maxi(settings.vertices_per_side - 1, 1))
	var height: float = get_height(world_x, world_z)
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

	var moisture_pattern: float = moisture_noise.get_noise_2d(world_x, world_z) * 0.5 + 0.5
	var forest_pattern: float = forest_noise.get_noise_2d(world_x, world_z) * 0.5 + 0.5
	var rock_pattern: float = rock_noise.get_noise_2d(world_x, world_z) * 0.5 + 0.5
	var masks: Vector3 = _calculate_environment_masks(
		height,
		slope,
		moisture_pattern,
		forest_pattern,
		rock_pattern
	)
	var moisture: float = masks.x
	var forest_density: float = masks.y
	var rockiness: float = masks.z
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
	collision_heights.resize(vertex_count)
	moisture_values.resize(vertex_count)
	forest_values.resize(vertex_count)
	rockiness_values.resize(vertex_count)
	buildability_values.resize(vertex_count)

	var chunk_world_x: float = float(chunk_coord.x) * settings.chunk_size
	var chunk_world_z: float = float(chunk_coord.y) * settings.chunk_size

	# One padded ring is enough for seamless central-difference normals.
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
			var normal: Vector3 = Vector3(
				left - right,
				2.0 * spacing,
				back - front
			).normalized()
			var slope: float = clampf(1.0 - normal.y, 0.0, 1.0)

			var moisture_pattern: float = moisture_noise.get_noise_2d(world_x, world_z) * 0.5 + 0.5
			var forest_pattern: float = forest_noise.get_noise_2d(world_x, world_z) * 0.5 + 0.5
			var rock_pattern: float = rock_noise.get_noise_2d(world_x, world_z) * 0.5 + 0.5
			var masks: Vector3 = _calculate_environment_masks(
				height,
				slope,
				moisture_pattern,
				forest_pattern,
				rock_pattern
			)
			var moisture: float = masks.x
			var forest_density: float = masks.y
			var rockiness: float = masks.z
			var buildability: float = _get_buildability(height, slope, rockiness)

			vertices[index] = Vector3(local_x, height, local_z)
			normals[index] = normal
			collision_heights[index] = height
			uvs[index] = Vector2(world_x, world_z) * 0.02
			colors[index] = _get_surface_color(height, moisture, rockiness, slope)
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

	var decoration: Dictionary = _generate_decorations(
		chunk_coord,
		resolution,
		spacing,
		collision_heights,
		forest_values,
		rockiness_values,
		buildability_values
	)

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
		"tree_transforms": decoration["tree_transforms"],
		"rock_transforms": decoration["rock_transforms"],
		"resolution": resolution,
		"spacing": spacing,
	}


func _calculate_environment_masks(
	height: float,
	slope: float,
	moisture_pattern: float,
	forest_pattern: float,
	rock_pattern: float
) -> Vector3:
	var water_bonus: float = 1.0 - smoothstep(
		settings.sea_level + 1.0,
		settings.sea_level + 12.0,
		height
	)
	var moisture: float = clampf(
		moisture_pattern * 0.82 + water_bonus * 0.28,
		0.0,
		1.0
	)

	var exposed_rock: float = smoothstep(0.68, 0.92, rock_pattern)
	var slope_rock: float = smoothstep(0.055, 0.28, slope)
	var rockiness: float = clampf(
		slope_rock * 0.78 + exposed_rock * 0.46,
		0.0,
		1.0
	)

	var forest_density: float = 0.0
	if height > settings.sea_level + 0.5:
		var pattern_mask: float = smoothstep(0.28, 0.70, forest_pattern)
		var slope_penalty: float = smoothstep(0.09, 0.31, slope)
		var shore_penalty: float = 1.0 - smoothstep(
			settings.sea_level + 0.5,
			settings.sea_level + settings.shore_band + 2.0,
			height
		)
		forest_density = clampf(
			pattern_mask * (0.48 + moisture * 0.70)
			- rockiness * 0.34
			- slope_penalty * 0.42
			- shore_penalty * 0.42,
			0.0,
			1.0
		)

	return Vector3(moisture, forest_density, rockiness)


func _get_buildability(height: float, slope: float, rockiness: float) -> float:
	if height <= settings.sea_level + 1.0:
		return 0.0
	var slope_score: float = 1.0 - smoothstep(0.015, 0.11, slope)
	var rock_score: float = 1.0 - smoothstep(0.58, 0.96, rockiness)
	return clampf(slope_score * rock_score, 0.0, 1.0)


func _get_surface_color(
	height: float,
	moisture: float,
	rockiness: float,
	slope: float
) -> Color:
	var grass: Color = COLOR_DRY_GRASS.lerp(COLOR_LUSH_GRASS, moisture)

	# Rock potential should mostly create physical rock outcrops. Only steep
	# terrain is strongly painted as exposed stone; flat rock-rich ground gets
	# a subtle tint instead of turning into a giant gray carpet.
	var slope_exposure: float = smoothstep(0.065, 0.23, slope)
	var rock_hint: float = smoothstep(0.78, 0.98, rockiness) * 0.16
	var rock_blend: float = clampf(slope_exposure * 0.88 + rock_hint, 0.0, 0.92)
	var color: Color = grass.lerp(COLOR_ROCK, rock_blend)

	if height < settings.sea_level:
		return color.lerp(COLOR_SUBMERGED, 0.72)

	var shore_factor: float = 1.0 - smoothstep(
		settings.sea_level + 0.15,
		settings.sea_level + settings.shore_band,
		height
	)
	return color.lerp(COLOR_SHORE, shore_factor * 0.82)


func _generate_decorations(
	chunk_coord: Vector2i,
	resolution: int,
	spacing: float,
	height_values: PackedFloat32Array,
	forest_values: PackedFloat32Array,
	rock_values: PackedFloat32Array,
	build_values: PackedFloat32Array
) -> Dictionary:
	var tree_transforms: Array[Transform3D] = []
	var rock_transforms: Array[Transform3D] = []
	var step: int = maxi(settings.decoration_vertex_step, 2)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var mixed_seed: int = settings.world_seed
	mixed_seed ^= chunk_coord.x * 73856093
	mixed_seed ^= chunk_coord.y * 19349663
	rng.seed = mixed_seed

	for base_z in range(0, resolution - 1, step):
		for base_x in range(0, resolution - 1, step):
			var cell_width: int = mini(step, resolution - 1 - base_x)
			var cell_depth: int = mini(step, resolution - 1 - base_z)
			var vertex_x: float = float(base_x) + rng.randf_range(0.18, 0.82) * float(cell_width)
			var vertex_z: float = float(base_z) + rng.randf_range(0.18, 0.82) * float(cell_depth)

			var terrain_height: float = _sample_grid(height_values, resolution, vertex_x, vertex_z)
			var forest_density: float = _sample_grid(forest_values, resolution, vertex_x, vertex_z)
			var rockiness: float = _sample_grid(rock_values, resolution, vertex_x, vertex_z)
			var buildability: float = _sample_grid(build_values, resolution, vertex_x, vertex_z)
			var local_x: float = vertex_x * spacing
			var local_z: float = vertex_z * spacing

			var tree_chance: float = smoothstep(
				settings.tree_threshold,
				0.82,
				forest_density
			) * settings.tree_density
			if rng.randf() < tree_chance:
				var tree_scale: float = rng.randf_range(0.82, 1.32)
				var tree_yaw: float = rng.randf_range(0.0, TAU)
				var tree_basis: Basis = Basis(Vector3.UP, tree_yaw).scaled(
					Vector3.ONE * tree_scale
				)
				var tree_origin: Vector3 = Vector3(
					local_x,
					terrain_height + 2.25 * tree_scale,
					local_z
				)
				tree_transforms.append(Transform3D(tree_basis, tree_origin))

			var rock_chance: float = smoothstep(
				settings.rock_threshold,
				0.96,
				rockiness
			) * settings.rock_density
			# A little extra rock presence in terrain that is otherwise poor for
			# construction makes the mask readable without painting it gray.
			rock_chance += (1.0 - buildability) * 0.05
			if rng.randf() < rock_chance:
				var rock_scale_x: float = rng.randf_range(0.7, 1.8)
				var rock_scale_y: float = rng.randf_range(0.35, 0.95)
				var rock_scale_z: float = rng.randf_range(0.65, 1.65)
				var rock_yaw: float = rng.randf_range(0.0, TAU)
				var rock_basis: Basis = Basis(Vector3.UP, rock_yaw).scaled(
					Vector3(rock_scale_x, rock_scale_y, rock_scale_z)
				)
				var rock_origin: Vector3 = Vector3(
					local_x,
					terrain_height + rock_scale_y * 0.5,
					local_z
				)
				rock_transforms.append(Transform3D(rock_basis, rock_origin))

	return {
		"tree_transforms": tree_transforms,
		"rock_transforms": rock_transforms,
	}


func _sample_grid(
	values: PackedFloat32Array,
	resolution: int,
	vertex_x: float,
	vertex_z: float
) -> float:
	var clamped_x: float = clampf(vertex_x, 0.0, float(resolution - 1))
	var clamped_z: float = clampf(vertex_z, 0.0, float(resolution - 1))
	var x0: int = floori(clamped_x)
	var z0: int = floori(clamped_z)
	var x1: int = mini(x0 + 1, resolution - 1)
	var z1: int = mini(z0 + 1, resolution - 1)
	var tx: float = clamped_x - float(x0)
	var tz: float = clamped_z - float(z0)

	var a: float = lerpf(
		values[z0 * resolution + x0],
		values[z0 * resolution + x1],
		tx
	)
	var b: float = lerpf(
		values[z1 * resolution + x0],
		values[z1 * resolution + x1],
		tx
	)
	return lerpf(a, b, tz)
