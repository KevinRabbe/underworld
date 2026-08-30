extends Node
class_name UnderworldGameplayAudioBinding

const AudioController := preload("res://presentation/audio/audio_presentation_controller.gd")
const CueCatalog := preload("res://presentation/audio/audio_cue_catalog.gd")
const PrototypeCatalog := preload("res://content/presentation/audio/prototype_audio_cue_catalog.tres")
const ProvisionalStreams := preload("res://presentation/audio/provisional_audio_stream_library.gd")

const RESOURCE_SCHEMA := "resource.runtime.depletion.v1"
const MAX_RECENT_CUES := 64
const CRAFTED_ITEM_IDS: Array[String] = [
	"item.tool.stone_axe",
	"item.tool.stone_pickaxe",
	"item.weapon.iron_sword",
]

var _game: Node = null
var _audio = null
var _player = null
var _survival = null
var _death_recovery = null
var _encounter = null
var _underworld = null
var _bound: bool = false

var _last_player_health: int = 0
var _enemy_state: Dictionary = {}
var _last_harvest_progress: Dictionary = {}
var _last_equipment_descriptor: String = ""
var _known_owned_item_ids: Dictionary = {}
var _pending_loot_ids: Dictionary = {}
var _resource_remaining: Dictionary = {}
var _last_cave_presence: bool = false
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
	var failures: Array[String] = []
	if game_node == null:
		return ["gameplay audio binding requires Game parent"]
	_game = game_node
	_player = game_node.get("player")
	_survival = game_node.get("survival")
	_death_recovery = game_node.get("death_recovery_controller")
	_encounter = game_node.get("encounter_controller")
	_underworld = game_node.get("underworld_runtime")

	if _player == null:
		failures.append("gameplay audio binding requires Player")
	if _survival == null:
		failures.append("gameplay audio binding requires Survival")
	if _death_recovery == null:
		failures.append("gameplay audio binding requires death recovery controller")
	if _encounter == null:
		failures.append("gameplay audio binding requires Burrower encounter controller")
	if _underworld == null:
		failures.append("gameplay audio binding requires underworld runtime")
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

	_connect_if_present(_player, "attack_requested", Callable(self, "_on_player_attack_requested"))
	_connect_if_present(_player, "parry_succeeded", Callable(self, "_on_player_parry_succeeded"))
	_connect_if_present(_player, "defeat_requested", Callable(self, "_on_player_defeat_requested"))
	_connect_if_present(_survival, "harvest_result", Callable(self, "_on_harvest_result"))
	_connect_if_present(_death_recovery, "recovery_committed", Callable(self, "_on_recovery_committed"))
	_connect_if_present(_encounter, "loot_pending", Callable(self, "_on_loot_pending"))

	_prime_state()
	_bound = true
	_apply_ambience(_last_cave_presence)
	return []


func _process(_delta: float) -> void:
	poll_now()


func poll_now() -> void:
	if not _bound:
		return
	_observe_player_damage()
	_observe_enemies()
	_observe_harvest_progress()
	_observe_equipment_and_crafting()
	_observe_pending_loot()
	_observe_resource_depletion()
	_observe_cave_presence()


func audio_controller():
	return _audio


func recent_cue_ids() -> Array[String]:
	return _recent_cues.duplicate()


func clear_recent_cues() -> void:
	_recent_cues.clear()


func is_bound() -> bool:
	return _bound


func _prime_state() -> void:
	_last_player_health = int(_player.get("health"))
	_last_harvest_progress = _dictionary_copy(_survival.get("object_hit_progress"))
	_last_equipment_descriptor = _equipment_descriptor()
	_known_owned_item_ids = _owned_item_ids()
	_pending_loot_ids = _current_pending_loot_ids()
	_resource_remaining = _current_resource_remaining()
	_last_cave_presence = _is_player_in_realized_cave()
	_prime_enemies()


