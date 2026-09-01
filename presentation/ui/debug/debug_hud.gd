extends CanvasLayer

var world
var player
var survival
var combat_resolver
var encounter_controller
var underworld_runtime
var settings
var label: Label
var crosshair: Label
var survival_label: Label
var update_timer: float = 0.0
var visible_debug: bool = true


func configure(
	world_node,
	player_node,
	world_settings,
	survival_controller = null,
	combat_resolver_node = null,
	encounter_controller_node = null,
	underworld_runtime_node = null
) -> void:
	world = world_node
	player = player_node
	settings = world_settings
	survival = survival_controller
	combat_resolver = combat_resolver_node
	encounter_controller = encounter_controller_node
	underworld_runtime = underworld_runtime_node


func _ready() -> void:
	layer = 25
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
	crosshair.name = "ActionCrosshair"
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 22)
	crosshair.add_theme_color_override("font_color", Color.WHITE)
	crosshair.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	crosshair.add_theme_constant_override("shadow_offset_x", 1)
	crosshair.add_theme_constant_override("shadow_offset_y", 1)
	add_child(crosshair)

	survival_label = Label.new()
	survival_label.name = "SurvivalHUD"
	survival_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	survival_label.add_theme_font_size_override("font_size", 17)
	survival_label.add_theme_color_override("font_color", Color.WHITE)
	survival_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	survival_label.add_theme_constant_override("shadow_offset_x", 2)
	survival_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(survival_label)

	_set_debug_presentation_visible(visible_debug)
	_refresh_text()
	_update_layout()


func _process(delta: float) -> void:
	_update_layout()
	update_timer -= delta
	if update_timer > 0.0:
		return

	update_timer = 0.1
	_refresh_text()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		_set_debug_presentation_visible(not visible_debug)


func _set_debug_presentation_visible(value: bool) -> void:
	visible_debug = value
	for control in [label, crosshair, survival_label]:
		if control != null:
			control.visible = visible_debug


func _update_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if crosshair != null:
		crosshair.position = viewport_size * 0.5 - Vector2(6.0, 14.0)
	if survival_label != null:
		survival_label.position = Vector2(0.0, viewport_size.y - 112.0)
		survival_label.size = Vector2(viewport_size.x, 106.0)


