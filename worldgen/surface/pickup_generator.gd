extends RefCounted

const StableAddressScript := preload("res://worldgen/identity/stable_address.gd")
const StableIdScript := preload("res://worldgen/identity/stable_id.gd")

var settings


func configure(world_settings) -> void:
	settings = world_settings


func add_pickups_to_chunk_data(chunk_coord: Vector2i, data: Dictionary) -> void:
	var resolution: int = int(data["resolution"])
	var spacing: float = float(data["spacing"])
	var heights: PackedFloat32Array = data["collision_heights"]
	var forest_values: PackedFloat32Array = data["forest_density"]
	var rock_values: PackedFloat32Array = data["rockiness"]
	var build_values: PackedFloat32Array = data["buildability"]

	var branch_transforms: Array[Transform3D] = []
	var branch_stable_ids: Array[String] = []
	var loose_stone_transforms: Array[Transform3D] = []
	var loose_stone_stable_ids: Array[String] = []
	var step: int = maxi(settings.pickup_vertex_step, 2)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var mixed_seed: int = settings.world_seed ^ 0x5A17C3
	mixed_seed ^= chunk_coord.x * 83492791
	mixed_seed ^= chunk_coord.y * 297121507
	rng.seed = mixed_seed

	for base_z in range(0, resolution - 1, step):
		for base_x in range(0, resolution - 1, step):
			var cell_width: int = mini(step, resolution - 1 - base_x)
			var cell_depth: int = mini(step, resolution - 1 - base_z)
			var vertex_x: float = float(base_x) + rng.randf_range(0.12, 0.88) * float(cell_width)
			var vertex_z: float = float(base_z) + rng.randf_range(0.12, 0.88) * float(cell_depth)

			var terrain_height: float = _sample_grid(heights, resolution, vertex_x, vertex_z)
			if terrain_height <= settings.sea_level + 0.35:
				continue

			var forest_density: float = _sample_grid(forest_values, resolution, vertex_x, vertex_z)
			var rockiness: float = _sample_grid(rock_values, resolution, vertex_x, vertex_z)
			var buildability: float = _sample_grid(build_values, resolution, vertex_x, vertex_z)
			var local_x: float = vertex_x * spacing
			var local_z: float = vertex_z * spacing
			var shore_factor: float = 1.0 - smoothstep(
				settings.sea_level + 0.8,
				settings.sea_level + 5.5,
				terrain_height
			)

			# Branches are common enough on ordinary dry ground that a fresh player
			# can bootstrap without needing to find a dense forest first.
			var branch_chance: float = settings.branch_pickup_density * (
				0.55 + forest_density * 0.55 + buildability * 0.15
			)
			if rng.randf() < branch_chance:
				var branch_length: float = rng.randf_range(0.75, 1.35)
				var branch_yaw: float = rng.randf_range(0.0, TAU)
				var branch_basis: Basis = Basis(Vector3.UP, branch_yaw).scaled(
					Vector3(branch_length, rng.randf_range(0.09, 0.14), rng.randf_range(0.09, 0.14))
				)
				branch_transforms.append(Transform3D(
					branch_basis,
					Vector3(local_x, terrain_height + 0.09, local_z)
				))
				branch_stable_ids.append(_candidate_stable_id(
					"branch", chunk_coord, resolution, base_x, base_z
				))

			# Loose stones favor shorelines and rocky ground, but retain a baseline
			# chance in clearings so the starting loop cannot dead-end on one seed.
			var stone_chance: float = settings.loose_stone_pickup_density * (
				0.48 + rockiness * 0.85 + shore_factor * 0.55
			)
			if rng.randf() < stone_chance:
				var sx: float = rng.randf_range(0.30, 0.62)
				var sy: float = rng.randf_range(0.20, 0.42)
				var sz: float = rng.randf_range(0.28, 0.58)
				var stone_yaw: float = rng.randf_range(0.0, TAU)
				var stone_basis: Basis = Basis(Vector3.UP, stone_yaw).scaled(Vector3(sx, sy, sz))
				loose_stone_transforms.append(Transform3D(
					stone_basis,
					Vector3(local_x, terrain_height + sy * 0.5, local_z)
				))
				loose_stone_stable_ids.append(_candidate_stable_id(
					"loose-stone", chunk_coord, resolution, base_x, base_z
				))

	data["branch_transforms"] = branch_transforms
	data["branch_stable_ids"] = branch_stable_ids
	data["loose_stone_transforms"] = loose_stone_transforms
	data["loose_stone_stable_ids"] = loose_stone_stable_ids


func _candidate_stable_id(
	domain: String,
	chunk_coord: Vector2i,
	resolution: int,
	base_x: int,
	base_z: int
) -> String:
	var candidate_span: int = resolution - 1
	var global_cell_x: int = chunk_coord.x * candidate_span + base_x
	var global_cell_z: int = chunk_coord.y * candidate_span + base_z
	var address = StableAddressScript.surface_candidate(
		domain,
		global_cell_x,
		global_cell_z,
		"0"
	)
	return StableIdScript.from_address(address).value()


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
