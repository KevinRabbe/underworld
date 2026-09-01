extends RefCounted

const THEME_PATH := "res://presentation/ui/theme/underworld_theme.tres"
const TITLE_PATH := "res://presentation/ui/screens/title/title_screen.tscn"
const SECTION_HEADER_PATH := "res://presentation/ui/components/section_header/section_header.tscn"
const FIXTURE_PATH := "res://tests/presentation/fixtures/ui_skin_reuse_fixture.tscn"
const PROTOTYPE_SKIN_ROOT := "res://presentation/ui/assets/skin/prototype/"
const KEYCAP_SOURCE_PATH := PROTOTYPE_SKIN_ROOT + "keycap_frame.svg"
const BUTTON_PROTOTYPE_SIZE := Vector2(96, 48)
const ITEM_SLOT_PROTOTYPE_SIZE := Vector2(64, 64)
const ITEM_SLOT_ICON_SAFE_RECT := Rect2(12, 12, 40, 40)
const KEYCAP_PROTOTYPE_SIZE := Vector2(48, 48)
const BUTTON_ORNAMENT_SAFE_HORIZONTAL := 20.0
const BUTTON_ORNAMENT_SAFE_VERTICAL := 14.0
const COMPACT_VIEWPORT := Vector2(960, 540)


static func run() -> Array[String]:
	var failures: Array[String] = []
	var theme = ResourceLoader.load(THEME_PATH)
	if theme == null or not theme is Theme:
		failures.append("Underworld Theme must load as the stable UI architecture contract")
		return failures
	var typed_theme := theme as Theme
	_test_panel_skin_contract(typed_theme, failures)
	_test_button_skin_contract(typed_theme, failures)
	_test_foundation_theme_contract(typed_theme, failures)
	_test_skin_reference_boundary(failures)
	_test_structured_component_contract(failures)
	_test_reuse_fixture_contract(failures)
	_test_title_consumes_contract(failures)
	return failures


static func _test_panel_skin_contract(theme: Theme, failures: Array[String]) -> void:
	for variation in [&"MenuPanel", &"ContentPanel", &"DialogPanel", &"OverlayPanel"]:
		if not theme.is_type_variation(variation, &"PanelContainer"):
			failures.append("%s must remain a semantic PanelContainer Theme variation" % variation)
	var menu_style := theme.get_stylebox(&"panel", &"MenuPanel")
	var content_style := theme.get_stylebox(&"panel", &"ContentPanel")
	var dialog_style := theme.get_stylebox(&"panel", &"DialogPanel")
	var overlay_style := theme.get_stylebox(&"panel", &"OverlayPanel")
	_expect_texture_style(menu_style, "MenuPanel", failures)
	_expect_texture_style(content_style, "ContentPanel", failures)
	_expect_texture_style(dialog_style, "DialogPanel", failures)
	_expect_texture_style(overlay_style, "OverlayPanel", failures)
	if menu_style != null and content_style != null and menu_style.resource_path != content_style.resource_path:
		failures.append("MenuPanel and ContentPanel must reuse the same replaceable panel skin resource")
	if menu_style != null and dialog_style != null and menu_style.resource_path != dialog_style.resource_path:
		failures.append("MenuPanel and DialogPanel must reuse the same replaceable panel skin resource")
	if menu_style != null and overlay_style != null and menu_style.resource_path != overlay_style.resource_path:
		failures.append("OverlayPanel must initially reuse the accepted replaceable panel skin resource")


static func _test_button_skin_contract(theme: Theme, failures: Array[String]) -> void:
	var states := [&"normal", &"hover", &"focus", &"pressed", &"disabled"]
	var reference_metrics: Array[float] = []
	var state_paths: Dictionary = {}
	for state in states:
		var style := theme.get_stylebox(state, &"Button")
		_expect_texture_style(style, "Button/%s" % state, failures)
		if style == null or not style is StyleBoxTexture:
			continue
		var texture_style := style as StyleBoxTexture
		_expect_button_ornament_safe_boundary(texture_style, state, failures)
		var metrics := _patch_metrics(texture_style)
		if reference_metrics.is_empty():
			reference_metrics = metrics
		elif metrics != reference_metrics:
			failures.append("Button visual states must keep identical patch/content geometry to avoid layout jitter")
		state_paths[state] = texture_style.texture.resource_path if texture_style.texture != null else ""
	if state_paths.get(&"hover", "") == state_paths.get(&"focus", ""):
		failures.append("keyboard/controller focus art must remain independently replaceable from hover art")


