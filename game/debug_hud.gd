extends CanvasLayer

var world
var player
var settings: UnderworldWorldSettings
var label: Label
var crosshair: Label
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
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)

	crosshair = Label.new()
	crosshair.name = "HarvestCrosshair"
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 22)
	crosshair.add_theme_color_override("font_color", Color.WHITE)
	crosshair.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	crosshair.add_theme_constant_override("shadow_offset_x", 1)
	crosshair.add_theme_constant_override("shadow_offset_y", 1)
	add_child(crosshair)

	_refresh_text()
	_update_crosshair_position()


func _process(delta: float) -> void:
	_update_crosshair_position()
	update_timer -= delta
	if update_timer > 0.0:
		return

	update_timer = 0.1
	_refresh_text()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		visible_debug = not visible_debug
		label.visible = visible_debug


func _update_crosshair_position() -> void:
	if crosshair == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	crosshair.position = viewport_size * 0.5 - Vector2(6.0, 14.0)


func _refresh_text() -> void:
	if label == null or world == null or player == null or settings == null:
		return

	var position: Vector3 = player.global_position
	var chunk: Vector2i = world.get_current_player_chunk()
	var speed: float = player.get_horizontal_speed()
	var worker_state: String = "busy" if world.is_worker_busy() else "idle"
	var surface: Dictionary = world.get_surface_sample_at_world(position.x, position.z)
	var decoration_counts: Vector2i = world.get_current_decoration_counts()
	var active_world_objects: int = world.get_active_world_object_count()
	var resources: Vector2i = world.get_resource_counts()

	label.text = (
		"UNDERWORLD — prototype 0.04\n"
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
		+ "Chunk decor: %d trees   %d rocks\n" % [
			decoration_counts.x,
			decoration_counts.y
		]
		+ "Near physical: %d   Radius: %.0f m\n" % [
			active_world_objects,
			settings.world_object_physics_radius
		]
		+ "Resources: %d wood   %d stone   Removed: %d\n" % [
			resources.x,
			resources.y,
			world.get_destroyed_object_count()
		]
		+ "Harvest: %s\n" % world.get_last_harvest_message()
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
		+ "Speed: %.1f m/s\n" % speed
		+ "LMB: harvest   F3: debug   Esc: release mouse   Wheel: camera zoom"
	)
