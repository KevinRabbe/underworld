extends RefCounted
class_name UnderworldFacetedSkinnedMeshData

var success: bool = false
var surfaces: Array[Dictionary] = []
var bounds: AABB = AABB()
var source_fingerprint: String = ""
var diagnostics: Array[String] = []
var metrics: Dictionary = {}


func canonical_surface_descriptor() -> String:
	var lines: Array[String] = []
	for surface in surfaces:
		var vertices: PackedVector3Array = surface.get("vertices", PackedVector3Array())
		var indices: PackedInt32Array = surface.get("indices", PackedInt32Array())
		var bones: PackedInt32Array = surface.get("bones", PackedInt32Array())
		var weights: PackedFloat32Array = surface.get("weights", PackedFloat32Array())
		lines.append("%d|%d|%d|%d|%d" % [
			int(surface.get("palette_index", -1)), vertices.size(), indices.size(),
			bones.size(), weights.size(),
		])
	lines.sort()
	return ";".join(lines)
