extends RefCounted

const APP_ROOT_PATH := "res://app/app_root.tscn"
const TITLE_SCREEN_PATH := "res://presentation/ui/screens/title/title_screen.tscn"
const PAUSE_MENU_PATH := "res://presentation/ui/screens/pause/pause_menu.tscn"
const THEME_PATH := "res://presentation/ui/theme/underworld_theme.tres"
const GAMEFLOW_FIXTURE_SCRIPT_PATH := "res://tests/fixtures/gameflow_game_fixture.gd"


class FakeSaveSlotService:
	extends RefCounted
	var fail_saves: bool = false
	var save_calls: int = 0
	var slot_version: int = 0
	var available: bool = false

	func probe_slot(_slot_path: String) -> Dictionary:
		return {"success": true, "available": available, "diagnostics": []}

	func load_slot(_slot_path: String) -> Dictionary:
		return {"success": false, "diagnostics": ["fixture load not configured"]}

	func save_slot(_context, _delta_store, _inventory, _equipment, _pending, _position, _slot_path: String) -> Dictionary:
		save_calls += 1
		if fail_saves:
			return {"success": false, "diagnostics": ["injected save failure"]}
		slot_version += 1
		available = true
		return {"success": true, "diagnostics": [], "slot_version": slot_version}


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_app_root_contract(failures)
	_test_pause_menu_contract(failures)
	return failures


