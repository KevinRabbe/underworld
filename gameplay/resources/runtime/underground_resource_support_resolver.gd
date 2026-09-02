extends RefCounted
class_name UndergroundResourceSupportResolver

const CAVE_SUPPORT_COLLISION_MASK: int = 1
const SUPPORT_OFFSET: float = 0.02
const BOUNDS_EXTENSION: float = 0.5


## Resolves a generated free-space anchor down onto the current cave collision.
## This is a bounded realization-time query only; it creates no persistent body,
## owns no cave collision state, and returns value data only.
func resolve(realization_parent, current_entry: Dictionary, hook: Dictionary) -> Dictionary:
	var failures: Array[String] = []
	if realization_parent == null or not realization_parent is Node3D:
		failures.append("resource support resolution requires Node3D realization parent")
	if current_entry.is_empty() or not bool(current_entry.get("collision_ready", false)):
		failures.append("resource support resolution requires current collision-ready owner cell")

	var cell_address_variant = current_entry.get("cell_address", null)
	if not cell_address_variant is String or cell_address_variant.is_empty():
		failures.append("resource support resolution requires current cell address")
	var source_fingerprint_variant = current_entry.get("source_fingerprint", null)
	if not source_fingerprint_variant is String or source_fingerprint_variant.is_empty():
		failures.append("resource support resolution requires current source fingerprint")

	var anchor_variant = hook.get("free_world_anchor", null)
	if typeof(anchor_variant) != TYPE_VECTOR3:
		failures.append("resource support hook requires Vector3 free_world_anchor")
	var bounds_variant = hook.get("reserved_bounds", null)
	if typeof(bounds_variant) != TYPE_AABB:
		failures.append("resource support hook requires AABB reserved_bounds")
	if not failures.is_empty():
		return _failure(failures)

	var anchor: Vector3 = anchor_variant
	var bounds: AABB = bounds_variant
	if not _finite_vector3(anchor):
		return _failure(["resource support free_world_anchor must be finite"])
	if not _valid_bounds(bounds):
		return _failure(["resource support reserved_bounds must be finite and positive"])
	if not bounds.grow(0.001).has_point(anchor):
		return _failure(["resource support free_world_anchor must lie inside reserved_bounds"])
	var end_y: float = bounds.position.y - BOUNDS_EXTENSION
	if end_y >= anchor.y:
		return _failure(["resource support reserved_bounds do not extend below free_world_anchor"])

	var tree = realization_parent.get_tree()
	if tree == null:
		return _failure(["resource support resolution requires realization parent inside SceneTree"])

	var ray := RayCast3D.new()
	ray.enabled = true
	ray.collide_with_areas = false
	ray.collide_with_bodies = true
	ray.hit_from_inside = false
	ray.collision_mask = CAVE_SUPPORT_COLLISION_MASK
	var local_start: Vector3 = realization_parent.to_local(anchor)
	var local_end: Vector3 = realization_parent.to_local(Vector3(anchor.x, end_y, anchor.z))
	ray.position = local_start
	ray.target_position = local_end - local_start
	realization_parent.add_child(ray)
	ray.force_raycast_update()

	var collided: bool = ray.is_colliding()
	var collider = ray.get_collider() if collided else null
	var collision_point: Vector3 = ray.get_collision_point() if collided else Vector3.ZERO
	var collision_normal: Vector3 = ray.get_collision_normal() if collided else Vector3.ZERO
	_remove_query_ray(ray)

	if not collided:
		return _failure(["resource support query found no current cave support"])
	if collider == null or not collider is Node:
		return _failure(["resource support query did not resolve a semantic cave collider"])
	if str(collider.get_meta("cell_address", "")) != str(cell_address_variant):
		return _failure(["resource support query first hit is not the current owner-cell cave collider"])
	if str(collider.get_meta("source_fingerprint", "")) != str(source_fingerprint_variant):
		return _failure(["resource support query cave collider source fingerprint is stale"])
	if not _finite_vector3(collision_point) or not _finite_vector3(collision_normal):
		return _failure(["resource support query returned non-finite hit data"])
	if collision_normal.length_squared() <= 0.0:
		return _failure(["resource support query returned invalid surface normal"])

	return {
		"success": true,
		"world_position": collision_point + collision_normal.normalized() * SUPPORT_OFFSET,
		"surface_normal": collision_normal.normalized(),
		"cell_address": str(cell_address_variant),
		"source_fingerprint": str(source_fingerprint_variant),
		"diagnostics": [],
	}


static func _remove_query_ray(ray) -> void:
	if ray == null or not is_instance_valid(ray):
		return
	var parent = ray.get_parent()
	if parent != null:
		parent.remove_child(ray)
	ray.free()


static func _valid_bounds(bounds: AABB) -> bool:
	return (
		_finite_vector3(bounds.position)
		and _finite_vector3(bounds.size)
		and bounds.size.x > 0.0
		and bounds.size.y > 0.0
		and bounds.size.z > 0.0
	)


static func _finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x)
		and not is_inf(value.x)
		and not is_nan(value.y)
		and not is_inf(value.y)
		and not is_nan(value.z)
		and not is_inf(value.z)
	)


static func _failure(failures: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for failure in failures:
		diagnostics.append(str(failure))
	diagnostics.sort()
	return {
		"success": false,
		"world_position": Vector3.ZERO,
		"surface_normal": Vector3.ZERO,
		"diagnostics": diagnostics,
	}
