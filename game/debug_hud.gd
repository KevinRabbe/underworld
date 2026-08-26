extends CanvasLayer

var world
var player
var settings: UnderworldWorldSettings
var label: Label
var crosshair: Label
var hotbar: Label
var update_timer: float = 0.0
var visible_debug: bool = true


func configure(world_node, player_node, world_settings: UnderworldWorldSettings) -> void:
	world = world_node
	player = player_node
	settings = world_settings


func _ready() -> void:
	layer = 100

	label = Label.new()
	label.name = "DebugLabel"
	label.position = Vector2(14.0, 14.0)
	label.add_theme_font_size_override("font_size", 16)
	_apply_readable_text_style(label)
	add_child(label)

	crosshair = Label.new()
	crosshair.name = "HarvestCrosshair"
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 22)
	_apply_readable_text_style(crosshair)
	add_child(crosshair)

	hotbar = Label.new()
	hotbar.name = "PrototypeHotbar"
	hotbar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotbar.add_theme_font_size_override("font_size", 17)
	_apply_readable_text_style(hotbar)
	add_child(hotbar)

	_refresh_text()
	_update_hud_positions()


func _apply_readable_text_style(target: Label) -> void:
	target.add_theme_color_override("font_color", Color.WHITE)
	target.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	target.add_theme_constant_override("shadow_offset_x", 2)
	target.add_theme_constant_override("shadow_offset_y", 2)


func _process(delta: float) -> void:
	_update_hud_positions()
	update_timer -= delta
	if update_timer > 0.0:
		return

	update_timer = 0.1
	_refresh_text()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		visible_debug = not visible_debug
		label.visible = visible_debug


func _update_hud_positions() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if crosshair != null:
		crosshair.position = viewport_size * 0.5 - Vector2(6.0, 14.0)
	if hotbar != null:
		hotbar.position = Vector2(0.0, viewport_size.y - 82.0)
		hotbar.size = Vector2(viewport_size.x, 76.0)


func _refresh_text() -> void:
	if label == null or hotbar == null or world == null or player == null or settings == null:
		return

	var position: Vector3 = player.global_position
	var chunk: Vector2i = world.get_current_player_chunk()
	var speed: float = player.get_horizontal_speed()
	var worker_state: String = "busy" if world.is_worker_busy() else "idle"
	var surface: Dictionary = world.get_surface_sample_at_world(position.x, position.z)
	var decoration_counts: Vector2i = world.get_current_decoration_counts()
	var pickup_counts: Vector2i = world.get_current_pickup_counts()
	var active_world_objects: int = world.get_active_world_object_count()
	var resources: Vector2i = world.get_resource_counts()
	var selected_slot: int = world.get_selected_hotbar_slot()

	label.text = (
		"UNDERWORLD — prototype 0.05\n"
		+ "FPS: %d\n" % Engine.get_frames_per_second()
		+ "Seed: %d   Sea: %.1f\n" % [settings.world_seed, settings.sea_level]
		+ "Position: %.1f, %.1f, %.1f\n" % [position.x, position.y, position.z]
		+ "Chunk: %d, %d\n" % [chunk.x, chunk.y]
		+ "Loaded: %d   Pending: %d   Generated: %d\n" % [
			world.get_loaded_chunk_count(),
			world.get_pending_chunk_count(),
			world.get_total_chunks_generated()
		]
		+ "Surface H: %.1f   Slope: %.3f\n" % [
			float(surface["height"]),
			float(surface["slope"])
		]
		+ "Moist: %.2f   Forest: %.2f   Rock: %.2f   Build: %.2f\n" % [
			float(surface["moisture"]),
			float(surface["forest_density"]),
			float(surface["rockiness"]),
			float(surface["buildability"])
		]
		+ "Chunk: %d trees  %d rocks  |  %d branches  %d loose stones\n" % [
			decoration_counts.x,
			decoration_counts.y,
			pickup_counts.x,
			pickup_counts.y
		]
		+ "Near physical: %d   Radius: %.0f m\n" % [
			active_world_objects,
			settings.world_object_physics_radius
		]
		+ "Inventory: %d wood   %d stone   Removed world objects: %d\n" % [
			resources.x,
			resources.y,
			world.get_destroyed_object_count()
		]
		+ "Equipped: %s   Action: %s\n" % [
			_pretty_tool_name(world.get_equipped_tool()),
			world.get_last_action_message()
		]
		+ "Worker: %s\n" % worker_state
		+ "Chunk CPU: %.2f ms   Max: %.2f ms\n" % [
			world.get_last_generation_ms(),
			world.get_max_generation_ms()
		]
		+ "  Data (worker): %.2f ms   Max: %.2f ms\n" % [
			world.get_last_data_generation_ms(),
			world.get_max_data_generation_ms()
		]
		+ "  Build (main): %.2f ms   Max: %.2f ms\n" % [
			world.get_last_chunk_build_ms(),
			world.get_max_chunk_build_ms()
		]
		+ "Speed: %.1f m/s   F3: debug" % speed
	)

	var axe_name: String = "Stone Axe" if world.has_tool("stone_axe") else "Stone Axe (not crafted)"
	var pickaxe_name: String = (
		"Stone Pickaxe" if world.has_tool("stone_pickaxe") else "Stone Pickaxe (not crafted)"
	)
	var slot1: String = _format_slot(1, "Hands", selected_slot)
	var slot2: String = _format_slot(2, axe_name, selected_slot)
	var slot3: String = _format_slot(3, pickaxe_name, selected_slot)

	hotbar.text = (
		"%s     %s     %s\n" % [slot1, slot2, slot3]
		+ "Wood %d   Stone %d     C: craft Axe (%dW/%dS)     V: craft Pickaxe (%dW/%dS)\n" % [
			resources.x,
			resources.y,
			settings.stone_axe_wood_cost,
			settings.stone_axe_stone_cost,
			settings.stone_pickaxe_wood_cost,
			settings.stone_pickaxe_stone_cost
		]
		+ "Walk over loose pickups   |   LMB: use equipped tool"
	)


func _format_slot(slot: int, text: String, selected_slot: int) -> String:
	if slot == selected_slot:
		return "> [%d %s] <" % [slot, text]
	return "[%d %s]" % [slot, text]


func _pretty_tool_name(tool_id: String) -> String:
	if tool_id == "stone_axe":
		return "Stone Axe"
	if tool_id == "stone_pickaxe":
		return "Stone Pickaxe"
	return "Hands"