static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var original_paused := tree.paused
	var original_mouse_mode := Input.mouse_mode
	tree.paused = false

	var app_packed = ResourceLoader.load(APP_ROOT_PATH)
	var title_packed = ResourceLoader.load(TITLE_SCREEN_PATH)
	var game_fixture := _make_gameflow_fixture_scene()
	if app_packed == null or not app_packed is PackedScene or title_packed == null or not title_packed is PackedScene or game_fixture == null:
		return ["GAMEFLOW runtime proof could not load required composition"]

	var app: Node = app_packed.instantiate()
	var fake_save := FakeSaveSlotService.new()
	if app == null or not bool(app.call("configure_route_scenes", title_packed, game_fixture)):
		if app != null:
			app.free()
		return ["GAMEFLOW runtime proof could not configure AppRoot fixtures"]
	app.set("_save_slot_service", fake_save)
	tree.root.add_child(app)
	await tree.process_frame

	var host: Node = app.get_node_or_null("SceneHost")
	var flow: Node = app.get_node_or_null("GameFlowController")
	var pause_menu := app.get_node_or_null("PauseLayer/PauseMenu") as Control
	var title: Node = app.get("current_scene") as Node
	if host == null or flow == null or pause_menu == null or title == null:
		failures.append("GAMEFLOW runtime composition did not realize route/flow/pause nodes")
		await _cleanup(tree, app, original_paused, original_mouse_mode)
		return failures

	title.emit_signal("new_game_requested")
	var game: Node = app.get("current_scene") as Node
	if game == null or game == title or str(app.call("current_route_id")) != "game":
		failures.append("GAMEFLOW runtime proof could not enter Game route")
		await _cleanup(tree, app, original_paused, original_mouse_mode)
		return failures
	await tree.process_frame

	# Headless backends may reject captured mode. The invariant is exact restoration
	# of the mode actually owned before pause, whatever backend accepted.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var expected_resume_mouse_mode: int = Input.mouse_mode
	await _dispatch_cancel(tree, true)
	if not bool(flow.call("is_pause_active")) or not tree.paused or not pause_menu.visible:
		failures.append("ui_cancel did not enter exactly one semantic pause state")
	if int(game.get("unhandled_cancel_count")) != 0:
		failures.append("handled pause ui_cancel leaked into gameplay _unhandled_input")
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		failures.append("pause did not release mouse ownership")
	if bool(flow.call("request_pause")):
		failures.append("duplicate pause request was not idempotent")

	await _dispatch_cancel(tree, false)
	var paused_ticks: int = int(game.get("process_ticks"))
	await tree.process_frame
	await tree.process_frame
	if int(game.get("process_ticks")) != paused_ticks:
		failures.append("gameplay simulation advanced while SceneTree was paused")
	if pause_menu.process_mode != Node.PROCESS_MODE_ALWAYS:
		failures.append("pause presentation is not processable while paused")

	await _dispatch_cancel(tree, true)
	if bool(flow.call("is_pause_active")) or tree.paused or pause_menu.visible:
		failures.append("second handled ui_cancel did not resume exactly once")
	if int(game.get("unhandled_cancel_count")) != 0:
		failures.append("resume ui_cancel leaked into gameplay _unhandled_input")
	if Input.mouse_mode != expected_resume_mouse_mode:
		failures.append("Resume did not restore the exact pre-pause mouse ownership mode")
	if bool(flow.call("request_resume")):
		failures.append("duplicate resume request was not idempotent")
	await _dispatch_cancel(tree, false)

	fake_save.fail_saves = true
	var slot_before_failure := fake_save.slot_version
	var game_before_failure: Node = app.get("current_scene") as Node
	if not bool(flow.call("request_pause")):
		failures.append("GAMEFLOW could not pause for Save & Quit proof")
	if bool(flow.call("request_save_and_quit")):
		failures.append("injected SAVE failure unexpectedly routed to Title")
	if fake_save.save_calls != 1 or int(game.get("save_request_count")) != 1:
		failures.append("failed Save & Quit did not invoke accepted SAVE exactly once")
	if fake_save.slot_version != slot_before_failure:
		failures.append("failed Save & Quit changed prior slot state")
	if app.get("current_scene") != game_before_failure or str(app.call("current_route_id")) != "game":
		failures.append("SAVE failure replaced the active Game route")
	if not tree.paused or not bool(flow.call("is_pause_active")) or not pause_menu.visible:
		failures.append("SAVE failure did not remain safely paused in Game")
	if not str(pause_menu.call("feedback_text")).contains("injected save failure"):
		failures.append("SAVE failure diagnostics were not surfaced")

	fake_save.fail_saves = false
	if not bool(flow.call("request_save_and_quit")):
		failures.append("successful Save & Quit did not route to Title")
	if fake_save.save_calls != 2 or int(game.get("save_request_count")) != 2:
		failures.append("successful Save & Quit did not invoke accepted SAVE exactly once")
	if fake_save.slot_version != slot_before_failure + 1:
		failures.append("successful Save & Quit did not commit exactly one slot version")
	if str(app.call("current_route_id")) != "title" or app.get("current_scene") == game:
		failures.append("successful Save & Quit did not commit Title route")
	if tree.paused or bool(flow.call("is_pause_active")) or pause_menu.visible:
		failures.append("successful Save & Quit retained stale pause ownership")
	if game.get_parent() != null:
		failures.append("successful Save & Quit did not detach stale Game synchronously")
	await tree.process_frame
	if is_instance_valid(game):
		failures.append("successful Save & Quit retained stale Game after teardown frame")
	if host.get_child_count() != 1:
		failures.append("successful Save & Quit left overlapping route children")
	var returned_title: Node = app.get("current_scene") as Node
	if returned_title == null:
		failures.append("successful Save & Quit did not realize fresh Title")
	else:
		var continue_button := returned_title.get_node_or_null("SafeMargin/Center/MenuPanel/Menu/ContinueButton") as Button
		if continue_button == null or continue_button.disabled:
			failures.append("returned Title did not re-probe newly available Continue")

	await _cleanup(tree, app, original_paused, original_mouse_mode)
	return failures