static func _test_foundation_theme_contract(theme: Theme, failures: Array[String]) -> void:
	_test_safe_margin(theme, &"HudSafeMargin", 24, failures)
	_test_safe_margin(theme, &"OverlaySafeMargin", 48, failures)

	var slot_variations := [
		&"ItemSlot",
		&"ItemSlotDisabled",
		&"ItemSlotInvalid",
		&"ItemSlotSelectedOverlay",
		&"ItemSlotFocusOverlay",
		&"ItemSlotHoverOverlay",
	]
	var slot_paths: Dictionary = {}
	var reference_content_metrics: Array[float] = []
	for variation in slot_variations:
		if not theme.is_type_variation(variation, &"Panel"):
			failures.append("%s must be a semantic Panel Theme variation" % variation)
		var style := theme.get_stylebox(&"panel", variation)
		_expect_fixed_skin_style(style, variation, ITEM_SLOT_PROTOTYPE_SIZE, failures)
		if style == null or not style is StyleBoxTexture:
			continue
		var texture_style := style as StyleBoxTexture
		var content_metrics := _content_metrics(texture_style)
		if reference_content_metrics.is_empty():
			reference_content_metrics = content_metrics
		elif content_metrics != reference_content_metrics:
			failures.append("ItemSlot base/overlay states must preserve identical content geometry")
		slot_paths[variation] = texture_style.resource_path

	if slot_paths.get(&"ItemSlotSelectedOverlay", "") == slot_paths.get(&"ItemSlotFocusOverlay", ""):
		failures.append("ItemSlot selection and focus must remain independently composable Theme layers")
	if slot_paths.get(&"ItemSlotFocusOverlay", "") == slot_paths.get(&"ItemSlotHoverOverlay", ""):
		failures.append("ItemSlot focus must remain independently replaceable from pointer hover")
	if ITEM_SLOT_ICON_SAFE_RECT.position.x < 0.0 or ITEM_SLOT_ICON_SAFE_RECT.position.y < 0.0 \
		or ITEM_SLOT_ICON_SAFE_RECT.end.x > ITEM_SLOT_PROTOTYPE_SIZE.x \
		or ITEM_SLOT_ICON_SAFE_RECT.end.y > ITEM_SLOT_PROTOTYPE_SIZE.y:
		failures.append("ItemSlot 40x40 icon safe rect must remain inside the fixed 64x64 frame")

	if not theme.is_type_variation(&"ItemSlotInputSurface", &"Button"):
		failures.append("ItemSlotInputSurface must be a semantic Button Theme variation")
	for state in [&"normal", &"hover", &"focus", &"pressed", &"disabled"]:
		var input_style := theme.get_stylebox(state, &"ItemSlotInputSurface")
		if input_style == null or not input_style is StyleBoxEmpty:
			failures.append("ItemSlotInputSurface/%s must suppress native Button chrome with StyleBoxEmpty" % state)

	if not theme.is_type_variation(&"KeyPrompt", &"PanelContainer"):
		failures.append("KeyPrompt must expose a semantic PanelContainer Theme role")
	var keycap_style := theme.get_stylebox(&"panel", &"KeyPrompt")
	_expect_texture_style(keycap_style, "KeyPrompt", failures)
	if keycap_style is StyleBoxTexture and (keycap_style as StyleBoxTexture).texture != null:
		if (keycap_style as StyleBoxTexture).texture.get_size() != KEYCAP_PROTOTYPE_SIZE:
			failures.append("KeyPrompt prototype source must remain 48x48")
	var keycap_source := FileAccess.get_file_as_string(KEYCAP_SOURCE_PATH)
	if keycap_source.is_empty() or keycap_source.contains("<text"):
		failures.append("KeyPrompt skin art must exist and must not bake physical key text into the texture")

	for variation in [&"HealthResourceBar", &"StaminaResourceBar"]:
		if not theme.is_type_variation(variation, &"ProgressBar"):
			failures.append("%s must be a semantic ProgressBar Theme variation" % variation)
		var background := theme.get_stylebox(&"background", variation)
		var fill := theme.get_stylebox(&"fill", variation)
		if background == null or not background is StyleBoxFlat or fill == null or not fill is StyleBoxFlat:
			failures.append("%s must use procedural StyleBoxFlat track/fill styles rather than skin textures" % variation)

	if not theme.is_type_variation(&"OverlayShade", &"Panel"):
		failures.append("OverlayShade must be a semantic Panel Theme variation")
	elif not theme.get_stylebox(&"panel", &"OverlayShade") is StyleBoxFlat:
		failures.append("OverlayShade must remain procedural StyleBoxFlat presentation")
	if not theme.is_type_variation(&"OverlayStack", &"VBoxContainer"):
		failures.append("OverlayStack must be a semantic VBoxContainer Theme variation")
	elif theme.get_constant(&"separation", &"OverlayStack") != 16:
		failures.append("OverlayStack must preserve the 16px reference content separation")

	if theme.get_font_size(&"font_size", &"BodyLabel") != 18:
		failures.append("BodyLabel must resolve the 18px reference typography")
	if theme.get_font_size(&"font_size", &"CompactLabel") != 14:
		failures.append("CompactLabel must resolve the 14px reference typography")
	if theme.get_font_size(&"font_size", &"ItemQuantityLabel") != 14:
		failures.append("ItemQuantityLabel must resolve the 14px reference typography")
	if theme.get_font_size(&"font_size", &"ItemIndexLabel") != 12:
		failures.append("ItemIndexLabel must resolve the 12px reference typography")
	if theme.get_font_size(&"font_size", &"KeycapLabel") != 14:
		failures.append("KeycapLabel must resolve the 14px reference typography")

	var theme_source := FileAccess.get_file_as_string(THEME_PATH)
	if theme_source.contains("content/presentation/"):
		failures.append("UI skin Theme must not reference content item/icon presentation assets")


