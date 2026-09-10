extends RefCounted

const PRESENTATION_UI_ROOT := "res://presentation/ui"
const PROJECT_FILE_PATH := "res://project.godot"
const EXPECTED_CONTENT_SCALE_SIZE := Vector2i(1280, 720)
const EXPECTED_CONTENT_SCALE_FACTOR := 1.0


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_explicit_project_settings(failures)
	_test_serialized_project_settings(failures)
	_test_live_root_window(failures)
	_test_no_competing_presentation_scale_authority(failures)
	return failures


static func _test_explicit_project_settings(failures: Array[String]) -> void:
	_expect_explicit_setting("display/window/size/viewport_width", 1280, failures)
	_expect_explicit_setting("display/window/size/viewport_height", 720, failures)
	_expect_explicit_setting("display/window/stretch/mode", "canvas_items", failures)
	_expect_explicit_setting("display/window/stretch/aspect", "expand", failures)
	_expect_explicit_setting("display/window/stretch/scale", EXPECTED_CONTENT_SCALE_FACTOR, failures)
	_expect_explicit_setting("display/window/stretch/scale_mode", "fractional", failures)


static func _expect_explicit_setting(path: String, expected: Variant, failures: Array[String]) -> void:
	if not ProjectSettings.has_setting(path):
		failures.append("project.godot must explicitly serialize %s" % path)
		return
	var actual: Variant = ProjectSettings.get_setting(path)
	if actual != expected:
		failures.append("%s must resolve to %s, got %s" % [path, str(expected), str(actual)])


static func _test_serialized_project_settings(failures: Array[String]) -> void:
	var config := ConfigFile.new()
	var error := config.load(PROJECT_FILE_PATH)
	if error != OK:
		failures.append("UI scale contract could not load project.godot through ConfigFile")
		return

	_expect_serialized_display_setting(config, "window/size/viewport_width", 1280, failures)
	_expect_serialized_display_setting(config, "window/size/viewport_height", 720, failures)
	_expect_serialized_display_setting(config, "window/stretch/mode", "canvas_items", failures)
	_expect_serialized_display_setting(config, "window/stretch/aspect", "expand", failures)
	_expect_serialized_display_setting(config, "window/stretch/scale", EXPECTED_CONTENT_SCALE_FACTOR, failures)
	_expect_serialized_display_setting(config, "window/stretch/scale_mode", "fractional", failures)


static func _expect_serialized_display_setting(
	config: ConfigFile,
	key: String,
	expected: Variant,
	failures: Array[String]
) -> void:
	if not config.has_section_key("display", key):
		failures.append("project.godot [display] must physically serialize %s" % key)
		return
	var actual: Variant = config.get_value("display", key)
	if actual != expected:
		failures.append(
			"project.godot [display] %s must serialize %s, got %s"
			% [key, str(expected), str(actual)]
		)


static func _test_live_root_window(failures: Array[String]) -> void:
	var main_loop := Engine.get_main_loop()
	if main_loop == null or not main_loop is SceneTree:
		failures.append("UI scale contract requires the live SceneTree")
		return
	var root := (main_loop as SceneTree).root
	if root == null:
		failures.append("UI scale contract requires a live root Window")
		return
	if root.content_scale_size != EXPECTED_CONTENT_SCALE_SIZE:
		failures.append("root Window content_scale_size must remain 1280x720")
	if root.content_scale_mode != Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
		failures.append("root Window must use CONTENT_SCALE_MODE_CANVAS_ITEMS")
	if root.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_EXPAND:
		failures.append("root Window must use CONTENT_SCALE_ASPECT_EXPAND")
	if not is_equal_approx(root.content_scale_factor, EXPECTED_CONTENT_SCALE_FACTOR):
		failures.append("root Window content_scale_factor must begin at 1.0")
	if root.content_scale_stretch != Window.CONTENT_SCALE_STRETCH_FRACTIONAL:
		failures.append("root Window must use CONTENT_SCALE_STRETCH_FRACTIONAL")


static func _test_no_competing_presentation_scale_authority(failures: Array[String]) -> void:
	_assert_no_content_scale_factor_in_directory(PRESENTATION_UI_ROOT, failures)


static func _assert_no_content_scale_factor_in_directory(path: String, failures: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var entry_path := path.path_join(entry)
			if directory.current_is_dir():
				_assert_no_content_scale_factor_in_directory(entry_path, failures)
			elif entry.get_extension() == "gd":
				var source := FileAccess.get_file_as_string(entry_path)
				if source.contains("content_scale_factor"):
					failures.append("presentation UI must inherit root scale instead of owning content_scale_factor: %s" % entry_path)
		entry = directory.get_next()
	directory.list_dir_end()
