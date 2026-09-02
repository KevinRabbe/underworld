extends Node
class_name UnderworldUiFocusStack

signal stack_changed(depth: int)

## Presentation-only top-surface focus/Back ordering.
##
## This stack never pauses gameplay, performs SAVE, or owns route truth. Controls
## are held weakly so route/surface destruction cannot be prevented by focus
## bookkeeping. A Back handler is explicit and belongs only to the top entry.

var _entries: Array[Dictionary] = []
var _next_token: int = 1


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func push_surface(
	surface: Control,
	back_handler: Callable,
	origin_focus: Control = null,
	initial_focus: Control = null,
	fallback_focus: Control = null
) -> int:
	if surface == null or not is_instance_valid(surface) or not back_handler.is_valid():
		return 0
	_prune_invalid_top(false)
	var token := _allocate_token()
	_entries.append({
		"token": token,
		"surface": weakref(surface),
		"back_handler": back_handler,
		"origin_focus": _weak_control(origin_focus),
		"initial_focus": _weak_control(initial_focus),
		"fallback_focus": _weak_control(fallback_focus),
	})
	_focus_deferred(initial_focus)
	stack_changed.emit(_entries.size())
	return token


func pop_surface(token: int) -> bool:
	_prune_invalid_top(false)
	if token <= 0 or _entries.is_empty():
		return false
	var entry: Dictionary = _entries.back()
	if int(entry.get("token", 0)) != token:
		return false
	_entries.pop_back()
	_restore_focus(entry)
	stack_changed.emit(_entries.size())
	return true


func has_back_owner() -> bool:
	_prune_invalid_top(true)
	return not _entries.is_empty()


func dispatch_back() -> bool:
	_prune_invalid_top(true)
	if _entries.is_empty():
		return false
	var entry: Dictionary = _entries.back()
	var handler: Callable = entry.get("back_handler", Callable())
	if not handler.is_valid():
		_prune_invalid_top(true)
		return false
	handler.call()
	return true


func depth() -> int:
	_prune_invalid_top(false)
	return _entries.size()


func top_token() -> int:
	_prune_invalid_top(false)
	if _entries.is_empty():
		return 0
	return int(_entries.back().get("token", 0))


func clear(restore_focus: bool = false) -> void:
	if _entries.is_empty():
		return
	var restore_entry: Dictionary = _entries.front() if restore_focus else {}
	_entries.clear()
	if restore_focus:
		_restore_focus(restore_entry)
	stack_changed.emit(0)


func _allocate_token() -> int:
	var token := _next_token
	_next_token += 1
	if _next_token <= 0:
		_next_token = 1
	while token <= 0 or _contains_token(token):
		token = _next_token
		_next_token += 1
	return token


func _contains_token(token: int) -> bool:
	for entry in _entries:
		if int(entry.get("token", 0)) == token:
			return true
	return false


func _prune_invalid_top(restore_focus: bool) -> void:
	var changed := false
	while not _entries.is_empty():
		var entry: Dictionary = _entries.back()
		var surface: Control = _resolve_control(entry.get("surface", null))
		var handler: Callable = entry.get("back_handler", Callable())
		if _is_active_surface(surface) and handler.is_valid():
			break
		_entries.pop_back()
		if restore_focus:
			_restore_focus(entry)
		changed = true
	if changed:
		stack_changed.emit(_entries.size())


func _restore_focus(entry: Dictionary) -> void:
	var origin: Control = _resolve_control(entry.get("origin_focus", null))
	if _can_receive_focus(origin):
		_focus_deferred(origin)
		return
	var fallback: Control = _resolve_control(entry.get("fallback_focus", null))
	if _can_receive_focus(fallback):
		_focus_deferred(fallback)


static func _weak_control(control: Control) -> WeakRef:
	return null if control == null or not is_instance_valid(control) else weakref(control)


static func _resolve_control(reference: Variant) -> Control:
	if reference == null or not reference is WeakRef:
		return null
	var value: Variant = (reference as WeakRef).get_ref()
	return value as Control if value != null and is_instance_valid(value) and value is Control else null


static func _is_active_surface(control: Control) -> bool:
	return (
		control != null
		and is_instance_valid(control)
		and control.is_inside_tree()
		and control.is_visible_in_tree()
	)


static func _can_receive_focus(control: Control) -> bool:
	if not _is_active_surface(control) or control.focus_mode == Control.FOCUS_NONE:
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false
	return true


static func _focus_deferred(control: Control) -> void:
	if _can_receive_focus(control):
		control.call_deferred("grab_focus")