extends RefCounted
class_name UnderworldMacroRegionPlan

const Identity := preload("res://worldgen/graph/definition_identity.gd")

var stable_address
var stable_id: String
var region_coord: Vector2i
var world_anchor: Vector3
var world_bounds: AABB
var surface_reference_y: float
var profile_bias: Vector3
var topology_tendencies: Dictionary
var network_candidate_slots: Array[int]
var special_candidate_slots: Array[int]


func _init(
	address,
	region_coord_value: Vector2i,
	world_anchor_value: Vector3,
	world_bounds_value: AABB,
	surface_reference_y_value: float,
	profile_bias_value: Vector3,
	topology_tendencies_value: Dictionary,
	network_candidate_slots_value: Array[int],
	special_candidate_slots_value: Array[int]
) -> void:
	stable_address = Identity.copy_address(address)
	stable_id = Identity.id_value(stable_address)
	region_coord = region_coord_value
	world_anchor = world_anchor_value
	world_bounds = world_bounds_value
	surface_reference_y = surface_reference_y_value
	profile_bias = profile_bias_value
	topology_tendencies = Identity.copy_dictionary(topology_tendencies_value)
	network_candidate_slots = network_candidate_slots_value.duplicate()
	special_candidate_slots = special_candidate_slots_value.duplicate()


func canonical_data() -> Dictionary:
	return {
		"stable_address": stable_address.canonical_text(),
		"stable_id": stable_id,
		"region_coord": region_coord,
		"world_anchor": world_anchor,
		"world_bounds": world_bounds,
		"surface_reference_y": surface_reference_y,
		"profile_bias": profile_bias,
		"topology_tendencies": topology_tendencies,
		"network_candidate_slots": network_candidate_slots,
		"special_candidate_slots": special_candidate_slots,
	}
