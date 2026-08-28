extends RefCounted
class_name UnderworldChamberGeometryDescriptor

const Identity := preload("res://worldgen/graph/definition_identity.gd")

var stable_address
var stable_id: String
var source_node_id: String
var owning_region_id: String
var owning_network_id: String
var center: Vector3
var dimensions: Vector3
var rotation_y: float
var shape_family: String
var floor_bias: float
var ceiling_arch: float
var wall_roughness: float
var asymmetry: Vector3
var profile_blend: Vector3
var semantic_type: String
var tags: Array[String]


func _init(
	address,
	source_node_id_value: String,
	owning_region_id_value: String,
	owning_network_id_value: String,
	center_value: Vector3,
	dimensions_value: Vector3,
	rotation_y_value: float,
	shape_family_value: String,
	floor_bias_value: float,
	ceiling_arch_value: float,
	wall_roughness_value: float,
	asymmetry_value: Vector3,
	profile_blend_value: Vector3,
	semantic_type_value: String,
	tags_value: Array = []
) -> void:
	stable_address = Identity.copy_address(address)
	stable_id = Identity.id_value(stable_address)
	source_node_id = source_node_id_value
	owning_region_id = owning_region_id_value
	owning_network_id = owning_network_id_value
	center = center_value
	dimensions = dimensions_value
	rotation_y = rotation_y_value
	shape_family = shape_family_value
	floor_bias = floor_bias_value
	ceiling_arch = ceiling_arch_value
	wall_roughness = wall_roughness_value
	asymmetry = asymmetry_value
	profile_blend = profile_blend_value
	semantic_type = semantic_type_value
	tags = Identity.copy_string_array(tags_value)


func canonical_data() -> Dictionary:
	return {
		"stable_address": stable_address.canonical_text(),
		"stable_id": stable_id,
		"source_node_id": source_node_id,
		"owning_region_id": owning_region_id,
		"owning_network_id": owning_network_id,
		"center": center,
		"dimensions": dimensions,
		"rotation_y": rotation_y,
		"shape_family": shape_family,
		"floor_bias": floor_bias,
		"ceiling_arch": ceiling_arch,
		"wall_roughness": wall_roughness,
		"asymmetry": asymmetry,
		"profile_blend": profile_blend,
		"semantic_type": semantic_type,
		"tags": tags,
	}
