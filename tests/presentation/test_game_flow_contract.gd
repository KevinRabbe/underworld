extends RefCounted

const APP_ROOT_PATH := "res://app/app_root.tscn"
const GAME_SCENE_PATH := "res://app/game/game.tscn"
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


class BackProbe:
	extends RefCounted
	var stack: Node = null
	var token: int = 0
	var calls: int = 0

	func handle_back() -> void:
		calls += 1
		if stack != null and token > 0:
			stack.call("pop_surface", token)


class RejectingPlayerProbe:
	extends Node

	func configure_gameplay_input_gate(_gate: Node) -> bool:
		return false


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_app_root_contract(failures)
	_test_production_input_composition(failures)
	_test_pause_menu_contract(failures)
	return failures


static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var original_paused := tree.paused
	var original_mouse_mode := Input.mouse_mode
	tree.paused = false

	var app_packed = ResourceLoader.load(APP_ROOT_PATH)
	var title_packed = ResourceLoader.load(TITLE_SCREEN_PATH)
	var game_fixture := _make_gameflow_fixture_scene(false)
	var rejecting_game_fixture := _make_gameflow_fixture_scene(true)
	var missing_gate_fixture := _make_missing_game_gate_scene()
	if (
		app_packed == null or not app_packed is PackedScene
		or title_packed == null or not title_packed is PackedScene
		or game_fixture == null
		or rejecting_game_fixture == null
		or missing_gate_fixture == null
	):
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
	var input_gate: Node = app.get_node_or_null("GameplayInputGate")
	var focus_stack: Node = app.get_node_or_null("UiFocusStack")
	var pause_menu := app.get_node_or_null("PauseLayer/PauseMenu") as Control
	var title: Node = app.get("current_scene") as Node
	if host == null or flow == null or input_gate == null or focus_stack == null or pause_menu == null or title == null:
		failures.append("GAMEFLOW runtime composition did not realize route/flow/input/focus/pause nodes")
		await _cleanup(tree, app, original_paused, original_mouse_mode)
		return failures

	# The production AppRoot route must fail closed before startup preparation or
	# route commit when a Game candidate is missing or rejects the required gate.
	app.set("_game_scene", missing_gate_fixture)
	if bool(app.call("start_new_game")):
		failures.append("Game candidate without gameplay-input seam unexpectedly committed")
	if app.get("current_scene") != title or str(app.call("current_route_id")) != "title" or host.get_child_count() != 1:
		failures.append("missing gameplay-input Game seam replaced the active Title route")

	app.set("_game_scene", rejecting_game_fixture)
	if bool(app.call("start_new_game")):
		failures.append("Game candidate rejecting gameplay-input authority unexpectedly committed")
	if app.get("current_scene") != title or str(app.call("current_route_id")) != "title" or host.get_child_count() != 1:
		failures.append("rejected gameplay-input Game composition replaced the active Title route")

	app.set("_game_scene", game_fixture)
	title.emit_signal("new_game_requested")
	var game: Node = app.get("current_scene") as Node
	if game == null or game == title or str(app.call("current_route_id")) != "game":
		failures.append("GAMEFLOW runtime proof could not enter Game route")
		await _cleanup(tree, app, original_paused, original_mouse_mode)
		return failures
	if game.get("configured_gameplay_input_gate") != input_gate:
		failures.append("AppRoot did not inject its exact GameplayInputGate into Game fixture")
	if bool(game.get("gate_configured_inside_tree")):
		failures.append("AppRoot configured Game gameplay-input authority after SceneTree entry")
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

	# A normal Control cannot outrun GameFlow's `_input` phase. The configured
	# focus stack must therefore own Back explicitly before Pause/Resume fallback.
	var origin := Button.new()
	origin.name = "BackOrigin"
	origin.focus_mode = Control.FOCUS_ALL
	pause_menu.add_child(origin)
	origin.grab_focus()

	var surface_one := Control.new()
	surface_one.name = "SyntheticChildOne"
	surface_one.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_menu.add_child(surface_one)
	var focus_one := Button.new()
	focus_one.name = "FocusOne"
	focus_one.focus_mode = Control.FOCUS_ALL
	surface_one.add_child(focus_one)
	var probe_one := BackProbe.new()
	probe_one.stack = focus_stack
	probe_one.token = int(focus_stack.call(
		"push_surface",
		surface_one,
		Callable(probe_one, "handle_back"),
		origin,
		focus_one,
		origin
	))

	var surface_two := Control.new()
	surface_two.name = "SyntheticChildTwo"
	surface_two.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_menu.add_child(surface_two)
	var focus_two := Button.new()
	focus_two.name = "FocusTwo"
	focus_two.focus_mode = Control.FOCUS_ALL
	surface_two.add_child(focus_two)
	var probe_two := BackProbe.new()
	probe_two.stack = focus_stack
	probe_two.token = int(focus_stack.call(
		"push_surface",
		surface_two,
		Callable(probe_two, "handle_back"),
		focus_one,
		focus_two,
		focus_one
	))
	await tree.process_frame
	if probe_one.token <= 0 or probe_two.token <= 0 or int(focus_stack.call("depth")) != 2:
		failures.append("nested UI Back owners were not registered deterministically")

	await _dispatch_cancel(tree, true)
	await _dispatch_cancel(tree, false)
	if probe_two.calls != 1 or probe_one.calls != 0 or int(focus_stack.call("depth")) != 1:
		failures.append("first nested ui_cancel did not pop exactly the top UI surface")
	if not tree.paused or not bool(flow.call("is_pause_active")):
		failures.append("nested UI Back resumed gameplay underneath Pause")
	await tree.process_frame
	if not focus_one.has_focus():
		failures.append("nested UI pop did not restore originating focus")

	await _dispatch_cancel(tree, true)
	await _dispatch_cancel(tree, false)
	if probe_one.calls != 1 or int(focus_stack.call("depth")) != 0:
		failures.append("second nested ui_cancel did not pop exactly the parent UI surface")
	if not tree.paused or not bool(flow.call("is_pause_active")):
		failures.append("parent UI Back resumed gameplay instead of returning to Pause")
	await tree.process_frame
	if not origin.has_focus():
		failures.append("parent UI pop did not restore safe origin focus")
	if int(game.get("unhandled_cancel_count")) != 0:
		failures.append("UI-owned Back leaked into gameplay _unhandled_input")

	surface_two.queue_free()
	surface_one.queue_free()
	origin.queue_free()
	await tree.process_frame

	# With the higher UI stack empty, Back falls through to the existing single
	# GameFlow resume authority exactly once.
	await _dispatch_cancel(tree, true)
	if bool(flow.call("is_pause_active")) or tree.paused or pause_menu.visible:
		failures.append("Back did not resume after the higher UI stack became empty")
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

	# A successful durable save does not authorize route destruction. If the
	# subsequent Title replacement fails, the exact current Game stays live and
	# paused so the player can retry. The successful slot commit is intentionally
	# retained; GAMEFLOW does not invent persistence rollback authority.
	fake_save.fail_saves = false
	var game_before_route_failure: Node = app.get("current_scene") as Node
	var invalid_title := PackedScene.new()
	app.set("_title_scene", invalid_title)
	if bool(flow.call("request_save_and_quit")):
		failures.append("failed Game-to-Title replacement unexpectedly reported Save & Quit success")
	if fake_save.save_calls != 2 or int(game.get("save_request_count")) != 2:
		failures.append("route-failed Save & Quit did not invoke accepted SAVE exactly once")
	if fake_save.slot_version != slot_before_failure + 1:
		failures.append("successful SAVE before route failure did not commit exactly one slot version")
	if app.get("current_scene") != game_before_route_failure or str(app.call("current_route_id")) != "game":
		failures.append("failed Title replacement destroyed or replaced the active Game route")
	if not tree.paused or not bool(flow.call("is_pause_active")) or not pause_menu.visible:
		failures.append("failed Title replacement did not remain safely paused in Game")
	if not str(pause_menu.call("feedback_text")).contains("Title route transition failed"):
		failures.append("failed Title replacement diagnostics were not surfaced")

	# Route teardown is a hard ownership boundary. Seed one Game-owned focus entry
	# and one gameplay capture immediately before the successful transition; both
	# application-lived coordinators must be clean after the outgoing Game dies.
	var route_surface := Control.new()
	route_surface.name = "RouteOwnedSurface"
	game.add_child(route_surface)
	var route_focus := Button.new()
	route_focus.name = "RouteOwnedFocus"
	route_focus.focus_mode = Control.FOCUS_ALL
	route_surface.add_child(route_focus)
	var route_probe := BackProbe.new()
	route_probe.stack = focus_stack
	route_probe.token = int(focus_stack.call(
		"push_surface",
		route_surface,
		Callable(route_probe, "handle_back"),
		null,
		route_focus,
		null
	))
	var route_capture_token: int = int(input_gate.call("acquire", &"synthetic_game_overlay"))
	if route_probe.token <= 0 or int(focus_stack.call("depth")) != 1:
		failures.append("route-teardown fixture could not seed Game-owned focus state")
	if route_capture_token <= 0 or int(input_gate.call("active_capture_count")) != 1:
		failures.append("route-teardown fixture could not seed Game-owned input capture")

	app.set("_title_scene", title_packed)
	if not bool(flow.call("request_save_and_quit")):
		failures.append("later explicit Save & Quit did not recover after route failure")
	if fake_save.save_calls != 3 or int(game.get("save_request_count")) != 3:
		failures.append("successful Save & Quit did not invoke accepted SAVE exactly once")
	if fake_save.slot_version != slot_before_failure + 2:
		failures.append("successful Save & Quit did not commit exactly one additional slot version")
	if str(app.call("current_route_id")) != "title" or app.get("current_scene") == game:
		failures.append("successful Save & Quit did not commit Title route")
	if tree.paused or bool(flow.call("is_pause_active")) or pause_menu.visible:
		failures.append("successful Save & Quit retained stale pause ownership")
	if int(focus_stack.call("depth")) != 0:
		failures.append("successful route replacement retained stale outgoing UI focus ownership")
	if int(input_gate.call("active_capture_count")) != 0:
		failures.append("successful route replacement retained stale outgoing gameplay-input capture")
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
	var input_gate: Node = app.get_node_or_null("GameplayInputGate")
	var focus_stack: Node = app.get_node_or_null("UiFocusStack")
	var pause_menu: Node = app.get_node_or_null("PauseLayer/PauseMenu")
	if flow == null or input_gate == null or focus_stack == null or pause_menu == null:
		failures.append("AppRoot must compose GameFlow + input gate + focus stack + PauseMenu")
	else:
		if (
			flow.process_mode != Node.PROCESS_MODE_ALWAYS
			or input_gate.process_mode != Node.PROCESS_MODE_ALWAYS
			or focus_stack.process_mode != Node.PROCESS_MODE_ALWAYS
			or pause_menu.process_mode != Node.PROCESS_MODE_ALWAYS
		):
			failures.append("flow/input/focus/pause application siblings must remain processable while gameplay pauses")
		for method_name in ["acquire", "release", "allows_player_input", "clear_captures"]:
			if not input_gate.has_method(method_name):
				failures.append("AppRoot GameplayInputGate is missing semantic method: %s" % method_name)
		for method_name in ["push_surface", "pop_surface", "has_back_owner", "dispatch_back"]:
			if not focus_stack.has_method(method_name):
				failures.append("AppRoot UiFocusStack is missing semantic method: %s" % method_name)
	if app.process_mode == Node.PROCESS_MODE_ALWAYS:
		failures.append("AppRoot itself must not make SceneHost/Game ALWAYS-process")
	if not app.has_signal("route_changed"):
		failures.append("AppRoot must expose semantic route_changed")
	for method_name in ["save_current_game", "show_title", "quit_application", "get_gameplay_input_gate", "get_ui_focus_stack"]:
		if not app.has_method(method_name):
			failures.append("AppRoot is missing GAMEFLOW seam: %s" % method_name)
	app.free()


