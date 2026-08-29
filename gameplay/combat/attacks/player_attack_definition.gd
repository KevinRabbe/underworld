extends RefCounted
class_name UnderworldPlayerAttackDefinition

## Pure-data description of one committed player melee attack.
## Input, animation and physics resolution consume this contract; none of them
## owns the definition itself.

var attack_id: StringName
var startup: float
var active: float
var recovery: float
var damage: int
var reach: float
var center_distance: float
var radius: float
var minimum_dot: float
var attack_kind: StringName
var stamina_cost: float


func _init(
	id_value: StringName,
	startup_value: float,
	active_value: float,
	recovery_value: float,
	damage_value: int,
	reach_value: float,
	center_distance_value: float,
	radius_value: float,
	minimum_dot_value: float,
	attack_kind_value: StringName = &"light",
	stamina_cost_value: float = 0.0
) -> void:
	attack_id = id_value
	startup = maxf(startup_value, 0.0)
	active = maxf(active_value, 0.01)
	recovery = maxf(recovery_value, 0.0)
	damage = maxi(damage_value, 0)
	reach = maxf(reach_value, 0.1)
	center_distance = maxf(center_distance_value, 0.0)
	radius = maxf(radius_value, 0.05)
	minimum_dot = clampf(minimum_dot_value, -1.0, 1.0)
	attack_kind = &"heavy" if attack_kind_value == &"heavy" else &"light"
	stamina_cost = maxf(stamina_cost_value, 0.0)


func total_duration() -> float:
	return startup + active + recovery


func is_valid() -> bool:
	return (
		not attack_id.is_empty()
		and active > 0.0
		and total_duration() >= 0.05
		and damage > 0
		and reach > 0.0
		and radius > 0.0
	)


func make_execution(source_position: Vector3, world_direction: Vector3) -> Dictionary:
	var horizontal := Vector3(world_direction.x, 0.0, world_direction.z)
	if horizontal.is_zero_approx() or not is_valid():
		return {}
	horizontal = horizontal.normalized()
	return {
		"attack_id": attack_id,
		"source_position": source_position,
		"direction": horizontal,
		"damage": damage,
		"reach": reach,
		"center_distance": center_distance,
		"radius": radius,
		"minimum_dot": minimum_dot,
		"attack_kind": attack_kind,
	}
