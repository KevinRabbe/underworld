extends RefCounted
class_name UnderworldGeometryCellPartitioner

const StageResult := preload("res://worldgen/pipeline/generation_stage_result.gd")
const CaveGeometryResult := preload("res://worldgen/underworld/cave_geometry_result.gd")
const FinalizationResult := preload("res://worldgen/underworld/region_finalization_result.gd")
const Request := preload("res://worldgen/geometry/geometry_cell_partition_request.gd")
const Config := preload("res://worldgen/geometry/geometry_cell_partition_config.gd")
const CellAddress := preload("res://worldgen/geometry/geometry_cell_address.gd")
const Fragment := preload("res://worldgen/geometry/geometry_cell_fragment.gd")
const Plan := preload("res://worldgen/geometry/geometry_cell_plan.gd")
const PartitionResult := preload("res://worldgen/geometry/geometry_cell_partition_result.gd")
const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")


static func generate(request):
	if request == null or not (request is Request):
		return StageResult.fail("geometry_cell_partition", ["GeometryCellPartitionRequest is required"])
	var failures: Array[String] = request.validate()
	if not failures.is_empty():
		return StageResult.fail("geometry_cell_partition", failures)
	var geometry = request.cave_geometry_result
	var finalization = request.region_finalization_result
	if request.world_context != null:
		failures.append_array(request.world_context.validate_provenance(geometry.provenance, "geometry_description"))
		failures.append_array(request.world_context.validate_provenance(finalization.provenance, "region_finalization"))
		if geometry.provenance != null:
			failures.append_array(request.world_context.validate_exact_sources(
				geometry.provenance, request.expected_geometry_source_fingerprints
			))
		if not failures.is_empty():
			return StageResult.fail("geometry_cell_partition", failures)
	if geometry.bundle == null or finalization.bundle == null:
		return StageResult.fail("geometry_cell_partition", ["Partition inputs must contain finalized graph bundles"])
	var geometry_region_id: String = str(geometry.bundle.region_definition.stable_id)
	var finalization_region_id: String = str(finalization.bundle.region_definition.stable_id)
	if geometry_region_id != finalization_region_id:
		return StageResult.fail("geometry_cell_partition", ["Geometry and finalization inputs refer to different regions"])
	if geometry.fingerprint.is_empty() or finalization.fingerprint.is_empty():
		return StageResult.fail("geometry_cell_partition", ["Partition inputs require non-empty source fingerprints"])

	var sources: Array = _sources(geometry, finalization)
	var source_identity_seen: Dictionary = {}
	for source in sources:
		var source_key := str(source["kind"]) + ":" + str(source["source_id"])
		if source_identity_seen.has(source_key):
			return StageResult.fail("geometry_cell_partition", ["Duplicate geometry source descriptor: " + source_key])
		source_identity_seen[source_key] = true
	var source_cells: Dictionary = {}
	var occupied: Dictionary = {}
	for source in sources:
		var source_key := str(source["kind"]) + ":" + str(source["source_id"])
		var bounds: AABB = source["bounds"]
		var cells := _overlap_coordinates(bounds, request.configuration)
		var keys: Array[String] = []
		for coordinate in cells:
			var key := _coordinate_key(coordinate)
			keys.append(key)
			occupied[key] = coordinate
		source_cells[source_key] = keys

	var requested := _requested_coordinates(request.requested_cells, request.configuration)
	if requested.is_empty():
		for coordinate in occupied.values():
			requested.append(coordinate)
	requested.sort_custom(_coordinate_less)

	var plans: Array = []
	var total_fragments := 0
	var total_entrances := 0
	var total_sites := 0
	for coordinate in requested:
		var address := CellAddress.new(coordinate)
		var cell_bounds := _cell_bounds(coordinate, request.configuration)
		var fragments: Array = []
		var entrance_metadata: Array = []
		var site_metadata: Array = []
		for source in sources:
			var source_key := str(source["kind"]) + ":" + str(source["source_id"])
			var source_keys: Array = source_cells[source_key]
			if not source_keys.has(_coordinate_key(coordinate)):
				continue
			var clipped := _intersection(source["bounds"], cell_bounds)
			if clipped.size.x <= 0.0 or clipped.size.y <= 0.0 or clipped.size.z <= 0.0:
				continue
			var owner_coordinate: Vector3i = _owner_coordinate(source_keys)
			var continuation := _continuation_mask(source["bounds"], cell_bounds)
			var neighbors := _neighbor_addresses(coordinate, continuation)
			var fragment_id := _fragment_id(request.configuration, source, address)
			var fragment := Fragment.new(
				fragment_id,
				source["source_id"],
				source["kind"],
				address,
				cell_bounds,
				clipped,
				coordinate == owner_coordinate,
				continuation,
				neighbors,
				source["fingerprint"],
				source["metadata"]
			)
			fragments.append(fragment)
			if source["kind"] == "entrance":
				entrance_metadata.append(source["metadata"])
			elif source["kind"] == "reserved_site":
				site_metadata.append(source["metadata"])
		fragments.sort_custom(_fragment_less)
		entrance_metadata.sort_custom(_metadata_less)
		site_metadata.sort_custom(_metadata_less)
		total_fragments += fragments.size()
		total_entrances += entrance_metadata.size()
		total_sites += site_metadata.size()
		plans.append(Plan.new(
			address,
			fragments,
			entrance_metadata,
			site_metadata,
			geometry.fingerprint,
			finalization.fingerprint,
			{
				"fragment_count": fragments.size(),
				"entrance_count": entrance_metadata.size(),
				"reserved_site_count": site_metadata.size(),
			},
			[]
		))
	plans.sort_custom(_plan_less)
	var plan_failures: Array[String] = _validate_plans(plans)
	if not plan_failures.is_empty():
		return StageResult.fail("geometry_cell_partition", plan_failures)
	var metrics := {
		"cell_count": plans.size(),
		"fragment_count": total_fragments,
		"entrance_fragment_count": total_entrances,
		"reserved_site_fragment_count": total_sites,
		"owner_fragment_count": _owner_count(plans),
	}
	var result := PartitionResult.new(
		plans,
		request.configuration.fingerprint,
		geometry.fingerprint,
		finalization.fingerprint,
		metrics,
		[],
		_request_provenance(request, geometry, finalization)
	)
	return StageResult.ok("geometry_cell_partition", result, result.fingerprint, result.provenance)


