extends RefCounted
class_name UnderworldCaveVoxelMesher

const StageResult := preload("res://worldgen/pipeline/generation_stage_result.gd")
const Request := preload("res://worldgen/geometry/cave_voxel_field_request.gd")
const MeshData := preload("res://worldgen/geometry/cave_mesh_data.gd")
const Fragment := preload("res://worldgen/geometry/geometry_cell_fragment.gd")

## Versioned canonical Marching-Cubes lookup contract (Paul Bourke topology).
const MARCHING_CUBES_TABLE_REVISION: int = 2
const CUBE_OFFSETS: Array = [Vector3i(0,0,0), Vector3i(1,0,0), Vector3i(1,1,0), Vector3i(0,1,0), Vector3i(0,0,1), Vector3i(1,0,1), Vector3i(1,1,1), Vector3i(0,1,1)]
const CUBE_EDGES: Array = [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]]
static var MARCHING_CUBES_TABLE: Array = []
static var MARCHING_CUBES_EDGE_TABLE: Array = []
const CANONICAL_TRIANGLE_TABLE_JSON: String = "[[],[0,8,3],[0,1,9],[1,8,3,9,8,1],[1,2,10],[0,8,3,1,2,10],[9,2,10,0,2,9],[2,8,3,2,10,8,10,9,8],[3,11,2],[0,11,2,8,11,0],[1,9,0,2,3,11],[1,11,2,1,9,11,9,8,11],[3,10,1,11,10,3],[0,10,1,0,8,10,8,11,10],[3,9,0,3,11,9,11,10,9],[9,8,10,10,8,11],[4,7,8],[4,3,0,7,3,4],[0,1,9,8,4,7],[4,1,9,4,7,1,7,3,1],[1,2,10,8,4,7],[3,4,7,3,0,4,1,2,10],[9,2,10,9,0,2,8,4,7],[2,10,9,2,9,7,2,7,3,7,9,4],[8,4,7,3,11,2],[11,4,7,11,2,4,2,0,4],[9,0,1,8,4,7,2,3,11],[4,7,11,9,4,11,9,11,2,9,2,1],[3,10,1,3,11,10,7,8,4],[1,11,10,1,4,11,1,0,4,7,11,4],[4,7,8,9,0,11,9,11,10,11,0,3],[4,7,11,4,11,9,9,11,10],[9,5,4],[9,5,4,0,8,3],[0,5,4,1,5,0],[8,5,4,8,3,5,3,1,5],[1,2,10,9,5,4],[3,0,8,1,2,10,4,9,5],[5,2,10,5,4,2,4,0,2],[2,10,5,3,2,5,3,5,4,3,4,8],[9,5,4,2,3,11],[0,11,2,0,8,11,4,9,5],[0,5,4,0,1,5,2,3,11],[2,1,5,2,5,8,2,8,11,4,8,5],[10,3,11,10,1,3,9,5,4],[4,9,5,0,8,1,8,10,1,8,11,10],[5,4,0,5,0,11,5,11,10,11,0,3],[5,4,8,5,8,10,10,8,11],[9,7,8,5,7,9],[9,3,0,9,5,3,5,7,3],[0,7,8,0,1,7,1,5,7],[1,5,3,3,5,7],[9,7,8,9,5,7,10,1,2],[10,1,2,9,5,0,5,3,0,5,7,3],[8,0,2,8,2,5,8,5,7,10,5,2],[2,10,5,2,5,3,3,5,7],[7,9,5,7,8,9,3,11,2],[9,5,7,9,7,2,9,2,0,2,7,11],[2,3,11,0,1,8,1,7,8,1,5,7],[11,2,1,11,1,7,7,1,5],[9,5,8,8,5,7,10,1,3,10,3,11],[5,7,0,5,0,9,7,11,0,1,0,10,11,10,0],[11,10,0,11,0,3,10,5,0,8,0,7,5,7,0],[11,10,5,7,11,5],[10,6,5],[0,8,3,5,10,6],[9,0,1,5,10,6],[1,8,3,1,9,8,5,10,6],[1,6,5,2,6,1],[1,6,5,1,2,6,3,0,8],[9,6,5,9,0,6,0,2,6],[5,9,8,5,8,2,5,2,6,3,2,8],[2,3,11,10,6,5],[11,0,8,11,2,0,10,6,5],[0,1,9,2,3,11,5,10,6],[5,10,6,1,9,2,9,11,2,9,8,11],[6,3,11,6,5,3,5,1,3],[0,8,11,0,11,5,0,5,1,5,11,6],[3,11,6,0,3,6,0,6,5,0,5,9],[6,5,9,6,9,11,11,9,8],[5,10,6,4,7,8],[4,3,0,4,7,3,6,5,10],[1,9,0,5,10,6,8,4,7],[10,6,5,1,9,7,1,7,3,7,9,4],[6,1,2,6,5,1,4,7,8],[1,2,5,5,2,6,3,0,4,3,4,7],[8,4,7,9,0,5,0,6,5,0,2,6],[7,3,9,7,9,4,3,2,9,5,9,6,2,6,9],[3,11,2,7,8,4,10,6,5],[5,10,6,4,7,2,4,2,0,2,7,11],[0,1,9,4,7,8,2,3,11,5,10,6],[9,2,1,9,11,2,9,4,11,7,11,4,5,10,6],[8,4,7,3,11,5,3,5,1,5,11,6],[5,1,11,5,11,6,1,0,11,7,11,4,0,4,11],[0,5,9,0,6,5,0,3,6,11,6,3,8,4,7],[6,5,9,6,9,11,4,7,9,7,11,9],[10,4,9,6,4,10],[4,10,6,4,9,10,0,8,3],[10,0,1,10,6,0,6,4,0],[8,3,1,8,1,6,8,6,4,6,1,10],[1,4,9,1,2,4,2,6,4],[3,0,8,1,2,9,2,4,9,2,6,4],[0,2,4,4,2,6],[8,3,2,8,2,4,4,2,6],[10,4,9,10,6,4,11,2,3],[0,8,2,2,8,11,4,9,10,4,10,6],[3,11,2,0,1,6,0,6,4,6,1,10],[6,4,1,6,1,10,4,8,1,2,1,11,8,11,1],[9,6,4,9,3,6,9,1,3,11,6,3],[8,11,1,8,1,0,11,6,1,9,1,4,6,4,1],[3,11,6,3,6,0,0,6,4],[6,4,8,11,6,8],[7,10,6,7,8,10,8,9,10],[0,7,3,0,10,7,0,9,10,6,7,10],[10,6,7,1,10,7,1,7,8,1,8,0],[10,6,7,10,7,1,1,7,3],[1,2,6,1,6,8,1,8,9,8,6,7],[2,6,9,2,9,1,6,7,9,0,9,3,7,3,9],[7,8,0,7,0,6,6,0,2],[7,3,2,6,7,2],[2,3,11,10,6,8,10,8,9,8,6,7],[2,0,7,2,7,11,0,9,7,6,7,10,9,10,7],[1,8,0,1,7,8,1,10,7,6,7,10,2,3,11],[11,2,1,11,1,7,10,6,1,6,7,1],[8,9,6,8,6,7,9,1,6,11,6,3,1,3,6],[0,9,1,11,6,7],[7,8,0,7,0,6,3,11,0,11,6,0],[7,11,6],[7,6,11],[3,0,8,11,7,6],[0,1,9,11,7,6],[8,1,9,8,3,1,11,7,6],[10,1,2,6,11,7],[1,2,10,3,0,8,6,11,7],[2,9,0,2,10,9,6,11,7],[6,11,7,2,10,3,10,8,3,10,9,8],[7,2,3,6,2,7],[7,0,8,7,6,0,6,2,0],[2,7,6,2,3,7,0,1,9],[1,6,2,1,8,6,1,9,8,8,7,6],[10,7,6,10,1,7,1,3,7],[10,7,6,1,7,10,1,8,7,1,0,8],[0,3,7,0,7,10,0,10,9,6,10,7],[7,6,10,7,10,8,8,10,9],[6,8,4,11,8,6],[3,6,11,3,0,6,0,4,6],[8,6,11,8,4,6,9,0,1],[9,4,6,9,6,3,9,3,1,11,3,6],[6,8,4,6,11,8,2,10,1],[1,2,10,3,0,11,0,6,11,0,4,6],[4,11,8,4,6,11,0,2,9,2,10,9],[10,9,3,10,3,2,9,4,3,11,3,6,4,6,3],[8,2,3,8,4,2,4,6,2],[0,4,2,4,6,2],[1,9,0,2,3,4,2,4,6,4,3,8],[1,9,4,1,4,2,2,4,6],[8,1,3,8,6,1,8,4,6,6,10,1],[10,1,0,10,0,6,6,0,4],[4,6,3,4,3,8,6,10,3,0,3,9,10,9,3],[10,9,4,6,10,4],[4,9,5,7,6,11],[0,8,3,4,9,5,11,7,6],[5,0,1,5,4,0,7,6,11],[11,7,6,8,3,4,3,5,4,3,1,5],[9,5,4,10,1,2,7,6,11],[6,11,7,1,2,10,0,8,3,4,9,5],[7,6,11,5,4,10,4,2,10,4,0,2],[3,4,8,3,5,4,3,2,5,10,5,2,11,7,6],[7,2,3,7,6,2,5,4,9],[9,5,4,0,8,6,0,6,2,6,8,7],[3,6,2,3,7,6,1,5,0,5,4,0],[6,2,8,6,8,7,2,1,8,4,8,5,1,5,8],[9,5,4,10,1,6,1,7,6,1,3,7],[1,6,10,1,7,6,1,0,7,8,7,0,9,5,4],[4,0,10,4,10,5,0,3,10,6,10,7,3,7,10],[7,6,10,7,10,8,5,4,10,4,8,10],[6,9,5,6,11,9,11,8,9],[3,6,11,0,6,3,0,5,6,0,9,5],[0,11,8,0,5,11,0,1,5,5,6,11],[6,11,3,6,3,5,5,3,1],[1,2,10,9,5,11,9,11,8,11,5,6],[0,11,3,0,6,11,0,9,6,5,6,9,1,2,10],[11,8,5,11,5,6,8,0,5,10,5,2,0,2,5],[6,11,3,6,3,5,2,10,3,10,5,3],[5,8,9,5,2,8,5,6,2,3,8,2],[9,5,6,9,6,0,0,6,2],[1,5,8,1,8,0,5,6,8,3,8,2,6,2,8],[1,5,6,2,1,6],[1,3,6,1,6,10,3,8,6,5,6,9,8,9,6],[10,1,0,10,0,6,9,5,0,5,6,0],[0,3,8,5,6,10],[10,5,6],[11,5,10,7,5,11],[11,5,10,11,7,5,8,3,0],[5,11,7,5,10,11,1,9,0],[10,7,5,10,11,7,9,8,1,8,3,1],[11,1,2,11,7,1,7,5,1],[0,8,3,1,2,7,1,7,5,7,2,11],[9,7,5,9,2,7,9,0,2,2,11,7],[7,5,2,7,2,11,5,9,2,3,2,8,9,8,2],[2,5,10,2,3,5,3,7,5],[8,2,0,8,5,2,8,7,5,10,2,5],[9,0,1,5,10,3,5,3,7,3,10,2],[9,8,2,9,2,1,8,7,2,10,2,5,7,5,2],[1,3,5,3,7,5],[0,8,7,0,7,1,1,7,5],[9,0,3,9,3,5,5,3,7],[9,8,7,5,9,7],[5,8,4,5,10,8,10,11,8],[5,0,4,5,11,0,5,10,11,11,3,0],[0,1,9,8,4,10,8,10,11,10,4,5],[10,11,4,10,4,5,11,3,4,9,4,1,3,1,4],[2,5,1,2,8,5,2,11,8,4,5,8],[0,4,11,0,11,3,4,5,11,2,11,1,5,1,11],[0,2,5,0,5,9,2,11,5,4,5,8,11,8,5],[9,4,5,2,11,3],[2,5,10,3,5,2,3,4,5,3,8,4],[5,10,2,5,2,4,4,2,0],[3,10,2,3,5,10,3,8,5,4,5,8,0,1,9],[5,10,2,5,2,4,1,9,2,9,4,2],[8,4,5,8,5,3,3,5,1],[0,4,5,1,0,5],[8,4,5,8,5,3,9,0,5,0,3,5],[9,4,5],[4,11,7,4,9,11,9,10,11],[0,8,3,4,9,7,9,11,7,9,10,11],[1,10,11,1,11,4,1,4,0,7,4,11],[3,1,4,3,4,8,1,10,4,7,4,11,10,11,4],[4,11,7,9,11,4,9,2,11,9,1,2],[9,7,4,9,11,7,9,1,11,2,11,1,0,8,3],[11,7,4,11,4,2,2,4,0],[11,7,4,11,4,2,8,3,4,3,2,4],[2,9,10,2,7,9,2,3,7,7,4,9],[9,10,7,9,7,4,10,2,7,8,7,0,2,0,7],[3,7,10,3,10,2,7,4,10,1,10,0,4,0,10],[1,10,2,8,7,4],[4,9,1,4,1,7,7,1,3],[4,9,1,4,1,7,0,8,1,8,7,1],[4,0,3,7,4,3],[4,8,7],[9,10,8,10,11,8],[3,0,9,3,9,11,11,9,10],[0,1,10,0,10,8,8,10,11],[3,1,10,11,3,10],[1,2,11,1,11,9,9,11,8],[3,0,9,3,9,11,1,2,9,2,11,9],[0,2,11,8,0,11],[3,2,11],[2,3,8,2,8,10,10,8,9],[9,10,2,0,9,2],[2,3,8,2,8,10,0,1,8,1,10,8],[1,10,2],[1,3,8,9,1,8],[0,9,1],[0,3,8],[]]"