static func _test_app_root_contract(failures: Array[String]) -> void:
	var packed = ResourceLoader.load(APP_ROOT_PATH)
	if packed == null or not packed is PackedScene:
		failures.append("GAMEFLOW AppRoot contract could not load")
		return
	var app: Node = packed.instantiate()
	var flow: Node = app.get_node_or_null("GameFlowController")
	var pause_menu: Node = app.get_node_or_null("PauseLayer/PauseMenu")
	if flow == null or pause_menu == null:
		failures.append("AppRoot must compose sibling GameFlowController + PauseMenu")
	else:
		if flow.process_mode != Node.PROCESS_MODE_ALWAYS or pause_menu.process_mode != Node.PROCESS_MODE_ALWAYS:
			failures.append("flow/pause siblings must remain processable while gameplay pauses")
	if app.process_mode == Node.PROCESS_MODE_ALWAYS:
		failures.append("AppRoot itself must not make SceneHost/Game ALWAYS-process")
	if not app.has_signal("route_changed"):
		failures.append("AppRoot must expose semantic route_changed")
	for method_name in ["save_current_game", "show_title", "quit_application"]:
		if not app.has_method(method_name):
			failures.append("AppRoot is missing GAMEFLOW seam: %s" % method_name)
	app.free()


static func _test_pause_menu_contract(failures: Array[String]) -> void:
	var packed = ResourceLoader.load(PAUSE_MENU_PATH)
	if packed == null or not packed is PackedScene:
		failures.append("pause menu did not load")
		return
	var menu: Node = packed.instantiate()
	if menu == null or not menu is Control:
		failures.append("pause menu root must inherit Control")
		return
	var control := menu as Control
	if control.anchor_right != 1.0 or control.anchor_bottom != 1.0 or control.process_mode != Node.PROCESS_MODE_ALWAYS:
		failures.append("pause menu must be full-rect and ALWAYS-process")
	if control.theme == null or control.theme.resource_path != THEME_PATH:
		failures.append("pause menu must consume stable Underworld Theme")
	for signal_name in ["resume_requested", "save_and_quit_requested", "quit_requested"]:
		if not control.has_signal(signal_name):
			failures.append("pause menu missing semantic signal: %s" % signal_name)
	var path := "SafeMargin/Center/MenuPanel/Menu/"
	var resume := control.get_node_or_null(path + "ResumeButton") as Button
	var save_quit := control.get_node_or_null(path + "SaveAndQuitButton") as Button
	var quit := control.get_node_or_null(path + "QuitButton") as Button
	if resume == null or resume.text != "RESUME" or resume.focus_mode != Control.FOCUS_ALL:
		failures.append("pause menu must expose focused Resume")
	if save_quit == null or save_quit.text != "SAVE & QUIT TO TITLE" or save_quit.focus_mode != Control.FOCUS_ALL:
		failures.append("pause menu must expose focused Save & Quit")
	if quit == null or quit.text != "QUIT GAME" or quit.focus_mode != Control.FOCUS_ALL:
		failures.append("pause menu must expose explicit Quit Game")
	var background := control.get_node_or_null("Background") as Control
	var margin := control.get_node_or_null("SafeMargin") as Control
	var panel := control.get_node_or_null("SafeMargin/Center/MenuPanel") as Control
	var stack := control.get_node_or_null("SafeMargin/Center/MenuPanel/Menu") as Control
	if background == null or background.theme_type_variation != &"ScreenBackground" or margin == null or margin.theme_type_variation != &"MenuSafeMargin" or panel == null or panel.theme_type_variation != &"MenuPanel" or stack == null or stack.theme_type_variation != &"MenuStack":
		failures.append("pause layout styling must remain delegated to accepted Theme roles")
	control.free()


static func _make_gameflow_fixture_scene() -> PackedScene:
	var script = ResourceLoader.load(GAMEFLOW_FIXTURE_SCRIPT_PATH)
	if script == null or not script is Script:
		return null
	var root := Node.new()
	root.name = "GameFlowFixture"
	root.set_script(script)
	var packed := PackedScene.new()
	var result := packed.pack(root)
	root.free()
	return packed if result == OK else null


static func _dispatch_cancel(tree: SceneTree, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	await tree.process_frame


static func _cleanup(tree: SceneTree, app: Node, original_paused: bool, original_mouse_mode: int) -> void:
	if tree.paused:
		tree.paused = false
	if app != null and is_instance_valid(app):
		app.queue_free()
		await tree.process_frame
	Input.mouse_mode = original_mouse_mode
	tree.paused = original_paused
