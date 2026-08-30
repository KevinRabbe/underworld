extends RefCounted

const Binding := preload("res://presentation/audio/gameplay_audio_binding.gd")
const CueCatalog := preload("res://presentation/audio/audio_cue_catalog.gd")

class FakePlayer:
	extends Node3D
	signal attack_requested(execution: Dictionary)
	signal parry_succeeded(source_position: Vector3)
	signal damage_committed(amount: int, remaining_health: int, source_position: Vector3)
	signal defeat_requested(reason: StringName)

class FakeSurvival:
	extends Node
	signal harvest_result(event: Dictionary)
	signal equipped_tool_changed(tool_id: String)
	signal craft_completed(recipe_id: String, item_id: String)

class FakeRecovery:
	extends Node
	signal recovery_committed(reason: StringName, target: Vector3)

class FakeEncounter:
	extends Node3D
	signal loot_pending(occurrence_id: String, profile_id: String, world_position: Vector3)
	signal enemy_attack_started(enemy_id: String, world_position: Vector3)
	signal enemy_damage_committed(enemy_id: String, amount: int, remaining_health: int, world_position: Vector3)
	signal enemy_died(enemy_id: String, world_position: Vector3)

class FakeUnderworld:
	extends Node3D
	signal cave_presence_changed(in_cave: bool)

class FakeGame:
	extends Node3D
	var player
	var survival
	var death_recovery_controller
	var encounter_controller
	var underworld_runtime


static func run() -> Array[String]:
	var failures: Array[String] = []
	var game := FakeGame.new()
	game.player = FakePlayer.new()
	game.survival = FakeSurvival.new()
	game.death_recovery_controller = FakeRecovery.new()
	game.encounter_controller = FakeEncounter.new()
	game.underworld_runtime = FakeUnderworld.new()
	for child in [game.player, game.survival, game.death_recovery_controller, game.encounter_controller, game.underworld_runtime]:
		game.add_child(child)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		failures.append("gameplay audio fixture requires active SceneTree root")
		game.free()
		return failures
	tree.root.add_child(game)
	var binding := Binding.new()
	game.add_child(binding)
	var bind_failures: Array[String] = binding.bind_game(game)
	if not bind_failures.is_empty():
		failures.append("semantic audio binding rejected complete producer set: %s" % [bind_failures])
		game.free()
		return failures

	_test_existing_semantic_routes(game, binding, failures)
	_test_committed_observation_routes(game, binding, failures)
	_test_typed_result_routes(binding, failures)
	_test_ambience_transition(game, binding, failures)
	_test_muting_never_changes_semantic_routing(game, binding, failures)
	_test_provisional_streams_are_audible(binding, failures)
	_test_scope_has_no_polling_or_gameplay_authority(failures)
	game.free()
	return failures


static func _test_existing_semantic_routes(game, binding, failures: Array[String]) -> void:
	binding.clear_recent_cues()
	game.player.attack_requested.emit({"attack_kind": &"light"})
	game.player.attack_requested.emit({"attack_kind": &"heavy"})
	game.player.parry_succeeded.emit(Vector3.ZERO)
	game.player.defeat_requested.emit(&"damage")
	game.death_recovery_controller.recovery_committed.emit(&"damage", Vector3(2, 3, 4))
	game.survival.harvest_result.emit({"type": "harvest.hit_registered", "world_position": Vector3(1, 2, 3)})
	game.survival.harvest_result.emit({"type": "harvest.completed"})
	game.survival.harvest_result.emit({"type": "harvest.pickup_collected"})
	game.encounter_controller.loot_pending.emit("burrower_1", "loot.profile", Vector3(4, 5, 6))
	_expect_sequence(binding.recent_cue_ids(), [
		"audio_cue.player.attack.light",
		"audio_cue.player.attack.heavy",
		"audio_cue.player.parry.success",
		"audio_cue.player.death",
		"audio_cue.player.respawn",
		"audio_cue.harvest.impact",
		"audio_cue.harvest.complete",
		"audio_cue.inventory.pickup",
		"audio_cue.loot.available",
	], "existing semantic producer routes", failures)


