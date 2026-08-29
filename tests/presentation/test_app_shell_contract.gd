extends RefCounted

const APP_ROOT_PATH := "res://app/app_root.tscn"
const GAME_SCENE_PATH := "res://app/game/game.tscn"
const TITLE_SCREEN_PATH := "res://presentation/ui/screens/title/title_screen.tscn"
const THEME_PATH := "res://presentation/ui/theme/underworld_theme.tres"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_main_scene_contract(failures)
	_test_app_root_contract(failures)
	_test_title_screen_contract(failures)
	_test_theme_boundary(failures)
	_test_game_scene_remains_independent(failures)
	return failures


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
	if not root.has_method("show_title") or not root.has_method("start_new_game"):
		failures.append("application root must expose explicit title/game routing operations")
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
		failures.append("Continue must fail closed and leave focus navigation until persistence integration")
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
	var menu_panel := title.get_node_or_null("SafeMargin/Center/MenuPanel") as Control
	if menu_panel == null or menu_panel.theme_type_variation != &"MenuPanel":
		failures.append("title panel styling must be delegated to the Theme")
	var title_label := title.get_node_or_null(menu_path + "Title") as Control
	if title_label == null or title_label.theme_type_variation != &"TitleLabel":
		failures.append("title typography must be delegated to the Theme")
	title.free()


static func _test_theme_boundary(failures: Array[String]) -> void:
	var theme = ResourceLoader.load(THEME_PATH)
	if theme == null or not theme is Theme:
		failures.append("stable Underworld Theme did not load as Theme")
		return
	for variation in [&"ScreenBackground", &"MenuPanel", &"TitleLabel", &"SubtitleLabel", &"StatusLabel"]:
		if not theme.is_type_variation(variation, &"Control") and not (
			theme.is_type_variation(variation, &"Panel")
			or theme.is_type_variation(variation, &"PanelContainer")
			or theme.is_type_variation(variation, &"Label")
		):
			failures.append("Underworld Theme is missing reusable variation: %s" % variation)


static func _test_game_scene_remains_independent(failures: Array[String]) -> void:
	var packed = ResourceLoader.load(GAME_SCENE_PATH)
	if packed == null or not packed is PackedScene:
		failures.append("existing gameplay composition root no longer loads independently")