static func _test_production_input_composition(failures: Array[String]) -> void:
	var app_packed = ResourceLoader.load(APP_ROOT_PATH)
	var game_packed = ResourceLoader.load(GAME_SCENE_PATH)
	if app_packed == null or not app_packed is PackedScene or game_packed == null or not game_packed is PackedScene:
		failures.append("production gameplay-input composition could not load AppRoot/Game scenes")
		return
	var app: Node = app_packed.instantiate()
	var game: Node = game_packed.instantiate()
	var input_gate: Node = app.get_node_or_null("GameplayInputGate")
	if app == null or game == null or input_gate == null:
		failures.append("production gameplay-input composition could not instantiate authority chain")
		if game != null:
			game.free()
		if app != null:
			app.free()
		return

	if not bool(app.call("_configure_gameplay_input_authority", game)):
		failures.append("production AppRoot rejected valid Game gameplay-input composition")
	else:
		if game.is_inside_tree():
			failures.append("production Game entered SceneTree before gameplay-input composition completed")
		if game.get("_gameplay_input_gate") != input_gate:
			failures.append("production Game did not retain exact AppRoot GameplayInputGate object")
		var prepared_player: Node = game.get("_prepared_player") as Node
		if prepared_player == null or not is_instance_valid(prepared_player):
			failures.append("production Game did not pre-bind a real Player before SceneTree entry")
		else:
			if prepared_player.is_inside_tree():
				failures.append("production Player entered SceneTree before gameplay-input composition completed")
			if prepared_player.get("_gameplay_input_gate") != input_gate:
				failures.append("production Player did not retain same exact AppRoot GameplayInputGate object")

	var missing_player := Node.new()
	if bool(game.call("_bind_player_input_authority", missing_player, input_gate)):
		failures.append("production Game accepted Player candidate missing gameplay-input seam")
	missing_player.free()
	var rejecting_player := RejectingPlayerProbe.new()
	if bool(game.call("_bind_player_input_authority", rejecting_player, input_gate)):
		failures.append("production Game accepted Player candidate rejecting gameplay-input authority")
	rejecting_player.free()

	var missing_prebind_game: Node = game_packed.instantiate()
	missing_prebind_game.set("_gameplay_input_gate", input_gate)
	if bool(missing_prebind_game.call("_create_player")):
		failures.append("production Game created playable Player without successful pre-binding")
	if missing_prebind_game.get("player") != null:
		failures.append("failed Player pre-binding retained an unsuppressed playable Player")
	missing_prebind_game.free()

	game.free()
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


static func _make_gameflow_fixture_scene(reject_gate: bool = false) -> PackedScene:
	var script = ResourceLoader.load(GAMEFLOW_FIXTURE_SCRIPT_PATH)
	if script == null or not script is Script:
		return null
	var root := Node.new()
	root.name = "GameFlowFixture"
	root.set_script(script)
	root.set("reject_gameplay_input_gate", reject_gate)
	var packed := PackedScene.new()
	var result := packed.pack(root)
	root.free()
	return packed if result == OK else null


static func _make_missing_game_gate_scene() -> PackedScene:
	var root := Node.new()
	root.name = "MissingGameplayInputGateFixture"
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