static func partition(geometry_result, finalization_result, configuration = null, requested_cells: Array = [], context = null, expected_geometry_sources: Array = []):
	var request := Request.new(geometry_result, finalization_result, configuration, requested_cells, context, expected_geometry_sources)
	return generate(request)


static func build(request):
	return generate(request)


static func _request_provenance(request, geometry, finalization):
	if request.world_context == null or geometry.provenance == null or finalization.provenance == null:
		return null
	return request.world_context.make_provenance(
		"geometry_cell_partition",
		str(geometry.bundle.region_definition.stable_id),
		geometry.bundle.region_definition.stable_address.canonical_text(),
		[geometry.provenance.fingerprint, finalization.provenance.fingerprint]
	)


static func _sources(geometry, finalization) -> Array:
	var result: Array = []
	for chamber in geometry.chamber_descriptors:
		if chamber == null:
			continue
		result.append(_source(
			str(chamber.stable_id), "chamber", _chamber_bounds(chamber), chamber.canonical_data(),
		))
	for tunnel in geometry.tunnel_descriptors:
		if tunnel == null:
			continue
		result.append(_source(
			str(tunnel.stable_id), "tunnel", _tunnel_bounds(tunnel), tunnel.canonical_data(),
		))
	for descriptor in finalization.surface_integration_descriptors:
		if descriptor == null:
			continue
		result.append(_source(
			str(descriptor.entrance_id), "entrance", descriptor.required_opening_bounds,
			descriptor.canonical_data(),
		))
	for site in geometry.reserved_site_descriptors:
		if site == null:
			continue
		result.append(_source(
			str(site.stable_id), "reserved_site", site.reserved_bounds, site.canonical_data(),
		))
	result.sort_custom(_source_less)
	var seen: Dictionary = {}
	for source in result:
		if seen.has(source["source_id"]):
			# Source IDs are expected to be StableId namespaces; retaining the first
			# would make identity ambiguous, so mark the duplicate for validation.
			source["duplicate"] = true
		seen[source["source_id"]] = true
	return result


