extends RefCounted
class_name UnderworldCaveMeshRealizationBoundary

const MeshData := preload("res://worldgen/geometry/cave_mesh_data.gd")
const Handle := preload("res://worldgen/geometry/cave_runtime_mesh_handle.gd")

static func realize_main_thread(mesh_data, material = null, expected_source_fingerprint: String = ""):
	if mesh_data == null or not (mesh_data is MeshData):
		return {"success": false, "diagnostics": ["CaveMeshData is required"]}
	if not mesh_data.success:
		return {"success": false, "diagnostics": ["Cannot realize failed CaveMeshData"]}
	if not expected_source_fingerprint.is_empty() and mesh_data.input_fingerprint != expected_source_fingerprint:
		return {"success": false, "diagnostics": ["CaveMeshData source fingerprint is stale"]}
	if mesh_data.indices.size() % 3 != 0:
		return {"success": false, "diagnostics": ["CaveMeshData has no complete triangles"]}
	for index in mesh_data.indices:
		if index < 0 or index >= mesh_data.vertices.size():
			return {"success": false, "diagnostics": ["CaveMeshData index is out of range"]}
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var array_mesh := ArrayMesh.new()
	if not mesh_data.indices.is_empty():
		arrays[Mesh.ARRAY_VERTEX] = mesh_data.vertices
		arrays[Mesh.ARRAY_INDEX] = mesh_data.indices
		arrays[Mesh.ARRAY_NORMAL] = mesh_data.normals
		arrays[Mesh.ARRAY_TEX_UV] = mesh_data.uvs
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material != null and array_mesh.get_surface_count() > 0:
		array_mesh.surface_set_material(0, material)
	return {
		"success": true,
		"mesh": array_mesh,
		"cell_address": mesh_data.cell_address,
		"input_fingerprint": mesh_data.input_fingerprint,
		"output_fingerprint": mesh_data.output_fingerprint,
		"triangle_count": mesh_data.indices.size() / 3,
		"handle": Handle.new(array_mesh, mesh_data.cell_address, mesh_data.input_fingerprint, mesh_data.output_fingerprint, mesh_data.indices.size() / 3),
		"diagnostics": [],
	}