static func build(request) -> StageResult:
	if MARCHING_CUBES_TABLE.is_empty():
		MARCHING_CUBES_TABLE = _build_case_table()
		MARCHING_CUBES_EDGE_TABLE = _build_edge_table(MARCHING_CUBES_TABLE)
	if request == null or not (request is Request): return StageResult.fail("cave_mesh_preparation", ["CaveVoxelFieldRequest is required"])
	var failures: Array[String] = request.validate()
	if not failures.is_empty(): return StageResult.fail("cave_mesh_preparation", failures)
	var plan = request.geometry_cell_plan
	var fragments: Array = plan.fragments.duplicate()
	for candidate in fragments:
		if candidate == null or not (candidate is Fragment): return StageResult.fail("cave_mesh_preparation", ["Malformed or empty geometry fragment"])
	fragments.sort_custom(func(a, b): return str(a.fragment_id) < str(b.fragment_id))
	var vertices := PackedVector3Array(); var indices := PackedInt32Array(); var normals := PackedVector3Array(); var uvs := PackedVector2Array(); var edge_vertices: Dictionary = {}
	var descriptor_ids: Array[String] = []; var fragment_ids: Array[String] = []; var rejected := 0
	for fragment in fragments:
		var bounds: AABB = fragment.clipped_source_bounds
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0: rejected += 1
		else:
			var kind := str(fragment.source_kind)
			if not ["chamber", "tunnel", "entrance", "reserved_site"].has(kind): return StageResult.fail("cave_mesh_preparation", ["Unknown geometry source kind: " + kind])
			if kind == "chamber" and not ["ellipsoid", "arched_ellipsoid", "irregular_ellipsoid", "entrance_vestibule", "alcove", "junction_vault", "fracture_vault", "gallery", "low_oval"].has(str(fragment.metadata.get("shape_family", "ellipsoid"))): return StageResult.fail("cave_mesh_preparation", ["Unknown chamber shape family: " + str(fragment.metadata.get("shape_family"))])
			descriptor_ids.append(fragment.source_descriptor_id); fragment_ids.append(fragment.fragment_id)
	if rejected > 0: return StageResult.fail("cave_mesh_preparation", ["Geometry fragment has non-positive clipped bounds"])
	var pitch: float = request.partition_configuration.voxel_pitch
	var cell_bounds: AABB = _AABB_from_plan(plan); var halo := pitch * float(request.partition_configuration.sample_halo)
	if fragments.is_empty():
		var empty_metrics := {"fragment_count": 0, "source_descriptor_count": 0, "vertex_count": 0, "index_count": 0, "triangle_count": 0, "sample_count": 0, "cube_count": 0, "sample_pitch": pitch, "sample_halo": request.partition_configuration.sample_halo, "marching_cubes_table_revision": MARCHING_CUBES_TABLE_REVISION, "extraction_mode": "global_signed_distance_marching_cubes", "memory_bytes": 0, "extraction_ms": 0.0, "preparation_ms": 0.0}
		var empty_data := MeshData.new(plan.cell_address, cell_bounds, PackedVector3Array(), PackedInt32Array(), PackedVector3Array(), PackedVector2Array(), [], [], request.input_fingerprint, empty_metrics, [], true)
		return StageResult.ok("cave_mesh_preparation", empty_data, empty_data.fingerprint)
	var scan := AABB()
	var scan_initialized := false
	for fragment in fragments:
		var fragment_scan: AABB = fragment.clipped_source_bounds.grow(halo)
		if not scan_initialized:
			scan = fragment_scan
			scan_initialized = true
		else:
			scan = scan.merge(fragment_scan)
	var halo_bounds := AABB(cell_bounds.position - Vector3.ONE * halo, cell_bounds.size + Vector3.ONE * halo * 2.0)
	scan = scan.intersection(halo_bounds)
	var minimum := Vector3i(floori(scan.position.x / pitch), floori(scan.position.y / pitch), floori(scan.position.z / pitch)); var maximum := Vector3i(ceili((scan.position.x + scan.size.x) / pitch), ceili((scan.position.y + scan.size.y) / pitch), ceili((scan.position.z + scan.size.z) / pitch))
	var samples := 0; var cubes := 0; var started := Time.get_ticks_usec()
	for x in range(minimum.x, maximum.x):
		for y in range(minimum.y, maximum.y):
			for z in range(minimum.z, maximum.z):
				cubes += 1; var positions: Array[Vector3] = []; var values: Array[float] = []
				for offset in CUBE_OFFSETS:
					var point := Vector3(Vector3i(x + offset.x, y + offset.y, z + offset.z)) * pitch; positions.append(point); values.append(_field(point, fragments, request.iso_level)); samples += 1
				var mask := 0
				for i in range(8):
					if values[i] < request.iso_level: mask |= 1 << i
				if mask == 0 or mask == 255: continue
				for tri in MARCHING_CUBES_TABLE[mask]:
					var edge_a: int = int(tri[0]); var edge_b: int = int(tri[1]); var edge_c: int = int(tri[2])
					var a := _edge_point(positions, values, CUBE_EDGES[edge_a], request.iso_level); var b := _edge_point(positions, values, CUBE_EDGES[edge_b], request.iso_level); var c := _edge_point(positions, values, CUBE_EDGES[edge_c], request.iso_level)
					_append_triangle(a, b, c, [_lattice_edge_key(Vector3i(x, y, z), edge_a), _lattice_edge_key(Vector3i(x, y, z), edge_b), _lattice_edge_key(Vector3i(x, y, z), edge_c)], edge_vertices, vertices, indices, normals, uvs)
	var fallback_count := 0
	if indices.is_empty() and not fragments.is_empty():
		for fragment in fragments:
			_append_box_shell(fragment.clipped_source_bounds, vertices, indices, normals, uvs)
			fallback_count += 1
	var memory_bytes := vertices.size() * 12 + normals.size() * 12 + uvs.size() * 8 + indices.size() * 4
	var metrics := {"fragment_count": fragments.size(), "source_descriptor_count": _unique_count(descriptor_ids), "vertex_count": vertices.size(), "index_count": indices.size(), "triangle_count": indices.size() / 3, "sample_count": samples, "cube_count": cubes, "sample_pitch": pitch, "sample_halo": request.partition_configuration.sample_halo, "marching_cubes_table_revision": MARCHING_CUBES_TABLE_REVISION, "extraction_mode": "global_signed_distance_marching_cubes", "fallback_shell_count": fallback_count, "memory_bytes": memory_bytes, "extraction_ms": float(Time.get_ticks_usec() - started) / 1000.0, "preparation_ms": float(Time.get_ticks_usec() - started) / 1000.0}
	var data := MeshData.new(plan.cell_address, cell_bounds, vertices, indices, normals, uvs, descriptor_ids, fragment_ids, request.input_fingerprint, metrics, [], true)
	return StageResult.ok("cave_mesh_preparation", data, data.fingerprint)

