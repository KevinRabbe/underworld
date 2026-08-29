extends RefCounted
class_name UnderworldCaveCollisionRealizationBoundary

const CollisionData := preload("res://worldgen/runtime/cave_collision_data.gd")

static func realize_main_thread(collision_data, expected_mesh_fingerprint: String = "") -> Dictionary:
	if collision_data == null or not (collision_data is CollisionData):
		return {"success": false, "diagnostics": ["CaveCollisionData is required"]}
	if not expected_mesh_fingerprint.is_empty() and collision_data.source_mesh_fingerprint != expected_mesh_fingerprint:
		return {"success": false, "diagnostics": ["Collision source mesh fingerprint is stale"]}
	if collision_data.vertices.size() % 3 != 0:
		return {"success": false, "diagnostics": ["Collision data has no complete faces"]}
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(collision_data.vertices)
	return {
		"success": true,
		"shape": shape,
		"cell_address": collision_data.cell_address,
		"source_mesh_fingerprint": collision_data.source_mesh_fingerprint,
		"source_plan_fingerprint": collision_data.source_plan_fingerprint,
		"fingerprint": collision_data.fingerprint,
		"triangle_count": collision_data.triangle_count,
		"diagnostics": [],
	}
