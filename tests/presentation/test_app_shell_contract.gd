extends RefCounted

const APP_ROOT_PATH := "res://app/app_root.tscn"
const GAME_SCENE_PATH := "res://app/game/game.tscn"
const TITLE_SCREEN_PATH := "res://presentation/ui/screens/title/title_screen.tscn"
const THEME_PATH := "res://presentation/ui/theme/underworld_theme.tres"
const GAME_FIXTURE_SCRIPT_PATH := "res://tests/fixtures/app_shell_game_fixture.gd"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_main_scene_contract(failures)
	_test_app_root_contract(failures)
	_test_title_screen_contract(failures)
	_test_theme_boundary(failures)
	_test_game_scene_remains_independent(failures)
	return failures


static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var app_packed = ResourceLoader.load(APP_ROOT_PATH)
	var title_packed = ResourceLoader.load(TITLE_SCREEN_PATH)
	var game_fixture: PackedScene = _make_fixture_scene("RuntimeGameFixture")
	var reject_new_fixture: PackedScene = _make_fixture_scene("RejectNewFixture", true, false)
	var reject_continue_fixture: PackedScene = _make_fixture_scene("RejectContinueFixture", false, true)
	if app_packed == null or not app_packed is PackedScene:
		failures.append("runtime app-shell proof could not load AppRoot PackedScene")
		return failures
	if title_packed == null or not title_packed is PackedScene:
		failures.append("runtime app-shell proof could not load title PackedScene")
		return failures
	if game_fixture == null or reject_new_fixture == null or reject_continue_fixture == null:
		failures.append("runtime app-shell proof could not build prepared-game fixtures")
		return failures

	var app: Node = app_packed.instantiate()
	if app == null:
		failures.append("runtime app-shell proof could not instantiate AppRoot")
		return failures
	if not bool(app.call("configure_route_scenes", title_packed, game_fixture)):
		failures.append("AppRoot rejected pre-tree injected route scenes")
		app.free()
		return failures

	tree.root.add_child(app)
	await tree.process_frame

	var scene_host: Node = app.get_node_or_null("SceneHost")
	if scene_host == null:
		failures.append("runtime AppRoot is missing SceneHost")
		app.queue_free()
		await tree.process_frame
		return failures
	if scene_host.get_child_count() != 1:
		failures.append("AppRoot must realize exactly one title route child on SceneTree entry")

	var title: Node = app.get("current_scene") as Node
	if title == null or title.get_parent() != scene_host:
		failures.append("AppRoot current scene must be the live title child after SceneTree entry")
	elif str(app.call("current_route_id")) != "title":
		failures.append("AppRoot must expose title as the current semantic route after entry")

	if title != null:
		var continue_button := title.get_node_or_null("SafeMargin/Center/MenuPanel/Menu/ContinueButton") as Button
		if continue_button == null or not continue_button.disabled:
			failures.append("missing SAVE slot must leave Continue disabled on the live title route")

		title.emit_signal("continue_requested")
		if app.get("current_scene") != title or scene_host.get_child_count() != 1:
			failures.append("missing SAVE slot Continue must remain fail-closed and non-routing")

		# An unusable target route must fail before the current title route is
		# detached. PackedScene.can_instantiate() keeps this proof free of expected
		# engine errors from attempting to instantiate an empty PackedScene.
		var invalid_game := PackedScene.new()
		app.set("_game_scene", invalid_game)
		title.emit_signal("new_game_requested")
		if app.get("current_scene") != title or scene_host.get_child_count() != 1:
			failures.append("uninstantiable replacement must leave the current title route intact")
		if str(app.call("current_route_id")) != "title":
			failures.append("failed replacement must not commit a new semantic route id")

		# A valid scene whose off-tree preparation rejects startup is also a failed
		# replacement. Title must remain live because route mutation happens only
		# after prepare_new_game() succeeds.
		app.set("_game_scene", reject_new_fixture)
		title.emit_signal("new_game_requested")
		if app.get("current_scene") != title or scene_host.get_child_count() != 1:
			failures.append("rejected NEW preparation must leave title route untouched")
		if str(app.call("current_route_id")) != "title":
			failures.append("rejected NEW preparation must not commit game route identity")

		app.set("_game_scene", game_fixture)
		title.emit_signal("new_game_requested")
		var first_game: Node = app.get("current_scene") as Node
		if first_game == null or first_game == title:
			failures.append("New Game semantic intent did not replace title with the game route")
		elif first_game.get_parent() != scene_host or first_game.name != "RuntimeGameFixture":
			failures.append("New Game did not realize the injected game route under SceneHost")
		elif str(first_game.get("prepared_mode")) != "new":
			failures.append("New Game route was not prepared with NEW semantics before commit")
		else:
			var app_gate: Node = app.call("get_gameplay_input_gate") as Node
			if first_game.get("gameplay_input_gate") != app_gate:
				failures.append("New Game fixture did not receive the exact AppRoot GameplayInputGate authority")
			if bool(first_game.get("gate_configured_inside_tree")):
				failures.append("New Game fixture gameplay-input authority must be configured off-tree before route commit")
		if scene_host.get_child_count() != 1:
			failures.append("SceneHost retained overlapping title/game route children")
		if title.get_parent() != null or not title.is_queued_for_deletion():
			failures.append("stale title route must be detached and queued after New Game transition")
		if str(app.call("current_route_id")) != "game":
			failures.append("AppRoot did not commit semantic game route identity")

		# The detached title can still emit before the queued free is processed. Its
		# stale signal connection must not create a second game scene.
		title.emit_signal("new_game_requested")
		if app.get("current_scene") != first_game or scene_host.get_child_count() != 1:
			failures.append("stale duplicate New Game intent replaced or duplicated the active game route")

		var duplicate_result: bool = bool(app.call("start_new_game"))
		if duplicate_result or app.get("current_scene") != first_game or scene_host.get_child_count() != 1:
			failures.append("duplicate direct game-route request must be idempotent")

		# Force the transition guard to model a nested route request while a route
		# commit is active. The current game route must remain untouched.
		app.set("_transition_in_progress", true)
		var reentrant_result: bool = bool(app.call("show_title"))
		app.set("_transition_in_progress", false)
		if reentrant_result or app.get("current_scene") != first_game or scene_host.get_child_count() != 1:
			failures.append("re-entrant route request must not mutate the active scene")

	app.queue_free()
	await tree.process_frame

	# CONTINUE routing is tested separately from the persistence codec itself. The
	# fixture accepts any detached candidate, allowing this contract to prove the
	# critical ordering invariant: prepare_continue() runs while Game is still
	# off-tree, and rejection cannot detach the current title route.
	var continue_app: Node = app_packed.instantiate()
	if continue_app == null:
		failures.append("runtime Continue proof could not instantiate AppRoot")
		return failures
	if not bool(continue_app.call("configure_route_scenes", title_packed, game_fixture)):
		failures.append("runtime Continue proof could not configure route fixtures")
		continue_app.free()
		return failures
	tree.root.add_child(continue_app)
	await tree.process_frame

	var continue_host: Node = continue_app.get_node_or_null("SceneHost")
	var continue_title: Node = continue_app.get("current_scene") as Node
	if continue_host == null or continue_title == null:
		failures.append("runtime Continue proof did not start on a live title route")
	else:
		var fixture_candidate: Dictionary = {
			"fixture_token": "detached-before-route-commit",
			"nested": {"value": 7},
		}
		continue_app.set("_game_scene", reject_continue_fixture)
		var rejected_continue: bool = bool(
			continue_app.call("_replace_game_scene", true, fixture_candidate)
		)
		if rejected_continue:
			failures.append("rejected CONTINUE preparation unexpectedly reported success")
		if continue_app.get("current_scene") != continue_title or continue_host.get_child_count() != 1:
			failures.append("rejected CONTINUE preparation must leave title route untouched")
		if str(continue_app.call("current_route_id")) != "title":
			failures.append("rejected CONTINUE preparation must not commit game route identity")

		continue_app.set("_game_scene", game_fixture)
		var continued: bool = bool(continue_app.call("_replace_game_scene", true, fixture_candidate))
		var continued_game: Node = continue_app.get("current_scene") as Node
		if not continued or continued_game == null or continued_game == continue_title:
			failures.append("prepared CONTINUE route did not replace title")
		elif continued_game.get_parent() != continue_host:
			failures.append("prepared CONTINUE route is not the live SceneHost child")
		else:
			if str(continued_game.get("prepared_mode")) != "continue":
				failures.append("CONTINUE fixture did not receive detached preparation before route commit")
			var prepared_candidate: Variant = continued_game.get("prepared_candidate")
			if not prepared_candidate is Dictionary or prepared_candidate != fixture_candidate:
				failures.append("CONTINUE preparation did not receive the exact detached candidate")
			var continue_gate: Node = continue_app.call("get_gameplay_input_gate") as Node
			if continued_game.get("gameplay_input_gate") != continue_gate:
				failures.append("CONTINUE fixture did not receive the exact AppRoot GameplayInputGate authority")
			if bool(continued_game.get("gate_configured_inside_tree")):
				failures.append("CONTINUE fixture gameplay-input authority must be configured off-tree before route commit")
		if str(continue_app.call("current_route_id")) != "game":
			failures.append("successful CONTINUE did not commit semantic game route identity")
		if continue_host.get_child_count() != 1:
			failures.append("successful CONTINUE retained overlapping title/game route children")

	continue_app.queue_free()
	await tree.process_frame
	return failures


