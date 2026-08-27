extends RefCounted
class_name UnderworldDeterministicSurfaceSampler

const WorldSettings := preload("res://data/world_settings.gd")
const TerrainGenerator := preload("res://world/terrain_generator.gd")
const SurfaceSample := preload("res://worldgen/surface/deterministic_surface_sample.gd")

var world_seed: int
var _settings
var _terrain


func _init(seed_value: int) -> void:
	world_seed = seed_value
	_settings = WorldSettings.new()
	_settings.world_seed = world_seed
	_terrain = TerrainGenerator.new()
	_terrain.configure(_settings)


func sample(world_x: float, world_z: float):
	var values: Dictionary = _terrain.get_surface_sample(world_x, world_z)
	var spacing: float = _settings.chunk_size / float(maxi(_settings.vertices_per_side - 1, 1))
	var left: float = _terrain.get_height(world_x - spacing, world_z)
	var right: float = _terrain.get_height(world_x + spacing, world_z)
	var back: float = _terrain.get_height(world_x, world_z - spacing)
	var front: float = _terrain.get_height(world_x, world_z + spacing)
	var normal := Vector3(left - right, 2.0 * spacing, back - front).normalized()
	values["sea_level"] = _settings.sea_level
	return SurfaceSample.new(
		Vector3(world_x, float(values["height"]), world_z),
		normal,
		values
	)
