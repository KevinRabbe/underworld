extends CanvasLayer

var world
var player
var settings: UnderworldWorldSettings
var label: Label
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
	_refresh_text()


func _process(delta: float) -> void:
	update_timer -= delta
	if update_timer > 0.0:
		return

	update_timer = 0.2
	_refresh_text()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		visible_debug = not visible_debug
		label.visible = visible_debug


func _refresh_text() -> void:
	if label == null or world == null or player == null or settings == null:
		return

	var position: Vector3 = player.global_position
	var chunk: Vector2i = world.get_current_player_chunk()
	var speed: float = player.get_horizontal_speed()

	label.text = (
		"UNDERWORLD — prototype 0.01\n"
		+ "FPS: %d\n" % Engine.get_frames_per_second()
		+ "Seed: %d\n" % settings.world_seed
		+ "Position: %.1f, %.1f, %.1f\n" % [position.x, position.y, position.z]
		+ "Chunk: %d, %d\n" % [chunk.x, chunk.y]
		+ "Loaded: %d   Pending: %d   Generated: %d\n" % [
			world.get_loaded_chunk_count(),
			world.get_pending_chunk_count(),
			world.get_total_chunks_generated()
		]
		+ "Chunk total: %.2f ms   Max: %.2f ms\n" % [
			world.get_last_generation_ms(),
			world.get_max_generation_ms()
		]
		+ "  Data: %.2f ms   Max: %.2f ms\n" % [
			world.get_last_data_generation_ms(),
			world.get_max_data_generation_ms()
		]
		+ "  Build: %.2f ms   Max: %.2f ms\n" % [
			world.get_last_chunk_build_ms(),
			world.get_max_chunk_build_ms()
		]
		+ "Speed: %.1f m/s\n" % speed
		+ "F3: debug   Esc: release mouse   Wheel: camera zoom"
	)