static func prepare(request) -> StageResult: return build(request)

static func _field(point: Vector3, fragments: Array, iso: float) -> float:
	var value := INF
	for fragment in fragments:
		if fragment.source_kind == "reserved_site": continue
		value = minf(value, _source_sdf(point, fragment))
	return value if value != INF else 1.0

static func _source_sdf(point: Vector3, fragment) -> float:
	var metadata: Dictionary = fragment.metadata
	match str(fragment.source_kind):
		"chamber":
			var center: Vector3 = metadata.get("center", fragment.clipped_source_bounds.get_center()); var dimensions: Vector3 = metadata.get("dimensions", fragment.clipped_source_bounds.size); var local := (point - center).rotated(Vector3.UP, -float(metadata.get("rotation_y", 0.0))); var radius := maxf(minf(dimensions.x, minf(dimensions.y, dimensions.z)) * 0.5, 0.01); var q := Vector3(local.x / maxf(dimensions.x * 0.5, 0.01), local.y / maxf(dimensions.y * 0.5, 0.01), local.z / maxf(dimensions.z * 0.5, 0.01)); return (q.length() - 1.0) * radius + _roughness(point, fragment)
		"tunnel":
			var points: Array = metadata.get("control_points", []); var best := INF
			for i in range(maxi(points.size() - 1, 0)):
				var a: Vector3 = points[i]; var b: Vector3 = points[i + 1]; var ab := b - a; var t := clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0); best = minf(best, point.distance_to(a.lerp(b, t)))
			var radius := maxf(minf(float(metadata.get("width", 2.0)), float(metadata.get("height", 2.0))) * 0.5, 0.1); return best - radius + _roughness(point, fragment)
		"entrance": return _box_sdf(point, metadata.get("required_opening_bounds", fragment.clipped_source_bounds)) + _roughness(point, fragment)
		_: return _box_sdf(point, fragment.clipped_source_bounds)

