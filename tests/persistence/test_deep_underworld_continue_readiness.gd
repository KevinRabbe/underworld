extends RefCounted

const GAME_SCENE_PATH := "res://app/game/game.tscn"
const TEST_SLOT := "user://save_001_deep_underworld_continue.json"
const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const GameplaySaveCatalog := preload("res://gameplay/persistence/gameplay_save_catalog.gd")
const GameSaveSlotService := preload("res://gameplay/persistence/game_save_slot_service.gd")
const PlayerSupportBounds := preload("res://gameplay/player/player_collision_support_bounds.gd")

const TEST_SEED: int = 2174242
const BOUNDARY_INSET: float = 0.10
const FLOOR_CLEARANCE: float = 0.04
const MAX_BOUNDARY_TRIANGLE_DISTANCE: float = 0.38


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
	# to reach a real, physically standable near-boundary cell outside the finite
	# entrance handoff. This is not a synthetic floor/fixture injection.
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
	var target: Dictionary = await _find_observer_boundary_target(runtime, player, tree)
	if target.is_empty():
		failures.append("production observer path did not find a standable near-boundary underground target outside entrance handoff")
		_free_attached(game)
		_cleanup_slot()
		return failures
	var target_position: Vector3 = target["position"]
	var target_key: String = str(target["key"])
	var target_source: String = str(target["source"])
	var target_provenance: String = str(target["provenance"])
	player.global_position = target_position
	player.velocity = Vector3.ZERO
	for _step in range(12):
		runtime.update_player_position(target_position)

	var initial_support: Dictionary = _support_keys_for_player(runtime, player, target_position)
	if not bool(initial_support.get("success", false)):
		failures.append("deep observer target support query failed: %s" % [initial_support.get("diagnostics", [])])
	elif initial_support.get("keys", []).size() < 2:
		failures.append("deep observer target does not cross a runtime cell boundary")
	else:
		for key in initial_support.get("keys", []):
			var support_record = runtime.streamer.records.get(str(key), null)
			if not _record_is_gameplay_ready(runtime, support_record, str(key)):
				failures.append("deep observer target support cell is not gameplay-ready before SAVE: %s" % str(key))

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
	# a physics/process frame at the deep exact position.
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

	# Resolve synchronously in the test instead of waiting an idle frame. Production
	# uses the deferred call while the Game subtree remains processing-disabled.
	var readiness_variant: Variant = gate.call("resolve_now")
	if not readiness_variant is Array or not readiness_variant.is_empty():
		failures.append("deep Continue local reconstruction failed: %s" % [readiness_variant])
	if resumed.process_mode == Node.PROCESS_MODE_DISABLED:
		failures.append("deep Continue did not release Game processing after collision readiness")
	if not bool(gate.call("resume_ready")):
		failures.append("deep Continue readiness gate did not report resolved state")
	if str(gate.call("resume_cell_key")) != target_key:
		failures.append("deep Continue reconstructed a different containing runtime cell than the saved position")
	var resumed_support_variant: Variant = gate.call("resume_support_cell_keys")
	if not resumed_support_variant is Array or resumed_support_variant.size() < 2:
		failures.append("deep Continue gate did not require the multi-cell Player support envelope")
	else:
		for raw_key in resumed_support_variant:
			var key: String = str(raw_key)
			var support_record = resumed_runtime.streamer.records.get(key, null)
			if not _record_is_gameplay_ready(resumed_runtime, support_record, key):
				failures.append("deep Continue released Game before required support cell readiness: %s" % key)
	if not resumed_player.global_position.is_equal_approx(target_position):
		failures.append("deep Continue relocated Player while reconstructing local cave")

	var resumed_record = resumed_runtime.streamer.records.get(target_key, null)
	if not _record_is_gameplay_ready(resumed_runtime, resumed_record, target_key):
		failures.append("deep Continue released Player before saved containing-cell render/collision readiness")
	elif (
		resumed_record.source_fingerprint != target_source
		or resumed_record.provenance_fingerprint != target_provenance
	):
		failures.append("deep Continue rebuilt saved cell with different canonical source/provenance")

	# Exercise actual SceneTree physics after release; direct _physics_process calls
	# are not accepted evidence for collision-safe Continue.
	var first_physics_position: Vector3 = resumed_player.global_position
	for _frame in range(6):
		await tree.physics_frame
	if resumed_player.has_method("is_defeated") and bool(resumed_player.call("is_defeated")):
		failures.append("deep Continue first real physics frames triggered Player defeat")
	var after_physics: Vector3 = resumed_player.global_position
	if Vector2(after_physics.x, after_physics.z).distance_to(Vector2(first_physics_position.x, first_physics_position.z)) > 0.05:
		failures.append("deep Continue first physics frames horizontally relocated Player")
	if absf(after_physics.y - first_physics_position.y) > 0.35:
		failures.append("deep Continue first physics frames fell/teleported Player despite support readiness")

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
			resumed_player.velocity = Vector3.ZERO
			for _step in range(8):
				resumed_runtime.update_player_position(entrance_position)
			if not resumed_runtime.gate_is_open(entrance_id):
				failures.append("deep Continue backtrack did not restore traversable entrance readiness")
			resumed_player.global_position = target_position
			resumed_player.velocity = Vector3.ZERO
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