static func _make_fixture_scene(
	root_name: String,
	reject_new: bool = false,
	reject_continue: bool = false
) -> PackedScene:
	var fixture_script = ResourceLoader.load(GAME_FIXTURE_SCRIPT_PATH)
	if fixture_script == null or not fixture_script is Script:
		return null
	var fixture_root := Node.new()
	fixture_root.name = root_name
	fixture_root.set_script(fixture_script)
	fixture_root.set("reject_new_preparation", reject_new)
	fixture_root.set("reject_continue_preparation", reject_continue)
	var packed := PackedScene.new()
	var pack_result: Error = packed.pack(fixture_root)
	fixture_root.free()
	if pack_result != OK:
		return null
	return packed


static func _test_main_scene_contract(failures: Array[String]) -> void:
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_scene != APP_ROOT_PATH:
		failures.append("project main scene must route through app root: %s" % main_scene)


static func _test_app_root_contract(failures: Array[String]) -> void:
	var packed = ResourceLoader.load(APP_ROOT_PATH)
	if packed == null or not packed is PackedScene:
		failures.append("application root did not load as PackedScene")
		return
	var root: Node = packed.instantiate()
	if root == null:
		failures.append("application root could not instantiate")
		return
	if not root.has_node("SceneHost"):
		failures.append("application root is missing replaceable SceneHost")
	if not root.has_method("show_title") or not root.has_method("start_new_game") or not root.has_method("continue_game"):
		failures.append("application root must expose explicit title/NEW/CONTINUE routing operations")
	if not root.has_method("configure_route_scenes") or not root.has_method("current_route_id"):
		failures.append("application root must expose pre-tree route composition and semantic route inspection")
	if not root.has_method("configure_save_slot_path"):
		failures.append("application root must expose pre-tree SAVE slot-path composition")
	root.free()