func _on_player_attack_requested(execution: Dictionary) -> void:
	var attack_kind: String = str(execution.get("attack_kind", "light"))
	var cue_id := "audio_cue.player.attack.heavy" if attack_kind == "heavy" else "audio_cue.player.attack.light"
	_dispatch(cue_id)


func _on_player_parry_succeeded(_source_position: Vector3) -> void:
	_dispatch("audio_cue.player.parry.success")


func _on_player_defeat_requested(_reason: StringName) -> void:
	_dispatch("audio_cue.player.death")


func _on_recovery_committed(_reason: StringName, _target: Vector3) -> void:
	_dispatch("audio_cue.player.respawn")


func _on_harvest_result(event: Dictionary) -> void:
	match str(event.get("type", "")):
		"harvest.completed":
			_dispatch("audio_cue.harvest.impact", _spatial_payload(_player_position()))
			_dispatch("audio_cue.harvest.complete")
		"harvest.pickup_collected":
			_dispatch("audio_cue.inventory.pickup")


func _on_loot_pending(_occurrence_id: String, _profile_id: String, world_position: Vector3) -> void:
	if _finite_vector3(world_position):
		_dispatch("audio_cue.loot.available", _spatial_payload(world_position))


func _observe_player_damage() -> void:
	var current: int = int(_player.get("health"))
	if current < _last_player_health:
		_dispatch("audio_cue.player.damage")
	_last_player_health = current


func _prime_enemies() -> void:
	_enemy_state.clear()
	for enemy in _active_enemy_nodes():
		_track_enemy(enemy)


func _observe_enemies() -> void:
	var active_ids: Dictionary = {}
	for enemy in _active_enemy_nodes():
		var enemy_id: String = str(enemy.get("enemy_id"))
		if enemy_id.is_empty():
			continue
		active_ids[enemy_id] = true
		if not _enemy_state.has(enemy_id):
			_track_enemy(enemy)
			continue
		var previous: Dictionary = _enemy_state[enemy_id]
		var current_health: int = int(enemy.get("health"))
		var current_attack: bool = bool(enemy.get("attack_pending"))
		if current_health < int(previous.get("health", current_health)):
			_dispatch("audio_cue.enemy.burrower.hit", _spatial_payload(enemy.global_position))
		if current_attack and not bool(previous.get("attack_pending", false)):
			_dispatch("audio_cue.enemy.burrower.attack", _spatial_payload(enemy.global_position))
		_enemy_state[enemy_id] = {
			"health": current_health,
			"attack_pending": current_attack,
			"position": enemy.global_position,
		}
	for enemy_id in _enemy_state.keys().duplicate():
		if not active_ids.has(enemy_id):
			_enemy_state.erase(enemy_id)


