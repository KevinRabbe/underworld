extends RefCounted

const Binding := preload("res://presentation/audio/gameplay_audio_binding.gd")
const CueCatalog := preload("res://presentation/audio/audio_cue_catalog.gd")
const PrototypeCatalog := preload("res://content/presentation/audio/prototype_audio_cue_catalog.tres")

const AUDIO_BINDING_PATH := "res://presentation/audio/gameplay_audio_binding.gd"
const PROVISIONAL_STREAMS_PATH := "res://presentation/audio/provisional_audio_stream_library.gd"


class FakeDefinition:
	extends Resource
	var content_id: String = ""

	func _init(value: String = "") -> void:
		content_id = value


class FakeInventory:
	extends RefCounted
	var records: Array[Dictionary] = []

	func slot_capacity() -> int:
		return records.size()

	func state_at(index: int) -> Dictionary:
		return records[index].duplicate(true) if index >= 0 and index < records.size() else {}


class FakeEquipment:
	extends RefCounted
	var hotbar: int = 1
	var selected_id: String = ""
	var owned_ids: Array[String] = []

	func selected_hotbar() -> int:
		return hotbar

	func selected_definition():
		return FakeDefinition.new(selected_id) if not selected_id.is_empty() else null

	func canonical_snapshot() -> Dictionary:
		var slots: Array = []
		for item_id in owned_ids:
			slots.append({
				"container": {
					"slots": [{"state": {"item_id": item_id}}],
				},
			})
		return {"slots": slots}


class FakePlayer:
	extends Node3D
	signal attack_requested(execution: Dictionary)
	signal parry_succeeded(source_position: Vector3)
	signal defeat_requested(reason: StringName)
	var health: int = 100


class FakeSurvival:
	extends Node3D
	signal harvest_result(event: Dictionary)
	var object_hit_progress: Dictionary = {}
	var inventory := FakeInventory.new()
	var equipment := FakeEquipment.new()

	func get_inventory_state():
		return inventory

	func get_equipment_state():
		return equipment


class FakeRecovery:
	extends Node
	signal recovery_committed(reason: StringName, target: Vector3)


class FakeEncounter:
	extends Node3D
	signal loot_pending(occurrence_id: String, profile_id: String, world_position: Vector3)
	var active_enemies: Dictionary = {}
	var pending_ids: Array[String] = []

	func get_pending_loot_occurrence_ids() -> Array[String]:
		return pending_ids.duplicate()


class FakeEnemy:
	extends Node3D
	signal died(enemy_id: String)
	var enemy_id: String = "burrower_1"
	var health: int = 36
	var attack_pending: bool = false


class FakeUnderworld:
	extends Node
	var render_nodes: Dictionary = {}


class FakeDeltaStore:
	extends RefCounted
	var data: Dictionary = {"object_state": {}}

	func snapshot() -> Dictionary:
		return data.duplicate(true)


class FakeGame:
	extends Node3D
	var player := FakePlayer.new()
	var survival := FakeSurvival.new()
	var death_recovery_controller := FakeRecovery.new()
	var encounter_controller := FakeEncounter.new()
	var underworld_runtime := FakeUnderworld.new()
	var world_delta_store := FakeDeltaStore.new()

	func _ready() -> void:
		add_child(player)
		add_child(survival)
		add_child(death_recovery_controller)
		add_child(encounter_controller)
		add_child(underworld_runtime)


static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var game := FakeGame.new()
	tree.root.add_child(game)
	var binding = Binding.new()
	binding.name = "GameplayAudio"
	game.add_child(binding)
	var bind_failures: Array[String] = binding.bind_game(game)
	if not bind_failures.is_empty():
		failures.append("gameplay audio fixture did not bind: %s" % [bind_failures])
		_free_node(game)
		return failures

	_test_vocabulary_and_provisional_streams(binding, failures)
	_test_presentation_scope(failures)
	_test_player_combat_and_death(binding, game, failures)
	_test_harvest_equipment_and_loot(binding, game, failures)
	_test_enemy_resource_and_ambience(binding, game, failures)
	_test_mute_is_presentation_only(binding, game, failures)

	_free_node(game)
	return failures


