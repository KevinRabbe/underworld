extends CanvasLayer

const GameplayHudReadModel := preload("res://presentation/ui/hud/gameplay_hud_read_model.gd")
const GameplayObjectiveReadModel := preload("res://presentation/ui/hud/gameplay_objective_read_model.gd")
const UnderworldTheme := preload("res://presentation/ui/theme/underworld_theme.tres")

const REFRESH_INTERVAL := 0.05

var _read_model := GameplayHudReadModel.new()
var _objective_model := GameplayObjectiveReadModel.new()
var _game = null
var _player = null
var _inventory_state = null
var _equipment_state = null
var _material_ids: Array[String] = GameplayHudReadModel.DEFAULT_MATERIAL_IDS.duplicate()
var _refresh_timer: float = 0.0
var _feedback_text: String = ""
var _latest_model: Dictionary = {}
var _latest_objective: Dictionary = {}

var _root: Control
var _health_bar: ProgressBar
var _health_label: Label
var _stamina_bar: ProgressBar
var _stamina_label: Label
var _materials_label: Label
var _action_label: Label
var _objective_label: Label
var _feedback_label: Label
var _hint_label: Label
var _hotbar_labels: Array[Label] = []


func configure(
	player,
	inventory_state,
	equipment_state,
	material_ids: Array[String] = GameplayHudReadModel.DEFAULT_MATERIAL_IDS
) -> Array[String]:
	_game = get_parent()
	_player = player
	_inventory_state = inventory_state
	_equipment_state = equipment_state
	_material_ids = material_ids.duplicate()
	_ensure_ui()
	_bind_semantic_feedback_sources()
	var model: Dictionary = refresh_now()
	if bool(model.get("success", false)):
		return []
	var failures: Array[String] = []
	for diagnostic in model.get("diagnostics", []):
		failures.append(str(diagnostic))
	return failures


func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = REFRESH_INTERVAL
	refresh_now()


func refresh_now() -> Dictionary:
	_ensure_ui()
	_latest_model = _read_model.sample(
		_player,
		_inventory_state,
		_equipment_state,
		_material_ids
	)
	_render(_latest_model)
	_refresh_objective()
	return _latest_model.duplicate(true)


func present_feedback(event: Dictionary) -> void:
	var next_text: String = _read_model.feedback_text(event)
	if next_text.is_empty():
		return
	_feedback_text = next_text
	_ensure_ui()
	_feedback_label.text = _feedback_text


func set_hint(text: String) -> void:
	_ensure_ui()
	_hint_label.text = text.strip_edges()


func render_snapshot() -> Dictionary:
	_ensure_ui()
	var hotbar_text: Array[String] = []
	for label in _hotbar_labels:
		hotbar_text.append(label.text)
	return {
		"health": _health_label.text,
		"stamina": _stamina_label.text,
		"materials": _materials_label.text,
		"action": _action_label.text,
		"objective": _objective_label.text,
		"feedback": _feedback_label.text,
		"hint": _hint_label.text,
		"hotbar": hotbar_text,
		"model": _latest_model.duplicate(true),
		"objective_model": _latest_objective.duplicate(true),
	}


func controls_are_mouse_passthrough() -> bool:
	_ensure_ui()
	return _controls_are_mouse_passthrough(_root)


func _refresh_objective() -> void:
	_latest_objective = {}
	if _game == null or not is_instance_valid(_game):
		_objective_label.text = ""
		return
	_latest_objective = _objective_model.sample(
		_game,
		_player,
		_inventory_state,
		_equipment_state
	)
	if not bool(_latest_objective.get("success", false)):
		_objective_label.text = "Objective unavailable"
		return
	var text: String = str(_latest_objective.get("text", "")).strip_edges()
	_objective_label.text = "Objective: %s" % text if not text.is_empty() else ""


func _bind_semantic_feedback_sources() -> void:
	if _game == null or not is_instance_valid(_game):
		return
	var survival = _game.get("survival")
	if survival != null and is_instance_valid(survival):
		_connect_once(survival, &"craft_completed", Callable(self, "_on_craft_completed"))
		_connect_once(survival, &"equipped_tool_changed", Callable(self, "_on_equipped_tool_changed"))


func _connect_once(source, signal_name: StringName, callback: Callable) -> void:
	if source == null or not is_instance_valid(source) or not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, callback):
		return
	source.connect(signal_name, callback)


func _on_craft_completed(_recipe_id: String, item_id: String) -> void:
	present_feedback({"type": "craft.completed", "item_id": item_id})


func _on_equipped_tool_changed(tool_id: String) -> void:
	var semantic_id: String = tool_id.strip_edges()
	if semantic_id.is_empty() or semantic_id == "hands":
		return
	if not semantic_id.begins_with("item."):
		semantic_id = "item.tool." + semantic_id
	present_feedback({"type": "equipment.hotbar_selected", "slot_key": semantic_id})


