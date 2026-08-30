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

	func save_slot(
		_context,
		_delta_store,
		_inventory_state,
		_equipment_state,
		_pending_loot_states,
		_resume_position,
		_slot_path: String
	) -> Dictionary:
		save_calls += 1
		if fail_saves:
			return {"success": false, "diagnostics": ["injected save failure"]}
		slot_version += 1
		available = true
		return {"success": true, "diagnostics": [], "slot_version": slot_version}


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_app_root_gameflow_contract(failures)
	_test_pause_menu_contract(failures)
	return failures


static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var original_paused: bool = tree.paused
	var original_mouse_mode: int = Input.mouse_mode
	tree.paused = false

	var app_packed = ResourceLoader.load(APP_ROOT_PATH)
	var title_packed = ResourceLoader.load(TITLE_SCREEN_PATH)
	var game_fixture: PackedScene = _make_gameflow_fixture_scene()
	if app_packed == null or not app_packed is PackedScene:
		return ["GAMEFLOW runtime proof could not load AppRoot"]
	if title_packed == null or not title_packed is PackedScene:
		return ["GAMEFLOW runtime proof could not load Title screen"]
	if game_fixture == null:
		return ["GAMEFLOW runtime proof could not build gameplay fixture"]

	var app: Node = app_packed.instantiate()
	var fake_save := FakeSaveSlotService.new()
	if app == null:
		return ["GAMEFLOW runtime proof could not instantiate AppRoot"]
	if not bool(app.call("configure_route_scenes", title_packed, game_fixture)):
		app.free()
		return ["GAMEFLOW runtime proof could not inject route fixtures"]
	app.set("_save_slot_service", fake_save)
	tree.root.add_child(app)
	await tree.process_frame

	var scene_host: Node = app.get_node_or_null("SceneHost")
	var flow: Node = app.get_node_or_null("GameFlowController")
	var pause_menu: Control = app.get_node_or_null("PauseLayer/PauseMenu") as Control
	var title: Node = app.get("current_scene") as Node
	if scene_host == null or flow == null or pause_menu == null or title == null:
		failures.append("GAMEFLOW runtime composition did not realize title/flow/pause nodes")
		await _cleanup(tree, app, original_paused, original_mouse_mode)
		return failures

	title.emit_signal("new_game_requested")
	var game: Node = app.get("current_scene") as Node
	if game == null or game == title or str(app.call("current_route_id")) != "game":
		failures.append("GAMEFLOW runtime proof could not enter injected Game route")
		await _cleanup(tree, app, original_paused, original_mouse_mode)
		return failures
	await tree.process_frame

	# Real input pipeline: GameFlowController receives _input before the fixture's
	# _unhandled_input and marks ui_cancel handled, so the prototype Player-style
	# fallback cannot observe the same event.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _dispatch_cancel(tree, true)
	if not bool(flow.call("is_pause_active")) or not tree.paused:
		failures.append("ui_cancel did not enter exactly one semantic pause state")
	if not pause_menu.visible:
		failures.append("semantic pause did not expose pause presentation")
	if int(game.get("unhandled_cancel_count")) != 0:
		failures.append("handled pause ui_cancel leaked into gameplay _unhandled_input")
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		failures.append("pause did not release captured mouse ownership")
	if bool(flow.call("request_pause")):
		failures.append("duplicate pause request was not idempotent")

	await _dispatch_cancel(tree, false)
	var paused_ticks: int = int(game.get("process_ticks"))
	await tree.process_frame
	await tree.process_frame
	if int(game.get("process_ticks")) != paused_ticks:
		failures.append("gameplay fixture continued simulation while SceneTree was paused")
	if pause_menu.process_mode != Node.PROCESS_MODE_ALWAYS:
		failures.append("pause presentation is not processable while SceneTree is paused")

	await _dispatch_cancel(tree, true)
	if bool(flow.call("is_pause_active")) or tree.paused or pause_menu.visible:
		failures.append("second handled ui_cancel did not resume exactly once")
	if int(game.get("unhandled_cancel_count")) != 0:
		failures.append("resume ui_cancel leaked into gameplay _unhandled_input")
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		failures.append("Resume did not restore captured mouse ownership")
	if bool(flow.call("request_resume")):
		failures.append("duplicate resume request was not idempotent")
	await _dispatch_cancel(tree, false)

	# Save failure must remain paused on the exact same live Game and must not
	# mutate the prior valid slot state.
	fake_save.fail_saves = true
	var slot_before_failure: int = fake_save.slot_version
	var game_before_failure: Node = app.get("current_scene") as Node
	if not bool(flow.call("request_pause")):
		failures.append("GAMEFLOW could not enter pause state for Save & Quit proof")
	var failed_save_quit: bool = bool(flow.call("request_save_and_quit"))
	if failed_save_quit:
		failures.append("injected SAVE failure unexpectedly routed to Title")
	if fake_save.save_calls != 1 or int(game.get("save_request_count")) != 1:
		failures.append("Save & Quit failure path did not invoke accepted SAVE exactly once")
	if fake_save.slot_version != slot_before_failure:
		failures.append("Save & Quit failure changed the prior valid slot state")
	if app.get("current_scene") != game_before_failure or str(app.call("current_route_id")) != "game":
		failures.append("SAVE failure destroyed or replaced the active Game route")
	if not tree.paused or not bool(flow.call("is_pause_active")) or not pause_menu.visible:
		failures.append("SAVE failure did not remain safely paused in Game")
	if not str(pause_menu.call("feedback_text")).contains("injected save failure"):
		failures.append("SAVE failure diagnostics were not surfaced through pause presentation")

	# The next explicit attempt succeeds, transitions once through accepted
	# AppRoot.show_title(), and lets the accepted Title route re-probe Continue.
	fake_save.fail_saves = false
	var successful_save_quit: bool = bool(flow.call("request_save_and_quit"))
	if not successful_save_quit:
		failures.append("successful Save & Quit did not route to Title")
	if fake_save.save_calls != 2 or int(game.get("save_request_count")) != 2:
		failures.append("successful Save & Quit did not invoke accepted SAVE exactly once for its request")
	if fake_save.slot_version != slot_before_failure + 1:
		failures.append("successful Save & Quit did not commit exactly one new slot version")
	if str(app.call("current_route_id")) != "title" or app.get("current_scene") == game:
		failures.append("successful Save & Quit did not commit the accepted Title route")
	if tree.paused or bool(flow.call("is_pause_active")) or pause_menu.visible:
		failures.append("successful Save & Quit left stale pause ownership active")
	if game.get_parent() != null:
		failures.append("successful Save & Quit did not synchronously detach stale Game route")
	await tree.process_frame
	if is_instance_valid(game):
		failures.append("successful Save & Quit retained stale Game ownership after teardown frame")
	if scene_host.get_child_count() != 1:
		failures.append("successful Save & Quit left overlapping route children")
	var returned_title: Node = app.get("current_scene") as Node
	if returned_title == null:
		failures.append("successful Save & Quit did not realize a fresh Title route")
	else:
		var continue_button := returned_title.get_node_or_null("SafeMargin/Center/MenuPanel/Menu/ContinueButton") as Button
		if continue_button == null or continue_button.disabled:
			failures.append("returned Title did not re-probe newly available Continue through AppRoot SAVE authority")

	await _cleanup(tree, app, original_paused, original_mouse_mode)
	return failures


