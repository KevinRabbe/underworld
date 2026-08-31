extends RefCounted

const GAME_SCENE_PATH := "res://app/game/game.tscn"
const TEST_SLOT := "user://save_001_deep_underworld_continue.json"
const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const GameplaySaveCatalog := preload("res://gameplay/persistence/gameplay_save_catalog.gd")
const GameSaveSlotService := preload("res://gameplay/persistence/game_save_slot_service.gd")

const TEST_SEED: int = 2174242


static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_cleanup_slot()
	var packed = ResourceLoader.load(GAME_SCENE_PATH)
	if packed == null or not packed is PackedScene:
		return ["deep Continue proof could not load game.tscn"]
	var candidate: Dictionary = _candidate(failures)
	if candidate.is_empty():
		_cleanup_slot()
		return failures

	# Start from a normal detached Continue, then use the production observer path
	# to reach a real cell that was not part of the entrance handoff.
	var game: Node = packed.instantiate()
	game.set("enable_debug_hud", false)
	if not bool(game.call("prepare_continue", candidate)):
		failures.append("deep Continue proof initial Game rejected valid candidate")
		game.free()
		_cleanup_slot()
		return failures
	tree.root.add_child(game)
	var runtime = game.get("underworld_runtime")
	var player = game.get("player")
	if runtime == null or player == null:
		failures.append("deep Continue proof initial Game did not create runtime/Player")
		_free_attached(game)
		_cleanup_slot()
		return failures
	var target: Dictionary = _find_observer_target(runtime)
	if target.is_empty():
		failures.append("production observer path did not realize an underground cell outside entrance handoff")
		_free_attached(game)
		_cleanup_slot()
		return failures
	var target_position: Vector3 = target["position"]
	var target_key: String = str(target["key"])
	var target_source: String = str(target["source"])
	var target_provenance: String = str(target["provenance"])
	player.global_position = target_position
	for _step in range(4):
		runtime.update_player_position(target_position)

	# Real production snapshot -> durable slot -> detached load.
	var request_variant: Variant = game.call("build_save_request")
	if not request_variant is Dictionary or not bool(request_variant.get("success", false)):
		failures.append("deep observer Game could not build production SAVE request")
		_free_attached(game)
		_cleanup_slot()
		return failures
	var request: Dictionary = request_variant
	var saved_resume_variant: Variant = request.get("resume_position", null)
	if not saved_resume_variant is Vector3 or not saved_resume_variant.is_equal_approx(target_position):
		failures.append("deep observer SAVE did not preserve exact runtime Player position")
	var service = GameSaveSlotService.new()
	var saved: Dictionary = service.save_slot(
		request.get("context", null),
		request.get("delta_store", null),
		request.get("inventory_state", null),
		request.get("equipment_state", null),
		request.get("pending_loot_states", []),
		request.get("resume_position", Vector3.ZERO),
		TEST_SLOT
	)
	if not bool(saved.get("success", false)):
		failures.append("deep observer production SAVE failed: %s" % [saved.get("diagnostics", [])])
		_free_attached(game)
		_cleanup_slot()
		return failures
	var loaded: Dictionary = service.load_slot(TEST_SLOT)
	if not bool(loaded.get("success", false)):
		failures.append("deep observer detached slot load failed: %s" % [loaded.get("diagnostics", [])])
		_free_attached(game)
		_cleanup_slot()
		return failures
	var loaded_candidate_variant: Variant = loaded.get("candidate", null)
	if not loaded_candidate_variant is Dictionary:
		failures.append("deep observer detached slot load did not return candidate")
		_free_attached(game)
		_cleanup_slot()
		return failures
	var loaded_candidate: Dictionary = loaded_candidate_variant
	_free_attached(game)

	# Recreate the real Game. The scene child readiness gate runs before Game._ready
	# and must hold the entire Game subtree before the restored Player can receive
	# a physics/process frame at the deep position.
	var resumed: Node = packed.instantiate()
	resumed.set("enable_debug_hud", false)
	if not bool(resumed.call("prepare_continue", loaded_candidate)):
		failures.append("deep observer recreated Game rejected durable Continue candidate")
		resumed.free()
		_cleanup_slot()
		return failures
	tree.root.add_child(resumed)
	var resumed_player = resumed.get("player")
	var resumed_runtime = resumed.get("underworld_runtime")
	var gate = resumed.get_node_or_null("UnderworldContinueReadinessGate")
	if resumed_player == null or resumed_runtime == null or gate == null:
		failures.append("deep Continue recreated Game is missing Player/runtime/readiness gate")
		_free_attached(resumed)
		_cleanup_slot()
		return failures
	if not resumed_player.global_position.is_equal_approx(target_position):
		failures.append("deep Continue changed exact durable Player resume position before readiness")
	if resumed.process_mode != Node.PROCESS_MODE_DISABLED:
		failures.append("deep Continue did not hold Game processing before local cave readiness")
	if not bool(gate.call("is_holding")):
		failures.append("deep Continue readiness gate was not holding restored Player startup")

	# Resolve synchronously in the test instead of waiting a frame. Production uses
	# the gate's deferred call while the Game subtree remains processing-disabled.
	var readiness_variant: Variant = gate.call("resolve_now")
	if not readiness_variant is Array or not readiness_variant.is_empty():
		failures.append("deep Continue local reconstruction failed: %s" % [readiness_variant])
	if resumed.process_mode == Node.PROCESS_MODE_DISABLED:
		failures.append("deep Continue did not release Game processing after collision readiness")
	if not bool(gate.call("resume_ready")):
		failures.append("deep Continue readiness gate did not report resolved state")
	if str(gate.call("resume_cell_key")) != target_key:
		failures.append("deep Continue reconstructed a different runtime cell than the saved position")
	if not resumed_player.global_position.is_equal_approx(target_position):
		failures.append("deep Continue relocated Player while reconstructing local cave")

	var resumed_record = resumed_runtime.streamer.records.get(target_key, null)
	if not _record_is_gameplay_ready(resumed_runtime, resumed_record, target_key):
		failures.append("deep Continue released Player before saved cell render/collision readiness")
	elif (
		resumed_record.source_fingerprint != target_source
		or resumed_record.provenance_fingerprint != target_provenance
	):
		failures.append("deep Continue rebuilt saved cell with different canonical source/provenance")

	# Deliberately backtrack to the generated entrance and return to the saved cell.
	# This verifies that reconstruction did not create a one-way/stale runtime state.
	var entrance_ids: Array = resumed_runtime.entrance_plans.keys()
	entrance_ids.sort()
	if entrance_ids.is_empty():
		failures.append("deep Continue runtime lost generated entrance handoff")
	else:
		var entrance_id: String = str(entrance_ids[0])
		var handoff = resumed_runtime.entrance_plans[entrance_id]
		if handoff == null or handoff.cell_addresses.is_empty():
			failures.append("deep Continue runtime generated entrance handoff is empty")
		else:
			var entrance_address = handoff.cell_addresses[0]
			var entrance_position: Vector3 = (
				Vector3(entrance_address.coordinate) * resumed_runtime.streamer.cell_size
				+ resumed_runtime.streamer.cell_size * 0.5
			)
			resumed_player.global_position = entrance_position
			for _step in range(8):
				resumed_runtime.update_player_position(entrance_position)
			if not resumed_runtime.gate_is_open(entrance_id):
				failures.append("deep Continue backtrack did not restore traversable entrance readiness")
			resumed_player.global_position = target_position
			for _step in range(24):
				resumed_runtime.update_player_position(target_position)
			var returned_record = resumed_runtime.streamer.records.get(target_key, null)
			if not _record_is_gameplay_ready(resumed_runtime, returned_record, target_key):
				failures.append("deep Continue return did not re-establish saved-cell readiness")
			elif (
				returned_record.source_fingerprint != target_source
				or returned_record.provenance_fingerprint != target_provenance
			):
				failures.append("deep Continue backtrack/return changed saved-cell identity")
			if resumed_runtime.streamer.stale_result_count != 0:
				failures.append("deep Continue backtrack/return resurrected stale runtime results")

	_free_attached(resumed)
	_cleanup_slot()
	return failures


