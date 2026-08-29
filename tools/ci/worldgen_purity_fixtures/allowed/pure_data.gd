extends RefCounted

const StableId := preload("res://worldgen/identity/stable_id.gd")

var bounds: AABB = AABB(Vector3.ZERO, Vector3.ONE)
var values: Dictionary = {"node_label": "Node3D is prose, not a symbol"}


func build(points: Array[Vector3]) -> Dictionary:
	# Node3D and get_tree() in comments must not trip the guard.
	return {"count": points.size(), "id_type": StableId}