static func _test_safe_margin(theme: Theme, variation: StringName, expected: int, failures: Array[String]) -> void:
	if not theme.is_type_variation(variation, &"MarginContainer"):
		failures.append("%s must be a semantic MarginContainer Theme variation" % variation)
		return
	for constant_name in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		if theme.get_constant(constant_name, variation) != expected:
			failures.append("%s/%s must remain %d logical pixels at UI scale 1.0" % [variation, constant_name, expected])


static func _expect_fixed_skin_style(
	style: StyleBox,
	label: StringName,
	expected_size: Vector2,
	failures: Array[String]
) -> void:
	if style == null or not style is StyleBoxTexture:
		failures.append("%s must resolve through a replaceable StyleBoxTexture resource" % label)
		return
	var texture_style := style as StyleBoxTexture
	if texture_style.texture == null:
		failures.append("%s StyleBoxTexture must reference replaceable skin art" % label)
		return
	if not texture_style.texture.resource_path.begins_with(PROTOTYPE_SKIN_ROOT):
		failures.append("%s texture must stay behind the provisional skin asset boundary" % label)
	if texture_style.texture.get_size() != expected_size:
		failures.append("%s prototype source must remain %dx%d" % [label, int(expected_size.x), int(expected_size.y)])


static func _test_skin_reference_boundary(failures: Array[String]) -> void:
	for root in [
		"res://presentation/ui/components",
		"res://presentation/ui/hud",
		"res://presentation/ui/screens",
	]:
		_assert_no_direct_skin_refs_in_directory(root, failures)


