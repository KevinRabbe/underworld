extends RefCounted

const Selector := preload("res://worldgen/surface/natural_entrance_route_selector.gd")
const Composer := preload("res://world/runtime/streaming/surface_entrance_chunk_composer.gd")
const WorldSettings := preload("res://world/runtime/config/world_settings.gd")
const TerrainGenerator := preload("res://worldgen/surface/terrain_generator.gd")
const PickupGenerator := preload("res://worldgen/surface/pickup_generator.gd")
const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")

const WORLD_SEED := 12345


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_real_resolution_composition(failures)
	return failures


static func _test_real_resolution_composition(failures: Array[String]) -> void:
	var settings = WorldSettings.new()
	settings.world_seed = WORLD_SEED
	var preferred := Vector3(settings.chunk_size * 0.5, 0.0, settings.chunk_size * 0.5)
	var selection: Dictionary = Selector.select(WORLD_SEED, preferred)
	_expect(failures, "production opening fixture selects ordinary route", bool(selection.get("success", false)))
	if not bool(selection.get("success", false)):
		return
	var route_variant: Variant = selection.get("route", null)
	if not route_variant is Dictionary:
		failures.append("production opening fixture route is malformed")
		return
	var route: Dictionary = route_variant
	var surface_variant: Variant = route.get("surface_world_position", null)
	if not surface_variant is Vector3:
		failures.append("production opening fixture lacks surface position")
		return
	var surface: Vector3 = surface_variant
	var coord := Vector2i(
		floori(surface.x / settings.chunk_size),
		floori(surface.z / settings.chunk_size)
	)

	var terrain = TerrainGenerator.new()
	terrain.configure(settings)
	var pickups = PickupGenerator.new()
	pickups.configure(settings)
	var source: Dictionary = terrain.generate_chunk_data(coord)
	pickups.add_pickups_to_chunk_data(coord, source)
	var synthetic_id: String = _inject_mouth_candidate(source, coord, settings, surface)
	_expect(failures, "production opening fixture creates canonical intersecting candidate", not synthetic_id.is_empty())
	if synthetic_id.is_empty():
		return

	var source_indices: PackedInt32Array = source.get("indices", PackedInt32Array()).duplicate()
	var source_heights: PackedFloat32Array = source.get("collision_heights", PackedFloat32Array()).duplicate()
	var source_branch_ids: Array = source.get("branch_stable_ids", []).duplicate()
	var durable_destroyed: Dictionary = _durable_fixture(source, synthetic_id)
	var durable_before: Dictionary = durable_destroyed.duplicate(true)

	var first: Dictionary = Composer.compose(coord, source, settings, route, durable_destroyed)
	_expect(failures, "production opening composes accepted route", bool(first.get("success", false)))
	if not bool(first.get("success", false)):
		for diagnostic in first.get("diagnostics", []):
			failures.append("production opening composition: %s" % diagnostic)
		return
	var first_data: Dictionary = first.get("data", {})
	var first_snapshot: Dictionary = first.get("snapshot", {})
	var realization_destroyed: Dictionary = first.get("realization_destroyed_objects", {})
	var first_indices: PackedInt32Array = first_data.get("indices", PackedInt32Array())
	var first_heights: PackedFloat32Array = first_data.get("collision_heights", PackedFloat32Array())
	var omitted_count: int = int(first_snapshot.get("omitted_index_count", 0))
	var hole_count: int = int(first_snapshot.get("collision_hole_count", 0))

	_expect(failures, "production opening omits real render indices", omitted_count > 0 and first_indices.size() == source_indices.size() - omitted_count)
	_expect(failures, "production opening creates real heightmap holes", hole_count > 0 and _nan_count(first_heights) == hole_count)
	_expect(
		failures,
		"production collision holes stay inside accepted opening and preserve outside heights",
		_collision_cutout_is_bounded(source, source_heights, first_heights, coord, settings, route)
	)
	_expect(failures, "production opening source render data remains immutable", source.get("indices", PackedInt32Array()) == source_indices)
	_expect(failures, "production opening source height data remains immutable", source.get("collision_heights", PackedFloat32Array()) == source_heights)
	_expect(failures, "production opening preserves candidate StableId ordering", source.get("branch_stable_ids", []) == source_branch_ids)
	_expect(failures, "mouth candidate is suppressed only for realization", realization_destroyed.has(synthetic_id) and first_snapshot.get("suppressed_object_ids", []).has(synthetic_id))
	_expect(failures, "mouth suppression never mutates durable destroyed lookup", durable_destroyed == durable_before and not durable_destroyed.has(synthetic_id))
	for durable_id in durable_before.keys():
		_expect(
			failures,
			"pre-existing WorldDelta suppression survives realization-only entrance mask",
			realization_destroyed.has(durable_id)
		)

	var second: Dictionary = Composer.compose(coord, source, settings, route, durable_destroyed)
	_expect(failures, "production opening recomposes deterministically", bool(second.get("success", false)))
	if bool(second.get("success", false)):
		var second_snapshot: Dictionary = second.get("snapshot", {})
		_expect(
			failures,
			"production opening fingerprint is deterministic",
			str(second_snapshot.get("plan_fingerprint", "")) == str(first_snapshot.get("plan_fingerprint", ""))
		)
		_expect(
			failures,
			"production opening suppression is deterministic",
			second_snapshot.get("suppressed_object_ids", []) == first_snapshot.get("suppressed_object_ids", [])
		)
		_expect(
			failures,
			"production opening render cutout is deterministic",
			second.get("data", {}).get("indices", PackedInt32Array()) == first_indices
		)

	var far_coord := coord + Vector2i(8, 8)
	var far_source: Dictionary = terrain.generate_chunk_data(far_coord)
	pickups.add_pickups_to_chunk_data(far_coord, far_source)
	var far_indices: PackedInt32Array = far_source.get("indices", PackedInt32Array()).duplicate()
	var far: Dictionary = Composer.compose(far_coord, far_source, settings, route, durable_destroyed)
	_expect(failures, "production opening leaves non-overlapping chunks unchanged", bool(far.get("success", false)) and far.get("snapshot", {}).is_empty())
	if bool(far.get("success", false)):
		_expect(failures, "non-overlapping render indices remain identical", far.get("data", {}).get("indices", PackedInt32Array()) == far_indices)


