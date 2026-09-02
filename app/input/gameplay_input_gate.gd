extends Node
class_name UnderworldGameplayInputGate

## Application/gameplay-owned suppression authority for ordinary Player input.
##
## Callers own tokens. The gate deliberately does not know which presentation
## screen or lifecycle system requested suppression; nested owners therefore
## cannot re-enable gameplay through a last-writer-wins boolean.

const RELEASE_GUARD_PHYSICS_TICKS := 2

var _captures: Dictionary = {}
var _next_token: int = 1
var _release_guard_ticks: int = 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(_delta: float) -> void:
	if not _captures.is_empty() or _release_guard_ticks <= 0:
		return
	_release_guard_ticks -= 1


func acquire(reason: StringName = &"") -> int:
	var token := _next_token
	_next_token += 1
	if _next_token <= 0:
		_next_token = 1
	while token <= 0 or _captures.has(token):
		token = _next_token
		_next_token += 1
	_captures[token] = reason
	_release_guard_ticks = 0
	return token


func release(token: int) -> bool:
	if token <= 0 or not _captures.has(token):
		return false
	_captures.erase(token)
	if _captures.is_empty():
		# UI close/confirm input may still be reported as `just_pressed` during
		# the immediately following physics tick. Keep one complete physics tick
		# between the final release and ordinary Player sampling regardless of
		# sibling processing order.
		_release_guard_ticks = RELEASE_GUARD_PHYSICS_TICKS
	return true


func is_blocked() -> bool:
	return not _captures.is_empty()


func allows_player_input() -> bool:
	return _captures.is_empty() and _release_guard_ticks <= 0


func active_capture_count() -> int:
	return _captures.size()


func active_reasons() -> Array[StringName]:
	var reasons: Array[StringName] = []
	for value in _captures.values():
		reasons.append(StringName(value))
	reasons.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	return reasons


func clear_captures() -> void:
	if _captures.is_empty():
		return
	_captures.clear()
	_release_guard_ticks = RELEASE_GUARD_PHYSICS_TICKS