static func _source(source_id: String, kind: String, bounds: AABB, metadata: Dictionary) -> Dictionary:
	return {
		"source_id": source_id,
		"kind": kind,
		"bounds": bounds,
		"metadata": metadata.duplicate(true),
		"fingerprint": CanonicalValue.fingerprint(metadata),
	}


static func _overlap_coordinates(bounds: AABB, configuration) -> Array:
	var result: Array = []
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
		return result
	var minimum := Vector3i(
		floori(bounds.position.x / configuration.cell_size.x),
		floori(bounds.position.y / configuration.cell_size.y),
		floori(bounds.position.z / configuration.cell_size.z)
	)
	var maximum_point := bounds.position + bounds.size
	var maximum := Vector3i(
		ceili(maximum_point.x / configuration.cell_size.x) - 1,
		ceili(maximum_point.y / configuration.cell_size.y) - 1,
		ceili(maximum_point.z / configuration.cell_size.z) - 1
	)
	for x in range(minimum.x, maximum.x + 1):
		for y in range(minimum.y, maximum.y + 1):
			for z in range(minimum.z, maximum.z + 1):
				result.append(Vector3i(x, y, z))
	return result


static func _requested_coordinates(requested_cells: Array, configuration) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for value in requested_cells:
		var coordinate: Vector3i
		if value is Vector3i:
			coordinate = value
		else:
			coordinate = value.coordinate
		var key := _coordinate_key(coordinate)
		if not seen.has(key):
			seen[key] = true
			result.append(coordinate)
	return result


static func _cell_bounds(coordinate: Vector3i, configuration) -> AABB:
	return AABB(Vector3(coordinate) * configuration.cell_size, configuration.cell_size)


static func _intersection(a: AABB, b: AABB) -> AABB:
	var minimum := Vector3(
		maxf(a.position.x, b.position.x), maxf(a.position.y, b.position.y), maxf(a.position.z, b.position.z)
	)
	var a_end := a.position + a.size
	var b_end := b.position + b.size
	var maximum := Vector3(
		minf(a_end.x, b_end.x), minf(a_end.y, b_end.y), minf(a_end.z, b_end.z)
	)
	return AABB(minimum, maximum - minimum)


static func _continuation_mask(bounds: AABB, cell_bounds: AABB) -> Dictionary:
	var source_end := bounds.position + bounds.size
	var cell_end := cell_bounds.position + cell_bounds.size
	return {
		"-x": bounds.position.x < cell_bounds.position.x,
		"+x": source_end.x > cell_end.x,
		"-y": bounds.position.y < cell_bounds.position.y,
		"+y": source_end.y > cell_end.y,
		"-z": bounds.position.z < cell_bounds.position.z,
		"+z": source_end.z > cell_end.z,
	}


static func _neighbor_addresses(coordinate: Vector3i, continuation: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var offsets := {
		"-x": Vector3i(-1, 0, 0), "+x": Vector3i(1, 0, 0),
		"-y": Vector3i(0, -1, 0), "+y": Vector3i(0, 1, 0),
		"-z": Vector3i(0, 0, -1), "+z": Vector3i(0, 0, 1),
	}
	for face in offsets.keys():
		if bool(continuation.get(face, false)):
			result[face] = CellAddress.new(coordinate + offsets[face])
	return result


static func _owner_coordinate(keys: Array) -> Vector3i:
	var coordinates: Array = []
	for key in keys:
		var parts := str(key).split(":")
		coordinates.append(Vector3i(int(parts[0]), int(parts[1]), int(parts[2])))
	coordinates.sort_custom(_coordinate_less)
	return coordinates[0]


static func _fragment_id(configuration, source: Dictionary, address) -> String:
	return "gfrag1:" + CanonicalValue.fingerprint({
		"partition_contract": configuration.canonical_data(),
		"source_descriptor_id": source["source_id"],
		"cell_address": address.canonical_text(),
		"fragment_kind": source["kind"],
	})


static func _chamber_bounds(chamber) -> AABB:
	var half: Vector3 = chamber.dimensions * 0.5
	var cosine := absf(cos(chamber.rotation_y))
	var sine := absf(sin(chamber.rotation_y))
	var rotated_half := Vector3(cosine * half.x + sine * half.z, half.y, sine * half.x + cosine * half.z)
	return AABB(chamber.center - rotated_half, rotated_half * 2.0)


static func _tunnel_bounds(tunnel) -> AABB:
	if tunnel.control_points.is_empty():
		return AABB(Vector3.ZERO, Vector3.ZERO)
	var minimum: Vector3 = tunnel.control_points[0]
	var maximum: Vector3 = minimum
	for point_variant in tunnel.control_points:
		var point: Vector3 = point_variant
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		minimum.z = minf(minimum.z, point.z)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
		maximum.z = maxf(maximum.z, point.z)
	var radius: float = maxf(float(tunnel.width), float(tunnel.height)) * 0.5 + float(tunnel.clearance_margin)
	var expansion: Vector3 = Vector3.ONE * radius
	return AABB(minimum - expansion, maximum - minimum + expansion * 2.0)


static func _coordinate_key(coordinate: Vector3i) -> String:
	return "%d:%d:%d" % [coordinate.x, coordinate.y, coordinate.z]


static func _coordinate_less(a, b) -> bool:
	return a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and a.z < b.z)))