static func _find_observer_target(runtime) -> Dictionary:
	if runtime == null or runtime.streamer == null or runtime.entrance_plans.is_empty():
		return {}
	var entrance_ids: Array = runtime.entrance_plans.keys()
	entrance_ids.sort()
	var handoff_keys: Dictionary = {}
	var anchor_address = null
	for raw_id in entrance_ids:
		var plan = runtime.entrance_plans.get(str(raw_id), null)
		if plan == null:
			continue
		for address in plan.cell_addresses:
			handoff_keys[address.canonical_text()] = true
			if anchor_address == null:
				anchor_address = address
	if anchor_address == null:
		return {}
	var anchor_position: Vector3 = (
		Vector3(anchor_address.coordinate) * runtime.streamer.cell_size
		+ runtime.streamer.cell_size * 0.5
	)
	for _step in range(32):
		runtime.update_player_position(anchor_position)
		var keys: Array = runtime.streamer.records.keys()
		keys.sort()
		for raw_key in keys:
			var key: String = str(raw_key)
			if handoff_keys.has(key):
				continue
			var record = runtime.streamer.records.get(key, null)
			if record == null or record.cell_address == null:
				continue
			if int(record.cell_address.coordinate.y) >= 0:
				continue
			if not _record_is_gameplay_ready(runtime, record, key):
				continue
			return {
				"key": key,
				"position": Vector3(record.cell_address.coordinate) * runtime.streamer.cell_size + runtime.streamer.cell_size * 0.5,
				"source": record.source_fingerprint,
				"provenance": record.provenance_fingerprint,
			}
	return {}


