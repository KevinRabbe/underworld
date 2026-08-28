extends RefCounted
class_name UnderworldSurfaceEntranceChunkPlan

const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")
const Descriptor := preload("res://worldgen/graph/surface_entrance_integration_descriptor.gd")
const CellAddress := preload("res://worldgen/geometry/geometry_cell_address.gd")
const SCRIPT_PATH: String = "res://worldgen/surface/surface_entrance_chunk_plan.gd"
const Data := preload("res://worldgen/surface/surface_entrance_chunk_plan_data.gd")
const Demand := preload("res://worldgen/surface/entrance_runtime_demand.gd")

var chunk_bounds: AABB
var entrance_ids: Array[String]
var opening_mask: Array[bool]
var omitted_triangle_indices: PackedInt32Array
var collision_hole_indices: Array[int]
var rim_bounds: AABB
var underground_cells: Array
var demand_handoffs: Array
var fingerprint: String


static func build(chunk_bounds_value: AABB, descriptors: Array, grid_size: Vector2i = Vector2i(16, 16), source_provenance: String = ""):
	var failures: Array[String] = []
	if chunk_bounds_value.size.x <= 0.0 or chunk_bounds_value.size.z <= 0.0:
		failures.append("Surface chunk bounds must have positive X/Z size")
	if grid_size.x <= 0 or grid_size.y <= 0:
		failures.append("Surface entrance grid dimensions must be positive")
	for descriptor in descriptors:
		if descriptor == null or not (descriptor is Descriptor):
			failures.append("Surface entrance query contains an invalid descriptor")
	if not failures.is_empty():
		return {"success": false, "diagnostics": failures}
	var sorted: Array = descriptors.duplicate()
	sorted.sort_custom(func(a, b): return str(a.entrance_id) < str(b.entrance_id))
	var plan = load("res://worldgen/surface/surface_entrance_chunk_plan_data.gd").new()
	plan.chunk_bounds = chunk_bounds_value
	plan.entrance_ids = []
	plan.opening_mask = []
	plan.collision_hole_indices = []
	plan.omitted_triangle_indices = PackedInt32Array()
	plan.underground_cells = []
	plan.demand_handoffs = []
	var has_rim := false
	for descriptor in sorted:
		if not descriptor.overlaps_world_bounds(chunk_bounds_value):
			continue
		plan.entrance_ids.append(descriptor.entrance_id)
		var opening: AABB = descriptor.required_opening_bounds.grow(descriptor.clearance_radius)
		plan.rim_bounds = opening if not has_rim else plan.rim_bounds.merge(opening)
		has_rim = true
		var coordinate := Vector3i(
			floori(descriptor.underground_anchor.x / 32.0),
			floori(descriptor.underground_anchor.y / 32.0),
			floori(descriptor.underground_anchor.z / 32.0)
		)
		plan.underground_cells.append(CellAddress.new(coordinate))
		plan.demand_handoffs.append(Demand.new(descriptor.entrance_id, [CellAddress.new(coordinate)], source_provenance))
	var vertex_count := (grid_size.x + 1) * (grid_size.y + 1)
	plan.opening_mask.resize(vertex_count)
	for row in range(grid_size.y + 1):
		for column in range(grid_size.x + 1):
			var x := chunk_bounds_value.position.x + chunk_bounds_value.size.x * float(column) / float(grid_size.x)
			var z := chunk_bounds_value.position.z + chunk_bounds_value.size.z * float(row) / float(grid_size.y)
			var open := false
			for descriptor in sorted:
				var opening: AABB = descriptor.required_opening_bounds.grow(descriptor.clearance_radius)
				if _contains_xz(opening, x, z):
					open = true
					break
			plan.opening_mask[row * (grid_size.x + 1) + column] = open
			if open:
				plan.collision_hole_indices.append(row * (grid_size.x + 1) + column)
	for row in range(grid_size.y):
		for column in range(grid_size.x):
			var base := row * (grid_size.x + 1) + column
			var triangle := row * grid_size.x + column
			if plan.opening_mask[base] or plan.opening_mask[base + 1] or plan.opening_mask[base + grid_size.x + 1] or plan.opening_mask[base + grid_size.x + 2]:
				plan.omitted_triangle_indices.append_array(PackedInt32Array([triangle * 6, triangle * 6 + 1, triangle * 6 + 2, triangle * 6 + 3, triangle * 6 + 4, triangle * 6 + 5]))
	plan.entrance_ids.sort()
	plan.collision_hole_indices.sort()
	plan.underground_cells.sort_custom(func(a, b): return a.canonical_text() < b.canonical_text())
	plan.demand_handoffs.sort_custom(func(a, b): return str(a.entrance_id) < str(b.entrance_id))
	plan.finalize_fingerprint()
	return {"success": true, "data": plan, "fingerprint": plan.fingerprint, "diagnostics": []}


static func _contains_xz(bounds: AABB, x: float, z: float) -> bool:
	return x >= bounds.position.x and x <= bounds.position.x + bounds.size.x \
		and z >= bounds.position.z and z <= bounds.position.z + bounds.size.z