static func _test_title_screen_contract(failures: Array[String]) -> void:
	var packed = ResourceLoader.load(TITLE_SCREEN_PATH)
	if packed == null or not packed is PackedScene:
		failures.append("title screen did not load as PackedScene")
		return
	var title: Node = packed.instantiate()
	if title == null:
		failures.append("title screen could not instantiate")
		return

	for signal_name in ["new_game_requested", "continue_requested", "quit_requested"]:
		if not title.has_signal(signal_name):
			failures.append("title screen is missing semantic intent signal: %s" % signal_name)
	if not title.has_method("set_continue_available"):
		failures.append("title screen must expose persistence-driven Continue availability")

	var menu_path := "SafeMargin/Center/MenuPanel/Menu/"
	var new_game := title.get_node_or_null(menu_path + "NewGameButton") as Button
	var continue_button := title.get_node_or_null(menu_path + "ContinueButton") as Button
	var quit_button := title.get_node_or_null(menu_path + "QuitButton") as Button
	if new_game == null or new_game.text != "NEW GAME":
		failures.append("title screen is missing New Game action")
	elif new_game.focus_mode != Control.FOCUS_ALL:
		failures.append("New Game must participate in keyboard/controller focus navigation")
	if continue_button == null:
		failures.append("title screen is missing Continue action")
	elif not continue_button.disabled or continue_button.focus_mode != Control.FOCUS_NONE:
		failures.append("Continue must default fail-closed until AppRoot proves a valid SAVE slot")
	if quit_button == null or quit_button.text != "QUIT":
		failures.append("title screen is missing Quit action")
	elif quit_button.focus_mode != Control.FOCUS_ALL:
		failures.append("Quit must participate in keyboard/controller focus navigation")

	if title is Control:
		var control := title as Control
		if control.anchor_right != 1.0 or control.anchor_bottom != 1.0:
			failures.append("title root must use full-rect anchors")
		if control.theme == null or control.theme.resource_path != THEME_PATH:
			failures.append("title screen must consume the stable Underworld Theme contract")
	else:
		failures.append("title screen root must inherit Control")

	var background := title.get_node_or_null("Background") as Control
	if background == null or background.theme_type_variation != &"ScreenBackground":
		failures.append("title background styling must be delegated to the Theme")
	var safe_margin := title.get_node_or_null("SafeMargin") as Control
	if safe_margin == null or safe_margin.theme_type_variation != &"MenuSafeMargin":
		failures.append("title safe-area spacing must be delegated to the Theme")
	var menu_panel := title.get_node_or_null("SafeMargin/Center/MenuPanel") as Control
	if menu_panel == null or menu_panel.theme_type_variation != &"MenuPanel":
		failures.append("title panel styling must be delegated to the Theme")
	var menu_stack := title.get_node_or_null("SafeMargin/Center/MenuPanel/Menu") as Control
	if menu_stack == null or menu_stack.theme_type_variation != &"MenuStack":
		failures.append("title menu spacing must be delegated to the Theme")
	var title_label := title.get_node_or_null(menu_path + "Title") as Control
	if title_label == null or title_label.theme_type_variation != &"TitleLabel":
		failures.append("title typography must be delegated to the Theme")
	title.free()


