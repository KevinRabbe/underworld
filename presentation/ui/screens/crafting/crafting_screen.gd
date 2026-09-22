extends CanvasLayer

## Production crafting surface backed by the canonical weapon runtime session.
## The screen owns presentation/input only; crafting authority remains in the
## runtime session and its recipe registry.

const UnderworldTheme := preload("res://presentation/ui/theme/underworld_theme.tres")

var _runtime_session = null
var _input_gate: Node = null
var _focus_stack: Node = null
var _capture_token: int = 0
var _focus_token: int = 0
var _open: bool = false
var _status_text: String = ""

var _root: Control
var _panel: PanelContainer
var _recipe_list: VBoxContainer
var _status_label: Label
var _close_button: Button


func configure(runtime_session, input_gate: Node, focus_stack: Node) -> Array[String]:
	_runtime_session = runtime_session
	_input_gate = input_gate
	_focus_stack = focus_stack
	_ensure_input_action()
	_ensure_ui()
	_refresh_recipes()
	return []


func _ready() -> void:
	_ensure_input_action()
	_ensure_ui()
	_set_open(false)


func _input(event: InputEvent) -> void:
	if event == null or event.is_echo() or not event.is_action_pressed(&"craft_toggle"):
		return
	get_viewport().set_input_as_handled()
	_set_open(not _open)


func is_open() -> bool:
	return _open


func render_snapshot() -> Dictionary:
	_ensure_ui()
	var recipes: Array[String] = []
	for child in _recipe_list.get_children():
		if child is Button:
			recipes.append((child as Button).text)
	return {
		"open": _open,
		"status": _status_label.text,
		"recipes": recipes,
	}


func _ensure_ui() -> void:
	if _root != null:
		return
	_root = Control.new()
	_root.name = "CraftingRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UnderworldTheme
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.name = "CraftingPanel"
	_panel.theme_type_variation = &"MenuPanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-300.0, -220.0)
	_panel.size = Vector2(600.0, 440.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "CRAFTING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var hint := Label.new()
	hint.text = "Select a recipe to craft and equip"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	_recipe_list = VBoxContainer.new()
	_recipe_list.name = "RecipeList"
	_recipe_list.add_theme_constant_override("separation", 8)
	column.add_child(_recipe_list)
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0.0, 48.0)
	column.add_child(_status_label)
	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "Close  [C / Esc]"
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.pressed.connect(_close_from_button)
	column.add_child(_close_button)
	_set_open(false)


func _refresh_recipes() -> void:
	_ensure_ui()
	for child in _recipe_list.get_children():
		child.queue_free()
	_status_label.text = _status_text
	if _runtime_session == null or not is_instance_valid(_runtime_session) or not _runtime_session.has_method("craft_capabilities"):
		_status_label.text = "Crafting unavailable: runtime session is not ready."
		return
	var capabilities: Array = _runtime_session.call("craft_capabilities")
	if capabilities.is_empty():
		_status_label.text = "No recipes available."
		return
	for capability_variant in capabilities:
		if not capability_variant is Dictionary:
			continue
		var capability: Dictionary = capability_variant
		var recipe_id := str(capability.get("recipe_id", ""))
		if recipe_id.is_empty():
			continue
		var button := Button.new()
		button.name = "Recipe_%s" % recipe_id.replace(".", "_")
		button.custom_minimum_size = Vector2(0.0, 54.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s\nOutput: %s" % [_display_name(recipe_id), _display_name(str(capability.get("output_item_id", "")))]
		button.tooltip_text = recipe_id
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_craft_recipe.bind(recipe_id))
		_recipe_list.add_child(button)
	if _recipe_list.get_child_count() > 0:
		(_recipe_list.get_child(0) as Control).focus_mode = Control.FOCUS_ALL


func _craft_recipe(recipe_id: String) -> void:
	if _runtime_session == null or not is_instance_valid(_runtime_session):
		_status_text = "Craft failed: runtime session is unavailable."
	elif not _runtime_session.has_method("craft_and_equip"):
		_status_text = "Craft failed: canonical craft/equip service is unavailable."
	else:
		var result: Dictionary = _runtime_session.call("craft_and_equip", recipe_id)
		if bool(result.get("success", false)):
			_status_text = "Crafted and equipped %s." % _display_name(str(result.get("capability", {}).get("output_item_id", "")))
		else:
			var diagnostics: Array[String] = []
			for diagnostic in result.get("diagnostics", []):
				diagnostics.append(str(diagnostic))
			_status_text = "Unable to craft: %s" % "; ".join(diagnostics)
	_status_label.text = _status_text
	_refresh_recipes()
	_status_label.text = _status_text


func _set_open(value: bool) -> void:
	_ensure_ui()
	if _open == value:
		_panel.visible = value
		_root.mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
		return
	_open = value
	_panel.visible = value
	_root.mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	if value:
		if _input_gate != null and _input_gate.has_method("acquire"):
			_capture_token = int(_input_gate.call("acquire", &"crafting_ui"))
		if _focus_stack != null and _focus_stack.has_method("push_surface"):
			_focus_token = int(_focus_stack.call("push_surface", _panel, Callable(self, "_close_from_focus"), null, _close_button, _close_button))
		_refresh_recipes()
	else:
		if _focus_stack != null and _focus_token > 0 and _focus_stack.has_method("pop_surface"):
			_focus_stack.call("pop_surface", _focus_token)
		_focus_token = 0
		if _input_gate != null and _capture_token > 0 and _input_gate.has_method("release"):
			_input_gate.call("release", _capture_token)
		_capture_token = 0


func _close_from_focus() -> void:
	_set_open(false)


func _close_from_button() -> void:
	_set_open(false)


func _ensure_input_action() -> void:
	if not InputMap.has_action(&"craft_toggle"):
		InputMap.add_action(&"craft_toggle")
	for existing_event in InputMap.action_get_events(&"craft_toggle"):
		if existing_event is InputEventKey and existing_event.physical_keycode == KEY_C:
			return
	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_C
	InputMap.action_add_event(&"craft_toggle", key_event)


static func _display_name(identifier: String) -> String:
	var value := identifier
	if value.contains("."):
		value = value.get_slice(".", value.get_slice_count(".") - 1)
	value = value.replace("_", " ")
	return value.capitalize()
