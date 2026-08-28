extends RefCounted
class_name UnderworldLegacyV2SurfaceResolver

const TerrainGeneratorScript := preload("res://worldgen/surface/terrain_generator.gd")
const PickupGeneratorScript := preload("res://worldgen/surface/pickup_generator.gd")
const StableAddressScript := preload("res://worldgen/identity/stable_address.gd")
const StableIdScript := preload("res://worldgen/identity/stable_id.gd")

const LEGACY_TREE_DOMAIN: String = "legacy-v2-tree"
const LEGACY_ROCK_DOMAIN: String = "legacy-v2-rock"
const LEGACY_BRANCH_DOMAIN: String = "legacy-v2-branch"
const LEGACY_STONE_DOMAIN: String = "legacy-v2-loose-stone"

var settings
var _terrain_generator
var _pickup_generator


func configure(world_settings) -> void:
	settings = world_settings
	_terrain_generator = TerrainGeneratorScript.new()
	_terrain_generator.configure(settings)
	_pickup_generator = PickupGeneratorScript.new()
	_pickup_generator.configure(settings)


func build_chunk_index_map(chunk_coord: Vector2i) -> Dictionary:
	if settings == null:
		return {
			"mapping": {},
			"diagnostics": ["Legacy v2 resolver is not configured"],
			"counts": {},
		}

	var data: Dictionary = _terrain_generator.generate_chunk_data(chunk_coord)
	_pickup_generator.add_pickups_to_chunk_data(chunk_coord, data)

	var replay: Dictionary = {}
	replay.merge(_replay_decoration_candidates(chunk_coord, data), true)
	replay.merge(_replay_pickup_candidates(chunk_coord, data), true)

	var diagnostics: Array[String] = []
	_validate_replay_count("tree", data.get("tree_transforms", []), replay.get("tree", []), diagnostics)
	_validate_replay_count("rock", data.get("rock_transforms", []), replay.get("rock", []), diagnostics)
	_validate_replay_count("branch", data.get("branch_transforms", []), replay.get("branch", []), diagnostics)
	_validate_replay_count(
		"loose_stone",
		data.get("loose_stone_transforms", []),
		replay.get("loose_stone", []),
		diagnostics
	)

	var mapping: Dictionary = {}
	for object_type in ["tree", "rock", "branch", "loose_stone"]:
		var stable_ids: Array = replay.get(object_type, [])
		for accepted_index in range(stable_ids.size()):
			var legacy_id: String = _legacy_id(chunk_coord, object_type, accepted_index)
			mapping[legacy_id] = str(stable_ids[accepted_index])

	return {
		"mapping": mapping,
		"diagnostics": diagnostics,
		"counts": {
			"tree": replay.get("tree", []).size(),
			"rock": replay.get("rock", []).size(),
			"branch": replay.get("branch", []).size(),
			"loose_stone": replay.get("loose_stone", []).size(),
		},
	}


func resolve_legacy_id(legacy_id: String) -> Dictionary:
	var parsed: Dictionary = parse_legacy_id(legacy_id)
	if parsed.is_empty():
		return {
			"resolved": false,
			"legacy_id": legacy_id,
			"stable_id": "",
			"reason": "invalid legacy v2 object ID",
		}

	var chunk_coord := Vector2i(int(parsed["chunk_x"]), int(parsed["chunk_z"]))
	var chunk_map: Dictionary = build_chunk_index_map(chunk_coord)
	var mapping: Dictionary = chunk_map["mapping"]
	if not mapping.has(legacy_id):
		return {
			"resolved": false,
			"legacy_id": legacy_id,
			"stable_id": "",
			"reason": "accepted index does not resolve under frozen legacy-v2 generation",
			"diagnostics": chunk_map["diagnostics"],
		}

	return {
		"resolved": true,
		"legacy_id": legacy_id,
		"stable_id": str(mapping[legacy_id]),
		"reason": "",
		"diagnostics": chunk_map["diagnostics"],
	}


static func parse_legacy_id(legacy_id: String) -> Dictionary:
	var parts: PackedStringArray = legacy_id.split(":", false)
	if parts.size() != 4:
		return {}
	if not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[3].is_valid_int():
		return {}

	var object_type: String = parts[2]
	if object_type not in ["tree", "rock", "branch", "loose_stone"]:
		return {}

	var accepted_index: int = int(parts[3])
	if accepted_index < 0:
		return {}

	return {
		"chunk_x": int(parts[0]),
		"chunk_z": int(parts[1]),
		"object_type": object_type,
		"accepted_index": accepted_index,
	}


