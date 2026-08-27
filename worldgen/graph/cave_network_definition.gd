extends RefCounted
class_name UnderworldCaveNetworkDefinition

const Identity := preload("res://worldgen/graph/definition_identity.gd")

var stable_address
var stable_id: String
var owning_region_id: String
var root_node_id: String
var node_ids: Array[String]
var primary_edge_ids: Array[String]
var attached_entrance_ids: Array[String]
var topology_metrics: Dictionary


func _init(
	address,
	owning_region_id_value: String,
	root_node_id_value: String,
	node_ids_value: Array = [],
	primary_edge_ids_value: Array = [],
	attached_entrance_ids_value: Array = [],
	topology_metrics_value: Dictionary = {}
) -> void:
	stable_address = Identity.copy_address(address)
	stable_id = Identity.id_value(stable_address)
	owning_region_id = owning_region_id_value
	root_node_id = root_node_id_value
	node_ids = Identity.copy_string_array(node_ids_value)
	primary_edge_ids = Identity.copy_string_array(primary_edge_ids_value)
	attached_entrance_ids = Identity.copy_string_array(attached_entrance_ids_value)
	topology_metrics = Identity.copy_dictionary(topology_metrics_value)
