extends RefCounted
class_name PlayerCollisionSupportBounds


static func bounds_at(player, world_position: Vector3) -> Dictionary:
	var failures: Array[String] = []
	if player == null or not player is CharacterBody3D:
		failures.append("Player collision support bounds require CharacterBody3D")
		return _failure(failures)
	if not _finite_vector3(world_position):
		failures.append("Player collision support position must be finite")
		return _failure(failures)

	var collision_shape: CollisionShape3D = null
	for child in player.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D and not child.disabled:
			if collision_shape != null:
				failures.append("Player collision support bounds require exactly one active capsule")
				return _failure(failures)
			collision_shape = child
	if collision_shape == null:
		failures.append("Player collision support bounds require one active CapsuleShape3D")
		return _failure(failures)

	var capsule: CapsuleShape3D = collision_shape.shape
	if (
		capsule.radius <= 0.0
		or capsule.height <= 0.0
		or not is_finite(capsule.radius)
		or not is_finite(capsule.height)
	):
		failures.append("Player capsule dimensions must be finite and positive")
		return _failure(failures)
	if player.floor_snap_length < 0.0 or not is_finite(player.floor_snap_length):
		failures.append("Player floor snap length must be finite and non-negative")
		return _failure(failures)
	if player.safe_margin < 0.0 or not is_finite(player.safe_margin):
		failures.append("Player safe margin must be finite and non-negative")
		return _failure(failures)

	# The production Player capsule is upright and the CharacterBody root is not
	# pitched/rolled. Keep this helper fail-closed if that physical contract ever
	# changes so readiness does not silently under-estimate support geometry.
	var up: Vector3 = player.global_transform.basis.y.normalized()
	if absf(up.dot(Vector3.UP)) < 0.999:
		failures.append("Player collision support bounds require an upright CharacterBody capsule")
		return _failure(failures)

	var margin: float = maxf(float(player.safe_margin), 0.001)
	var radius: float = float(capsule.radius) + margin
	var half_height: float = float(capsule.height) * 0.5 + margin
	var center: Vector3 = (
		world_position
		+ player.global_transform.basis * collision_shape.position
	)
	var minimum := Vector3(
		center.x - radius,
		center.y - half_height - float(player.floor_snap_length) - margin,
		center.z - radius
	)
	var maximum := Vector3(
		center.x + radius,
		center.y + half_height + margin,
		center.z + radius
	)
	var bounds := AABB(minimum, maximum - minimum)
	if not _valid_bounds(bounds):
		failures.append("Player collision support bounds resolved invalid AABB")
		return _failure(failures)
	return {
		"success": true,
		"bounds": bounds,
		"diagnostics": [],
	}


static func _failure(failures: Array[String]) -> Dictionary:
	failures.sort()
	return {
		"success": false,
		"bounds": AABB(),
		"diagnostics": failures,
	}


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
		is_finite(value.x)
		and is_finite(value.y)
		and is_finite(value.z)
	)