static func _assert_no_direct_skin_refs_in_directory(path: String, failures: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var entry_path := path.path_join(entry)
			if directory.current_is_dir():
				_assert_no_direct_skin_refs_in_directory(entry_path, failures)
			elif entry.get_extension() in ["gd", "tscn"]:
				var source := FileAccess.get_file_as_string(entry_path)
				if source.contains(PROTOTYPE_SKIN_ROOT):
					failures.append("screen/component source must consume Theme roles, not direct prototype skin paths: %s" % entry_path)
		entry = directory.get_next()
	directory.list_dir_end()


static func _expect_button_ornament_safe_boundary(
	style: StyleBoxTexture,
	state: StringName,
	failures: Array[String]
) -> void:
	if style.texture == null:
		return
	var size := style.texture.get_size()
	if size != BUTTON_PROTOTYPE_SIZE:
		failures.append(
			"Prototype Button/%s source dimensions changed; re-verify the authored ornament-safe 9-slice boundary" % state
		)
	var left := float(style.get("texture_margin_left"))
	var top := float(style.get("texture_margin_top"))
	var right := float(style.get("texture_margin_right"))
	var bottom := float(style.get("texture_margin_bottom"))
	if left < BUTTON_ORNAMENT_SAFE_HORIZONTAL or right < BUTTON_ORNAMENT_SAFE_HORIZONTAL:
		failures.append(
			"Button/%s horizontal patch margins must protect the current 2px-stroked corner ornament envelope" % state
		)
	if top < BUTTON_ORNAMENT_SAFE_VERTICAL or bottom < BUTTON_ORNAMENT_SAFE_VERTICAL:
		failures.append(
			"Button/%s vertical patch margins must protect the current 2px-stroked corner ornament envelope" % state
		)


static func _expect_texture_style(style: StyleBox, label: String, failures: Array[String]) -> void:
	if style == null or not style is StyleBoxTexture:
		failures.append("%s must resolve through a StyleBoxTexture 9-slice resource" % label)
		return
	var texture_style := style as StyleBoxTexture
	if texture_style.texture == null:
		failures.append("%s StyleBoxTexture must reference replaceable skin art" % label)
		return
	if not texture_style.texture.resource_path.begins_with(PROTOTYPE_SKIN_ROOT):
		failures.append("%s texture must stay behind the provisional skin asset boundary" % label)
	var size := texture_style.texture.get_size()
	var left := float(texture_style.get("texture_margin_left"))
	var top := float(texture_style.get("texture_margin_top"))
	var right := float(texture_style.get("texture_margin_right"))
	var bottom := float(texture_style.get("texture_margin_bottom"))
	if left <= 0.0 or top <= 0.0 or right <= 0.0 or bottom <= 0.0:
		failures.append("%s must define positive 9-slice patch margins" % label)
	if left + right >= size.x or top + bottom >= size.y:
		failures.append("%s patch margins must leave a stretchable center region" % label)


static func _patch_metrics(style: StyleBoxTexture) -> Array[float]:
	return [
		float(style.get("texture_margin_left")),
		float(style.get("texture_margin_top")),
		float(style.get("texture_margin_right")),
		float(style.get("texture_margin_bottom")),
		float(style.get("content_margin_left")),
		float(style.get("content_margin_top")),
		float(style.get("content_margin_right")),
		float(style.get("content_margin_bottom")),
	]


static func _content_metrics(style: StyleBoxTexture) -> Array[float]:
	return [
		float(style.get("content_margin_left")),
		float(style.get("content_margin_top")),
		float(style.get("content_margin_right")),
		float(style.get("content_margin_bottom")),
	]


static func _test_structured_component_contract(failures: Array[String]) -> void:
	var packed = ResourceLoader.load(SECTION_HEADER_PATH)
	if packed == null or not packed is PackedScene:
		failures.append("reusable SectionHeader component must load as PackedScene")
		return
	var header := (packed as PackedScene).instantiate()
	if header == null or not header is HBoxContainer:
		failures.append("SectionHeader must remain a layout component, not baked screen art")
		return
	var title := header.get_node_or_null("Title") as Label
	var divider := header.get_node_or_null("Divider") as HSeparator
	if title == null or title.theme_type_variation != &"SectionHeaderLabel":
		failures.append("SectionHeader title must consume a semantic Theme role")
	if divider == null or divider.theme_type_variation != &"SectionDivider":
		failures.append("SectionHeader divider must consume a semantic Theme role")
	header.free()


static func _test_reuse_fixture_contract(failures: Array[String]) -> void:
	var packed = ResourceLoader.load(FIXTURE_PATH)
	if packed == null or not packed is PackedScene:
		failures.append("UI architecture reuse fixture must load")
		return
	var root := (packed as PackedScene).instantiate()
	var tall := root.get_node_or_null("Layout/TallMenu") as PanelContainer
	var wide := root.get_node_or_null("Layout/WideContent") as PanelContainer
	if tall == null or wide == null:
		failures.append("reuse fixture must contain tall and wide panel compositions")
	else:
		if tall.theme_type_variation != &"MenuPanel" or wide.theme_type_variation != &"ContentPanel":
			failures.append("different UI compositions must consume semantic panel Theme roles")
		if tall.custom_minimum_size == wide.custom_minimum_size:
			failures.append("reuse proof must exercise materially different panel shapes")
	root.free()


static func _test_title_consumes_contract(failures: Array[String]) -> void:
	var packed = ResourceLoader.load(TITLE_PATH)
	if packed == null or not packed is PackedScene:
		failures.append("accepted title screen must still load after skin extraction")
		return
	var title := (packed as PackedScene).instantiate()
	if title == null or not title is Control:
		failures.append("accepted title must remain a responsive Control composition")
		return
	var title_control := title as Control
	var safe_margin := title.get_node_or_null("SafeMargin") as MarginContainer
	var center := title.get_node_or_null("SafeMargin/Center") as CenterContainer
	var panel := title.get_node_or_null("SafeMargin/Center/MenuPanel") as PanelContainer
	if panel == null or panel.theme_type_variation != &"MenuPanel":
		failures.append("accepted title must consume the reusable MenuPanel contract without routing changes")
	if title_control.anchor_right != 1.0 or title_control.anchor_bottom != 1.0:
		failures.append("accepted title must retain full-rect anchors for viewport growth")
	if safe_margin == null or safe_margin.anchor_right != 1.0 or safe_margin.anchor_bottom != 1.0 or center == null:
		failures.append("accepted title must retain full-rect safe margins and container-owned centering")
	if panel != null and title_control.theme != null:
		var theme := title_control.theme
		var safe_width := float(theme.get_constant(&"margin_left", &"MenuSafeMargin") + theme.get_constant(&"margin_right", &"MenuSafeMargin"))
		var safe_height := float(theme.get_constant(&"margin_top", &"MenuSafeMargin") + theme.get_constant(&"margin_bottom", &"MenuSafeMargin"))
		var panel_minimum := panel.get_combined_minimum_size()
		if panel_minimum.x + safe_width > COMPACT_VIEWPORT.x or panel_minimum.y + safe_height > COMPACT_VIEWPORT.y:
			failures.append("accepted title minimum composition must fit the 960x540 compact responsive smoke viewport")
	title.free()
