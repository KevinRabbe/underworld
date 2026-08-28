extends RefCounted
class_name UnderworldSurfaceEntranceQuery

const Descriptor := preload("res://worldgen/graph/surface_entrance_integration_descriptor.gd")

static func query(definition_service, world_bounds: AABB) -> Dictionary:
	if definition_service == null or not definition_service.has_method("query_surface_entrances"):
		return {"success": false, "diagnostics": ["WorldDefinitionService query boundary is required"]}
	var descriptors: Array = definition_service.query_surface_entrances(world_bounds)
	for descriptor in descriptors:
		if not (descriptor is Descriptor):
			return {"success": false, "diagnostics": ["Definition service returned an invalid entrance descriptor"]}
	descriptors.sort_custom(func(a, b): return str(a.entrance_id) < str(b.entrance_id))
	return {"success": true, "descriptors": descriptors, "diagnostics": []}