static func _test_theme_boundary(failures: Array[String]) -> void:
	var theme = ResourceLoader.load(THEME_PATH)
	if theme == null or not theme is Theme:
		failures.append("stable Underworld Theme did not load as Theme")
		return

	var expected_variations: Dictionary = {
		&"ScreenBackground": &"Panel",
		&"MenuPanel": &"PanelContainer",
		&"MenuSafeMargin": &"MarginContainer",
		&"MenuStack": &"VBoxContainer",
		&"TitleLabel": &"Label",
		&"SubtitleLabel": &"Label",
		&"StatusLabel": &"Label",
	}
	for variation in expected_variations:
		var base_type: StringName = expected_variations[variation]
		if not theme.is_type_variation(variation, base_type):
			failures.append("Underworld Theme variation '%s' must extend %s" % [variation, base_type])

	var hover_style: StyleBox = theme.get_stylebox(&"hover", &"Button")
	var focus_style: StyleBox = theme.get_stylebox(&"focus", &"Button")
	if hover_style == null or focus_style == null:
		failures.append("Underworld Theme must define hover and focus button states")
	elif hover_style == focus_style:
		failures.append("keyboard/controller focus styling must be independently replaceable from hover styling")


static func _test_game_scene_remains_independent(failures: Array[String]) -> void:
	var packed = ResourceLoader.load(GAME_SCENE_PATH)
	if packed == null or not packed is PackedScene:
		failures.append("existing gameplay composition root no longer loads independently")