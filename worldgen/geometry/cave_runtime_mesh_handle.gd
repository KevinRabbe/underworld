extends RefCounted
class_name UnderworldCaveRuntimeMeshHandle

var mesh
var cell_address
var source_fingerprint: String
var output_fingerprint: String
var triangle_count: int


func _init(mesh_value = null, address_value = null, source_value: String = "", output_value: String = "", triangles_value: int = 0) -> void:
	mesh = mesh_value
	cell_address = address_value
	source_fingerprint = source_value
	output_fingerprint = output_value
	triangle_count = triangles_value


func is_current(expected_source_fingerprint: String) -> bool:
	return expected_source_fingerprint == source_fingerprint
