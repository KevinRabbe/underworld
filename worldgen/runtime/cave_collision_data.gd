extends RefCounted
class_name UnderworldCaveCollisionData

const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")

var cell_address
var vertices: PackedVector3Array
var source_mesh_fingerprint: String
var source_plan_fingerprint: String
var source_provenance_fingerprint: String
var triangle_count: int
var fingerprint: String


func _init(address_value, vertices_value: PackedVector3Array, mesh_fingerprint_value: String, plan_fingerprint_value: String, provenance_value: String = "") -> void:
	cell_address = address_value
	vertices = vertices_value
	source_mesh_fingerprint = mesh_fingerprint_value
	source_plan_fingerprint = plan_fingerprint_value
	source_provenance_fingerprint = provenance_value
	triangle_count = vertices.size() / 3
	fingerprint = "collision-data1:" + CanonicalValue.fingerprint({
		"cell": cell_address.canonical_text() if cell_address != null else "",
		"vertices": vertices,
		"source_mesh": source_mesh_fingerprint,
		"source_plan": source_plan_fingerprint,
		"source_provenance": source_provenance_fingerprint,
	})