static func _test_app_root_gameflow_contract(failures: Array[String]) -> void:
	var packed = ResourceLoader.load(APP_ROOT_PATH)
	if packed == null or not packed is PackedScene:
		failures.append("GAMEFLOW AppRoot contract could not load")
		return
	var app: Node = packed.instantiate()
	if app == null:
		failures.append("GAMEFLOW AppRoot contract could not instantiate")
		return
	var flow: Node = app.get_node_or_null("GameFlowController")
	var pause_menu: Node = app.get_node_or_null("PauseLayer/PauseMenu")
	if flow == null or pause_menu == null:
		failures.append("AppRoot must compose dedicated sibling GameFlowController + PauseMenu")
	else:
		if flow.process_mode != Node.PROCESS_MODE_ALWAYS:
			failures.append("GameFlowController must remain processable while gameplay is paused")
		if pause_menu.process_mode != Node.PROCESS_MODE_ALWAYS:
			failures.append("PauseMenu must remain processable while gameplay is paused")
	if app.process_mode == Node.PROCESS_MODE_ALWAYS:
		failures.append("AppRoot itself must remain pausable so SceneHost/Game do not inherit ALWAYS processing")
	if not app.has_signal("route_changed"):
		failures.append("AppRoot must expose semantic route_changed observation for pause cleanup")
	for method_name in ["save_current_game", "show_title", "quit_application"]:
		if not app.has_method(method_name):
			failures.append("AppRoot is missing GAMEFLOW authority seam: %s" % method_name)
	app.free()


