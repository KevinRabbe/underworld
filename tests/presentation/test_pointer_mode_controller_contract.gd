extends RefCounted

const PointerModeController := preload("res://app/input/pointer_mode_controller.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var original_mouse_mode := Input.mouse_mode
	var controller := PointerModeController.new()

	_test_default_and_baseline_contract(controller, failures)
	_test_nested_request_contract(controller, failures)
	_test_clear_and_stale_token_contract(controller, failures)

	controller.free()
	Input.mouse_mode = original_mouse_mode
	return failures


static func _test_default_and_baseline_contract(controller: Node, failures: Array[String]) -> void:
	if int(controller.call("route_baseline")) != Input.MOUSE_MODE_VISIBLE:
		failures.append("Pointer authority must default to semantic VISIBLE route baseline")
	if int(controller.call("effective_mode")) != Input.MOUSE_MODE_VISIBLE:
		failures.append("Pointer authority default effective mode must be VISIBLE")
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		failures.append("Pointer authority construction must reconcile the safe VISIBLE default to Input.mouse_mode")
	if bool(controller.call("set_route_baseline", -1)):
		failures.append("Pointer authority accepted an arbitrary non-semantic route baseline")
	if int(controller.call("route_baseline")) != Input.MOUSE_MODE_VISIBLE:
		failures.append("Rejected pointer baseline changed canonical route baseline")
	if not bool(controller.call("set_route_baseline", Input.MOUSE_MODE_CAPTURED)):
		failures.append("Pointer authority rejected semantic CAPTURED route baseline")
	if int(controller.call("effective_mode")) != Input.MOUSE_MODE_CAPTURED:
		failures.append("CAPTURED route baseline did not become the semantic effective mode without visible requests")


static func _test_nested_request_contract(controller: Node, failures: Array[String]) -> void:
	var first_token := int(controller.call("request_visible"))
	var second_token := int(controller.call("request_visible"))
	if first_token <= 0 or second_token <= 0 or first_token == second_token:
		failures.append("Visible pointer requests must receive unique non-zero tokens")
	if int(controller.call("visible_request_count")) != 2:
		failures.append("Nested visible requests were not retained independently")
	if int(controller.call("effective_mode")) != Input.MOUSE_MODE_VISIBLE or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		failures.append("Any valid visible request must force semantic and observable VISIBLE pointer mode")

	if not bool(controller.call("release_visible", second_token)):
		failures.append("Out-of-order release rejected a valid visible-request token")
	if int(controller.call("visible_request_count")) != 1 or int(controller.call("effective_mode")) != Input.MOUSE_MODE_VISIBLE:
		failures.append("Releasing one nested request affected another visible owner")
	if bool(controller.call("release_visible", second_token)):
		failures.append("Double release of a visible-request token was not harmless")
	if bool(controller.call("release_visible", 0)):
		failures.append("Unknown visible-request token was not rejected harmlessly")
	if int(controller.call("visible_request_count")) != 1 or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		failures.append("Stale/unknown release changed active visible ownership")

	if not bool(controller.call("set_route_baseline", Input.MOUSE_MODE_VISIBLE)):
		failures.append("Pointer authority could not change route baseline while a request was active")
	if int(controller.call("effective_mode")) != Input.MOUSE_MODE_VISIBLE:
		failures.append("Baseline change disturbed active visible-request priority")
	if not bool(controller.call("release_visible", first_token)):
		failures.append("Final valid visible-request release failed")
	if int(controller.call("visible_request_count")) != 0:
		failures.append("Final release did not retire the last visible request")
	if int(controller.call("effective_mode")) != Input.MOUSE_MODE_VISIBLE or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		failures.append("Final release did not resolve the current VISIBLE baseline")

	if not bool(controller.call("set_route_baseline", Input.MOUSE_MODE_CAPTURED)):
		failures.append("Pointer authority could not restore semantic CAPTURED baseline after request retirement")
	if int(controller.call("effective_mode")) != Input.MOUSE_MODE_CAPTURED:
		failures.append("Current CAPTURED baseline was not restored after request retirement")


static func _test_clear_and_stale_token_contract(controller: Node, failures: Array[String]) -> void:
	var old_first := int(controller.call("request_visible"))
	var old_second := int(controller.call("request_visible"))
	if int(controller.call("clear_requests")) != 2:
		failures.append("Pointer authority clear_requests did not report the exact retired request count")
	if int(controller.call("visible_request_count")) != 0:
		failures.append("Pointer authority clear_requests retained stale visible ownership")
	if int(controller.call("effective_mode")) != Input.MOUSE_MODE_CAPTURED:
		failures.append("Clearing requests did not resolve the current CAPTURED baseline")
	if int(controller.call("clear_requests")) != 0:
		failures.append("Repeated pointer request clear was not bounded/idempotent")

	var current_token := int(controller.call("request_visible"))
	if current_token <= 0 or current_token == old_first or current_token == old_second:
		failures.append("Pointer authority reused a retired visible-request token")
	if bool(controller.call("release_visible", old_first)) or bool(controller.call("release_visible", old_second)):
		failures.append("Stale pre-clear request token unexpectedly released current pointer ownership")
	if int(controller.call("visible_request_count")) != 1 or int(controller.call("effective_mode")) != Input.MOUSE_MODE_VISIBLE:
		failures.append("Stale release mutated a newer visible-request owner")

	if not bool(controller.call("set_route_baseline", Input.MOUSE_MODE_VISIBLE)):
		failures.append("Pointer authority rejected current-baseline change under post-clear ownership")
	if not bool(controller.call("release_visible", current_token)):
		failures.append("Current post-clear request token could not be released")
	if int(controller.call("effective_mode")) != Input.MOUSE_MODE_VISIBLE or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		failures.append("Post-clear final release restored stale CAPTURED state instead of current VISIBLE baseline")
