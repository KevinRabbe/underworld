extends Node3D
class_name UnderworldPrototypeBurrowerEncounterController

signal loot_pending(occurrence_id: String, profile_id: String, world_position: Vector3)

const EnemyScript := preload("res://gameplay/creatures/underworld/burrower/burrower.gd")
const CreatureDefinition := preload("res://gameplay/creatures/definitions/creature_definition.gd")
const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const LootRewardService := preload("res://gameplay/loot/runtime/loot_reward_service.gd")
const LootProfileDefinition := preload("res://gameplay/loot/definitions/loot_profile_definition.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const BurrowerDefinition := preload("res://content/characters/creatures/prototype_burrower_definition.tres")
const BurrowerRewardProfile := preload("res://content/loot/profiles/prototype_burrower_reward_profile.tres")
const BurrowerChitinDefinition := preload("res://content/items/resources/burrower_chitin_definition.tres")

const TARGET_ENEMY_COUNT := 4
const SPAWN_MIN_DISTANCE := 18.0
const SPAWN_MAX_DISTANCE := 34.0
const SPAWN_INTERVAL := 2.0
const RELEASE_DISTANCE := 72.0

var world
var player
var settings
var active_enemies: Dictionary = {}
var spawn_timer: float = 0.0
var spawn_serial: int = 0
var creature_definition_ready: bool = false
var loot_ready: bool = false
var loot_reward_service = LootRewardService.new()
var loot_registry = ContentRegistry.new()


func configure(world_node, player_node, world_settings) -> void:
	world = world_node
	player = player_node
	settings = world_settings
	spawn_timer = 0.25
	creature_definition_ready = _validate_burrower_definition()
	loot_reward_service = LootRewardService.new()
	loot_registry = ContentRegistry.new()
	loot_ready = _configure_loot_registry()


func _process(delta: float) -> void:
	if (
		world == null
		or player == null
		or settings == null
		or not creature_definition_ready
		or not loot_ready
	):
		return

	_release_distant_or_invalid_enemies()
	spawn_timer = maxf(0.0, spawn_timer - delta)
	if active_enemies.size() < TARGET_ENEMY_COUNT and spawn_timer <= 0.0:
		spawn_timer = SPAWN_INTERVAL
		_spawn_enemy_near_player()


func get_active_enemy_count() -> int:
	return active_enemies.size()


func get_pending_loot_count() -> int:
	return loot_reward_service.pending_count()


func get_pending_loot_snapshot(occurrence_id: String) -> Dictionary:
	return loot_reward_service.pending_snapshot(occurrence_id)


func get_pending_loot_occurrence_ids() -> Array[String]:
	return loot_reward_service.pending_occurrence_ids()


func collect_pending_loot(occurrence_id: String, destination_container) -> Dictionary:
	if not loot_ready:
		return {"success": false, "diagnostics": ["Burrower loot content is not ready"], "events": []}
	return loot_reward_service.collect_pending(
		occurrence_id,
		destination_container,
		loot_registry
	)


func _spawn_enemy_near_player() -> void:
	if player == null or world == null or not creature_definition_ready or not loot_ready:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = settings.world_seed + 9109 + spawn_serial * 7919
	spawn_serial += 1

	for _attempt in range(16):
		var angle: float = rng.randf_range(0.0, TAU)
		var distance: float = rng.randf_range(SPAWN_MIN_DISTANCE, SPAWN_MAX_DISTANCE)
		var candidate_x: float = player.global_position.x + cos(angle) * distance
		var candidate_z: float = player.global_position.z + sin(angle) * distance
		var sample: Dictionary = world.get_surface_sample_at_world(candidate_x, candidate_z)
		var height: float = float(sample["height"])
		var slope: float = float(sample["slope"])
		if height <= settings.sea_level + 1.0 or slope > 0.12:
			continue

		var spawn_position := Vector3(candidate_x, height + 0.2, candidate_z)
		if _is_too_close_to_other_enemy(spawn_position):
			continue

		var id: String = "burrower_%d" % spawn_serial
		var enemy = EnemyScript.new()
		enemy.configure(
			id,
			player,
			spawn_position,
			BurrowerDefinition.runtime_stats()
		)
		enemy.died.connect(_on_enemy_died)
		add_child(enemy)
		active_enemies[id] = enemy
		return


func _validate_burrower_definition() -> bool:
	var definition: Variant = BurrowerDefinition
	if definition == null or not definition is CreatureDefinition:
		push_error("Burrower authored creature definition did not load as CreatureDefinition")
		return false
	var failures: Array[String] = definition.validate_definition()
	if not failures.is_empty():
		push_error("Burrower authored creature definition is invalid: %s" % [failures])
		return false
	return true


func _configure_loot_registry() -> bool:
	if BurrowerRewardProfile == null or not BurrowerRewardProfile is LootProfileDefinition:
		push_error("Burrower reward profile did not load as LootProfileDefinition")
		return false
	if BurrowerChitinDefinition == null or not BurrowerChitinDefinition is ItemDefinition:
		push_error("Burrower reward item did not load as ItemDefinition")
		return false
	var failures: Array[String] = loot_registry.index_definitions([
		BurrowerDefinition,
		BurrowerRewardProfile,
		BurrowerChitinDefinition,
	])
	if not failures.is_empty():
		push_error("Burrower loot registry is invalid: %s" % [failures])
		return false
	if str(BurrowerRewardProfile.source_creature_id) != str(BurrowerDefinition.content_id):
		push_error("Burrower reward profile source creature does not match Burrower definition")
		return false
	return true


func _release_distant_or_invalid_enemies() -> void:
	for id_variant in active_enemies.keys():
		var id: String = str(id_variant)
		var enemy_node: Node3D = active_enemies[id] as Node3D
		if enemy_node == null or not is_instance_valid(enemy_node):
			active_enemies.erase(id)
			continue
		if enemy_node.global_position.distance_to(player.global_position) > RELEASE_DISTANCE:
			enemy_node.queue_free()
			active_enemies.erase(id)


func _is_too_close_to_other_enemy(position: Vector3) -> bool:
	for enemy_variant in active_enemies.values():
		var enemy_node: Node3D = enemy_variant as Node3D
		if enemy_node != null and is_instance_valid(enemy_node):
			if enemy_node.global_position.distance_to(position) < 6.0:
				return true
	return false


func _on_enemy_died(enemy_id: String) -> void:
	var death_position: Vector3 = Vector3.ZERO
	var enemy_node: Node3D = active_enemies.get(enemy_id, null) as Node3D
	if enemy_node != null and is_instance_valid(enemy_node):
		death_position = enemy_node.global_position

	if loot_ready:
		var reward_result: Dictionary = loot_reward_service.issue_for_creature(
			enemy_id,
			BurrowerDefinition,
			BurrowerRewardProfile,
			loot_registry
		)
		if not bool(reward_result.get("success", false)):
			push_error("Burrower death reward issuance failed: %s" % [
				reward_result.get("diagnostics", []),
			])
		elif not bool(reward_result.get("already_issued", false)):
			loot_pending.emit(
				enemy_id,
				str(BurrowerRewardProfile.content_id),
				death_position
			)

	active_enemies.erase(enemy_id)
	spawn_timer = maxf(spawn_timer, 6.0)
