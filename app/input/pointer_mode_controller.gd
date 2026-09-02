extends Node

const ROUTE_BASELINE_VISIBLE := Input.MOUSE_MODE_VISIBLE
const ROUTE_BASELINE_CAPTURED := Input.MOUSE_MODE_CAPTURED
const MAX_REQUEST_TOKEN: int = 9223372036854775807

var _route_baseline: int = ROUTE_BASELINE_VISIBLE
var _visible_requests: Dictionary = {}
var _next_request_token: int = 1


func _init() -> void:
	_apply_effective_mode()


func set_route_baseline(mode: int) -> bool:
	if not _is_supported_baseline(mode):
		return false
	_route_baseline = mode
	_apply_effective_mode()
	return true


func route_baseline() -> int:
	return _route_baseline


func request_visible() -> int:
	if _next_request_token <= 0:
		return 0
	var token := _next_request_token
	if _next_request_token == MAX_REQUEST_TOKEN:
		_next_request_token = 0
	else:
		_next_request_token += 1
	_visible_requests[token] = true
	_apply_effective_mode()
	return token


func release_visible(token: int) -> bool:
	if token <= 0 or not _visible_requests.has(token):
		return false
	_visible_requests.erase(token)
	_apply_effective_mode()
	return true


func clear_requests() -> int:
	var cleared_count := _visible_requests.size()
	_visible_requests.clear()
	_apply_effective_mode()
	return cleared_count


func visible_request_count() -> int:
	return _visible_requests.size()


func effective_mode() -> int:
	if not _visible_requests.is_empty():
		return Input.MOUSE_MODE_VISIBLE
	return _route_baseline


func _is_supported_baseline(mode: int) -> bool:
	return mode == ROUTE_BASELINE_VISIBLE or mode == ROUTE_BASELINE_CAPTURED


func _apply_effective_mode() -> void:
	var desired_mode := effective_mode()
	if Input.mouse_mode != desired_mode:
		Input.mouse_mode = desired_mode