static func _test_vocabulary_and_provisional_streams(binding, failures: Array[String]) -> void:
	if not CueCatalog.supported_cue_ids().has("audio_cue.player.respawn"):
		failures.append("AUDIO-001 did not add semantic player respawn cue")
	var original_respawn = PrototypeCatalog.cue_by_id("audio_cue.player.respawn")
	if original_respawn == null:
		failures.append("prototype catalog did not author respawn cue")
	elif original_respawn.stream != null:
		failures.append("prototype semantic catalog unexpectedly embeds provisional runtime stream")
	var controller = binding.audio_controller()
	if controller == null:
		failures.append("gameplay audio binding did not compose AudioPresentationController")
		return
	for cue_id in CueCatalog.supported_cue_ids():
		var definition = controller.catalog.cue_by_id(cue_id)
		if definition == null or definition.stream == null:
			failures.append("runtime provisional catalog is missing audible stream: %s" % cue_id)
	var audible: Dictionary = controller.dispatch("audio_cue.player.respawn")
	if not bool(audible.get("success", false)) or not bool(audible.get("played", false)):
		failures.append("unmuted in-tree provisional respawn stream did not enter physical playback path: %s" % [audible])


static func _test_presentation_scope(failures: Array[String]) -> void:
	var forbidden_fragments: Array[String] = [
		"res://app/",
		"res://gameplay/",
		"res://world/",
		"res://worldgen/",
		"get_instance_id(",
	]
	for path in [AUDIO_BINDING_PATH, PROVISIONAL_STREAMS_PATH]:
		var source: String = FileAccess.get_file_as_string(path)
		if source.is_empty():
			failures.append("AUDIO-001 presentation source could not be read: %s" % path)
			continue
		for fragment in forbidden_fragments:
			if source.contains(fragment):
				failures.append("AUDIO-001 presentation source imports/retains gameplay authority marker %s in %s" % [fragment, path])


static func _test_player_combat_and_death(binding, game, failures: Array[String]) -> void:
	var player: FakePlayer = game.player
	binding.clear_recent_cues()
	player.attack_requested.emit({"attack_kind": &"light"})
	player.attack_requested.emit({"attack_kind": &"heavy"})
	player.parry_succeeded.emit(Vector3(2.0, 0.0, 2.0))
	_expect_cue_once(binding, "audio_cue.player.attack.light", failures)
	_expect_cue_once(binding, "audio_cue.player.attack.heavy", failures)
	_expect_cue_once(binding, "audio_cue.player.parry.success", failures)

	binding.clear_recent_cues()
	player.health = 90
	binding.poll_now()
	_expect_cue_once(binding, "audio_cue.player.damage", failures)
	binding.clear_recent_cues()
	binding.poll_now()
	_expect_no_cue(binding, "audio_cue.player.damage", failures)

	player.defeat_requested.emit(&"damage")
	game.death_recovery_controller.recovery_committed.emit(&"damage", Vector3(4.0, 8.0, 4.0))
	_expect_cue_once(binding, "audio_cue.player.death", failures)
	_expect_cue_once(binding, "audio_cue.player.respawn", failures)


static func _test_harvest_equipment_and_loot(binding, game, failures: Array[String]) -> void:
	var survival: FakeSurvival = game.survival
	binding.clear_recent_cues()
	survival.object_hit_progress["tree-1"] = 1
	binding.poll_now()
	_expect_cue_once(binding, "audio_cue.harvest.impact", failures)
	binding.clear_recent_cues()
	binding.poll_now()
	_expect_no_cue(binding, "audio_cue.harvest.impact", failures)

	survival.harvest_result.emit({"type": "harvest.completed"})
	_expect_cue_once(binding, "audio_cue.harvest.complete", failures)
	survival.harvest_result.emit({"type": "harvest.pickup_collected"})
	_expect_cue_once(binding, "audio_cue.inventory.pickup", failures)

	binding.clear_recent_cues()
	survival.equipment.hotbar = 2
	survival.equipment.selected_id = "item.tool.stone_axe"
	survival.equipment.owned_ids = ["item.tool.stone_axe"]
	binding.poll_now()
	_expect_cue_once(binding, "audio_cue.equipment.changed", failures)
	_expect_cue_once(binding, "audio_cue.craft.success", failures)
	binding.clear_recent_cues()
	binding.poll_now()
	_expect_no_cue(binding, "audio_cue.craft.success", failures)

	var encounter: FakeEncounter = game.encounter_controller
	encounter.pending_ids = ["burrower_1"]
	encounter.loot_pending.emit("burrower_1", "loot_profile.creature.burrower.m3", Vector3(1.0, 2.0, 3.0))
	_expect_cue_once(binding, "audio_cue.loot.available", failures)
	binding.poll_now()
	binding.clear_recent_cues()
	encounter.pending_ids.clear()
	binding.poll_now()
	_expect_cue_once(binding, "audio_cue.loot.collected", failures)
	binding.clear_recent_cues()
	binding.poll_now()
	_expect_no_cue(binding, "audio_cue.loot.collected", failures)


