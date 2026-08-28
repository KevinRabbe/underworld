extends RefCounted
class_name UnderworldCaveCollisionBuilder

const MeshData := preload("res://worldgen/geometry/cave_mesh_data.gd")
const CollisionData := preload("res://worldgen/runtime/cave_collision_data.gd")
const StageResult := preload("res://worldgen/pipeline/generation_stage_result.gd")

static func prepare(mesh_data, provenance_fingerprint: String = "") -> StageResult:
	if mesh_data == null or not (mesh_data is MeshData):
		return StageResult.fail("collision_preparation", ["CaveMeshData is required"])
	if not mesh_data.success:
		return StageResult.fail("collision_preparation", ["Cannot build collision from failed mesh data"])
	if mesh_data.indices.is_empty() or mesh_data.indices.size() % 3 != 0:
		return StageResult.fail("collision_preparation", ["Mesh data has no complete triangles"])
	var faces := PackedVector3Array()
	for index in mesh_data.indices:
		if index < 0 or index >= mesh_data.vertices.size():
			return StageResult.fail("collision_preparation", ["Mesh index is out of range"])
		faces.append(mesh_data.vertices[index])
	var data := CollisionData.new(
		mesh_data.cell_address,
		faces,
		mesh_data.output_fingerprint,
		mesh_data.input_fingerprint,
		provenance_fingerprint
	)
	return StageResult.ok("collision_preparation", data, data.fingerprint)