static func _find_observer_boundary_target(runtime, player, tree: SceneTree) -> Dictionary:
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
	for _step in range(48):
		runtime.update_player_position(anchor_position)
	await tree.physics_frame

	var cell_size: Vector3 = runtime.streamer.cell_size
	var keys: Array = runtime.streamer.records.keys()
	keys.sort()
	for raw_key in keys:
		var key: String = str(raw_key)
		if handoff_keys.has(key):
			continue
		var record = runtime.streamer.records.get(key, null)
		if record == null or record.cell_address == null:
			continue
		var coordinate: Vector3i = record.cell_address.coordinate
		# Keep this proof above the legacy pre-#394 global fall threshold while it
		# exercises #372. #394 later removes Y as cross-domain validity authority.
		if coordinate.y >= 0 or coordinate.y < -2:
			continue
		if not _record_is_gameplay_ready(runtime, record, key):
			continue
		for axis in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var neighbor_coordinate: Vector3i = coordinate + axis
			var neighbor_key: String = "gcell1:r1:x%d:y%d:z%d" % [
				neighbor_coordinate.x,
				neighbor_coordinate.y,
				neighbor_coordinate.z,
			]
			if handoff_keys.has(neighbor_key):
				continue
			var neighbor = runtime.streamer.records.get(neighbor_key, null)
			if not _record_is_gameplay_ready(runtime, neighbor, neighbor_key):
				continue
			var probe := Vector3(
				(float(coordinate.x) + 0.5) * cell_size.x,
				(float(coordinate.y) + 0.5) * cell_size.y,
				(float(coordinate.z) + 0.5) * cell_size.z
			)
			if axis.x > 0:
				probe.x = float(coordinate.x + 1) * cell_size.x - BOUNDARY_INSET
			elif axis.x < 0:
				probe.x = float(coordinate.x) * cell_size.x + BOUNDARY_INSET
			elif axis.z > 0:
				probe.z = float(coordinate.z + 1) * cell_size.z - BOUNDARY_INSET
			else:
				probe.z = float(coordinate.z) * cell_size.z + BOUNDARY_INSET
			var floor_position_variant: Variant = _generated_floor_position(runtime, coordinate, probe)
			if not floor_position_variant is Vector3:
				continue
			var floor_position: Vector3 = floor_position_variant
			var support: Dictionary = _support_keys_for_player(runtime, player, floor_position)
			if not bool(support.get("success", false)) or support.get("keys", []).size() < 2:
				continue
			var all_ready: bool = true
			for support_key in support.get("keys", []):
				var support_record = runtime.streamer.records.get(str(support_key), null)
				if not _record_is_gameplay_ready(runtime, support_record, str(support_key)):
					all_ready = false
					break
			if not all_ready:
				continue

			# Prove this is a real standable generated point before saving it. Let the
			# actual Player physics settle for a few frames, then retain that exact
			# settled position (X/Z remain deliberately near the cell face).
			player.global_position = floor_position
			player.velocity = Vector3.ZERO
			var before: Vector3 = floor_position
			for _frame in range(3):
				await tree.physics_frame
			if player.has_method("is_defeated") and bool(player.call("is_defeated")):
				return {}
			var settled: Vector3 = player.global_position
			if Vector2(settled.x, settled.z).distance_to(Vector2(before.x, before.z)) > 0.05:
				continue
			if absf(settled.y - before.y) > 0.30:
				continue
			for _step in range(12):
				runtime.update_player_position(settled)
			var settled_coordinate: Vector3i = runtime.streamer.observer_cell(settled)
			var settled_key: String = "gcell1:r1:x%d:y%d:z%d" % [
				settled_coordinate.x,
				settled_coordinate.y,
				settled_coordinate.z,
			]
			var settled_record = runtime.streamer.records.get(settled_key, null)
			if not _record_is_gameplay_ready(runtime, settled_record, settled_key):
				continue
			var settled_support: Dictionary = _support_keys_for_player(runtime, player, settled)
			if not bool(settled_support.get("success", false)) or settled_support.get("keys", []).size() < 2:
				continue
			return {
				"key": settled_key,
				"position": settled,
				"source": settled_record.source_fingerprint,
				"provenance": settled_record.provenance_fingerprint,
			}
	return {}


