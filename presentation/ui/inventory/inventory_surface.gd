extends CanvasLayer

const UNDERWORLD_THEME_PATH := "res://presentation/ui/theme/underworld_theme.tres"

var _inventory = null
var _equipment = null
var _survival = null
var _input_gate: Node = null
var _focus_stack: Node = null
var _capture_token: int = 0
var _focus_token: int = 0
var _root: Control
var _grid: GridContainer
var _equipment_label: Label
var _status_label: Label
var _toggle_button: Button
var _slot_buttons: Array[Button] = []
var _visible_state: bool = false


func configure(survival, input_gate: Node, focus_stack: Node) -> Array[String]:
	_survival = survival
	_inventory = survival.get_inventory_state() if survival != null else null
	_equipment = survival.get_equipment_state() if survival != null else null
	_input_gate = input_gate
	_focus_stack = focus_stack
	if _inventory == null or _equipment == null:
		return ["inventory surface requires canonical Survival inventory and equipment state"]
	if _input_gate == null or not _input_gate.has_method("acquire"):
		return ["inventory surface requires GameplayInputGate"]
	if _focus_stack == null or not _focus_stack.has_method("push_surface"):
		return ["inventory surface requires UiFocusStack"]
	_ensure_ui()
	_refresh()
	return []


func is_open() -> bool:
	return _visible_state


func open() -> bool:
	if _visible_state:
		return false
	_visible_state = true
	_root.visible = true
	_capture_token = int(_input_gate.call("acquire", &"inventory"))
	_focus_token = int(_focus_stack.call("push_surface", _root, Callable(self, "close"), null, _toggle_button, _toggle_button))
	_refresh()
	_toggle_button.grab_focus()
	return _capture_token > 0 and _focus_token > 0


func close() -> bool:
	if not _visible_state:
		return false
	_visible_state = false
	_root.visible = false
	if _focus_token > 0:
		_focus_stack.call("pop_surface", _focus_token)
		_focus_token = 0
	if _capture_token > 0:
		_input_gate.call("release", _capture_token)
		_capture_token = 0
	return true


func toggle() -> void:
	close() if _visible_state else open()


func _ready() -> void:
	set_process_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if _visible_state and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _ensure_ui() -> void:
	if _root != null:
		return
	_root = Control.new()
	_root.name = "InventorySurface"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = _load_underworld_theme()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	var panel := PanelContainer.new()
	panel.name = "InventoryPanel"
	panel.theme_type_variation = &"MenuPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-360.0, -270.0)
	panel.size = Vector2(720.0, 540.0)
	_root.add_child(panel)
	var margin := MarginContainer.new()
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "INVENTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_status_label = Label.new()
	column.add_child(_status_label)
	_grid = GridContainer.new()
	_grid.name = "GridContainer"
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(_grid)
	_equipment_label = Label.new()
	column.add_child(_equipment_label)
	_toggle_button = Button.new()
	_toggle_button.text = "Close (I / Esc)"
	_toggle_button.focus_mode = Control.FOCUS_ALL
	_toggle_button.pressed.connect(close)
	column.add_child(_toggle_button)


func _refresh() -> void:
	# Survival may finish deferred runtime composition after this surface was
	# configured. Rebind presentation references before reading slot state so the
	# UI always reflects the canonical containers owned by Survival.
	if _survival != null and is_instance_valid(_survival):
		_inventory = _survival.call("get_inventory_state") if _survival.has_method("get_inventory_state") else _inventory
		_equipment = _survival.call("get_equipment_state") if _survival.has_method("get_equipment_state") else _equipment
	if _grid == null or _inventory == null or _equipment == null:
		return
	for button in _slot_buttons:
		if is_instance_valid(button):
			_grid.remove_child(button)
			button.free()
	_slot_buttons.clear()
	for index in range(_inventory.slot_capacity()):
		var button := Button.new()
		button.custom_minimum_size = Vector2(145.0, 58.0)
		button.focus_mode = Control.FOCUS_ALL
		var record: Dictionary = _inventory.state_at(index)
		button.text = _slot_text(index, record)
		button.disabled = record.is_empty()
		button.pressed.connect(_on_slot_pressed.bind(index))
		_grid.add_child(button)
		_slot_buttons.append(button)
	var selected_definition = _equipment.selected_definition()
	var selected_name := "Hands" if selected_definition == null else str(selected_definition.content_id)
	_equipment_label.text = "Equipped: %s  |  Hotbar %d" % [selected_name, _equipment.selected_hotbar()]
	_status_label.text = "Select an item to equip  |  Weight %.1f / %s" % [
		_inventory.current_weight(),
		"∞" if _inventory.max_weight() < 0.0 else "%.1f" % _inventory.max_weight(),
	]


func _on_slot_pressed(source_slot: int) -> void:
	var record: Dictionary = _inventory.state_at(source_slot)
	var definition = record.get("definition", null)
	if definition == null:
		return
	for target_slot_key in _equipment.slot_keys():
		var rule = _equipment.slot_rule(target_slot_key)
		if rule == null or not rule.compatibility_failures(definition).is_empty():
			continue
		var result: Dictionary = _survival.equip_inventory_slot(source_slot, target_slot_key)
		if bool(result.get("success", false)):
			_refresh()
			return
	_status_label.text = "Cannot equip %s" % str(definition.content_id)


static func _slot_text(index: int, record: Dictionary) -> String:
	if record.is_empty():
		return "%d\nEmpty" % (index + 1)
	var definition = record.get("definition", null)
	var state: Dictionary = record.get("state", {})
	var item_name := str(definition.content_id) if definition != null else "Invalid"
	var quantity := int(state.get("quantity", 1))
	return "%d\n%s x%d" % [index + 1, item_name, quantity]

func _load_underworld_theme() -> Theme:
	if not ResourceLoader.exists(UNDERWORLD_THEME_PATH):
		return null
	return ResourceLoader.load(UNDERWORLD_THEME_PATH) as Theme
