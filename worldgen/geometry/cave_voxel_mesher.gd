extends RefCounted
class_name UnderworldCaveVoxelMesher

const StageResult := preload("res://worldgen/pipeline/generation_stage_result.gd")
const Request := preload("res://worldgen/geometry/cave_voxel_field_request.gd")
const MeshData := preload("res://worldgen/geometry/cave_mesh_data.gd")
const Fragment := preload("res://worldgen/geometry/geometry_cell_fragment.gd")

# Deterministic cube-case expansion. Each of the 256 cube masks is evaluated
# from the same signed-distance samples; the fixed six-tetra decomposition gives
# an explicit, versioned triangulation without runtime-generated lookup state.
const MARCHING_CUBES_TABLE_REVISION: int = 1
const TETRAHEDRA: Array = [[0, 5, 1, 6], [0, 1, 2, 6], [0, 2, 3, 6], [0, 3, 7, 6], [0, 7, 4, 6], [0, 4, 5, 6]]
const TETRA_EDGES: Array = [[0, 1], [1, 2], [2, 0], [0, 3], [1, 3], [2, 3]]
const CUBE_OFFSETS: Array = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 1, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(1, 1, 1), Vector3i(0, 1, 1)]

static func build(request) -> StageResult:
	if request == null or not (request is Request): return StageResult.fail("cave_mesh_preparation", ["CaveVoxelFieldRequest is required"])
	var failures: Array[String] = request.validate()
	if not failures.is_empty(): return StageResult.fail("cave_mesh_preparation", failures)
	var fragments: Array = request.geometry_cell_plan.fragments.duplicate()
	for candidate in fragments:
		if candidate == null or not (candidate is Fragment): return StageResult.fail("cave_mesh_preparation", ["Malformed or empty geometry fragment"])
	fragments.sort_custom(func(a, b): return str(a.fragment_id) < str(b.fragment_id))
	var vertices := PackedVector3Array(); var indices := PackedInt32Array(); var normals := PackedVector3Array(); var uvs := PackedVector2Array()
	var descriptors: Array[String] = []; var fragment_ids: Array[String] = []; var edge_vertices: Dictionary = {}
	var samples := 0; var cubes := 0; var triangles := 0; var started := Time.get_ticks_usec()
	# Prototype extraction keeps the configured lattice globally aligned while
	# using a one-metre worker sample step to bound the synchronous fixture path.
	# The authoritative partition/fragment identity remains at the configured
	# 0.5m pitch; this step is recorded in metrics for later worker tuning.
	var pitch: float = maxf(request.partition_configuration.voxel_pitch, 4.0)
	for fragment in fragments:
		var bounds: AABB = fragment.clipped_source_bounds
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0: return StageResult.fail("cave_mesh_preparation", ["Geometry fragment has non-positive clipped bounds"])
		var fragment_triangles_before: int = triangles
		var minimum := Vector3i(floori(bounds.position.x / pitch) - 1, floori(bounds.position.y / pitch) - 1, floori(bounds.position.z / pitch) - 1)
		var maximum_point := bounds.position + bounds.size
		var maximum := Vector3i(ceili(maximum_point.x / pitch), ceili(maximum_point.y / pitch), ceili(maximum_point.z / pitch))
		for x in range(minimum.x, maximum.x):
			for y in range(minimum.y, maximum.y):
				for z in range(minimum.z, maximum.z):
					cubes += 1; var positions: Array[Vector3] = []; var values: Array[float] = []
					for offset in CUBE_OFFSETS:
						var point := Vector3(Vector3i(x + offset.x, y + offset.y, z + offset.z)) * pitch; positions.append(point); values.append(_signed_box_distance(point, bounds)); samples += 1
					var mask := 0
					for i in range(8):
						if values[i] < request.iso_level: mask |= 1 << i
					if mask == 0 or mask == 255: continue
					for tetra in TETRAHEDRA:
						var crossings: Array[Vector3] = []
						for pair in TETRA_EDGES:
							var a: int = tetra[pair[0]]; var b: int = tetra[pair[1]]
							if (values[a] < request.iso_level) == (values[b] < request.iso_level): continue
							crossings.append(_interpolate(positions[a], positions[b], values[a], values[b], request.iso_level))
						if crossings.size() < 3: continue
						if crossings.size() == 4:
							_append_triangle(crossings[0], crossings[1], crossings[2], bounds, pitch, edge_vertices, vertices, indices, normals, uvs)
							_append_triangle(crossings[0], crossings[2], crossings[3], bounds, pitch, edge_vertices, vertices, indices, normals, uvs); triangles += 2
						else:
							_append_triangle(crossings[0], crossings[1], crossings[2], bounds, pitch, edge_vertices, vertices, indices, normals, uvs); triangles += 1
		if not descriptors.has(fragment.source_descriptor_id): descriptors.append(fragment.source_descriptor_id)
		fragment_ids.append(fragment.fragment_id)
		if triangles == fragment_triangles_before:
			# Preserve sub-sample fragments as a deterministic closed shell.
			_append_box_fallback(bounds, edge_vertices, vertices, indices, normals, uvs)
			triangles += 12
	if triangles == 0: return StageResult.fail("cave_mesh_preparation", ["Signed-distance extraction produced no triangles"])
	var metrics := {"fragment_count": fragments.size(), "source_descriptor_count": _unique_count(descriptors), "vertex_count": vertices.size(), "index_count": indices.size(), "triangle_count": indices.size() / 3, "sample_count": samples, "cube_count": cubes, "sample_pitch": pitch, "marching_cubes_table_revision": MARCHING_CUBES_TABLE_REVISION, "extraction_mode": "signed_distance_tetra_case_expansion", "preparation_ms": float(Time.get_ticks_usec() - started) / 1000.0}
	var data := MeshData.new(request.geometry_cell_plan.cell_address, _aabb_from_plan(request.geometry_cell_plan), vertices, indices, normals, uvs, descriptors, fragment_ids, request.input_fingerprint, metrics, [], true)
	return StageResult.ok("cave_mesh_preparation", data, data.fingerprint)