static func _test_committed_observation_routes(game, binding, failures: Array[String]) -> void:
	binding.clear_recent_cues()
	game.player.damage_committed.emit(12, 88, Vector3.ZERO)
	game.survival.equipped_tool_changed.emit("stone_axe")
	game.survival.craft_completed.emit("stone_axe", "item.tool.stone_axe")
	game.encounter_controller.enemy_attack_started.emit("burrower_1", Vector3(3, 0, 2))
	game.encounter_controller.enemy_damage_committed.emit("burrower_1", 5, 31, Vector3(3, 0, 2))
	game.encounter_controller.enemy_died.emit("burrower_1", Vector3(3, 0, 2))
	_expect_sequence(binding.recent_cue_ids(), [
		"audio_cue.player.damage",
		"audio_cue.equipment.changed",
		"audio_cue.craft.success",
		"audio_cue.enemy.burrower.attack",
		"audio_cue.enemy.burrower.hit",
		"audio_cue.enemy.burrower.death",
	], "committed observation routes", failures)


static func _test_typed_result_routes(binding, failures: Array[String]) -> void:
	binding.clear_recent_cues()
	binding.consume_loot_collection_result({"success": false, "events": []})
	binding.consume_loot_collection_result({"success": true, "events": [{"event": "loot.collected"}]})
	binding.consume_resource_mining_result({"success": true, "duplicate": true, "events": []}, Vector3.ONE)
	binding.consume_resource_mining_result({
		"success": true,
		"duplicate": false,
		"depleted": true,
		"events": [{"type": "resource.mined"}],
	}, Vector3(7, -3, 2))
	_expect_sequence(binding.recent_cue_ids(), [
		"audio_cue.loot.collected",
		"audio_cue.resource.mine.impact",
		"audio_cue.resource.depleted",
	], "typed loot/resource results", failures)


static func _test_ambience_transition(game, binding, failures: Array[String]) -> void:
	var audio = binding.audio_controller()
	if audio == null or audio.ambience_role() != CueCatalog.AMBIENCE_SURFACE:
		failures.append("binding did not seed surface ambience without a fake gameplay cue")
		return
	game.underworld_runtime.cave_presence_changed.emit(true)
	if audio.ambience_role() != CueCatalog.AMBIENCE_CAVE:
		failures.append("cave presence transition did not select cave ambience")
	game.underworld_runtime.cave_presence_changed.emit(false)
	if audio.ambience_role() != CueCatalog.AMBIENCE_SURFACE:
		failures.append("surface return did not restore surface ambience")
	if audio.ambience_player_count() != 1:
		failures.append("semantic ambience transitions did not reuse one ambience player")


static func _test_muting_never_changes_semantic_routing(game, binding, failures: Array[String]) -> void:
	var audio = binding.audio_controller()
	binding.clear_recent_cues()
	var active_before: int = audio.active_one_shot_count()
	audio.set_muted(true)
	game.player.damage_committed.emit(1, 99, Vector3.ZERO)
	if binding.recent_cue_ids() != ["audio_cue.player.damage"]:
		failures.append("muting changed semantic audio routing")
	if audio.active_one_shot_count() != active_before:
		failures.append("muted committed outcome changed physical one-shot playback count")
	audio.set_muted(false)


static func _test_provisional_streams_are_audible(binding, failures: Array[String]) -> void:
	var audio = binding.audio_controller()
	if audio == null:
		failures.append("provisional playback proof has no audio controller")
		return
	if not audio.is_inside_tree():
		failures.append("provisional playback proof requires mounted controller")
		return
	var result: Dictionary = audio.dispatch("audio_cue.player.respawn")
	if not bool(result.get("success", false)) or not bool(result.get("played", false)):
		failures.append("unmuted production binding did not start provisional respawn stream")


static func _test_scope_has_no_polling_or_gameplay_authority(failures: Array[String]) -> void:
	var source: String = FileAccess.get_file_as_string("res://presentation/audio/gameplay_audio_binding.gd")
	for forbidden in ["func _process(", "poll_now(", "last_action_message", "object_hit_progress", "active_enemies", "render_nodes", "world_delta_store"]:
		if source.contains(forbidden):
			failures.append("gameplay audio binding contains forbidden polling/authority fragment: %s" % forbidden)


static func _expect_sequence(actual: Array[String], expected: Array[String], label: String, failures: Array[String]) -> void:
	if actual != expected:
		failures.append("%s cue sequence mismatch: %s != %s" % [label, actual, expected])
