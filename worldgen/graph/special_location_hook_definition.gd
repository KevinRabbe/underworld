extends RefCounted
class_name UnderworldSpecialLocationHookDefinition

const Identity := preload("res://worldgen/graph/definition_identity.gd")

var stable_address
var stable_id: String
var owning_region_id: String
var anchor_node_id: String
var anchor_edge_id: String
var free_world_anchor: Vector3
var semantic_category: String
var reserved_bounds: AABB
var profile_blend: Vector3
var generation_metadata: Dictionary


func _init(
	address,
	owning_region_id_value: String,
	anchor_node_id_value: String,
	anchor_edge_id_value: String,
	free_world_anchor_value: Vector3,
	semantic_category_value: String,
	reserved_bounds_value: AABB,
	profile_blend_value: Vector3,
	generation_metadata_value: Dictionary = {}
) -> void:
	stable_address = Identity.copy_address(address)
	stable_id = Identity.id_value(stable_address)
	owning_region_id = owning_region_id_value
	anchor_node_id = anchor_node_id_value
	anchor_edge_id = anchor_edge_id_value
	free_world_anchor = free_world_anchor_value
	semantic_category = semantic_category_value
	reserved_bounds = reserved_bounds_value
	profile_blend = profile_blend_value
	generation_metadata = Identity.copy_dictionary(generation_metadata_value)


func canonical_data() -> Dictionary:
	return {
		"stable_address": stable_address.canonical_text(),
		"stable_id": stable_id,
		"owning_region_id": owning_region_id,
		"anchor_node_id": anchor_node_id,
		"anchor_edge_id": anchor_edge_id,
		"free_world_anchor": free_world_anchor,
		"semantic_category": semantic_category,
		"reserved_bounds": reserved_bounds,
		"profile_blend": profile_blend,
		"generation_metadata": generation_metadata,
	}