static func _source_less(a, b) -> bool:
	return str(a["kind"]) + ":" + str(a["source_id"]) < str(b["kind"]) + ":" + str(b["source_id"])


static func _fragment_less(a, b) -> bool:
	return str(a.fragment_id) < str(b.fragment_id)


static func _plan_less(a, b) -> bool:
	return _coordinate_less(a.cell_address.coordinate, b.cell_address.coordinate)


static func _metadata_less(a, b) -> bool:
	return str(a.get("entrance_id", a.get("site_id", a.get("stable_id", "")))) < str(b.get("entrance_id", b.get("site_id", b.get("stable_id", ""))))


static func _owner_count(plans: Array) -> int:
	var count := 0
	for plan in plans:
		for fragment in plan.fragments:
			if fragment.is_owner:
				count += 1
	return count


static func _validate_plans(plans: Array) -> Array[String]:
	var failures: Array[String] = []
	var fragment_ids: Dictionary = {}
	var owners: Dictionary = {}
	var plans_by_coordinate: Dictionary = {}
	for plan in plans:
		var plan_key := _coordinate_key(plan.cell_address.coordinate)
		if plans_by_coordinate.has(plan_key):
			failures.append("Duplicate geometry cell plan: " + plan.cell_address.canonical_text())
		plans_by_coordinate[plan_key] = plan
	for plan in plans:
		for fragment in plan.fragments:
			if fragment_ids.has(fragment.fragment_id):
				failures.append("Duplicate geometry cell fragment: " + fragment.fragment_id)
			fragment_ids[fragment.fragment_id] = true
			var source_key := str(fragment.source_kind) + ":" + str(fragment.source_descriptor_id)
			if fragment.is_owner:
				if owners.has(source_key):
					failures.append("Source has multiple geometry-cell owners: " + source_key)
				owners[source_key] = true
			for face in fragment.neighboring_cell_addresses.keys():
				var neighbor = fragment.neighboring_cell_addresses[face]
				# Plans are keyed by canonical coordinate text; using Vector3i here
				# silently skipped mirrored validation because Dictionary does not
				# coerce the key type.
				var neighbor_plan = plans_by_coordinate.get(_coordinate_key(neighbor.coordinate))
				if neighbor_plan == null:
					continue
				var opposite := _opposite_face(str(face))
				var mirrored := false
				for neighbor_fragment in neighbor_plan.fragments:
					if neighbor_fragment.source_descriptor_id == fragment.source_descriptor_id \
							and neighbor_fragment.source_kind == fragment.source_kind \
							and bool(neighbor_fragment.continuation_mask.get(opposite, false)):
						mirrored = true
						break
				if not mirrored:
					failures.append("Unmirrored geometry-cell continuation: %s %s" % [fragment.fragment_id, face])
	return failures


static func _opposite_face(face: String) -> String:
	match face:
		"-x": return "+x"
		"+x": return "-x"
		"-y": return "+y"
		"+y": return "-y"
		"-z": return "+z"
		"+z": return "-z"
	return ""
