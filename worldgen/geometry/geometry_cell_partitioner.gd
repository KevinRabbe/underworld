extends RefCounted
class_name UnderworldGeometryCellPartitioner

const CellContribution := preload("res://worldgen/geometry/geometry_cell_contribution.gd")

const CELL_SIZE := Vector3(128.0, 128.0, 128.0)
const CELL_END_EPSILON := Vector3(0.001, 0.001, 0.001)


static func build(bundle, chambers: Array, tunnels: Array, reserved_sites: Array) -> Array:
	var cell_sources: Dictionary = {}
	for chamber in chambers:
		if chamber == null:
			continue
		_add_bounds_source(
			cell_sources,
			_chamber_bounds(chamber),
			"chamber",
			chamber.stable_id
		)
	for tunnel in tunnels:
		if tunnel == null:
			continue
		_add_bounds_source(
			cell_sources,
			_tunnel_bounds(tunnel),
			"tunnel",
			tunnel.stable_id
		)
	for site in reserved_sites:
		if site == null:
			continue
		_add_bounds_source(
			cell_sources,
			site.reserved_bounds,
			"reserved_site",
			site.stable_id
		)

	var keys: Array[String] = []
	for key in cell_sources.keys():
		keys.append(str(key))
	keys.sort()
	var result: Array = []
	for key in keys:
		var entry: Dictionary = cell_sources[key]
		var coord: Vector3i = entry["coord"]
		var address = bundle.region_definition.stable_address.child([
			"geometry-cell-contribution",
			"x", str(coord.x),
			"y", str(coord.y),
			"z", str(coord.z),
		])
		result.append(CellContribution.new(
			address,
			bundle.region_definition.stable_id,
			coord,
			_cell_bounds(coord),
			_typed_strings(entry["chambers"]),
			_typed_strings(entry["tunnels"]),
			_typed_strings(entry["reserved_sites"])
		))
	result.sort_custom(_stable_less)
	return result


static func _add_bounds_source(
	cell_sources: Dictionary,
	bounds: AABB,
	kind: String,
	stable_id: String
) -> void:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
		return
	var min_coord := _world_to_cell(bounds.position)
	var max_point: Vector3 = bounds.end - CELL_END_EPSILON
	var max_coord := _world_to_cell(max_point)
	for cell_y in range(min_coord.y, max_coord.y + 1):
		for cell_z in range(min_coord.z, max_coord.z + 1):
			for cell_x in range(min_coord.x, max_coord.x + 1):
				var coord := Vector3i(cell_x, cell_y, cell_z)
				var key: String = _cell_key(coord)
				if not cell_sources.has(key):
					cell_sources[key] = {
						"coord": coord,
						"chambers": {},
						"tunnels": {},
						"reserved_sites": {},
					}
				var bucket: String = ""
				match kind:
					"chamber": bucket = "chambers"
					"tunnel": bucket = "tunnels"
					"reserved_site": bucket = "reserved_sites"
				if not bucket.is_empty():
					cell_sources[key][bucket][stable_id] = true


static func _chamber_bounds(chamber) -> AABB:
	var half: Vector3 = chamber.dimensions * 0.5
	var cosine: float = absf(cos(chamber.rotation_y))
	var sine: float = absf(sin(chamber.rotation_y))
	var rotated_half := Vector3(
		cosine * half.x + sine * half.z,
		half.y,
		sine * half.x + cosine * half.z
	)
	return AABB(chamber.center - rotated_half, rotated_half * 2.0)


static func _tunnel_bounds(tunnel) -> AABB:
	if tunnel.control_points.is_empty():
		return AABB(Vector3.ZERO, Vector3.ZERO)
	var minimum: Vector3 = tunnel.control_points[0]
	var maximum: Vector3 = tunnel.control_points[0]
	for point_variant in tunnel.control_points:
		var point: Vector3 = point_variant
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		minimum.z = minf(minimum.z, point.z)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
		maximum.z = maxf(maximum.z, point.z)
	var radius: float = maxf(tunnel.width, tunnel.height) * 0.5 + tunnel.clearance_margin
	var expansion := Vector3.ONE * radius
	return AABB(minimum - expansion, maximum - minimum + expansion * 2.0)


static func _world_to_cell(position: Vector3) -> Vector3i:
	return Vector3i(
		floori(position.x / CELL_SIZE.x),
		floori(position.y / CELL_SIZE.y),
		floori(position.z / CELL_SIZE.z)
	)


static func _cell_bounds(coord: Vector3i) -> AABB:
	return AABB(
		Vector3(
			float(coord.x) * CELL_SIZE.x,
			float(coord.y) * CELL_SIZE.y,
			float(coord.z) * CELL_SIZE.z
		),
		CELL_SIZE
	)


static func _cell_key(coord: Vector3i) -> String:
	return "%d:%d:%d" % [coord.x, coord.y, coord.z]


static func _typed_strings(values: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for value in values.keys():
		result.append(str(value))
	result.sort()
	return result


static func _stable_less(a, b) -> bool:
	return str(a.stable_id) < str(b.stable_id)
