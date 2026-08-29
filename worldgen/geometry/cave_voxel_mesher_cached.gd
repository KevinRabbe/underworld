extends RefCounted
class_name UnderworldCaveVoxelMesherCached

const StageResult := preload("res://worldgen/pipeline/generation_stage_result.gd")
const Request := preload("res://worldgen/geometry/cave_voxel_field_request.gd")
const MeshData := preload("res://worldgen/geometry/cave_mesh_data.gd")
const Fragment := preload("res://worldgen/geometry/geometry_cell_fragment.gd")
const LegacyMesher := preload("res://worldgen/geometry/cave_voxel_mesher.gd")

## PERF-002 extraction path. The accepted mesher remains the topology/lookup/SDF
## authority; this implementation only reuses scalar lattice samples shared by
## adjacent cubes. All mask, interpolation, edge ownership and triangle emission
## operations remain delegated to the accepted implementation.


static func build(request) -> StageResult:
	if LegacyMesher.MARCHING_CUBES_TABLE.is_empty():
		LegacyMesher.MARCHING_CUBES_TABLE = LegacyMesher._build_case_table()
		LegacyMesher.MARCHING_CUBES_EDGE_TABLE = LegacyMesher._build_edge_table(
			LegacyMesher.MARCHING_CUBES_TABLE
		)
	if request == null or not (request is Request):
		return StageResult.fail("cave_mesh_preparation", ["CaveVoxelFieldRequest is required"])
	var failures: Array[String] = request.validate()
	if not failures.is_empty():
		return StageResult.fail("cave_mesh_preparation", failures)

	var plan = request.geometry_cell_plan
	var fragments: Array = plan.fragments.duplicate()
	for candidate in fragments:
		if candidate == null or not (candidate is Fragment):
			return StageResult.fail("cave_mesh_preparation", ["Malformed or empty geometry fragment"])
	fragments.sort_custom(func(a, b): return str(a.fragment_id) < str(b.fragment_id))

	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var edge_vertices: Dictionary = {}
	var descriptor_ids: Array[String] = []
	var fragment_ids: Array[String] = []
	var rejected := 0
	for fragment in fragments:
		var bounds: AABB = fragment.clipped_source_bounds
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
			rejected += 1
		else:
			var kind := str(fragment.source_kind)
			if not ["chamber", "tunnel", "entrance", "reserved_site"].has(kind):
				return StageResult.fail("cave_mesh_preparation", ["Unknown geometry source kind: " + kind])
			if (
				kind == "chamber"
				and not [
					"ellipsoid", "arched_ellipsoid", "irregular_ellipsoid",
					"entrance_vestibule", "alcove", "junction_vault",
					"fracture_vault", "gallery", "low_oval"
				].has(str(fragment.metadata.get("shape_family", "ellipsoid")))
			):
				return StageResult.fail(
					"cave_mesh_preparation",
					["Unknown chamber shape family: " + str(fragment.metadata.get("shape_family"))]
				)
			descriptor_ids.append(fragment.source_descriptor_id)
			fragment_ids.append(fragment.fragment_id)
	if rejected > 0:
		return StageResult.fail("cave_mesh_preparation", ["Geometry fragment has non-positive clipped bounds"])

	var pitch: float = request.partition_configuration.voxel_pitch
	var cell_bounds: AABB = LegacyMesher._AABB_from_plan(plan, request.partition_configuration)
	var halo := pitch * float(request.partition_configuration.sample_halo)
	if fragments.is_empty():
		var empty_metrics := {
			"fragment_count": 0,
			"source_descriptor_count": 0,
			"vertex_count": 0,
			"index_count": 0,
			"triangle_count": 0,
			"sample_count": 0,
			"cube_count": 0,
			"sample_pitch": pitch,
			"sample_halo": request.partition_configuration.sample_halo,
			"marching_cubes_table_revision": LegacyMesher.MARCHING_CUBES_TABLE_REVISION,
			"extraction_mode": "global_signed_distance_marching_cubes",
			"memory_bytes": 0,
			"extraction_ms": 0.0,
			"preparation_ms": 0.0,
		}
		var empty_data := MeshData.new(
			plan.cell_address,
			cell_bounds,
			PackedVector3Array(),
			PackedInt32Array(),
			PackedVector3Array(),
			PackedVector2Array(),
			[],
			[],
			request.input_fingerprint,
			empty_metrics,
			[],
			true
		)
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
	var halo_bounds := AABB(
		cell_bounds.position - Vector3.ONE * halo,
		cell_bounds.size + Vector3.ONE * halo * 2.0
	)
	scan = scan.intersection(halo_bounds)

	# Cube ownership is identical to the accepted half-open cell lattice range.
	var cell_min := Vector3i(
		floori(cell_bounds.position.x / pitch),
		floori(cell_bounds.position.y / pitch),
		floori(cell_bounds.position.z / pitch)
	)
	var cell_max := Vector3i(
		ceili((cell_bounds.position.x + cell_bounds.size.x) / pitch),
		ceili((cell_bounds.position.y + cell_bounds.size.y) / pitch),
		ceili((cell_bounds.position.z + cell_bounds.size.z) / pitch)
	)
	var minimum := Vector3i(
		maxi(floori(scan.position.x / pitch), cell_min.x),
		maxi(floori(scan.position.y / pitch), cell_min.y),
		maxi(floori(scan.position.z / pitch), cell_min.z)
	)
	var maximum := Vector3i(
		mini(ceili((scan.position.x + scan.size.x) / pitch), cell_max.x),
		mini(ceili((scan.position.y + scan.size.y) / pitch), cell_max.y),
		mini(ceili((scan.position.z + scan.size.z) / pitch), cell_max.z)
	)

	var samples := 0
	var cubes := 0
	var started := Time.get_ticks_usec()
	var sample_size := Vector3i(
		maximum.x - minimum.x + 1,
		maximum.y - minimum.y + 1,
		maximum.z - minimum.z + 1
	)
	var field_cache := PackedFloat64Array()
	if maximum.x > minimum.x and maximum.y > minimum.y and maximum.z > minimum.z:
		field_cache.resize(sample_size.x * sample_size.y * sample_size.z)
		for local_x in range(sample_size.x):
			for local_y in range(sample_size.y):
				for local_z in range(sample_size.z):
					var lattice := minimum + Vector3i(local_x, local_y, local_z)
					var point := Vector3(lattice) * pitch
					field_cache[_sample_index(local_x, local_y, local_z, sample_size)] = (
						LegacyMesher._field(point, fragments, request.iso_level)
					)

	for x in range(minimum.x, maximum.x):
		for y in range(minimum.y, maximum.y):
			for z in range(minimum.z, maximum.z):
				cubes += 1
				var positions: Array[Vector3] = []
				var values: Array[float] = []
				for offset in LegacyMesher.CUBE_OFFSETS:
					var lattice := Vector3i(x + offset.x, y + offset.y, z + offset.z)
					positions.append(Vector3(lattice) * pitch)
					var local := lattice - minimum
					values.append(field_cache[_sample_index(local.x, local.y, local.z, sample_size)])
					samples += 1
				var mask := 0
				for i in range(8):
					if values[i] < request.iso_level:
						mask |= 1 << i
				if mask == 0 or mask == 255:
					continue
				for tri in LegacyMesher.MARCHING_CUBES_TABLE[mask]:
					var edge_a: int = int(tri[0])
					var edge_b: int = int(tri[1])
					var edge_c: int = int(tri[2])
					var a := LegacyMesher._edge_point(
						positions, values, LegacyMesher.CUBE_EDGES[edge_a], request.iso_level
					)
					var b := LegacyMesher._edge_point(
						positions, values, LegacyMesher.CUBE_EDGES[edge_b], request.iso_level
					)
					var c := LegacyMesher._edge_point(
						positions, values, LegacyMesher.CUBE_EDGES[edge_c], request.iso_level
					)
					LegacyMesher._append_triangle(
						a,
						b,
						c,
						[
							LegacyMesher._lattice_edge_key(Vector3i(x, y, z), edge_a),
							LegacyMesher._lattice_edge_key(Vector3i(x, y, z), edge_b),
							LegacyMesher._lattice_edge_key(Vector3i(x, y, z), edge_c),
						],
						edge_vertices,
						vertices,
						indices,
						normals,
						uvs
					)

	var memory_bytes := (
		vertices.size() * 12
		+ normals.size() * 12
		+ uvs.size() * 8
		+ indices.size() * 4
	)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var metrics := {
		"fragment_count": fragments.size(),
		"source_descriptor_count": LegacyMesher._unique_count(descriptor_ids),
		"vertex_count": vertices.size(),
		"index_count": indices.size(),
		"triangle_count": indices.size() / 3,
		# Keep accepted metric semantics/identity stable: sample_count means logical
		# cube-corner sample accesses, not physical SDF evaluations.
		"sample_count": samples,
		"cube_count": cubes,
		"sample_pitch": pitch,
		"sample_halo": request.partition_configuration.sample_halo,
		"marching_cubes_table_revision": LegacyMesher.MARCHING_CUBES_TABLE_REVISION,
		"extraction_mode": "global_signed_distance_marching_cubes",
		"memory_bytes": memory_bytes,
		"extraction_ms": elapsed_ms,
		"preparation_ms": elapsed_ms,
	}
	var data := MeshData.new(
		plan.cell_address,
		cell_bounds,
		vertices,
		indices,
		normals,
		uvs,
		descriptor_ids,
		fragment_ids,
		request.input_fingerprint,
		metrics,
		[],
		true
	)
	return StageResult.ok("cave_mesh_preparation", data, data.fingerprint)


static func prepare(request) -> StageResult:
	return build(request)


static func _sample_index(x: int, y: int, z: int, size: Vector3i) -> int:
	return (x * size.y + y) * size.z + z
