extends RefCounted
class_name UnderworldPlayerInputBuffer

## One-slot, short-lived input intent buffer.
##
## This component does not know whether an action is legal. PlayerActionController
## remains the authority for action-state transitions. The buffer only remembers
## the newest recent discrete intent while the player is committed elsewhere.

const DEFAULT_LIFETIME: float = 0.12

var pending_action: StringName = &""
var pending_payload: Dictionary = {}
var remaining: float = 0.0


func push(
	action: StringName,
	payload: Dictionary = {},
	lifetime: float = DEFAULT_LIFETIME
) -> bool:
	if action == &"" or lifetime <= 0.0:
		return false
	pending_action = action
	pending_payload = payload.duplicate(true)
	remaining = lifetime
	return true


func tick(delta: float) -> void:
	if pending_action == &"" or delta <= 0.0:
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		clear()


func has_pending() -> bool:
	return pending_action != &"" and remaining > 0.0


func peek_action() -> StringName:
	return pending_action if has_pending() else &""


func consume() -> Dictionary:
	if not has_pending():
		return {}
	var result: Dictionary = {
		"action": pending_action,
		"payload": pending_payload.duplicate(true),
	}
	clear()
	return result


func clear() -> void:
	pending_action = &""
	pending_payload.clear()
	remaining = 0.0


func reset() -> void:
	clear()
