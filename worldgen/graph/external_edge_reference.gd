extends RefCounted
class_name UnderworldExternalEdgeReference

const Identity := preload("res://worldgen/graph/definition_identity.gd")

var edge_stable_address
var edge_stable_id: String
var owner_region_id: String
var local_region_id: String
var remote_region_id: String
var local_endpoint_node_id: String
var remote_endpoint_node_id: String
var connection_class: String


func _init(
	edge_address,
	owner_region_id_value: String,
	local_region_id_value: String,
	remote_region_id_value: String,
	local_endpoint_node_id_value: String,
	remote_endpoint_node_id_value: String,
	connection_class_value: String
) -> void:
	edge_stable_address = Identity.copy_address(edge_address)
	edge_stable_id = Identity.id_value(edge_stable_address)
	owner_region_id = owner_region_id_value
	local_region_id = local_region_id_value
	remote_region_id = remote_region_id_value
	local_endpoint_node_id = local_endpoint_node_id_value
	remote_endpoint_node_id = remote_endpoint_node_id_value
	connection_class = connection_class_value


func canonical_data() -> Dictionary:
	return {
		"edge_stable_address": (
			edge_stable_address.canonical_text()
			if edge_stable_address != null
			else ""
		),
		"edge_stable_id": edge_stable_id,
		"owner_region_id": owner_region_id,
		"local_region_id": local_region_id,
		"remote_region_id": remote_region_id,
		"local_endpoint_node_id": local_endpoint_node_id,
		"remote_endpoint_node_id": remote_endpoint_node_id,
		"connection_class": connection_class,
	}
