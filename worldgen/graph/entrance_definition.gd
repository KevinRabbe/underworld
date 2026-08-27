extends RefCounted
class_name UnderworldEntranceDefinition

const Identity := preload("res://worldgen/graph/definition_identity.gd")

var stable_address
var stable_id: String
var owning_region_id: String
var connected_network_id: String
var connected_node_id: String
var surface_world_position: Vector3
var underground_connection_position: Vector3
var entrance_kind: String
var descent_profile: String
var surface_integration_parameters: Dictionary
var generation_metadata: Dictionary


func _init(
	address,
	owning_region_id_value: String,
	connected_network_id_value: String,
	connected_node_id_value: String,
	surface_world_position_value: Vector3,
	underground_connection_position_value: Vector3,
	entrance_kind_value: String,
	descent_profile_value: String,
	surface_integration_parameters_value: Dictionary = {},
	generation_metadata_value: Dictionary = {}
) -> void:
	stable_address = Identity.copy_address(address)
	stable_id = Identity.id_value(stable_address)
	owning_region_id = owning_region_id_value
	connected_network_id = connected_network_id_value
	connected_node_id = connected_node_id_value
	surface_world_position = surface_world_position_value
	underground_connection_position = underground_connection_position_value
	entrance_kind = entrance_kind_value
	descent_profile = descent_profile_value
	surface_integration_parameters = Identity.copy_dictionary(surface_integration_parameters_value)
	generation_metadata = Identity.copy_dictionary(generation_metadata_value)
