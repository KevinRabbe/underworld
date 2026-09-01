extends RefCounted
class_name UnderworldPlayerPlacementProfile

# Placement consumes one explicit physical profile. Recovery configures this from
# the live Player's actual CharacterBody3D/capsule values; the defaults exist for
# pre-Player surface spawn search and are regression-checked against production.
const DEFAULT_CAPSULE_RADIUS: float = 0.45
const DEFAULT_CAPSULE_HEIGHT: float = 1.8
const DEFAULT_CAPSULE_CENTER_Y: float = 0.9
const DEFAULT_FLOOR_MAX_ANGLE: float = deg_to_rad(50.0)
const DEFAULT_FLOOR_SNAP_LENGTH: float = 0.45
const DEFAULT_COLLISION_MASK: int = 1 | 2
const SETTLEMENT_MARGIN: float = 0.08

var _capsule_radius: float = DEFAULT_CAPSULE_RADIUS
var _capsule_height: float = DEFAULT_CAPSULE_HEIGHT
var _capsule_center_y: float = DEFAULT_CAPSULE_CENTER_Y
var _floor_max_angle: float = DEFAULT_FLOOR_MAX_ANGLE
var _floor_snap_length: float = DEFAULT_FLOOR_SNAP_LENGTH
var _collision_mask: int = DEFAULT_COLLISION_MASK


func configure_from_player(player) -> Array[String]:
	var failures: Array[String] = []
	if player == null or not player is CharacterBody3D:
		return ["Player placement profile requires live CharacterBody3D"]
	var collision = player.get_node_or_null("CollisionShape3D")
	if collision == null or not collision is CollisionShape3D:
		return ["Player placement profile requires Player CollisionShape3D"]
	if collision.shape == null or not collision.shape is CapsuleShape3D:
		return ["Player placement profile requires Player CapsuleShape3D"]
	var capsule: CapsuleShape3D = collision.shape
	_capsule_radius = float(capsule.radius)
	_capsule_height = float(capsule.height)
	_capsule_center_y = float(collision.position.y)
	_floor_max_angle = float(player.floor_max_angle)
	_floor_snap_length = float(player.floor_snap_length)
	_collision_mask = int(player.collision_mask)
	failures.append_array(validate())
	return failures


func capsule_radius() -> float:
	return _capsule_radius


func capsule_height() -> float:
	return _capsule_height


func capsule_center_y() -> float:
	return _capsule_center_y


func floor_max_angle() -> float:
	return _floor_max_angle


func floor_snap_length() -> float:
	return _floor_snap_length


func collision_mask() -> int:
	return _collision_mask


func settlement_margin() -> float:
	return SETTLEMENT_MARGIN


func body_origin_y_for_support(support_y: float) -> float:
	return support_y + SETTLEMENT_MARGIN


func make_capsule_shape(shrink: float = 0.0) -> CapsuleShape3D:
	var resolved_shrink: float = maxf(shrink, 0.0)
	var shape := CapsuleShape3D.new()
	shape.radius = maxf(_capsule_radius - resolved_shrink, 0.01)
	shape.height = maxf(_capsule_height - resolved_shrink * 2.0, shape.radius * 2.0)
	return shape


func validate() -> Array[String]:
	var failures: Array[String] = []
	if _capsule_radius <= 0.0:
		failures.append("Player placement profile requires positive capsule radius")
	if _capsule_height < _capsule_radius * 2.0:
		failures.append("Player placement profile capsule height must contain its radius")
	if not is_equal_approx(_capsule_center_y, _capsule_height * 0.5):
		failures.append("Player placement profile expects body origin at capsule bottom")
	if _floor_max_angle <= 0.0 or _floor_max_angle >= PI * 0.5:
		failures.append("Player placement profile requires walkable floor angle below 90 degrees")
	if _floor_snap_length <= 0.0:
		failures.append("Player placement profile requires positive floor snap length")
	if SETTLEMENT_MARGIN <= 0.0 or SETTLEMENT_MARGIN >= _floor_snap_length:
		failures.append("Player placement profile settlement margin must fit inside floor snap range")
	return failures
