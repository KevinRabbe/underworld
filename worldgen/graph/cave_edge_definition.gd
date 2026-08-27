extends RefCounted
class_name UnderworldCaveEdgeDefinition

const Identity := preload("res://worldgen/graph/definition_identity.gd")

var stable_address
var stable_id: String
var endpoint_a_node_id: String
var endpoint_b_node_id: String
var owning_region_id: String
var connection_class: String
var topology_parameters: Dictionary
var geometry_tendencies: Dictionary
var tags: Array[String]


func _init(
	address,
	endpoint_a_node_id_value: String,
	endpoint_b_node_id_value: String,
	owning_region_id_value: String,
	connection_class_value: String,
	topology_parameters_value: Dictionary = {},
	geometry_tendencies_value: Dictionary = {},
	tags_value: Array = [],
	undirected: bool = true
) -> void:
	stable_address = Identity.copy_address(address)
	stable_id = Identity.id_value(stable_address)

	if undirected and endpoint_b_node_id_value < endpoint_a_node_id_value:
		endpoint_a_node_id = endpoint_b_node_id_value
		endpoint_b_node_id = endpoint_a_node_id_value
	else:
		endpoint_a_node_id = endpoint_a_node_id_value
		endpoint_b_node_id = endpoint_b_node_id_value

	owning_region_id = owning_region_id_value
	connection_class = connection_class_value
	topology_parameters = Identity.copy_dictionary(topology_parameters_value)
	geometry_tendencies = Identity.copy_dictionary(geometry_tendencies_value)
	tags = Identity.copy_string_array(tags_value)
