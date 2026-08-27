extends RefCounted
class_name UnderworldPlayerActionController

const STATE_FREE: int = 0
const STATE_DODGING: int = 1
const STATE_PARRYING: int = 2
const STATE_BLOCKING: int = 3

const DODGE_COST: float = 25.0
const DODGE_DURATION: float = 0.48
const DODGE_IFRAME_START: float = 0.09
const DODGE_IFRAME_END: float = 0.30
const DODGE_PEAK_SPEED: float = 10.8

const PARRY_COST: float = 15.0
const PARRY_STARTUP: float = 0.06
const PARRY_ACTIVE_DURATION: float = 0.12
const PARRY_RECOVERY: float = 0.30
const PARRY_TOTAL_DURATION: float = PARRY_STARTUP + PARRY_ACTIVE_DURATION + PARRY_RECOVERY

const BLOCK_MIN_START_STAMINA: float = 1.0

var stamina
var state: int = STATE_FREE
var elapsed: float = 0.0
var dodge_direction_world: Vector3 = Vector3.ZERO


func _init(stamina_component) -> void:
	stamina = stamina_component


func tick(delta: float) -> void:
	if state == STATE_FREE or delta <= 0.0:
		return
	elapsed += delta
	if state == STATE_DODGING and elapsed >= DODGE_DURATION:
		_finish_action()
	elif state == STATE_PARRYING and elapsed >= PARRY_TOTAL_DURATION:
		_finish_action()


func try_start_dodge(world_direction: Vector3) -> bool:
	if state != STATE_FREE or stamina == null:
		return false
	var horizontal := Vector3(world_direction.x, 0.0, world_direction.z)
	if horizontal.is_zero_approx() or not stamina.spend(DODGE_COST):
		return false
	dodge_direction_world = horizontal.normalized()
	state = STATE_DODGING
	elapsed = 0.0
	return true


func try_start_parry() -> bool:
	if state != STATE_FREE or stamina == null:
		return false
	if not stamina.spend(PARRY_COST):
		return false
	state = STATE_PARRYING
	elapsed = 0.0
	return true


func try_start_block() -> bool:
	if state != STATE_FREE or stamina == null:
		return false
	if not stamina.can_spend(BLOCK_MIN_START_STAMINA):
		return false
	state = STATE_BLOCKING
	elapsed = 0.0
	return true


func stop_block() -> void:
	if state == STATE_BLOCKING:
		_finish_action()


func try_absorb_block(impact_cost: float) -> bool:
	if state != STATE_BLOCKING or stamina == null:
		return false
	if stamina.spend(maxf(impact_cost, 0.0)):
		return true
	# Guard break consumes whatever stamina remains so holding block cannot
	# instantly re-enter guard at the same unusable stamina value next frame.
	var remaining: float = maxf(float(stamina.current_stamina), 0.0)
	if remaining > 0.0:
		stamina.spend(remaining)
	_finish_action()
	return false


func is_free() -> bool:
	return state == STATE_FREE


func is_dodging() -> bool:
	return state == STATE_DODGING


func is_parrying() -> bool:
	return state == STATE_PARRYING


func is_blocking() -> bool:
	return state == STATE_BLOCKING


func is_dodge_iframe_active() -> bool:
	return (
		state == STATE_DODGING
		and elapsed >= DODGE_IFRAME_START
		and elapsed < DODGE_IFRAME_END
	)


func is_parry_active() -> bool:
	return (
		state == STATE_PARRYING
		and elapsed >= PARRY_STARTUP
		and elapsed < PARRY_STARTUP + PARRY_ACTIVE_DURATION
	)


func get_dodge_speed() -> float:
	if state != STATE_DODGING:
		return 0.0
	var progress: float = clampf(elapsed / DODGE_DURATION, 0.0, 1.0)
	return sin(progress * PI) * DODGE_PEAK_SPEED


func reset() -> void:
	state = STATE_FREE
	elapsed = 0.0
	dodge_direction_world = Vector3.ZERO


func state_name() -> String:
	match state:
		STATE_DODGING: return "DODGING"
		STATE_PARRYING: return "PARRYING"
		STATE_BLOCKING: return "BLOCKING"
	return "FREE"


func _finish_action() -> void:
	state = STATE_FREE
	elapsed = 0.0
	dodge_direction_world = Vector3.ZERO