static func _record_is_gameplay_ready(runtime, record, key: String) -> bool:
	if runtime == null or record == null or bool(record.release_pending) or str(record.state) == "failed":
		return false
	if record.source_fingerprint.is_empty() or record.provenance_fingerprint.is_empty():
		return false
	for tier in ["definition", "fragment_plan", "voxel_geometry", "render", "collision"]:
		if not bool(record.readiness.get(tier, false)):
			return false
	return runtime.render_nodes.has(key) and runtime.collision_nodes.has(key)


static func _candidate(failures: Array[String]) -> Dictionary:
	var catalog_result: Dictionary = GameplaySaveCatalog.build_registry()
	if not bool(catalog_result.get("success", false)):
		failures.append("deep Continue fixture could not build gameplay catalog")
		return {}
	var inventory = ItemContainerState.new().configure(8, 100.0)
	if not inventory.validate_container().is_empty():
		failures.append("deep Continue fixture inventory is invalid")
		return {}
	var equipment = EquipmentHotbarState.new().configure(
		GameplaySaveCatalog.equipment_rules(),
		GameplaySaveCatalog.hotbar_bindings()
	)
	if not equipment.validate_state().is_empty():
		failures.append("deep Continue fixture equipment is invalid")
		return {}
	var context = WorldGenerationContext.new(TEST_SEED)
	var context_failures: Array[String] = context.validate()
	if not context_failures.is_empty():
		failures.append("deep Continue fixture world context is invalid: %s" % [context_failures])
		return {}
	return {
		"world_context": context,
		"world_seed": TEST_SEED,
		"world_id": context.world_id,
		"delta_store": WorldDeltaStore.new(),
		"inventory_state": inventory,
		"equipment_state": equipment,
		"pending_loot_states": [],
		"resume_position": Vector3(8.0, 44.0, 8.0),
	}


static func _free_attached(node: Node) -> void:
	if node == null:
		return
	if node.is_inside_tree():
		var parent: Node = node.get_parent()
		if parent != null:
			parent.remove_child(node)
	node.free()


static func _cleanup_slot() -> void:
	for path in [
		TEST_SLOT,
		TEST_SLOT + GameSaveSlotService.CANDIDATE_SUFFIX,
		TEST_SLOT + GameSaveSlotService.BACKUP_SUFFIX,
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
