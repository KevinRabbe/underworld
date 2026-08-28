extends RefCounted
class_name UnderworldTunnelGeometryDescriptor

const Identity := preload("res://worldgen/graph/definition_identity.gd")

var stable_address
var stable_id: String
var source_edge_id: String
var owning_region_id: String
var endpoint_a_node_id: String
var endpoint_b_node_id: String
var connection_class: String
var control_points: Array
var width: float
var height: float
var clearance_margin: float
var roughness: float
var path_style: String
var slope_class: String
var profile_blend: Vector3
var tags: Array[String]


func _init(
	address,
	source_edge_id_value: String,
	owning_region_id_value: String,
	endpoint_a_node_id_value: String,
	endpoint_b_node_id_value: String,
	connection_class_value: String,
	control_points_value: Array,
	width_value: float,
	height_value: float,
	clearance_margin_value: float,
	roughness_value: float,
	path_style_value: String,
	slope_class_value: String,
	profile_blend_value: Vector3,
	tags_value: Array = []
) -> void:
	stable_address = Identity.copy_address(address)
	stable_id = Identity.id_value(stable_address)
	source_edge_id = source_edge_id_value
	owning_region_id = owning_region_id_value
	endpoint_a_node_id = endpoint_a_node_id_value
	endpoint_b_node_id = endpoint_b_node_id_value
	connection_class = connection_class_value
	control_points = control_points_value.duplicate()
	width = width_value
	height = height_value
	clearance_margin = clearance_margin_value
	roughness = roughness_value
	path_style = path_style_value
	slope_class = slope_class_value
	profile_blend = profile_blend_value
	tags = Identity.copy_string_array(tags_value)


func canonical_data() -> Dictionary:
	return {
		"stable_address": stable_address.canonical_text(),
		"stable_id": stable_id,
		"source_edge_id": source_edge_id,
		"owning_region_id": owning_region_id,
		"endpoint_a_node_id": endpoint_a_node_id,
		"endpoint_b_node_id": endpoint_b_node_id,
		"connection_class": connection_class,
		"control_points": control_points,
		"width": width,
		"height": height,
		"clearance_margin": clearance_margin,
		"roughness": roughness,
		"path_style": path_style,
		"slope_class": slope_class,
		"profile_blend": profile_blend,
		"tags": tags,
	}
