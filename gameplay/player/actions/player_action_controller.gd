extends RefCounted
class_name UnderworldPlayerActionController

const STATE_FREE: int = 0
const STATE_DODGING: int = 1
const STATE_PARRYING: int = 2
const STATE_BLOCKING: int = 3
const STATE_USING_TOOL: int = 4
const STATE_ATTACKING: int = 5

const ATTACK_KIND_LIGHT: StringName = &"light"
const ATTACK_KIND_HEAVY: StringName = &"heavy"
const BUFFERED_ACTIONS: Array[StringName] = [&"attack", &"dodge", &"parry"]

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
const HEAVY_ATTACK_COST: float = 12.0

const BLOCK_MIN_START_STAMINA: float = 1.0

var stamina
var state: int = STATE_FREE
var elapsed: float = 0.0
var dodge_direction_world: Vector3 = Vector3.ZERO
var tool_action_duration: float = 0.0

var attack_startup: float = 0.0
var attack_active: float = 0.0
var attack_recovery: float = 0.0
var attack_activation_pending: bool = false
var attack_activation_emitted: bool = false
var attack_kind: StringName = ATTACK_KIND_LIGHT


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
	elif state == STATE_USING_TOOL and elapsed >= tool_action_duration:
		_finish_action()
	elif state == STATE_ATTACKING:
		if not attack_activation_emitted and elapsed >= attack_startup:
			attack_activation_emitted = true
			attack_activation_pending = true
		if elapsed >= get_attack_total_duration():
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


func try_start_tool_action(duration: float) -> bool:
	if state != STATE_FREE:
		return false
	state = STATE_USING_TOOL
	elapsed = 0.0
	tool_action_duration = maxf(duration, 0.05)
	return true


func try_start_attack(startup: float, active: float, recovery: float) -> bool:
	return try_start_attack_profile(startup, active, recovery, ATTACK_KIND_LIGHT)


func try_start_attack_profile(startup: float, active: float, recovery: float, kind: StringName = ATTACK_KIND_LIGHT, stamina_cost: float = 0.0) -> bool:
	if state != STATE_FREE:
		return false
	var sanitized_startup: float = maxf(startup, 0.0)
	var sanitized_active: float = maxf(active, 0.01)
	var sanitized_recovery: float = maxf(recovery, 0.0)
	if sanitized_startup + sanitized_active + sanitized_recovery < 0.05:
		return false
	if stamina != null and stamina_cost > 0.0 and not stamina.spend(stamina_cost):
		return false
	state = STATE_ATTACKING
	elapsed = 0.0
	attack_startup = sanitized_startup
	attack_active = sanitized_active
	attack_recovery = sanitized_recovery
	attack_activation_pending = false
	attack_activation_emitted = false
	attack_kind = ATTACK_KIND_HEAVY if kind == ATTACK_KIND_HEAVY else ATTACK_KIND_LIGHT
	return true


func can_queue_action(action: StringName) -> bool:
	return BUFFERED_ACTIONS.has(action)


func can_interrupt_action(action: StringName) -> bool:
	# M3 uses committed actions: defensive inputs may queue, but never cancel an
	# active attack/dodge/parry/tool action mid-window.
	return false


func transition_policy() -> Dictionary:
	return {
		"buffered": ["attack", "dodge", "parry"],
		"interruptible": [],
		"priority": ["dodge", "parry", "attack"],
		"buffer_lifetime": 0.16,
	}


func consume_attack_activation() -> bool:
	if not attack_activation_pending:
		return false
	attack_activation_pending = false
	return true


func is_free() -> bool:
	return state == STATE_FREE


func is_dodging() -> bool:
	return state == STATE_DODGING


func is_parrying() -> bool:
	return state == STATE_PARRYING


func is_blocking() -> bool:
	return state == STATE_BLOCKING


func is_using_tool() -> bool:
	return state == STATE_USING_TOOL


func is_attacking() -> bool:
	return state == STATE_ATTACKING


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


func get_attack_total_duration() -> float:
	return attack_startup + attack_active + attack_recovery


func get_attack_phase_name() -> String:
	if state != STATE_ATTACKING:
		return "NONE"
	if elapsed < attack_startup:
		return "STARTUP"
	if elapsed < attack_startup + attack_active:
		return "ACTIVE"
	return "RECOVERY"


func reset() -> void:
	state = STATE_FREE
	elapsed = 0.0
	dodge_direction_world = Vector3.ZERO
	attack_kind = ATTACK_KIND_LIGHT
	tool_action_duration = 0.0
	_reset_attack_contract(true)


func state_name() -> String:
	match state:
		STATE_DODGING: return "DODGING"
		STATE_PARRYING: return "PARRYING"
		STATE_BLOCKING: return "BLOCKING"
		STATE_USING_TOOL: return "USING_TOOL"
		STATE_ATTACKING: return "ATTACKING/%s" % get_attack_phase_name()
	return "FREE"


func get_attack_kind() -> StringName:
	return attack_kind


func _finish_action() -> void:
	var finished_attack: bool = state == STATE_ATTACKING
	state = STATE_FREE
	elapsed = 0.0
	dodge_direction_world = Vector3.ZERO
	tool_action_duration = 0.0
	if finished_attack:
		# Keep a just-crossed activation pending long enough for Player to consume
		# it even if a very large frame also crossed the end of recovery.
		_reset_attack_contract(false)


func _reset_attack_contract(clear_pending: bool) -> void:
	attack_startup = 0.0
	attack_active = 0.0
	attack_recovery = 0.0
	attack_activation_emitted = false
	if clear_pending:
		attack_activation_pending = false
