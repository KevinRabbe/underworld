extends RefCounted

const THEME_PATH := "res://presentation/ui/theme/underworld_theme.tres"
const TITLE_PATH := "res://presentation/ui/screens/title/title_screen.tscn"
const SECTION_HEADER_PATH := "res://presentation/ui/components/section_header/section_header.tscn"
const FIXTURE_PATH := "res://tests/presentation/fixtures/ui_skin_reuse_fixture.tscn"
const PROTOTYPE_SKIN_ROOT := "res://presentation/ui/assets/skin/prototype/"
const BUTTON_PROTOTYPE_SIZE := Vector2(96, 48)
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
	_test_structured_component_contract(failures)
	_test_reuse_fixture_contract(failures)
	_test_title_consumes_contract(failures)
	return failures


static func _test_panel_skin_contract(theme: Theme, failures: Array[String]) -> void:
	for variation in [&"MenuPanel", &"ContentPanel", &"DialogPanel"]:
		if not theme.is_type_variation(variation, &"PanelContainer"):
			failures.append("%s must remain a semantic PanelContainer Theme variation" % variation)
	var menu_style := theme.get_stylebox(&"panel", &"MenuPanel")
	var content_style := theme.get_stylebox(&"panel", &"ContentPanel")
	var dialog_style := theme.get_stylebox(&"panel", &"DialogPanel")
	_expect_texture_style(menu_style, "MenuPanel", failures)
	_expect_texture_style(content_style, "ContentPanel", failures)
	_expect_texture_style(dialog_style, "DialogPanel", failures)
	if menu_style != null and content_style != null and menu_style.resource_path != content_style.resource_path:
		failures.append("MenuPanel and ContentPanel must reuse the same replaceable panel skin resource")
	if menu_style != null and dialog_style != null and menu_style.resource_path != dialog_style.resource_path:
		failures.append("MenuPanel and DialogPanel must reuse the same replaceable panel skin resource")


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
