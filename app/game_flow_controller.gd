extends Node

signal pause_changed(is_paused)
signal flow_feedback_changed(messages)

const ROUTE_GAME: StringName = &"game"

var _app_root: Node = null
var _pause_menu: Control = null
var _ui_focus_stack: Node = null
var _pause_active: bool = false
var _operation_in_progress: bool = false
var _mouse_mode_before_pause: int = Input.MOUSE_MODE_CAPTURED


func configure(app_root: Node, pause_menu: Control, ui_focus_stack: Node = null) -> bool:
	if _app_root != null or _pause_menu != null or _ui_focus_stack != null:
		return false
	if app_root == null or pause_menu == null or ui_focus_stack == null:
		return false
	for method_name in ["current_route_id", "save_current_game", "show_title", "quit_application"]:
		if not app_root.has_method(method_name):
			return false
	if not app_root.has_signal("route_changed"):
		return false
	for signal_name in ["resume_requested", "save_and_quit_requested", "quit_requested"]:
		if not pause_menu.has_signal(signal_name):
			return false
	for method_name in ["set_open", "set_feedback"]:
		if not pause_menu.has_method(method_name):
			return false
	for method_name in ["has_back_owner", "dispatch_back"]:
		if not ui_focus_stack.has_method(method_name):
			return false

	_app_root = app_root
	_pause_menu = pause_menu
	_ui_focus_stack = ui_focus_stack
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_menu.call("set_open", false)
	_pause_menu.connect("resume_requested", Callable(self, "request_resume"))
	_pause_menu.connect("save_and_quit_requested", Callable(self, "request_save_and_quit"))
	_pause_menu.connect("quit_requested", Callable(self, "request_quit_application"))
	_app_root.connect("route_changed", Callable(self, "_on_route_changed"))
	return true


func _input(event: InputEvent) -> void:
	if _app_root == null or event == null:
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if not event.is_action_pressed("ui_cancel"):
		return

	# `_input` runs before ordinary GUI handling. Explicitly delegate Back to the
	# top interactive UI surface first so Settings/Modal/overlay ownership never
	# depends on sibling callback or GUI propagation order.
	if _ui_focus_stack != null and bool(_ui_focus_stack.call("has_back_owner")):
		var ui_viewport := get_viewport()
		if ui_viewport != null:
			ui_viewport.set_input_as_handled()
		_ui_focus_stack.call("dispatch_back")
		return

	if str(_app_root.call("current_route_id")) != str(ROUTE_GAME):
		return
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	if _operation_in_progress:
		return
	if _pause_active:
		request_resume()
	else:
		request_pause()


func request_pause() -> bool:
	if _app_root == null or _pause_menu == null or _operation_in_progress:
		return false
	if _pause_active or str(_app_root.call("current_route_id")) != str(ROUTE_GAME):
		return false
	var tree := get_tree()
	if tree == null or tree.paused:
		return false

	_mouse_mode_before_pause = Input.mouse_mode
	_pause_active = true
	_pause_menu.call("set_feedback", [])
	_pause_menu.call("set_open", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	tree.paused = true
	pause_changed.emit(true)
	return true


func request_resume() -> bool:
	if not _pause_active or _operation_in_progress:
		return false
	_finish_pause(_mouse_mode_before_pause)
	return true


func request_save_and_quit() -> bool:
	if _app_root == null or _pause_menu == null:
		return false
	if not _pause_active or _operation_in_progress:
		return false
	if str(_app_root.call("current_route_id")) != str(ROUTE_GAME):
		return false

	_operation_in_progress = true
	_pause_menu.call("set_feedback", ["SAVING..."])
	var save_variant: Variant = _app_root.call("save_current_game")
	if not save_variant is Dictionary:
		return _fail_operation(["SAVE returned an incompatible result"])
	var save_result: Dictionary = save_variant
	if not bool(save_result.get("success", false)):
		var diagnostics: Array[String] = _diagnostics(save_result.get("diagnostics", []))
		if diagnostics.is_empty():
			diagnostics.append("SAVE failed")
		return _fail_operation(diagnostics)

	if not bool(_app_root.call("show_title")):
		return _fail_operation(["SAVE succeeded but Title route transition failed"])

	_operation_in_progress = false
	_finish_pause(Input.MOUSE_MODE_VISIBLE)
	return true


func request_quit_application() -> bool:
	if _app_root == null or _operation_in_progress:
		return false
	_operation_in_progress = true
	_app_root.call("quit_application")
	return true


func is_pause_active() -> bool:
	return _pause_active


func operation_in_progress() -> bool:
	return _operation_in_progress


func _on_route_changed(route_id: StringName) -> void:
	if str(route_id) == str(ROUTE_GAME) or not _pause_active:
		return
	_finish_pause(Input.MOUSE_MODE_VISIBLE)


func _finish_pause(mouse_mode: int) -> void:
	if not _pause_active:
		Input.mouse_mode = mouse_mode
		return
	var tree := get_tree()
	if tree != null:
		tree.paused = false
	_pause_active = false
	if _pause_menu != null and is_instance_valid(_pause_menu):
		_pause_menu.call("set_open", false)
	Input.mouse_mode = mouse_mode
	pause_changed.emit(false)


func _fail_operation(messages: Array) -> bool:
	_operation_in_progress = false
	var diagnostics: Array[String] = _diagnostics(messages)
	if _pause_menu != null and is_instance_valid(_pause_menu):
		_pause_menu.call("set_feedback", diagnostics)
	flow_feedback_changed.emit(diagnostics)
	return false


static func _diagnostics(messages: Array) -> Array[String]:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	return diagnostics


func _exit_tree() -> void:
	if _pause_active:
		var tree := get_tree()
		if tree != null:
			tree.paused = false
		_pause_active = false
