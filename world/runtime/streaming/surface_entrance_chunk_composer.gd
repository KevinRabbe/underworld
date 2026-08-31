extends RefCounted
class_name UnderworldSurfaceEntranceChunkComposer

const SurfaceEntranceChunkPlan := preload("res://worldgen/surface/surface_entrance_chunk_plan.gd")
const SurfaceEntranceDescriptor := preload("res://worldgen/graph/surface_entrance_integration_descriptor.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")

const TREE_VISUAL_RADIUS := 1.25


static func validate_route(route: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if route.is_empty():
		return failures
	var entrance_id: String = str(route.get("entrance_id", ""))
	if entrance_id.is_empty() or StableId.parse(entrance_id) == null:
		failures.append("surface entrance route requires canonical entrance StableId")
	var owner_id: String = str(route.get("owning_region_id", ""))
	if owner_id.is_empty():
		failures.append("surface entrance route requires owning region identity")
	var surface_variant: Variant = route.get("surface_world_position", null)
	if not surface_variant is Vector3 or not _finite_vector3(surface_variant):
		failures.append("surface entrance route requires finite surface position")
	var orientation_variant: Variant = route.get("orientation", null)
	if not orientation_variant is Vector3 or not _finite_vector3(orientation_variant):
		failures.append("surface entrance route requires finite orientation")
	var bounds_variant: Variant = route.get("required_opening_bounds", null)
	if not bounds_variant is AABB:
		failures.append("surface entrance route requires opening AABB")
	else:
		var bounds: AABB = bounds_variant
		if not _finite_vector3(bounds.position) or not _finite_vector3(bounds.size):
			failures.append("surface entrance opening bounds must be finite")
		elif bounds.size.x <= 0.0 or bounds.size.z <= 0.0:
			failures.append("surface entrance opening bounds require positive X/Z size")
	var clearance_variant: Variant = route.get("clearance_radius", null)
	if typeof(clearance_variant) != TYPE_FLOAT and typeof(clearance_variant) != TYPE_INT:
		failures.append("surface entrance route requires numeric clearance radius")
	else:
		var clearance: float = float(clearance_variant)
		if not _finite_float(clearance) or clearance < 0.0:
			failures.append("surface entrance clearance radius must be finite and >= 0")
	var anchor_variant: Variant = route.get("underground_anchor", null)
	if not anchor_variant is Vector3 or not _finite_vector3(anchor_variant):
		failures.append("surface entrance route requires finite underground anchor")
	failures.sort()
	return failures


static func compose(
	chunk_coord: Vector2i,
	source_data: Dictionary,
	world_settings,
	route: Dictionary,
	durable_destroyed_objects: Dictionary
) -> Dictionary:
	var failures: Array[String] = validate_route(route)
	if world_settings == null:
		failures.append("surface entrance composition requires WorldSettings")
	if source_data.is_empty():
		failures.append("surface entrance composition requires generated chunk data")
	var resolution: int = int(source_data.get("resolution", 0))
	if resolution < 2:
		failures.append("surface entrance composition requires resolution >= 2")
	var chunk_size: float = float(world_settings.chunk_size) if world_settings != null else 0.0
	if not _finite_float(chunk_size) or chunk_size <= 0.0:
		failures.append("surface entrance composition requires finite positive chunk_size")
	if not failures.is_empty():
		return _failure(failures)

	var realization_destroyed: Dictionary = durable_destroyed_objects.duplicate()
	if route.is_empty():
		return _success(source_data, realization_destroyed, {})

	var required_bounds: AABB = route.get("required_opening_bounds") as AABB
	var clearance: float = float(route.get("clearance_radius", 0.0))
	var opening: AABB = required_bounds.grow(clearance)
	var chunk_origin := Vector3(
		float(chunk_coord.x) * chunk_size,
		0.0,
		float(chunk_coord.y) * chunk_size
	)
	if not _rectangles_overlap_xz(
		AABB(chunk_origin, Vector3(chunk_size, 1.0, chunk_size)),
		opening
	):
		return _success(source_data, realization_destroyed, {})

	var descriptor = SurfaceEntranceDescriptor.new(
		str(route.get("entrance_id", "")),
		str(route.get("owning_region_id", "")),
		route.get("surface_world_position", Vector3.ZERO),
		route.get("orientation", Vector3.ZERO),
		required_bounds,
		clearance,
		"",
		"",
		route.get("underground_anchor", Vector3.ZERO),
		str(route.get("descent_profile", ""))
	)
	var anchor: Vector3 = route.get("underground_anchor", Vector3.ZERO)
	var y_min: float = minf(opening.position.y, anchor.y)
	var y_max: float = maxf(opening.end.y, anchor.y)
	var chunk_bounds := AABB(
		Vector3(chunk_origin.x, y_min, chunk_origin.z),
		Vector3(chunk_size, maxf(y_max - y_min, 1.0), chunk_size)
	)
	var grid_size := Vector2i(resolution - 1, resolution - 1)
	var plan_result: Dictionary = SurfaceEntranceChunkPlan.build(
		chunk_bounds,
		[descriptor],
		grid_size,
		str(route.get("source_entrance_fingerprint", ""))
	)
	if not bool(plan_result.get("success", false)):
		return _failure(plan_result.get("diagnostics", []))
	var plan = plan_result.get("data", null)
	if plan == null or plan.entrance_ids.is_empty():
		return _failure(["selected surface entrance overlaps chunk but produced no opening plan"])

	var indices_variant: Variant = source_data.get("indices", null)
	var heights_variant: Variant = source_data.get("collision_heights", null)
	if not indices_variant is PackedInt32Array:
		failures.append("surface entrance composition requires PackedInt32Array indices")
	if not heights_variant is PackedFloat32Array:
		failures.append("surface entrance composition requires PackedFloat32Array collision heights")
	var expected_index_count: int = grid_size.x * grid_size.y * 6
	if indices_variant is PackedInt32Array and indices_variant.size() != expected_index_count:
		failures.append(
			"surface entrance index layout mismatch: expected %d, got %d" % [
				expected_index_count,
				indices_variant.size(),
			]
		)
	var expected_height_count: int = resolution * resolution
	if heights_variant is PackedFloat32Array and heights_variant.size() != expected_height_count:
		failures.append(
			"surface entrance collision layout mismatch: expected %d, got %d" % [
				expected_height_count,
				heights_variant.size(),
			]
		)
	if not failures.is_empty():
		return _failure(failures)

	var omitted_lookup: Dictionary = {}
	for raw_index in plan.omitted_triangle_indices:
		var entry_index: int = int(raw_index)
		if entry_index < 0 or entry_index >= indices_variant.size():
			failures.append("surface entrance omitted render index is outside generated mesh: %d" % entry_index)
			continue
		omitted_lookup[entry_index] = true
	for raw_index in plan.collision_hole_indices:
		var height_index: int = int(raw_index)
		if height_index < 0 or height_index >= heights_variant.size():
			failures.append("surface entrance collision hole index is outside generated heightmap: %d" % height_index)
	if not failures.is_empty():
		return _failure(failures)

	var composed_data: Dictionary = source_data.duplicate(true)
	var source_indices: PackedInt32Array = indices_variant
	var composed_indices := PackedInt32Array()
	composed_indices.resize(source_indices.size() - omitted_lookup.size())
	var write_index: int = 0
	for source_index in range(source_indices.size()):
		if omitted_lookup.has(source_index):
			continue
		composed_indices[write_index] = source_indices[source_index]
		write_index += 1
	composed_data["indices"] = composed_indices

	var composed_heights: PackedFloat32Array = heights_variant.duplicate()
	for raw_index in plan.collision_hole_indices:
		composed_heights[int(raw_index)] = NAN
	composed_data["collision_heights"] = composed_heights

	var suppressed_ids: Array[String] = []
	for specification in [
		["tree", "tree_transforms", "tree_stable_ids"],
		["rock", "rock_transforms", "rock_stable_ids"],
		["branch", "branch_transforms", "branch_stable_ids"],
		["loose_stone", "loose_stone_transforms", "loose_stone_stable_ids"],
	]:
		_collect_suppressed_ids(
			str(specification[0]),
			str(specification[1]),
			str(specification[2]),
			source_data,
			chunk_origin,
			plan.rim_bounds,
			world_settings,
			realization_destroyed,
			suppressed_ids,
			failures
		)
	if not failures.is_empty():
		return _failure(failures)
	suppressed_ids.sort()
	composed_data["entrance_surface_plan_fingerprint"] = str(plan.fingerprint)
	composed_data["entrance_surface_omitted_index_count"] = omitted_lookup.size()
	composed_data["entrance_surface_collision_hole_count"] = plan.collision_hole_indices.size()
	composed_data["entrance_surface_suppressed_object_ids"] = suppressed_ids.duplicate()

	var snapshot: Dictionary = {
		"entrance_id": str(route.get("entrance_id", "")),
		"plan_fingerprint": str(plan.fingerprint),
		"chunk_coord": chunk_coord,
		"chunk_bounds": chunk_bounds,
		"rim_bounds": plan.rim_bounds,
		"omitted_index_count": omitted_lookup.size(),
		"collision_hole_count": plan.collision_hole_indices.size(),
		"suppressed_object_ids": suppressed_ids.duplicate(),
		"original_index_count": source_indices.size(),
		"realized_index_count": composed_indices.size(),
	}
	return _success(composed_data, realization_destroyed, snapshot)


static func _collect_suppressed_ids(
	object_type: String,
	transforms_key: String,
	stable_ids_key: String,
	data: Dictionary,
	chunk_origin: Vector3,
	opening: AABB,
	world_settings,
	realization_destroyed: Dictionary,
	suppressed_ids: Array[String],
	failures: Array[String]
) -> void:
	var transforms_variant: Variant = data.get(transforms_key, [])
	var stable_ids_variant: Variant = data.get(stable_ids_key, [])
	if not transforms_variant is Array or not stable_ids_variant is Array:
		failures.append("surface entrance %s candidates require Array transforms and StableIds" % object_type)
		return
	var transforms: Array = transforms_variant
	var stable_ids: Array = stable_ids_variant
	if transforms.size() != stable_ids.size():
		failures.append(
			"surface entrance %s candidate StableId count mismatch: %d != %d" % [
				object_type,
				transforms.size(),
				stable_ids.size(),
			]
		)
		return
	for index in range(transforms.size()):
		if not transforms[index] is Transform3D:
			failures.append("surface entrance %s candidate %d has malformed transform" % [object_type, index])
			continue
		var transform: Transform3D = transforms[index]
		var world_origin: Vector3 = chunk_origin + transform.origin
		var footprint_radius: float = _candidate_footprint_radius(object_type, transform, world_settings)
		if not _contains_xz(opening.grow(footprint_radius), world_origin):
			continue
		var stable_id: String = str(stable_ids[index])
		if stable_id.is_empty() or StableId.parse(stable_id) == null:
			failures.append("surface entrance %s candidate %d has invalid StableId" % [object_type, index])
			continue
		realization_destroyed[stable_id] = true
		if not suppressed_ids.has(stable_id):
			suppressed_ids.append(stable_id)


static func _candidate_footprint_radius(
	object_type: String,
	transform: Transform3D,
	world_settings
) -> float:
	var scale_x: float = maxf(transform.basis.x.length(), 0.0)
	var scale_z: float = maxf(transform.basis.z.length(), 0.0)
	if object_type == "tree":
		var uniform_scale: float = maxf(scale_x, 0.05)
		return maxf(TREE_VISUAL_RADIUS, float(world_settings.tree_collider_radius)) * uniform_scale
	return 0.5 * sqrt(scale_x * scale_x + scale_z * scale_z)


static func _success(
	data: Dictionary,
	realization_destroyed_objects: Dictionary,
	snapshot: Dictionary
) -> Dictionary:
	return {
		"success": true,
		"diagnostics": [],
		"data": data,
		"realization_destroyed_objects": realization_destroyed_objects,
		"snapshot": snapshot,
	}


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {"success": false, "diagnostics": diagnostics}


static func _rectangles_overlap_xz(a: AABB, b: AABB) -> bool:
	return (
		a.position.x <= b.end.x
		and a.end.x >= b.position.x
		and a.position.z <= b.end.z
		and a.end.z >= b.position.z
	)


static func _contains_xz(bounds: AABB, point: Vector3) -> bool:
	return (
		point.x >= bounds.position.x
		and point.x <= bounds.end.x
		and point.z >= bounds.position.z
		and point.z <= bounds.end.z
	)


static func _finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _finite_vector3(value: Vector3) -> bool:
	return _finite_float(value.x) and _finite_float(value.y) and _finite_float(value.z)
