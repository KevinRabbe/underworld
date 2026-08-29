extends RefCounted

const APP_ROOT_PATH := "res://app/app_root.tscn"
const GAME_SCENE_PATH := "res://app/game/game.tscn"
const TITLE_SCREEN_PATH := "res://presentation/ui/screens/title/title_screen.tscn"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_main_scene_contract(failures)
	_test_app_root_contract(failures)
	_test_title_screen_contract(failures)
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
	if continue_button == null:
		failures.append("title screen is missing Continue action")
	elif not continue_button.disabled:
		failures.append("Continue must fail closed until persistence integration")
	if quit_button == null or quit_button.text != "QUIT":
		failures.append("title screen is missing Quit action")

	if title is Control:
		var control := title as Control
		if control.anchor_right != 1.0 or control.anchor_bottom != 1.0:
			failures.append("title root must use full-rect anchors")
	else:
		failures.append("title screen root must inherit Control")
	title.free()


static func _test_game_scene_remains_independent(failures: Array[String]) -> void:
	var packed = ResourceLoader.load(GAME_SCENE_PATH)
	if packed == null or not packed is PackedScene:
		failures.append("existing gameplay composition root no longer loads independently")