func _refresh_text() -> void:
	if (
		label == null
		or survival_label == null
		or world == null
		or player == null
		or settings == null
		or survival == null
	):
		return

	var position: Vector3 = player.global_position
	var chunk: Vector2i = world.get_current_player_chunk()
	var speed: float = player.get_horizontal_speed()
	var worker_state: String = "busy" if world.is_worker_busy() else "idle"
	var surface: Dictionary = world.get_surface_sample_at_world(position.x, position.z)
	var decoration_counts: Vector2i = world.get_current_decoration_counts()
	var pickup_counts: Vector2i = world.get_current_pickup_counts()
	var active_world_objects: int = world.get_active_world_object_count()
	var resources: Vector2i = survival.get_resource_counts()
	var selected_slot: int = survival.get_selected_hotbar_slot()
	var has_axe: bool = survival.has_tool("stone_axe")
	var has_pickaxe: bool = survival.has_tool("stone_pickaxe")
	var equipped: String = survival.get_equipped_tool()
	var axe_cost: Vector2i = survival.get_crafting_cost("stone_axe")
	var pickaxe_cost: Vector2i = survival.get_crafting_cost("stone_pickaxe")
	var stamina_current: float = player.get_stamina()
	var stamina_max: float = player.get_max_stamina()
	var action_state: String = player.get_action_state_name()
	var active_enemies: int = 0
	var combat_message: String = "Combat unavailable"
	if encounter_controller != null:
		active_enemies = encounter_controller.get_active_enemy_count()
	if combat_resolver != null:
		combat_message = combat_resolver.get_last_combat_message()
	var underworld_text := ""
	if underworld_runtime != null and underworld_runtime.streamer != null:
		var underworld_cell = underworld_runtime.streamer.observer_cell(position)
		var underworld_key := "gcell1:r1:x%d:y%d:z%d" % [underworld_cell.x, underworld_cell.y, underworld_cell.z]
		var underworld_record = underworld_runtime.streamer.records.get(underworld_key)
		var tier_text := "none"
		if underworld_record != null:
			var ready: Array[String] = []
			for tier in underworld_record.readiness.keys():
				if bool(underworld_record.readiness[tier]): ready.append(str(tier))
			ready.sort()
			tier_text = ",".join(ready) if not ready.is_empty() else "none"
		var entrance_text := "none"
		if not underworld_runtime.gates.is_empty():
			var entrance_ids: Array[String] = []
			for value in underworld_runtime.gates.keys(): entrance_ids.append(str(value))
			entrance_ids.sort()
			entrance_text = entrance_ids[0]
		underworld_text = (
			"Underworld: %s\n" % entrance_text
			+ "  Cell: %s   Tiers: %s   Owners: %d   Queued: %d   Stale: %d\n" % [
				underworld_key, tier_text, underworld_runtime.streamer.active_owner_count(),
				underworld_runtime.streamer.queued_count, underworld_runtime.streamer.stale_result_count
			]
			+ "  World: %s   Manifest: %s\n" % [underworld_runtime.world_id, underworld_runtime.generator_manifest_id]
			+ "  Source: %s\n" % (underworld_record.source_fingerprint if underworld_record != null else "none")
			+ "  Provenance: %s\n" % (underworld_record.provenance_fingerprint if underworld_record != null else "none")
			+ "  Bootstrap: %s\n" % underworld_runtime.last_bootstrap_fingerprint
		)

	label.text = (
		"UNDERWORLD — prototype character foundation\n"
		+ "FPS: %d\n" % Engine.get_frames_per_second()
		+ "Seed: %d   Sea: %.1f\n" % [settings.world_seed, settings.sea_level]
		+ "Position: %.1f, %.1f, %.1f\n" % [position.x, position.y, position.z]
		+ "Chunk: %d, %d\n" % [chunk.x, chunk.y]
		+ "Loaded: %d   Pending: %d   Generated: %d\n" % [
			world.get_loaded_chunk_count(), world.get_pending_chunk_count(),
			world.get_total_chunks_generated()
		]
		+ "Surface H: %.1f   Slope: %.3f\n" % [
			float(surface["height"]), float(surface["slope"])
		]
		+ "Moist: %.2f   Forest: %.2f   Rock: %.2f   Build: %.2f\n" % [
			float(surface["moisture"]), float(surface["forest_density"]),
			float(surface["rockiness"]), float(surface["buildability"])
		]
		+ "Chunk: %d trees  %d rocks  |  %d branches  %d loose stones\n" % [
			decoration_counts.x, decoration_counts.y, pickup_counts.x, pickup_counts.y
		]
		+ "Near physical: %d   Radius: %.0f m\n" % [
			active_world_objects, settings.world_object_physics_radius
		]
		+ "Inventory: %d wood  %d stone   Removed world objects: %d\n" % [
			resources.x, resources.y, world.get_destroyed_object_count()
		]
		+ "Equipped: %s   Harvest: %s\n" % [
			_tool_display_name(equipped), survival.get_last_harvest_message()
		]
		+ "Combat: %s   Active enemies: %d\n" % [combat_message, active_enemies]
		+ "Character: STA %.0f/%.0f   Action: %s\n" % [
			stamina_current, stamina_max, action_state
		]
		+ "Worker: %s\n" % worker_state
		+ underworld_text
		+ "Chunk CPU: %.2f ms   Max: %.2f ms\n" % [
			world.get_last_generation_ms(), world.get_max_generation_ms()
		]
		+ "  Data (worker): %.2f ms   Max: %.2f ms\n" % [
			world.get_last_data_generation_ms(), world.get_max_data_generation_ms()
		]
		+ "  Build (main): %.2f ms   Max: %.2f ms\n" % [
			world.get_last_chunk_build_ms(), world.get_max_chunk_build_ms()
		]
		+ "Speed: %.1f m/s   F3: debug" % speed
	)

	var slot_1: String = _format_slot(1, "Hands", true, selected_slot)
	var slot_2: String = _format_slot(2, "Stone Axe", has_axe, selected_slot)
	var slot_3: String = _format_slot(3, "Stone Pickaxe", has_pickaxe, selected_slot)
	survival_label.text = (
		"HP %d/%d    STA %.0f/%.0f    Action: %s    Enemies %d    %s\n" % [
			player.get_health(), player.get_max_health(),
			stamina_current, stamina_max, action_state,
			active_enemies, combat_message
		]
		+ slot_1 + "    " + slot_2 + "    " + slot_3 + "\n"
		+ "Wood %d   Stone %d    C: craft Axe (%dW/%dS)    V: craft Pickaxe (%dW/%dS)\n" % [
			resources.x, resources.y,
			axe_cost.x, axe_cost.y,
			pickaxe_cost.x, pickaxe_cost.y
		]
		+ "LMB: harvest   |   RMB: melee   |   Ctrl: dodge   |   Q: frontal parry   |   F: frontal block"
	)


func _format_slot(slot: int, item_name: String, available: bool, selected_slot: int) -> String:
	var content: String = "[%d %s]" % [slot, item_name]
	if not available:
		content = "[%d --]" % slot
	if slot == selected_slot:
		return "> %s <" % content
	return content


func _tool_display_name(tool_id: String) -> String:
	match tool_id:
		"stone_axe":
			return "Stone Axe"
		"stone_pickaxe":
			return "Stone Pickaxe"
		_:
			return "Hands"