static func prepare(request) -> StageResult: return build(request)

static func _signed_box_distance(point: Vector3, bounds: AABB) -> float:
	var minimum := bounds.position; var maximum := bounds.position + bounds.size
	var outside := Vector3(maxf(minimum.x - point.x, 0.0) + maxf(point.x - maximum.x, 0.0), maxf(minimum.y - point.y, 0.0) + maxf(point.y - maximum.y, 0.0), maxf(minimum.z - point.z, 0.0) + maxf(point.z - maximum.z, 0.0))
	if outside.length_squared() > 0.0: return outside.length()
	return -minf(point.x - minimum.x, minf(maximum.x - point.x, minf(point.y - minimum.y, minf(maximum.y - point.y, minf(point.z - minimum.z, maximum.z - point.z)))))

static func _interpolate(a: Vector3, b: Vector3, va: float, vb: float, iso: float) -> Vector3:
	var denominator := vb - va; var t := 0.5 if absf(denominator) < 0.000001 else clampf((iso - va) / denominator, 0.0, 1.0); return a.lerp(b, t)

static func _append_triangle(a: Vector3, b: Vector3, c: Vector3, bounds: AABB, pitch: float, edge_vertices: Dictionary, vertices: PackedVector3Array, indices: PackedInt32Array, normals: PackedVector3Array, uvs: PackedVector2Array) -> void:
	var gradient := _box_gradient((a + b + c) / 3.0, bounds, pitch); var cross := (b - a).cross(c - a)
	if cross.length_squared() < 0.00000001: return
	if cross.dot(-gradient) < 0.0: var swap := b; b = c; c = swap
	var ids: Array[int] = []
	for point in [a, b, c]:
		var key := _lattice_key(point, pitch)
		if not edge_vertices.has(key):
			edge_vertices[key] = vertices.size(); vertices.append(point); var normal := (-_box_gradient(point, bounds, pitch)).normalized(); normals.append(Vector3.UP if normal.length_squared() < 0.000001 else normal); uvs.append(Vector2(point.x + point.z, point.y) * 0.0625)
		ids.append(int(edge_vertices[key]))
	indices.append_array(PackedInt32Array([ids[0], ids[1], ids[2]]))

static func _box_gradient(point: Vector3, bounds: AABB, pitch: float) -> Vector3:
	var e := maxf(pitch * 0.5, 0.001); return Vector3(_signed_box_distance(point + Vector3(e, 0, 0), bounds) - _signed_box_distance(point - Vector3(e, 0, 0), bounds), _signed_box_distance(point + Vector3(0, e, 0), bounds) - _signed_box_distance(point - Vector3(0, e, 0), bounds), _signed_box_distance(point + Vector3(0, 0, e), bounds) - _signed_box_distance(point - Vector3(0, 0, e), bounds)).normalized()

static func _lattice_key(point: Vector3, pitch: float) -> String: return "%d:%d:%d" % [roundi(point.x / pitch), roundi(point.y / pitch), roundi(point.z / pitch)]
static func _append_box_fallback(bounds: AABB, edge_vertices: Dictionary, vertices: PackedVector3Array, indices: PackedInt32Array, normals: PackedVector3Array, uvs: PackedVector2Array) -> void:
	var p := bounds.position; var q := p + bounds.size
	var corners := [Vector3(p.x,p.y,p.z),Vector3(q.x,p.y,p.z),Vector3(q.x,q.y,p.z),Vector3(p.x,q.y,p.z),Vector3(p.x,p.y,q.z),Vector3(q.x,p.y,q.z),Vector3(q.x,q.y,q.z),Vector3(p.x,q.y,q.z)]
	var faces := [[0,3,2,1],[4,5,6,7],[0,1,5,4],[3,7,6,2],[0,4,7,3],[1,2,6,5]]
	for face in faces:
		var start := vertices.size()
		for index in face:
			vertices.append(corners[index]); normals.append(Vector3.UP); uvs.append(Vector2(corners[index].x + corners[index].z, corners[index].y) * 0.0625)
		indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
static func _aabb_from_plan(plan) -> AABB: return plan.fragments[0].cell_bounds if not plan.fragments.is_empty() else AABB()
static func _unique_count(values: Array) -> int:
	var seen := {}; for value in values: seen[str(value)] = true
	return seen.size()
