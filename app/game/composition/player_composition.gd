extends RefCounted

const PlayerScript := preload("res://gameplay/player/player.gd")
const VoxelCharacterPresentationProviderScript := preload("res://presentation/characters/voxel/voxel_character_presentation_provider.gd")


static func compose(
	root: Node3D,
	prepared_player: Node,
	gameplay_input_gate: Node,
	world,
	survival,
	survival_settings,
	spawn_position: Vector3,
	is_continue: bool,
	startup_candidate: Dictionary
) -> Dictionary:
	var player: Node
	if gameplay_input_gate != null:
		player = prepared_player
		if player == null or not is_instance_valid(player):
			return _failure(null, "Production Game has no pre-bound Player input authority")
		if player.get("_gameplay_input_gate") != gameplay_input_gate:
			player.free()
			return _failure(null, "Prepared Player does not retain exact Game gameplay-input authority")
	else:
		player = PlayerScript.new()

	player.name = "Player"
	# Presentation must be injected before add_child(), so Player._ready() never owns a hard-coded body implementation.
	player.character_presentation_provider = VoxelCharacterPresentationProviderScript.new()
	root.add_child(player)
	player.global_position = spawn_position
	player.set_harvest_range(survival_settings.harvest_range)
	player.set_tool_use_cooldown(survival_settings.tool_use_cooldown)
	player.harvest_requested.connect(survival.try_harvest)
	player.hotbar_slot_requested.connect(survival.select_hotbar_slot)
	player.craft_requested.connect(survival.request_craft)
	survival.equipped_tool_changed.connect(player.set_equipped_tool)
	world.set_player(player)
	survival.set_player(player)
	player.set_equipped_tool(survival.get_equipped_tool())

	if is_continue:
		if not player.has_method("restore_current_vitals"):
			return _failure(player, "Continue Player is missing current-vitals hydration seam")
		var vitals: Dictionary = startup_candidate.get("player_vitals", {})
		var hydration: Dictionary = player.call(
			"restore_current_vitals",
			vitals.get("current_health", null),
			vitals.get("current_stamina", null)
		)
		if not bool(hydration.get("success", false)):
			return _failure(
				player,
				"Continue Player vitals hydration rejected: %s" % [hydration.get("diagnostics", [])]
			)

	return {"success": true, "player": player, "diagnostics": []}


static func _failure(player: Node, diagnostic: String) -> Dictionary:
	return {"success": false, "player": player, "diagnostics": [diagnostic]}
