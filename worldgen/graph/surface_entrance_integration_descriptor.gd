extends RefCounted
class_name UnderworldSurfaceEntranceIntegrationDescriptor

var entrance_id: String
var owning_region_id: String
var surface_world_position: Vector3
var orientation: Vector3
var required_opening_bounds: AABB
var clearance_radius: float
var connected_network_id: String
var connected_node_id: String
var underground_anchor: Vector3
var descent_profile: String


func _init(
	entrance_id_value: String,
	owner_region_id_value: String,
	surface_position_value: Vector3,
	orientation_value: Vector3,
	opening_bounds_value: AABB,
	clearance_radius_value: float,
	connected_network_id_value: String,
	connected_node_id_value: String,
	underground_anchor_value: Vector3,
	descent_profile_value: String
) -> void:
	entrance_id = entrance_id_value
	owning_region_id = owner_region_id_value
	surface_world_position = surface_position_value
	orientation = orientation_value
	required_opening_bounds = opening_bounds_value
	clearance_radius = clearance_radius_value
	connected_network_id = connected_network_id_value
	connected_node_id = connected_node_id_value
	underground_anchor = underground_anchor_value
	descent_profile = descent_profile_value


func overlaps_world_bounds(bounds: AABB) -> bool:
	return required_opening_bounds.intersects(bounds)


func canonical_data() -> Dictionary:
	return {
		"entrance_id": entrance_id,
		"owning_region_id": owning_region_id,
		"surface_world_position": surface_world_position,
		"orientation": orientation,
		"required_opening_bounds": required_opening_bounds,
		"clearance_radius": clearance_radius,
		"connected_network_id": connected_network_id,
		"connected_node_id": connected_node_id,
		"underground_anchor": underground_anchor,
		"descent_profile": descent_profile,
	}