static func _test_pause_menu_contract(failures: Array[String]) -> void:
	var packed = ResourceLoader.load(PAUSE_MENU_PATH)
	if packed == null or not packed is PackedScene:
		failures.append("pause menu did not load as PackedScene")
		return
	var menu: Node = packed.instantiate()
	if menu == null or not menu is Control:
		failures.append("pause menu root must inherit Control")
		return
	var control := menu as Control
	if control.anchor_right != 1.0 or control.anchor_bottom != 1.0:
		failures.append("pause menu must use full-rect responsive anchors")
	if control.theme == null or control.theme.resource_path != THEME_PATH:
		failures.append("pause menu must consume the stable Underworld Theme")
	if control.process_mode != Node.PROCESS_MODE_ALWAYS:
		failures.append("pause menu must remain processable during SceneTree pause")
	for signal_name in ["resume_requested", "save_and_quit_requested", "quit_requested"]:
		if not control.has_signal(signal_name):
			failures.append("pause menu is missing semantic intent signal: %s" % signal_name)
	for method_name in ["set_open", "set_feedback", "feedback_text"]:
		if not control.has_method(method_name):
			failures.append("pause menu is missing presentation method: %s" % method_name)
	var menu_path := "SafeMargin/Center/MenuPanel/Menu/"
	var resume := control.get_node_or_null(menu_path + "ResumeButton") as Button
	var save_quit := control.get_node_or_null(menu_path + "SaveAndQuitButton") as Button
	var quit := control.get_node_or_null(menu_path + "QuitButton") as Button
	if resume == null or resume.text != "RESUME" or resume.focus_mode != Control.FOCUS_ALL:
		failures.append("pause menu must expose keyboard/controller Resume")
	if save_quit == null or save_quit.text != "SAVE & QUIT TO TITLE" or save_quit.focus_mode != Control.FOCUS_ALL:
		failures.append("pause menu must expose semantic Save & Quit to Title")
	if quit == null or quit.text != "QUIT GAME" or quit.focus_mode != Control.FOCUS_ALL:
		failures.append("pause menu must expose explicit Quit Game without hidden autosave")
	var background := control.get_node_or_null("Background") as Control
	var safe_margin := control.get_node_or_null("SafeMargin") as Control
	var panel := control.get_node_or_null("SafeMargin/Center/MenuPanel") as Control
	var stack := control.get_node_or_null("SafeMargin/Center/MenuPanel/Menu") as Control
	if background == null or background.theme_type_variation != &"ScreenBackground":
		failures.append("pause background styling must stay Theme-owned")
	if safe_margin == null or safe_margin.theme_type_variation != &"MenuSafeMargin":
		failures.append("pause safe margin must stay Theme-owned")
	if panel == null or panel.theme_type_variation != &"MenuPanel":
		failures.append("pause panel styling must stay Theme-owned")
	if stack == null or stack.theme_type_variation != &"MenuStack":
		failures.append("pause stack spacing must stay Theme-owned")
	control.free()


static func _make_gameflow_fixture_scene() -> PackedScene:
	var fixture_script = ResourceLoader.load(GAMEFLOW_FIXTURE_SCRIPT_PATH)
	if fixture_script == null or not fixture_script is Script:
		return null
	var root := Node.new()
	root.name = "GameFlowFixture"
	root.set_script(fixture_script)
	var packed := PackedScene.new()
	var result: Error = packed.pack(root)
	root.free()
	if result != OK:
		return null
	return packed


static func _dispatch_cancel(tree: SceneTree, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	await tree.process_frame


static func _cleanup(
	tree: SceneTree,
	app: Node,
	original_paused: bool,
	original_mouse_mode: int
) -> void:
	if tree.paused:
		tree.paused = false
	if app != null and is_instance_valid(app):
		app.queue_free()
		await tree.process_frame
	Input.mouse_mode = original_mouse_mode
	tree.paused = original_paused