static func _box_sdf(point: Vector3, bounds: AABB) -> float:
	var q := (point - bounds.get_center()).abs() - bounds.size * 0.5; var outside := Vector3(maxf(q.x, 0.0), maxf(q.y, 0.0), maxf(q.z, 0.0)); return outside.length() + minf(maxf(q.x, maxf(q.y, q.z)), 0.0)

static func _roughness(point: Vector3, fragment) -> float:
	var phase := float(abs(hash(str(fragment.source_descriptor_id))) % 997) * 0.017; return sin(point.x * 0.31 + phase) * sin(point.y * 0.23 + phase * 1.7) * sin(point.z * 0.19 + phase * 0.61) * 0.035

static func _edge_point(positions: Array, values: Array, edge: Array, iso: float) -> Vector3:
	var a: int = int(edge[0]); var b: int = int(edge[1]); var denominator := float(values[b]) - float(values[a]); var t := 0.5 if absf(denominator) < 0.000001 else clampf((iso - float(values[a])) / denominator, 0.0, 1.0); return positions[a].lerp(positions[b], t)

static func _append_triangle(a: Vector3, b: Vector3, c: Vector3, edge_keys: Array, edge_vertices: Dictionary, vertices: PackedVector3Array, indices: PackedInt32Array, normals: PackedVector3Array, uvs: PackedVector2Array) -> void:
	var cross := (b - a).cross(c - a); if cross.length_squared() < 0.00000001: return
	# The canonical table is wound for the solid side. The cave void is the
	# negative side, so reverse once and derive stable inward face normals.
	var swap := b
	b = c
	c = swap
	var key_swap = edge_keys[1]
	edge_keys[1] = edge_keys[2]
	edge_keys[2] = key_swap
	var inward_normal := -(c - a).cross(b - a).normalized()
	var ids: Array[int] = []
	for point_index in 3:
		var point: Vector3 = [a, b, c][point_index]
		var key: String = str(edge_keys[point_index])
		if not edge_vertices.has(key):
			edge_vertices[key] = vertices.size(); vertices.append(point); normals.append(inward_normal if inward_normal.length_squared() > 0.000001 else Vector3.UP); uvs.append(Vector2(point.x + point.z, point.y) * 0.0625)
		ids.append(int(edge_vertices[key]))
	indices.append_array(PackedInt32Array([ids[0], ids[1], ids[2]]))