func _ensure_ui() -> void:
	if _root != null:
		return

	_root = Control.new()
	_root.name = "GameplayHUDRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UnderworldTheme
	add_child(_root)

	var vitals_panel := PanelContainer.new()
	vitals_panel.name = "VitalsPanel"
	vitals_panel.theme_type_variation = &"MenuPanel"
	vitals_panel.position = Vector2(24.0, 24.0)
	vitals_panel.size = Vector2(330.0, 168.0)
	_root.add_child(vitals_panel)

	var vitals_margin := MarginContainer.new()
	vitals_margin.add_theme_constant_override("margin_left", 14)
	vitals_margin.add_theme_constant_override("margin_top", 12)
	vitals_margin.add_theme_constant_override("margin_right", 14)
	vitals_margin.add_theme_constant_override("margin_bottom", 12)
	vitals_panel.add_child(vitals_margin)

	var vitals := VBoxContainer.new()
	vitals.add_theme_constant_override("separation", 5)
	vitals_margin.add_child(vitals)

	_health_label = Label.new()
	_health_label.name = "HealthLabel"
	vitals.add_child(_health_label)
	_health_bar = ProgressBar.new()
	_health_bar.name = "HealthBar"
	_health_bar.show_percentage = false
	_health_bar.max_value = 1.0
	_health_bar.custom_minimum_size = Vector2(280.0, 16.0)
	vitals.add_child(_health_bar)

	_stamina_label = Label.new()
	_stamina_label.name = "StaminaLabel"
	vitals.add_child(_stamina_label)
	_stamina_bar = ProgressBar.new()
	_stamina_bar.name = "StaminaBar"
	_stamina_bar.show_percentage = false
	_stamina_bar.max_value = 1.0
	_stamina_bar.custom_minimum_size = Vector2(280.0, 16.0)
	vitals.add_child(_stamina_bar)

	_action_label = Label.new()
	_action_label.name = "ActionStateLabel"
	vitals.add_child(_action_label)

	_materials_label = Label.new()
	_materials_label.name = "MaterialsLabel"
	_materials_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_materials_label.position = Vector2(-430.0, 24.0)
	_materials_label.size = Vector2(400.0, 120.0)
	_materials_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_root.add_child(_materials_label)

	var crosshair := Label.new()
	crosshair.name = "Crosshair"
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-16.0, -16.0)
	crosshair.size = Vector2(32.0, 32.0)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(crosshair)

	var bottom := VBoxContainer.new()
	bottom.name = "BottomHUD"
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.position = Vector2(-330.0, -178.0)
	bottom.size = Vector2(660.0, 160.0)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 5)
	_root.add_child(bottom)

	_objective_label = Label.new()
	_objective_label.name = "ObjectiveLabel"
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.text = ""
	bottom.add_child(_objective_label)

	_feedback_label = Label.new()
	_feedback_label.name = "FeedbackLabel"
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.text = _feedback_text
	bottom.add_child(_feedback_label)

	var hotbar := HBoxContainer.new()
	hotbar.name = "Hotbar"
	hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar.add_theme_constant_override("separation", 8)
	bottom.add_child(hotbar)
	for index in range(1, 5):
		var slot := Label.new()
		slot.name = "Hotbar%d" % index
		slot.custom_minimum_size = Vector2(145.0, 44.0)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hotbar.add_child(slot)
		_hotbar_labels.append(slot)

	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.text = ""
	bottom.add_child(_hint_label)
	_set_mouse_passthrough(_root)


func _render(model: Dictionary) -> void:
	if not bool(model.get("success", false)):
		_health_label.text = "Health --"
		_health_bar.value = 0.0
		_stamina_label.text = "Stamina --"
		_stamina_bar.value = 0.0
		_action_label.text = "State unavailable"
		_materials_label.text = "Materials unavailable"
		_render_invalid_hotbar()
		return

	_health_label.text = "Health %d / %d" % [
		int(model.get("health", 0)),
		int(model.get("max_health", 0)),
	]
	_health_bar.value = float(model.get("health_ratio", 0.0))
	_stamina_label.text = "Stamina %.0f / %.0f" % [
		float(model.get("stamina", 0.0)),
		float(model.get("max_stamina", 0.0)),
	]
	_stamina_bar.value = float(model.get("stamina_ratio", 0.0))
	_action_label.text = "Action: %s" % _display_state(str(model.get("action_state", "")))

	var material_lines: Array[String] = []
	for record in model.get("materials", []):
		if not record is Dictionary:
			continue
		var item_id: String = str(record.get("item_id", ""))
		material_lines.append("%s  %d" % [
			GameplayHudReadModel.display_name_for_id(item_id),
			int(record.get("quantity", 0)),
		])
	_materials_label.text = "Materials\n" + "\n".join(material_lines)

	if not bool(model.get("equipment_valid", false)):
		_render_invalid_hotbar()
		return
	var hotbar: Array = model.get("hotbar", [])
	for index in range(_hotbar_labels.size()):
		if index >= hotbar.size() or not hotbar[index] is Dictionary:
			_hotbar_labels[index].text = "%d  ! INVALID" % (index + 1)
			continue
		var entry: Dictionary = hotbar[index]
		_hotbar_labels[index].text = _hotbar_text(entry)


func _render_invalid_hotbar() -> void:
	for index in range(_hotbar_labels.size()):
		_hotbar_labels[index].text = "%d  ! INVALID" % (index + 1)


static func _set_mouse_passthrough(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_passthrough(child)


static func _controls_are_mouse_passthrough(node: Node) -> bool:
	if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in node.get_children():
		if not _controls_are_mouse_passthrough(child):
			return false
	return true


static func _hotbar_text(entry: Dictionary) -> String:
	var prefix: String = ">" if bool(entry.get("selected", false)) else " "
	var index: int = int(entry.get("hotbar", 0))
	var kind: String = str(entry.get("kind", "invalid"))
	var display: String = ""
	match kind:
		"hands":
			display = "Hands"
		"empty":
			display = "Empty"
		"item":
			display = GameplayHudReadModel.display_name_for_id(str(entry.get("item_id", "")))
		"unbound":
			display = "Unbound"
		_:
			display = "! INVALID"
	return "%s%d  %s" % [prefix, index, display]


static func _display_state(value: String) -> String:
	var clean: String = value.strip_edges()
	return clean.replace("_", " ").capitalize() if not clean.is_empty() else "Idle"