func _replay_decoration_candidates(chunk_coord: Vector2i, data: Dictionary) -> Dictionary:
	var resolution: int = int(data["resolution"])
	var spacing: float = float(data["spacing"])
	var height_values: PackedFloat32Array = data["collision_heights"]
	var forest_values: PackedFloat32Array = data["forest_density"]
	var rock_values: PackedFloat32Array = data["rockiness"]
	var build_values: PackedFloat32Array = data["buildability"]
	var step: int = maxi(settings.decoration_vertex_step, 2)

	var trees: Array[String] = []
	var rocks: Array[String] = []

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

			var _terrain_height: float = _sample_grid(height_values, resolution, vertex_x, vertex_z)
			var forest_density: float = _sample_grid(forest_values, resolution, vertex_x, vertex_z)
			var rockiness: float = _sample_grid(rock_values, resolution, vertex_x, vertex_z)
			var buildability: float = _sample_grid(build_values, resolution, vertex_x, vertex_z)
			var _local_x: float = vertex_x * spacing
			var _local_z: float = vertex_z * spacing
			var global_cell: Vector2i = _global_vertex_cell(chunk_coord, resolution, base_x, base_z)

			var tree_chance: float = smoothstep(
				settings.tree_threshold,
				0.82,
				forest_density
			) * settings.tree_density
			if rng.randf() < tree_chance:
				# Consume the exact legacy shape calls so later candidates receive the
				# same RandomNumberGenerator state as prototype v2.
				rng.randf_range(0.82, 1.32)
				rng.randf_range(0.0, TAU)
				trees.append(_candidate_id(LEGACY_TREE_DOMAIN, global_cell))

			var rock_chance: float = smoothstep(
				settings.rock_threshold,
				0.96,
				rockiness
			) * settings.rock_density
			rock_chance += (1.0 - buildability) * 0.05
			if rng.randf() < rock_chance:
				rng.randf_range(0.7, 1.8)
				rng.randf_range(0.35, 0.95)
				rng.randf_range(0.65, 1.65)
				rng.randf_range(0.0, TAU)
				rocks.append(_candidate_id(LEGACY_ROCK_DOMAIN, global_cell))

	return {
		"tree": trees,
		"rock": rocks,
	}


func _replay_pickup_candidates(chunk_coord: Vector2i, data: Dictionary) -> Dictionary:
	var resolution: int = int(data["resolution"])
	var spacing: float = float(data["spacing"])
	var heights: PackedFloat32Array = data["collision_heights"]
	var forest_values: PackedFloat32Array = data["forest_density"]
	var rock_values: PackedFloat32Array = data["rockiness"]
	var build_values: PackedFloat32Array = data["buildability"]
	var step: int = maxi(settings.pickup_vertex_step, 2)

	var branches: Array[String] = []
	var stones: Array[String] = []

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
			var _local_x: float = vertex_x * spacing
			var _local_z: float = vertex_z * spacing
			var shore_factor: float = 1.0 - smoothstep(
				settings.sea_level + 0.8,
				settings.sea_level + 5.5,
				terrain_height
			)
			var global_cell: Vector2i = _global_vertex_cell(chunk_coord, resolution, base_x, base_z)

			var branch_chance: float = settings.branch_pickup_density * (
				0.55 + forest_density * 0.55 + buildability * 0.15
			)
			if rng.randf() < branch_chance:
				rng.randf_range(0.75, 1.35)
				rng.randf_range(0.0, TAU)
				rng.randf_range(0.09, 0.14)
				rng.randf_range(0.09, 0.14)
				branches.append(_candidate_id(LEGACY_BRANCH_DOMAIN, global_cell))

			var stone_chance: float = settings.loose_stone_pickup_density * (
				0.48 + rockiness * 0.85 + shore_factor * 0.55
			)
			if rng.randf() < stone_chance:
				rng.randf_range(0.30, 0.62)
				rng.randf_range(0.20, 0.42)
				rng.randf_range(0.28, 0.58)
				rng.randf_range(0.0, TAU)
				stones.append(_candidate_id(LEGACY_STONE_DOMAIN, global_cell))

	return {
		"branch": branches,
		"loose_stone": stones,
	}


static func _global_vertex_cell(
	chunk_coord: Vector2i,
	resolution: int,
	base_x: int,
	base_z: int
) -> Vector2i:
	var intervals_per_chunk: int = resolution - 1
	return Vector2i(
		chunk_coord.x * intervals_per_chunk + base_x,
		chunk_coord.y * intervals_per_chunk + base_z
	)


static func _candidate_id(candidate_domain: String, global_cell: Vector2i) -> String:
	var address = StableAddressScript.surface_candidate(
		candidate_domain,
		global_cell.x,
		global_cell.y,
		"0"
	)
	var stable_id = StableIdScript.from_address(address)
	return stable_id.value()


static func _legacy_id(chunk_coord: Vector2i, object_type: String, accepted_index: int) -> String:
	return "%d:%d:%s:%d" % [chunk_coord.x, chunk_coord.y, object_type, accepted_index]


static func _validate_replay_count(
	object_type: String,
	actual_transforms: Array,
	replayed_ids: Array,
	diagnostics: Array[String]
) -> void:
	if actual_transforms.size() != replayed_ids.size():
		diagnostics.append(
			"legacy-v2 replay mismatch for %s: runtime=%d replay=%d" % [
				object_type,
				actual_transforms.size(),
				replayed_ids.size(),
			]
		)


static func _sample_grid(
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