static func _test_enemy_resource_and_ambience(binding, game, failures: Array[String]) -> void:
	var encounter: FakeEncounter = game.encounter_controller
	var enemy := FakeEnemy.new()
	enemy.position = Vector3(5.0, 3.0, 5.0)
	encounter.add_child(enemy)
	encounter.active_enemies[enemy.enemy_id] = enemy
	binding.poll_now()
	binding.clear_recent_cues()
	enemy.attack_pending = true
	binding.poll_now()
	_expect_cue_once(binding, "audio_cue.enemy.burrower.attack", failures)
	binding.clear_recent_cues()
	enemy.health = 20
	binding.poll_now()
	_expect_cue_once(binding, "audio_cue.enemy.burrower.hit", failures)
	binding.clear_recent_cues()
	enemy.died.emit(enemy.enemy_id)
	_expect_cue_once(binding, "audio_cue.enemy.burrower.death", failures)

	binding.clear_recent_cues()
	game.world_delta_store.data = {"object_state": {
		"sid1:resource-test": {
			"schema": "resource.runtime.depletion.v1",
			"depletion": {"remaining_capacity_units": 3.0},
		},
	}}
	binding.poll_now()
	_expect_cue_once(binding, "audio_cue.resource.mine.impact", failures)
	binding.clear_recent_cues()
	binding.poll_now()
	_expect_no_cue(binding, "audio_cue.resource.mine.impact", failures)
	game.world_delta_store.data["object_state"]["sid1:resource-test"]["depletion"]["remaining_capacity_units"] = 0.0
	binding.poll_now()
	_expect_cue_once(binding, "audio_cue.resource.mine.impact", failures)
	_expect_cue_once(binding, "audio_cue.resource.depleted", failures)

	var cave_cell := Node3D.new()
	cave_cell.set_meta("cell_semantic_snapshot", {
		"world_bounds": AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0)),
	})
	game.underworld_runtime.add_child(cave_cell)
	game.underworld_runtime.render_nodes["cell"] = cave_cell
	game.player.position = Vector3.ZERO
	binding.poll_now()
	if binding.audio_controller().ambience_role() != CueCatalog.AMBIENCE_CAVE:
		failures.append("realized cave semantic bounds did not select cave ambience")
	game.player.position = Vector3(20.0, 5.0, 20.0)
	binding.poll_now()
	if binding.audio_controller().ambience_role() != CueCatalog.AMBIENCE_SURFACE:
		failures.append("leaving realized cave semantic bounds did not restore surface ambience")


static func _test_mute_is_presentation_only(binding, game, failures: Array[String]) -> void:
	var before_health: int = game.player.health
	var before_pending: Array[String] = game.encounter_controller.pending_ids.duplicate()
	binding.audio_controller().set_muted(true)
	binding.clear_recent_cues()
	game.player.attack_requested.emit({"attack_kind": &"light"})
	if game.player.health != before_health or game.encounter_controller.pending_ids != before_pending:
		failures.append("muted presentation dispatch mutated gameplay fixture state")
	_expect_cue_once(binding, "audio_cue.player.attack.light", failures)
	binding.audio_controller().set_muted(false)


static func _expect_cue_once(binding, cue_id: String, failures: Array[String]) -> void:
	var count: int = binding.recent_cue_ids().count(cue_id)
	if count != 1:
		failures.append("expected exactly one %s cue, got %d in %s" % [cue_id, count, binding.recent_cue_ids()])


static func _expect_no_cue(binding, cue_id: String, failures: Array[String]) -> void:
	if binding.recent_cue_ids().has(cue_id):
		failures.append("unexpected duplicate/rejected %s cue in %s" % [cue_id, binding.recent_cue_ids()])


static func _free_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