static func _field_gradient(point: Vector3, fragments: Array, step: float) -> Vector3:
	var e := maxf(step * 0.5, 0.001); return Vector3(_field(point + Vector3(e,0,0), fragments, 0.0) - _field(point - Vector3(e,0,0), fragments, 0.0), _field(point + Vector3(0,e,0), fragments, 0.0) - _field(point - Vector3(0,e,0), fragments, 0.0), _field(point + Vector3(0,0,e), fragments, 0.0) - _field(point - Vector3(0,0,e), fragments, 0.0))

static func _append_box_shell(bounds: AABB, vertices: PackedVector3Array, indices: PackedInt32Array, normals: PackedVector3Array, uvs: PackedVector2Array) -> void:
	var p := bounds.position; var q := p + bounds.size
	var corners := [Vector3(p.x,p.y,p.z),Vector3(q.x,p.y,p.z),Vector3(q.x,q.y,p.z),Vector3(p.x,q.y,p.z),Vector3(p.x,p.y,q.z),Vector3(q.x,p.y,q.z),Vector3(q.x,q.y,q.z),Vector3(p.x,q.y,q.z)]
	for face in [[0,3,2,1],[4,5,6,7],[0,1,5,4],[3,7,6,2],[0,4,7,3],[1,2,6,5]]:
		var start := vertices.size()
		for index in face:
			var point: Vector3 = corners[index]; vertices.append(point); normals.append(Vector3.UP); uvs.append(Vector2(point.x + point.z, point.y) * 0.0625)
		indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))