func _track_enemy(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var enemy_id: String = str(enemy.get("enemy_id"))
	if enemy_id.is_empty():
		return
	_enemy_state[enemy_id] = {
		"health": int(enemy.get("health")),
		"attack_pending": bool(enemy.get("attack_pending")),
		"position": enemy.global_position if enemy is Node3D else _player_position(),
	}
	if enemy.has_signal("died"):
		var callback := Callable(self, "_on_enemy_died")
		if not enemy.is_connected("died", callback):
			enemy.connect("died", callback)


func _on_enemy_died(enemy_id: String) -> void:
	var state: Dictionary = _enemy_state.get(enemy_id, {})
	var position_variant = state.get("position", _player_position())
	var position: Vector3 = position_variant if position_variant is Vector3 else _player_position()
	_dispatch("audio_cue.enemy.burrower.death", _spatial_payload(position))
	_enemy_state.erase(enemy_id)


func _active_enemy_nodes() -> Array[Node]:
	var result: Array[Node] = []
	var active_variant = _encounter.get("active_enemies")
	if not active_variant is Dictionary:
		return result
	for candidate in active_variant.values():
		if candidate != null and candidate is Node and is_instance_valid(candidate):
			result.append(candidate)
	return result


func _observe_harvest_progress() -> void:
	var current: Dictionary = _dictionary_copy(_survival.get("object_hit_progress"))
	for raw_id in current.keys():
		var object_id: String = str(raw_id)
		var value: int = int(current[raw_id])
		var previous: int = int(_last_harvest_progress.get(object_id, 0))
		if value > previous:
			_dispatch("audio_cue.harvest.impact", _spatial_payload(_player_position()))
	_last_harvest_progress = current


func _observe_equipment_and_crafting() -> void:
	var current_equipment: String = _equipment_descriptor()
	var current_owned: Dictionary = _owned_item_ids()
	if current_equipment != _last_equipment_descriptor:
		_dispatch("audio_cue.equipment.changed")
	for crafted_item_id in CRAFTED_ITEM_IDS:
		if current_owned.has(crafted_item_id) and not _known_owned_item_ids.has(crafted_item_id):
			_dispatch("audio_cue.craft.success")
			break
	_last_equipment_descriptor = current_equipment
	_known_owned_item_ids = current_owned


func _observe_pending_loot() -> void:
	var current: Dictionary = _current_pending_loot_ids()
	for occurrence_id in _pending_loot_ids.keys():
		if not current.has(occurrence_id):
			_dispatch("audio_cue.loot.collected")
	_pending_loot_ids = current


func _observe_resource_depletion() -> void:
	var current: Dictionary = _current_resource_remaining()
	for stable_id in current.keys():
		var remaining: float = float(current[stable_id])
		if not _resource_remaining.has(stable_id):
			_dispatch("audio_cue.resource.mine.impact", _spatial_payload(_resource_position(str(stable_id))))
			if remaining <= 0.0:
				_dispatch("audio_cue.resource.depleted", _spatial_payload(_resource_position(str(stable_id))))
			continue
		var previous: float = float(_resource_remaining[stable_id])
		if remaining < previous - 0.00001:
			var position := _resource_position(str(stable_id))
			_dispatch("audio_cue.resource.mine.impact", _spatial_payload(position))
			if remaining <= 0.0 and previous > 0.0:
				_dispatch("audio_cue.resource.depleted", _spatial_payload(position))
	_resource_remaining = current


func _observe_cave_presence() -> void:
	var current: bool = _is_player_in_realized_cave()
	if current == _last_cave_presence:
		return
	_last_cave_presence = current
	_apply_ambience(current)


func _apply_ambience(in_cave: bool) -> void:
	if _audio == null:
		return
	var role := CueCatalog.AMBIENCE_CAVE if in_cave else CueCatalog.AMBIENCE_SURFACE
	_audio.set_ambience_role(role)


func _is_player_in_realized_cave() -> bool:
	if _underworld == null or _player == null:
		return false
	var render_variant = _underworld.get("render_nodes")
	if not render_variant is Dictionary:
		return false
	var position := _player_position()
	for candidate in render_variant.values():
		if candidate == null or not candidate is Node or not is_instance_valid(candidate):
			continue
		if not candidate.has_meta("cell_semantic_snapshot"):
			continue
		var snapshot_variant = candidate.get_meta("cell_semantic_snapshot")
		if not snapshot_variant is Dictionary:
			continue
		var bounds_variant = snapshot_variant.get("world_bounds", null)
		if bounds_variant is AABB:
			var bounds: AABB = bounds_variant
			if bounds.grow(0.25).has_point(position):
				return true
	return false


func _equipment_state():
	if _survival == null or not _survival.has_method("get_equipment_state"):
		return null
	return _survival.call("get_equipment_state")


func _equipment_descriptor() -> String:
	var equipment = _equipment_state()
	if equipment == null or not equipment.has_method("canonical_snapshot"):
		return ""
	var snapshot_variant = equipment.call("canonical_snapshot")
	if not snapshot_variant is Dictionary:
		return ""
	return JSON.stringify(snapshot_variant)


func _owned_item_ids() -> Dictionary:
	var result: Dictionary = {}
	if _survival == null:
		return result
	var inventory = _survival.call("get_inventory_state") if _survival.has_method("get_inventory_state") else null
	if inventory != null and inventory.has_method("slot_capacity") and inventory.has_method("state_at"):
		for index in range(int(inventory.call("slot_capacity"))):
			var record_variant = inventory.call("state_at", index)
			if record_variant is Dictionary:
				var state_variant = record_variant.get("state", {})
				if state_variant is Dictionary:
					var item_id: String = str(state_variant.get("item_id", ""))
					if not item_id.is_empty():
						result[item_id] = true
	var equipment = _equipment_state()
	if equipment != null and equipment.has_method("canonical_snapshot"):
		var snapshot_variant = equipment.call("canonical_snapshot")
		if snapshot_variant is Dictionary:
			for slot_variant in snapshot_variant.get("slots", []):
				if not slot_variant is Dictionary:
					continue
				var container_variant = slot_variant.get("container", {})
				if not container_variant is Dictionary:
					continue
				for record_variant in container_variant.get("slots", []):
					if not record_variant is Dictionary:
						continue
					var state_variant = record_variant.get("state", {})
					if state_variant is Dictionary:
						var item_id: String = str(state_variant.get("item_id", ""))
						if not item_id.is_empty():
							result[item_id] = true
	return result


func _current_pending_loot_ids() -> Dictionary:
	var result: Dictionary = {}
	if _encounter == null or not _encounter.has_method("get_pending_loot_occurrence_ids"):
		return result
	for raw_id in _encounter.call("get_pending_loot_occurrence_ids"):
		result[str(raw_id)] = true
	return result


func _current_resource_remaining() -> Dictionary:
	var result: Dictionary = {}
	if _game == null:
		return result
	var store = _game.get("world_delta_store")
	if store == null or not store.has_method("snapshot"):
		return result
	var snapshot_variant = store.call("snapshot")
	if not snapshot_variant is Dictionary:
		return result
	var object_state_variant = snapshot_variant.get("object_state", {})
	if not object_state_variant is Dictionary:
		return result
	for raw_id in object_state_variant.keys():
		var envelope_variant = object_state_variant[raw_id]
		if not envelope_variant is Dictionary or str(envelope_variant.get("schema", "")) != RESOURCE_SCHEMA:
			continue
		var depletion_variant = envelope_variant.get("depletion", {})
		if not depletion_variant is Dictionary:
			continue
		var remaining_variant = depletion_variant.get("remaining_capacity_units", null)
		if typeof(remaining_variant) != TYPE_INT and typeof(remaining_variant) != TYPE_FLOAT:
			continue
		var remaining: float = float(remaining_variant)
		if not is_finite(remaining):
			continue
		result[str(raw_id)] = remaining
	return result


func _resource_position(stable_id: String) -> Vector3:
	var found := _find_placement_node(_game, stable_id)
	if found != null and found is Node3D:
		return (found as Node3D).global_position
	return _player_position()


func _find_placement_node(root: Node, stable_id: String) -> Node:
	if root == null:
		return null
	if root.has_meta("placement_stable_id") and str(root.get_meta("placement_stable_id")) == stable_id:
		return root
	for child in root.get_children():
		var found := _find_placement_node(child, stable_id)
		if found != null:
			return found
	return null


func _player_position() -> Vector3:
	if _player != null and _player is Node3D:
		var position: Vector3 = (_player as Node3D).global_position
		if _finite_vector3(position):
			return position
	return Vector3.ZERO


func _dispatch(cue_id: String, payload: Dictionary = {}) -> void:
	if _audio == null:
		return
	var result: Dictionary = _audio.dispatch(cue_id, payload)
	if not bool(result.get("success", false)):
		return
	_recent_cues.append(cue_id)
	while _recent_cues.size() > MAX_RECENT_CUES:
		_recent_cues.pop_front()


func _connect_if_present(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)


static func _spatial_payload(position: Vector3) -> Dictionary:
	return {"position": position}


static func _dictionary_copy(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


static func _finite_vector3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
