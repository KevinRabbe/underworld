extends RefCounted
class_name UnderworldPlayerPlacementProfile

# Authoritative physical envelope shared by Player locomotion and deterministic
# surface placement/recovery. Keep these values centralized so spawn safety cannot
# silently drift away from the actual CharacterBody3D collision contract.
const CAPSULE_RADIUS: float = 0.45
const CAPSULE_HEIGHT: float = 1.8
const CAPSULE_CENTER_Y: float = 0.9
const FLOOR_MAX_ANGLE_RADIANS: float = deg_to_rad(50.0)
const FLOOR_SNAP_LENGTH: float = 0.45
const COLLISION_MASK: int = 1 | 2
const SETTLEMENT_MARGIN: float = 0.08


func capsule_radius() -> float:
	return CAPSULE_RADIUS


func capsule_height() -> float:
	return CAPSULE_HEIGHT


func capsule_center_y() -> float:
	return CAPSULE_CENTER_Y


func floor_max_angle() -> float:
	return FLOOR_MAX_ANGLE_RADIANS


func floor_snap_length() -> float:
	return FLOOR_SNAP_LENGTH


func collision_mask() -> int:
	return COLLISION_MASK


func settlement_margin() -> float:
	return SETTLEMENT_MARGIN


func body_origin_y_for_support(support_y: float) -> float:
	return support_y + SETTLEMENT_MARGIN


func make_capsule_shape(shrink: float = 0.0) -> CapsuleShape3D:
	var resolved_shrink: float = maxf(shrink, 0.0)
	var shape := CapsuleShape3D.new()
	shape.radius = maxf(CAPSULE_RADIUS - resolved_shrink, 0.01)
	shape.height = maxf(CAPSULE_HEIGHT - resolved_shrink * 2.0, shape.radius * 2.0)
	return shape


func validate() -> Array[String]:
	var failures: Array[String] = []
	if CAPSULE_RADIUS <= 0.0:
		failures.append("Player placement profile requires positive capsule radius")
	if CAPSULE_HEIGHT < CAPSULE_RADIUS * 2.0:
		failures.append("Player placement profile capsule height must contain its radius")
	if not is_equal_approx(CAPSULE_CENTER_Y, CAPSULE_HEIGHT * 0.5):
		failures.append("Player placement profile expects body origin at capsule bottom")
	if FLOOR_MAX_ANGLE_RADIANS <= 0.0 or FLOOR_MAX_ANGLE_RADIANS >= PI * 0.5:
		failures.append("Player placement profile requires walkable floor angle below 90 degrees")
	if FLOOR_SNAP_LENGTH <= 0.0:
		failures.append("Player placement profile requires positive floor snap length")
	if SETTLEMENT_MARGIN <= 0.0 or SETTLEMENT_MARGIN >= FLOOR_SNAP_LENGTH:
		failures.append("Player placement profile settlement margin must fit inside floor snap range")
	return failures