static func _generated_floor_position(runtime, coordinate: Vector3i, probe: Vector3) -> Variant:
	if runtime == null:
		return null
	var key: String = "gcell1:r1:x%d:y%d:z%d" % [coordinate.x, coordinate.y, coordinate.z]
	var body_variant: Variant = runtime.collision_nodes.get(key, null)
	if not body_variant is StaticBody3D:
		return null
	var body: StaticBody3D = body_variant
	var collider_variant: Variant = body.get_node_or_null("CollisionShape3D")
	if not collider_variant is CollisionShape3D:
		return null
	var shape_variant: Variant = collider_variant.shape
	if not shape_variant is ConcavePolygonShape3D:
		return null
	var shape: ConcavePolygonShape3D = shape_variant
	var faces: PackedVector3Array = shape.get_faces()
	if faces.size() < 3:
		return null

	var cell_size: Vector3 = runtime.streamer.cell_size
	var cell_min: Vector3 = Vector3(coordinate) * cell_size
	var cell_max: Vector3 = cell_min + cell_size
	var x_probe_distance: float = minf(absf(probe.x - cell_min.x), absf(probe.x - cell_max.x))
	var z_probe_distance: float = minf(absf(probe.z - cell_min.z), absf(probe.z - cell_max.z))
	var use_x_boundary: bool = x_probe_distance <= z_probe_distance
	var boundary_value: float
	if use_x_boundary:
		boundary_value = cell_min.x if absf(probe.x - cell_min.x) < absf(probe.x - cell_max.x) else cell_max.x
	else:
		boundary_value = cell_min.z if absf(probe.z - cell_min.z) < absf(probe.z - cell_max.z) else cell_max.z

	var best_position: Variant = null
	var best_score: float = INF
	for index in range(0, faces.size(), 3):
		if index + 2 >= faces.size():
			break
		var a: Vector3 = faces[index]
		var b: Vector3 = faces[index + 1]
		var c: Vector3 = faces[index + 2]
		var normal: Vector3 = (b - a).cross(c - a)
		if normal.length_squared() <= 0.000001:
			continue
		normal = normal.normalized()
		# Backface collision is disabled in production. Only an upward-facing
		# generated triangle can actually support the Player from above.
		if normal.y < 0.55:
			continue
		var centroid: Vector3 = (a + b + c) / 3.0
		for vertex in [a, b, c]:
			# Stay inside the triangle instead of placing exactly on a shared vertex.
			var candidate: Vector3 = vertex.lerp(centroid, 0.08)
			var boundary_distance: float = (
				absf(candidate.x - boundary_value)
				if use_x_boundary
				else absf(candidate.z - boundary_value)
			)
			if boundary_distance > MAX_BOUNDARY_TRIANGLE_DISTANCE:
				continue
			var lateral_distance: float = (
				absf(candidate.z - probe.z)
				if use_x_boundary
				else absf(candidate.x - probe.x)
			)
			var score: float = boundary_distance * 100.0 + lateral_distance
			if score < best_score:
				best_score = score
				best_position = candidate + Vector3.UP * FLOOR_CLEARANCE
	return best_position


static func _support_keys_for_player(runtime, player, position: Vector3) -> Dictionary:
	var support_result: Dictionary = PlayerSupportBounds.bounds_at(player, position)
	if not bool(support_result.get("success", false)):
		return support_result
	var bounds_variant: Variant = support_result.get("bounds", null)
	if not bounds_variant is AABB:
		return {"success": false, "keys": [], "diagnostics": ["support bounds missing AABB"]}
	var bounds: AABB = bounds_variant
	var cell_size: Vector3 = runtime.streamer.cell_size
	var maximum: Vector3 = bounds.end - Vector3.ONE * 0.0001
	var minimum_coordinate := Vector3i(
		floori(bounds.position.x / cell_size.x),
		floori(bounds.position.y / cell_size.y),
		floori(bounds.position.z / cell_size.z)
	)
	var maximum_coordinate := Vector3i(
		floori(maximum.x / cell_size.x),
		floori(maximum.y / cell_size.y),
		floori(maximum.z / cell_size.z)
	)
	var keys: Array[String] = []
	for x in range(minimum_coordinate.x, maximum_coordinate.x + 1):
		for y in range(minimum_coordinate.y, maximum_coordinate.y + 1):
			for z in range(minimum_coordinate.z, maximum_coordinate.z + 1):
				keys.append("gcell1:r1:x%d:y%d:z%d" % [x, y, z])
	keys.sort()
	return {"success": true, "keys": keys, "diagnostics": []}


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
