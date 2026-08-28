extends RefCounted
class_name UnderworldDeterministicSurfaceSample

var world_position: Vector3
var normal: Vector3
var slope: float
var moisture: float
var forest_density: float
var rockiness: float
var buildability: float
var sea_level: float


func _init(position_value: Vector3, normal_value: Vector3, values: Dictionary) -> void:
	world_position = position_value
	normal = normal_value
	slope = float(values.get("slope", 0.0))
	moisture = float(values.get("moisture", 0.0))
	forest_density = float(values.get("forest_density", 0.0))
	rockiness = float(values.get("rockiness", 0.0))
	buildability = float(values.get("buildability", 0.0))
	sea_level = float(values.get("sea_level", 0.0))


func is_submerged() -> bool:
	return world_position.y < sea_level


func canonical_data() -> Dictionary:
	return {
		"world_position": world_position,
		"normal": normal,
		"slope": slope,
		"moisture": moisture,
		"forest_density": forest_density,
		"rockiness": rockiness,
		"buildability": buildability,
		"sea_level": sea_level,
	}
