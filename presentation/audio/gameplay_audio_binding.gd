extends Node
class_name UnderworldGameplayAudioBinding

const AudioController := preload("res://presentation/audio/audio_presentation_controller.gd")
const CueCatalog := preload("res://presentation/audio/audio_cue_catalog.gd")
const PrototypeCatalog := preload("res://content/presentation/audio/prototype_audio_cue_catalog.tres")
const ProvisionalStreams := preload("res://presentation/audio/provisional_audio_stream_library.gd")

const MAX_RECENT_CUES := 64

var _audio = null
var _bound: bool = false
var _recent_cues: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_bind_parent_game")


func _bind_parent_game() -> void:
	if _bound:
		return
	var parent := get_parent()
	if parent == null:
		return
	var failures: Array[String] = bind_game(parent)
	if not failures.is_empty():
		push_error("Gameplay audio binding failed: %s" % [failures])


func bind_game(game_node: Node) -> Array[String]:
	if _bound:
		return []
	if game_node == null:
		return ["gameplay audio binding requires Game parent"]
	var player = game_node.get("player")
	var survival = game_node.get("survival")
	var death_recovery = game_node.get("death_recovery_controller")
	var encounter = game_node.get("encounter_controller")
	var underworld = game_node.get("underworld_runtime")
	var failures: Array[String] = []
	for pair in [
		["Player", player],
		["Survival", survival],
		["death recovery controller", death_recovery],
		["Burrower encounter controller", encounter],
		["underworld runtime", underworld],
	]:
		if pair[1] == null:
			failures.append("gameplay audio binding requires %s" % pair[0])
	if not failures.is_empty():
		failures.sort()
		return failures

	var catalog = ProvisionalStreams.clone_with_missing_streams(PrototypeCatalog)
	if catalog == null or not catalog is CueCatalog:
		return ["gameplay audio binding could not build provisional cue catalog"]
	_audio = AudioController.new()
	_audio.name = "AudioPresentation"
	_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_audio)
	failures.append_array(_audio.configure(catalog))
	if not failures.is_empty():
		failures.sort()
		return failures

	_connect_required(player, "attack_requested", Callable(self, "_on_player_attack_requested"), failures)
	_connect_required(player, "parry_succeeded", Callable(self, "_on_player_parry_succeeded"), failures)
	_connect_required(player, "damage_committed", Callable(self, "_on_player_damage_committed"), failures)
	_connect_required(player, "defeat_requested", Callable(self, "_on_player_defeat_requested"), failures)
	_connect_required(survival, "harvest_result", Callable(self, "_on_harvest_result"), failures)
	_connect_required(survival, "equipped_tool_changed", Callable(self, "_on_equipped_tool_changed"), failures)
	_connect_required(survival, "craft_completed", Callable(self, "_on_craft_completed"), failures)
	_connect_required(death_recovery, "recovery_committed", Callable(self, "_on_recovery_committed"), failures)
	_connect_required(encounter, "loot_pending", Callable(self, "_on_loot_pending"), failures)
	_connect_required(encounter, "enemy_attack_started", Callable(self, "_on_enemy_attack_started"), failures)
	_connect_required(encounter, "enemy_damage_committed", Callable(self, "_on_enemy_damage_committed"), failures)
	_connect_required(encounter, "enemy_died", Callable(self, "_on_enemy_died"), failures)
	_connect_required(underworld, "cave_presence_changed", Callable(self, "_on_cave_presence_changed"), failures)
	if not failures.is_empty():
		failures.sort()
		return failures

	_bound = true
	_audio.set_ambience_role(CueCatalog.AMBIENCE_SURFACE)
	return []


func audio_controller():
	return _audio


func recent_cue_ids() -> Array[String]:
	return _recent_cues.duplicate()


func clear_recent_cues() -> void:
	_recent_cues.clear()


func is_bound() -> bool:
	return _bound


func consume_loot_collection_result(result: Dictionary) -> void:
	if not bool(result.get("success", false)):
		return
	for event_variant in result.get("events", []):
		if event_variant is Dictionary and str(event_variant.get("event", "")) == "loot.collected":
			_dispatch("audio_cue.loot.collected")


