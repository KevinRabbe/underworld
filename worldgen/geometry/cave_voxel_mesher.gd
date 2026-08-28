extends RefCounted
class_name UnderworldCaveVoxelMesher

const StageResult := preload("res://worldgen/pipeline/generation_stage_result.gd")
const Request := preload("res://worldgen/geometry/cave_voxel_field_request.gd")
const MeshData := preload("res://worldgen/geometry/cave_mesh_data.gd")
const Fragment := preload("res://worldgen/geometry/geometry_cell_fragment.gd")


static func build(request) -> StageResult:
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
	var descriptors: Array[String] = []
	var fragment_ids: Array[String] = []
	var rejected := 0
	for fragment in fragments:
		if fragment == null or not (fragment is Fragment):
			rejected += 1
			continue
		var bounds: AABB = fragment.clipped_source_bounds
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
			rejected += 1
			continue
		_append_box(bounds, vertices, indices, normals, uvs)
		descriptors.append(fragment.source_descriptor_id)
		fragment_ids.append(fragment.fragment_id)
	if rejected > 0:
		return StageResult.fail("cave_mesh_preparation", ["Malformed or empty geometry fragment"])
	var metrics := {
		"fragment_count": fragments.size(),
		"source_descriptor_count": _unique_count(descriptors),
		"vertex_count": vertices.size(),
		"index_count": indices.size(),
		"triangle_count": indices.size() / 3,
		"rejected_fragment_count": rejected,
		"preparation_ms": 0,
	}
	var data := MeshData.new(
		plan.cell_address,
		_AABB_from_plan(plan),
		vertices, indices, normals, uvs,
		descriptors, fragment_ids, plan.fingerprint, metrics, [], true
	)
	return StageResult.ok("cave_mesh_preparation", data, data.fingerprint)


static func prepare(request) -> StageResult:
	return build(request)


static func _append_box(bounds: AABB, vertices: PackedVector3Array, indices: PackedInt32Array, normals: PackedVector3Array, uvs: PackedVector2Array) -> void:
	var p := bounds.position
	var q := bounds.position + bounds.size
	var corners := [
		Vector3(p.x, p.y, p.z), Vector3(q.x, p.y, p.z), Vector3(q.x, q.y, p.z), Vector3(p.x, q.y, p.z),
		Vector3(p.x, p.y, q.z), Vector3(q.x, p.y, q.z), Vector3(q.x, q.y, q.z), Vector3(p.x, q.y, q.z),
	]
	# Faces are wound toward the navigable void: normals point inward.
	var faces := [
		[[0, 3, 2, 1], Vector3(0, 0, 1)], [[4, 5, 6, 7], Vector3(0, 0, -1)],
		[[0, 1, 5, 4], Vector3(0, 1, 0)], [[3, 7, 6, 2], Vector3(0, -1, 0)],
		[[0, 4, 7, 3], Vector3(1, 0, 0)], [[1, 2, 6, 5], Vector3(-1, 0, 0)],
	]
	for face in faces:
		var start := vertices.size()
		var ids: Array = face[0]
		var normal: Vector3 = face[1]
		for i in range(4):
			vertices.append(corners[ids[i]])
			normals.append(normal)
			var v: Vector3 = corners[ids[i]]
			uvs.append(Vector2(v.x + v.z, v.y) * 0.0625)
		indices.append_array(PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))


static func _AABB_from_plan(plan) -> AABB:
	if plan.fragments.is_empty():
		return AABB()
	return plan.fragments[0].cell_bounds


static func _unique_count(values: Array) -> int:
	var seen := {}
	for value in values:
		seen[str(value)] = true
	return seen.size()