static func _collision_cutout_is_bounded(
	source: Dictionary,
	source_heights: PackedFloat32Array,
	composed_heights: PackedFloat32Array,
	coord: Vector2i,
	settings,
	route: Dictionary
) -> bool:
	var resolution: int = int(source.get("resolution", 0))
	var spacing: float = float(source.get("spacing", 0.0))
	if resolution < 2 or spacing <= 0.0 or composed_heights.size() != source_heights.size():
		return false
	var bounds_variant: Variant = route.get("required_opening_bounds", null)
	if not bounds_variant is AABB:
		return false
	var opening: AABB = bounds_variant
	opening = opening.grow(float(route.get("clearance_radius", 0.0)))
	var chunk_origin := Vector3(
		float(coord.x) * settings.chunk_size,
		0.0,
		float(coord.y) * settings.chunk_size
	)
	for index in range(composed_heights.size()):
		var row: int = index / resolution
		var column: int = index % resolution
		var point := Vector3(
			chunk_origin.x + float(column) * spacing,
			0.0,
			chunk_origin.z + float(row) * spacing
		)
		if is_nan(composed_heights[index]):
			if not _contains_xz(opening, point):
				return false
		elif not is_equal_approx(composed_heights[index], source_heights[index]):
			return false
	return true


static func _inject_mouth_candidate(
	data: Dictionary,
	coord: Vector2i,
	settings,
	surface: Vector3
) -> String:
	var transforms: Array = data.get("branch_transforms", []).duplicate()
	var stable_ids: Array = data.get("branch_stable_ids", []).duplicate()
	var resolution: int = int(data.get("resolution", settings.vertices_per_side))
	var span: int = maxi(resolution - 1, 1)
	var global_cell_x: int = coord.x * span
	var global_cell_z: int = coord.y * span
	var address = StableAddress.surface_candidate(
		"branch",
		global_cell_x,
		global_cell_z,
		"999"
	)
	var stable_id: String = StableId.from_address(address).value()
	if StableId.parse(stable_id) == null:
		return ""
	var local_origin := Vector3(
		surface.x - float(coord.x) * settings.chunk_size,
		surface.y,
		surface.z - float(coord.y) * settings.chunk_size
	)
	transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.2, 0.1, 0.1)), local_origin))
	stable_ids.append(stable_id)
	data["branch_transforms"] = transforms
	data["branch_stable_ids"] = stable_ids
	return stable_id


static func _durable_fixture(data: Dictionary, excluded_id: String) -> Dictionary:
	for key in ["tree_stable_ids", "rock_stable_ids", "branch_stable_ids", "loose_stone_stable_ids"]:
		var ids_variant: Variant = data.get(key, [])
		if not ids_variant is Array:
			continue
		for raw_id in ids_variant:
			var stable_id: String = str(raw_id)
			if stable_id != excluded_id and StableId.parse(stable_id) != null:
				return {stable_id: true}
	return {}


static func _nan_count(values: PackedFloat32Array) -> int:
	var count: int = 0
	for value in values:
		if is_nan(value):
			count += 1
	return count


static func _contains_xz(bounds: AABB, point: Vector3) -> bool:
	return (
		point.x >= bounds.position.x
		and point.x <= bounds.end.x
		and point.z >= bounds.position.z
		and point.z <= bounds.end.z
	)


static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
