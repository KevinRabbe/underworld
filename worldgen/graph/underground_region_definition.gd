extends RefCounted
class_name UnderworldUndergroundRegionDefinition

const Identity := preload("res://worldgen/graph/definition_identity.gd")

var stable_address
var stable_id: String
var region_coord: Vector2i
var world_anchor: Vector3
var world_bounds: AABB
var profile_bias: Vector3
var network_ids: Array[String]
var entrance_ids: Array[String]
var secondary_edge_ids: Array[String]
var special_location_hook_ids: Array[String]
var topology_metrics: Dictionary


func _init(
	address,
	region_coord_value: Vector2i,
	world_anchor_value: Vector3,
	world_bounds_value: AABB,
	profile_bias_value: Vector3 = Vector3(1.0, 0.0, 0.0),
	network_ids_value: Array = [],
	entrance_ids_value: Array = [],
	secondary_edge_ids_value: Array = [],
	special_location_hook_ids_value: Array = [],
	topology_metrics_value: Dictionary = {}
) -> void:
	stable_address = Identity.copy_address(address)
	stable_id = Identity.id_value(stable_address)
	region_coord = region_coord_value
	world_anchor = world_anchor_value
	world_bounds = world_bounds_value
	profile_bias = profile_bias_value
	network_ids = Identity.copy_string_array(network_ids_value)
	entrance_ids = Identity.copy_string_array(entrance_ids_value)
	secondary_edge_ids = Identity.copy_string_array(secondary_edge_ids_value)
	special_location_hook_ids = Identity.copy_string_array(special_location_hook_ids_value)
	topology_metrics = Identity.copy_dictionary(topology_metrics_value)
