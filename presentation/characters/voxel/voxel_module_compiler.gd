extends RefCounted
class_name UnderworldVoxelModuleCompiler

const MeshDataScript := preload("res://presentation/characters/voxel/voxel_module_mesh_data.gd")
const COMPILER_REVISION: int = 1

const DIRECTIONS: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]


static func compile_part(part: Dictionary, voxel_size: float, palette, module_fingerprint: String) -> RefCounted:
	var result = MeshDataScript.new()
	result.part_id = str(part.get("part_id", ""))
	result.rig_role = str(part.get("rig_role", ""))
	if not is_finite(voxel_size) or voxel_size <= 0.0:
		result.diagnostics.append("voxel size must be finite and positive")
		return result
	if palette == null or not palette.has_method("entry"):
		result.diagnostics.append("compatible palette is required")
		return result

	var occupied: Dictionary = {}
	for cell_value in part.get("cells", []):
		var cell: Dictionary = cell_value
		if not cell.get("position", null) is Vector3i:
			result.diagnostics.append("cell requires Vector3i position")
			continue
		var position: Vector3i = cell["position"]
		var key := _cell_key(position)
		if occupied.has(key):
			result.diagnostics.append("duplicate cell: %s" % key)
			continue
		var palette_index: int = int(cell.get("palette_index", -1))
		if palette_index < 0 or palette_index >= palette.entries.size():
			result.diagnostics.append("invalid palette index at %s: %d" % [key, palette_index])
			continue
		occupied[key] = palette_index
	if occupied.is_empty():
		result.diagnostics.append("part must contain at least one valid cell")
	if not result.diagnostics.is_empty():
		result.diagnostics.sort()
		return result

	var pivot: Vector3i = part.get("pivot", Vector3i.ZERO)
	var offset: Vector3 = part.get("attachment_offset", Vector3.ZERO)
	var surface_builders: Dictionary = {}
	var visible_faces: int = 0
	var merged_quads: int = 0
	for direction_index in range(DIRECTIONS.size()):
		var face_groups := _visible_face_groups(occupied, direction_index)
		var group_keys: Array[String] = []
		for group_key in face_groups.keys():
			group_keys.append(str(group_key))
		group_keys.sort()
		for group_key in group_keys:
			var group: Dictionary = face_groups[group_key]
			visible_faces += group.size()
			var split := group_key.split("|")
			var plane: int = int(split[0])
			var palette_index: int = int(split[1])
			var rectangles := _greedy_rectangles(group)
			merged_quads += rectangles.size()
			for rectangle in rectangles:
				_emit_quad(surface_builders, palette, palette_index, direction_index, plane, rectangle, pivot, offset, voxel_size)

	var palette_indexes: Array[int] = []
	for raw_index in surface_builders.keys():
		palette_indexes.append(int(raw_index))
	palette_indexes.sort()
	var all_points := PackedVector3Array()
	var triangle_count: int = 0
	for palette_index in palette_indexes:
		var builder: Dictionary = surface_builders[palette_index]
		var surface := {
			"palette_index": palette_index,
			"vertices": PackedVector3Array(builder["vertices"]),
			"normals": PackedVector3Array(builder["normals"]),
			"colors": PackedColorArray(builder["colors"]),
			"indices": PackedInt32Array(builder["indices"]),
		}
		result.surfaces.append(surface)
		all_points.append_array(surface["vertices"])
		triangle_count += surface["indices"].size() / 3
	result.bounds = _bounds_for_points(all_points)
	result.metrics = {
		"occupied_cells": occupied.size(),
		"visible_faces": visible_faces,
		"merged_quads": merged_quads,
		"triangles": triangle_count,
		"vertices": all_points.size(),
		"surface_count": result.surfaces.size(),
		"estimated_bytes": all_points.size() * 40 + triangle_count * 12,
	}
	result.source_fingerprint = "vmesh1:sha256:" + (module_fingerprint + "|" + result.part_id + "|" + str(COMPILER_REVISION) + "|" + _surface_descriptor(result.surfaces)).sha256_text()
	result.success = true
	return result


static func _visible_face_groups(occupied: Dictionary, direction_index: int) -> Dictionary:
	var groups: Dictionary = {}
	var keys: Array[String] = []
	for key in occupied.keys(): keys.append(str(key))
	keys.sort()
	var direction: Vector3i = DIRECTIONS[direction_index]
	for key in keys:
		var position := _position_from_key(key)
		if occupied.has(_cell_key(position + direction)):
			continue
		var mapped := _face_coordinates(position, direction_index)
		var group_key := "%d|%d" % [mapped.x, int(occupied[key])]
		var group: Dictionary = groups.get(group_key, {})
		group["%d,%d" % [mapped.y, mapped.z]] = true
		groups[group_key] = group
	return groups