func consume_resource_mining_result(result: Dictionary, world_position: Vector3) -> void:
	if not bool(result.get("success", false)) or bool(result.get("duplicate", false)):
		return
	var committed := false
	for event_variant in result.get("events", []):
		if event_variant is Dictionary and str(event_variant.get("type", "")) == "resource.mined":
			committed = true
			break
	if not committed or not _finite_vector3(world_position):
		return
	_dispatch("audio_cue.resource.mine.impact", _spatial_payload(world_position))
	if bool(result.get("depleted", false)):
		_dispatch("audio_cue.resource.depleted", _spatial_payload(world_position))


func _on_player_attack_requested(execution: Dictionary) -> void:
	var attack_kind: String = str(execution.get("attack_kind", "light"))
	_dispatch("audio_cue.player.attack.heavy" if attack_kind == "heavy" else "audio_cue.player.attack.light")


func _on_player_parry_succeeded(_source_position: Vector3) -> void:
	_dispatch("audio_cue.player.parry.success")


func _on_player_damage_committed(amount: int, _remaining_health: int, _source_position: Vector3) -> void:
	if amount > 0:
		_dispatch("audio_cue.player.damage")


func _on_player_defeat_requested(_reason: StringName) -> void:
	_dispatch("audio_cue.player.death")


func _on_recovery_committed(_reason: StringName, _target: Vector3) -> void:
	_dispatch("audio_cue.player.respawn")


func _on_harvest_result(event: Dictionary) -> void:
	match str(event.get("type", "")):
		"harvest.hit_registered":
			var position_variant = event.get("world_position", null)
			if position_variant is Vector3 and _finite_vector3(position_variant):
				_dispatch("audio_cue.harvest.impact", _spatial_payload(position_variant))
		"harvest.completed":
			_dispatch("audio_cue.harvest.complete")
		"harvest.pickup_collected":
			_dispatch("audio_cue.inventory.pickup")


func _on_equipped_tool_changed(_tool_id: String) -> void:
	# Binding occurs deferred after Game startup/Continue synchronization, so only
	# subsequent committed equipment changes reach this callback.
	_dispatch("audio_cue.equipment.changed")


func _on_craft_completed(_recipe_id: String, _item_id: String) -> void:
	_dispatch("audio_cue.craft.success")


func _on_loot_pending(_occurrence_id: String, _profile_id: String, world_position: Vector3) -> void:
	if _finite_vector3(world_position):
		_dispatch("audio_cue.loot.available", _spatial_payload(world_position))


func _on_enemy_attack_started(_enemy_id: String, world_position: Vector3) -> void:
	if _finite_vector3(world_position):
		_dispatch("audio_cue.enemy.burrower.attack", _spatial_payload(world_position))


func _on_enemy_damage_committed(_enemy_id: String, amount: int, _remaining_health: int, world_position: Vector3) -> void:
	if amount > 0 and _finite_vector3(world_position):
		_dispatch("audio_cue.enemy.burrower.hit", _spatial_payload(world_position))


func _on_enemy_died(_enemy_id: String, world_position: Vector3) -> void:
	if _finite_vector3(world_position):
		_dispatch("audio_cue.enemy.burrower.death", _spatial_payload(world_position))


func _on_cave_presence_changed(in_cave: bool) -> void:
	if _audio != null:
		_audio.set_ambience_role(CueCatalog.AMBIENCE_CAVE if in_cave else CueCatalog.AMBIENCE_SURFACE)


func _dispatch(cue_id: String, payload: Dictionary = {}) -> Dictionary:
	if _audio == null:
		return {"success": false, "diagnostics": ["audio presentation is not bound"]}
	var result: Dictionary = _audio.dispatch(cue_id, payload)
	if bool(result.get("success", false)):
		_recent_cues.append(cue_id)
		if _recent_cues.size() > MAX_RECENT_CUES:
			_recent_cues.pop_front()
	return result


static func _spatial_payload(position: Vector3) -> Dictionary:
	return {"position": position, "intensity": 1.0}


static func _finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)


static func _connect_required(source, signal_name: String, callback: Callable, failures: Array[String]) -> void:
	if source == null or not source.has_signal(signal_name):
		failures.append("gameplay audio producer is missing required signal: %s" % signal_name)
		return
	if not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)