static func _lattice_edge_key(cube: Vector3i, edge_index: int) -> String:
	var endpoints: Array = CUBE_EDGES[edge_index]
	var first: Vector3i = cube + CUBE_OFFSETS[int(endpoints[0])]
	var second: Vector3i = cube + CUBE_OFFSETS[int(endpoints[1])]
	if first.x > second.x or (first.x == second.x and (first.y > second.y or (first.y == second.y and first.z > second.z))):
		var swap := first
		first = second
		second = swap
	return "%d:%d:%d-%d:%d:%d" % [first.x, first.y, first.z, second.x, second.y, second.z]
static func _AABB_from_plan(plan) -> AABB: return plan.fragments[0].cell_bounds if not plan.fragments.is_empty() else AABB()
static func _unique_count(values: Array) -> int:
	var seen := {}; for value in values: seen[str(value)] = true
	return seen.size()

static func _build_case_table() -> Array:
	var rows: Array = JSON.parse_string(CANONICAL_TRIANGLE_TABLE_JSON)
	var table: Array = []
	for row in rows:
		var triangles: Array = []
		for offset in range(0, row.size(), 3): triangles.append([int(row[offset]), int(row[offset + 1]), int(row[offset + 2])])
		table.append(triangles)
	return table

static func _build_edge_table(table: Array) -> Array:
	var edge_table: Array = []
	for triangles in table:
		var mask := 0
		for triangle in triangles:
			for edge in triangle: mask |= 1 << int(edge)
		edge_table.append(mask)
	return edge_table
