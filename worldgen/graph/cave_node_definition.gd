extends RefCounted
class_name UnderworldCaveNodeDefinition

const Identity := preload("res://worldgen/graph/definition_identity.gd")

var stable_address
var stable_id: String
var owning_network_id: String
var world_position: Vector3
var approximate_shape: String
var approximate_size: Vector3
var profile_blend: Vector3
var semantic_type: String
var tags: Array[String]
var generation_metadata: Dictionary


func _init(
	address,
	owning_network_id_value: String,
	world_position_value: Vector3,
	approximate_shape_value: String,
	approximate_size_value: Vector3,
	profile_blend_value: Vector3,
	semantic_type_value: String,
	tags_value: Array = [],
	generation_metadata_value: Dictionary = {}
) -> void:
	stable_address = Identity.copy_address(address)
	stable_id = Identity.id_value(stable_address)
	owning_network_id = owning_network_id_value
	world_position = world_position_value
	approximate_shape = approximate_shape_value
	approximate_size = approximate_size_value
	profile_blend = profile_blend_value
	semantic_type = semantic_type_value
	tags = Identity.copy_string_array(tags_value)
	generation_metadata = Identity.copy_dictionary(generation_metadata_value)
