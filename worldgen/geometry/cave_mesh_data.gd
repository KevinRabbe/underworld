extends RefCounted
class_name UnderworldCaveMeshData

const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")

var cell_address
var world_bounds: AABB
var vertices: PackedVector3Array
var indices: PackedInt32Array
var normals: PackedVector3Array
var uvs: PackedVector2Array
var source_descriptor_ids: Array[String]
var source_fragment_ids: Array[String]
var input_fingerprint: String
var output_fingerprint: String
var metrics: Dictionary
var diagnostics: Array[String]
var success: bool
var fingerprint: String


func _init(
	cell_address_value,
	world_bounds_value: AABB,
	vertices_value: PackedVector3Array,
	indices_value: PackedInt32Array,
	normals_value: PackedVector3Array,
	uvs_value: PackedVector2Array,
	source_descriptor_ids_value: Array = [],
	source_fragment_ids_value: Array = [],
	input_fingerprint_value: String = "",
	metrics_value: Dictionary = {},
	diagnostics_value: Array[String] = [],
	success_value: bool = true
) -> void:
	cell_address = cell_address_value
	world_bounds = world_bounds_value
	vertices = vertices_value
	indices = indices_value
	normals = normals_value
	uvs = uvs_value
	source_descriptor_ids = []
	for value in source_descriptor_ids_value:
		source_descriptor_ids.append(str(value))
	source_descriptor_ids.sort()
	source_fragment_ids = []
	for value in source_fragment_ids_value:
		source_fragment_ids.append(str(value))
	source_fragment_ids.sort()
	input_fingerprint = input_fingerprint_value
	metrics = metrics_value.duplicate(true)
	diagnostics = diagnostics_value.duplicate()
	success = success_value
	output_fingerprint = ""
	if success:
		output_fingerprint = "mesh-buffers1:" + CanonicalValue.fingerprint({
			"cell": cell_address.canonical_text() if cell_address != null else "",
			"input": input_fingerprint,
			"vertices": _packed_to_array(vertices),
			"indices": _packed_to_array(indices),
			"normals": _packed_to_array(normals),
			"uvs": _packed_to_array(uvs),
		})
	fingerprint = "cmesh-data1:" + CanonicalValue.fingerprint(canonical_data())


static func _packed_to_array(values) -> Array:
	var result: Array = []
	for value in values:
		result.append(value)
	return result


func canonical_data() -> Dictionary:
	return {
		"cell": cell_address.canonical_text() if cell_address != null else "",
		"world_bounds": world_bounds,
		"vertices": vertices,
		"indices": indices,
		"normals": normals,
		"uvs": uvs,
		"source_descriptor_ids": source_descriptor_ids,
		"source_fragment_ids": source_fragment_ids,
		"input_fingerprint": input_fingerprint,
		"output_fingerprint": output_fingerprint,
		# Wall-clock timings are observational diagnostics and must never alter
		# deterministic mesh identity.
		"metrics": _identity_metrics(),
		"success": success,
	}


func _identity_metrics() -> Dictionary:
	var result := metrics.duplicate(true)
	for key in result.keys():
		var name := str(key).to_lower()
		if name.ends_with("_ms") or name.ends_with("_usec") or name in ["elapsed_ms", "duration_ms"]:
			result.erase(key)
	return result