static func _face_coordinates(position: Vector3i, direction_index: int) -> Vector3i:
	match direction_index:
		0: return Vector3i(position.x + 1, position.y, position.z)
		1: return Vector3i(position.x, position.y, position.z)
		2: return Vector3i(position.y + 1, position.x, position.z)
		3: return Vector3i(position.y, position.x, position.z)
		4: return Vector3i(position.z + 1, position.x, position.y)
		_: return Vector3i(position.z, position.x, position.y)


static func _greedy_rectangles(group: Dictionary) -> Array[Vector4i]:
	var remaining := group.duplicate()
	var rectangles: Array[Vector4i] = []
	while not remaining.is_empty():
		var coordinates: Array[Vector2i] = []
		for key in remaining.keys():
			var split := str(key).split(",")
			coordinates.append(Vector2i(int(split[0]), int(split[1])))
		coordinates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
		var start := coordinates[0]
		var width: int = 1
		while remaining.has("%d,%d" % [start.x + width, start.y]): width += 1
		var height: int = 1
		while true:
			var row_complete := true
			for x_offset in range(width):
				if not remaining.has("%d,%d" % [start.x + x_offset, start.y + height]):
					row_complete = false
					break
			if not row_complete: break
			height += 1
		for y_offset in range(height):
			for x_offset in range(width):
				remaining.erase("%d,%d" % [start.x + x_offset, start.y + y_offset])
		rectangles.append(Vector4i(start.x, start.y, width, height))
	return rectangles


static func _emit_quad(builders: Dictionary, palette, palette_index: int, direction_index: int, plane: int, rectangle: Vector4i, pivot: Vector3i, offset: Vector3, voxel_size: float) -> void:
	var u0: int = rectangle.x
	var v0: int = rectangle.y
	var u1: int = u0 + rectangle.z
	var v1: int = v0 + rectangle.w
	var points: Array[Vector3]
	var normal: Vector3 = Vector3(DIRECTIONS[direction_index])
	match direction_index:
		0: points = [Vector3(plane,u0,v0), Vector3(plane,u1,v0), Vector3(plane,u1,v1), Vector3(plane,u0,v1)]
		1: points = [Vector3(plane,u0,v0), Vector3(plane,u0,v1), Vector3(plane,u1,v1), Vector3(plane,u1,v0)]
		2: points = [Vector3(u0,plane,v0), Vector3(u0,plane,v1), Vector3(u1,plane,v1), Vector3(u1,plane,v0)]
		3: points = [Vector3(u0,plane,v0), Vector3(u1,plane,v0), Vector3(u1,plane,v1), Vector3(u0,plane,v1)]
		4: points = [Vector3(u0,v0,plane), Vector3(u1,v0,plane), Vector3(u1,v1,plane), Vector3(u0,v1,plane)]
		_: points = [Vector3(u0,v0,plane), Vector3(u0,v1,plane), Vector3(u1,v1,plane), Vector3(u1,v0,plane)]
	var builder: Dictionary = builders.get(palette_index, {"vertices": [], "normals": [], "colors": [], "indices": []})
	var base_index: int = builder["vertices"].size()
	var palette_entry: Dictionary = palette.entry(palette_index)
	var base_color: Color = palette_entry.get("color", Color.WHITE)
	var shade: float = 1.0 if normal.y > 0.5 else (0.72 if normal.y < -0.5 else 0.90)
	var shaded := Color(base_color.r * shade, base_color.g * shade, base_color.b * shade, base_color.a)
	for point in points:
		builder["vertices"].append((point - Vector3(pivot)) * voxel_size + offset)
		builder["normals"].append(normal)
		builder["colors"].append(shaded)
	builder["indices"].append_array([base_index, base_index + 1, base_index + 2, base_index, base_index + 2, base_index + 3])
	builders[palette_index] = builder


static func _bounds_for_points(points: PackedVector3Array) -> AABB:
	if points.is_empty(): return AABB()
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)


static func _surface_descriptor(surfaces: Array[Dictionary]) -> String:
	var lines: Array[String] = []
	for surface in surfaces:
		var vertices: PackedVector3Array = surface["vertices"]
		var vertex_lines: Array[String] = []
		for vertex in vertices: vertex_lines.append("%.6f,%.6f,%.6f" % [vertex.x, vertex.y, vertex.z])
		lines.append("%d|%s|%s" % [int(surface["palette_index"]), ";".join(vertex_lines), str(surface["indices"])])
	return "\n".join(lines)


static func _cell_key(position: Vector3i) -> String:
	return "%d,%d,%d" % [position.x, position.y, position.z]


static func _position_from_key(key: String) -> Vector3i:
	var split := key.split(",")
	return Vector3i(int(split[0]), int(split[1]), int(split[2]))
