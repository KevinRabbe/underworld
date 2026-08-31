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
const FLOOR_CLEARANCE: float = 0.04
const BOUNDARY_INSET: float = 0.10
const SEAM_GEOMETRY_BAND: float = 1.25
const SEAM_QUANTIZATION: float = 0.10
const SEAM_TANGENTIAL_OFFSETS: Array[float] = [-0.45, 0.0, 0.45]
const MAX_SEAM_PROBES_PER_SIDE: int = 48
const MAX_SEARCH_HOPS: int = 4
const UPDATES_PER_HOP: int = 18
const SCAN_INTERVAL: int = 6
const MAX_PHYSICS_CANDIDATES: int = 48
const MAX_RAY_HITS_PER_PROBE: int = 8


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

	var safe_player_position: Vector3 = player.global_position
	var target: Dictionary = await _find_observer_boundary_target(
		runtime,
		player,
		tree,
		safe_player_position,
		failures
	)
	if target.is_empty():
		failures.append(
			"production observer path did not find a standable multi-cell underground target outside entrance handoff"
		)
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
		failures.append(
			"deep observer target support query failed: %s"
			% [initial_support.get("diagnostics", [])]
		)
	elif initial_support.get("keys", []).size() < 2:
		failures.append("deep observer target does not cross a runtime cell boundary")
	else:
		for raw_key in initial_support.get("keys", []):
			var key: String = str(raw_key)
			var support_record = runtime.streamer.records.get(key, null)
			if not _record_is_gameplay_ready(runtime, support_record, key):
				failures.append(
					"deep observer target support cell is not gameplay-ready before SAVE: %s"
					% key
				)

	var request_variant: Variant = game.call("build_save_request")
	if (
		not request_variant is Dictionary
		or not bool(request_variant.get("success", false))
	):
		failures.append("deep observer Game could not build production SAVE request")
		_free_attached(game)
		_cleanup_slot()
		return failures
	var request: Dictionary = request_variant
	var saved_resume_variant: Variant = request.get("resume_position", null)
	if (
		not saved_resume_variant is Vector3
		or not saved_resume_variant.is_equal_approx(target_position)
	):
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
		failures.append(
			"deep observer production SAVE failed: %s"
			% [saved.get("diagnostics", [])]
		)
		_free_attached(game)
		_cleanup_slot()
		return failures
	var loaded: Dictionary = service.load_slot(TEST_SLOT)
	if not bool(loaded.get("success", false)):
		failures.append(
			"deep observer detached slot load failed: %s"
			% [loaded.get("diagnostics", [])]
		)
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

	var readiness_variant: Variant = gate.call("resolve_now")
	if not readiness_variant is Array or not readiness_variant.is_empty():
		failures.append(
			"deep Continue local reconstruction failed: %s" % [readiness_variant]
		)
	if resumed.process_mode == Node.PROCESS_MODE_DISABLED:
		failures.append("deep Continue did not release Game processing after collision readiness")
	if not bool(gate.call("resume_ready")):
		failures.append("deep Continue readiness gate did not report resolved state")
	if str(gate.call("resume_cell_key")) != target_key:
		failures.append(
			"deep Continue reconstructed a different containing runtime cell than the saved position"
		)

	var resumed_support_variant: Variant = gate.call("resume_support_cell_keys")
	if not resumed_support_variant is Array or resumed_support_variant.size() < 2:
		failures.append("deep Continue gate did not require the multi-cell Player support envelope")
	else:
		for raw_key in resumed_support_variant:
			var key: String = str(raw_key)
			var support_record = resumed_runtime.streamer.records.get(key, null)
			if not _record_is_gameplay_ready(resumed_runtime, support_record, key):
				failures.append(
					"deep Continue released Game before required support cell readiness: %s"
					% key
				)
	if not resumed_player.global_position.is_equal_approx(target_position):
		failures.append("deep Continue relocated Player while reconstructing local cave")

	var resumed_record = resumed_runtime.streamer.records.get(target_key, null)
	if not _record_is_gameplay_ready(resumed_runtime, resumed_record, target_key):
		failures.append(
			"deep Continue released Player before saved containing-cell render/collision readiness"
		)
	elif (
		resumed_record.source_fingerprint != target_source
		or resumed_record.provenance_fingerprint != target_provenance
	):
		failures.append("deep Continue rebuilt saved cell with different canonical source/provenance")

	var first_physics_position: Vector3 = resumed_player.global_position
	for _frame in range(6):
		await tree.physics_frame
	if (
		resumed_player.has_method("is_defeated")
		and bool(resumed_player.call("is_defeated"))
	):
		failures.append("deep Continue first real physics frames triggered Player defeat")
	var after_physics: Vector3 = resumed_player.global_position
	if (
		Vector2(after_physics.x, after_physics.z).distance_to(
			Vector2(first_physics_position.x, first_physics_position.z)
		)
		> 0.05
	):
		failures.append("deep Continue first physics frames horizontally relocated Player")
	if absf(after_physics.y - first_physics_position.y) > 0.35:
		failures.append(
			"deep Continue first physics frames fell/teleported Player despite support readiness"
		)

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
				failures.append(
					"deep Continue backtrack did not restore traversable entrance readiness"
				)
			resumed_player.global_position = target_position
			resumed_player.velocity = Vector3.ZERO
			for _step in range(24):
				resumed_runtime.update_player_position(target_position)
			var returned_record = resumed_runtime.streamer.records.get(target_key, null)
			if not _record_is_gameplay_ready(
				resumed_runtime,
				returned_record,
				target_key
			):
				failures.append(
					"deep Continue return did not re-establish saved-cell readiness"
				)
			elif (
				returned_record.source_fingerprint != target_source
				or returned_record.provenance_fingerprint != target_provenance
			):
				failures.append(
					"deep Continue backtrack/return changed saved-cell identity"
				)
			if resumed_runtime.streamer.stale_result_count != 0:
				failures.append(
					"deep Continue backtrack/return resurrected stale runtime results"
				)

	_free_attached(resumed)
	_cleanup_slot()
	return failures


static func _find_observer_boundary_target(
	runtime,
	player,
	tree: SceneTree,
	safe_player_position: Vector3,
	failures: Array[String]
) -> Dictionary:
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

	var cell_size: Vector3 = runtime.streamer.cell_size
	var anchor_position: Vector3 = (
		Vector3(anchor_address.coordinate) * cell_size
		+ cell_size * 0.5
	)
	var observer_position: Vector3 = anchor_position
	var visited_observer_keys: Dictionary = {}
	var scanned_collision_keys: Dictionary = {}
	var totals := {
		"ready_cells": 0,
		"seam_probes": 0,
		"raycasts": 0,
		"hits": 0,
		"floor_hits": 0,
		"multicell_hits": 0,
		"physics_attempts": 0,
	}

	for _hop in range(MAX_SEARCH_HOPS):
		var observer_coordinate: Vector3i = runtime.streamer.observer_cell(observer_position)
		visited_observer_keys[_cell_key(observer_coordinate)] = true
		for step in range(UPDATES_PER_HOP):
			runtime.update_player_position(observer_position)
			if (step + 1) % SCAN_INTERVAL != 0:
				continue
			await tree.physics_frame
			var scan: Dictionary = await _scan_current_boundary_target(
				runtime,
				player,
				tree,
				handoff_keys,
				safe_player_position,
				scanned_collision_keys
			)
			for counter in totals.keys():
				totals[counter] = int(totals[counter]) + int(scan.get(counter, 0))
			var target_variant: Variant = scan.get("target", null)
			if target_variant is Dictionary and not target_variant.is_empty():
				return target_variant

		var next_position_variant: Variant = _next_exploration_position(
			runtime,
			handoff_keys,
			visited_observer_keys,
			anchor_position
		)
		if not next_position_variant is Vector3:
			break
		observer_position = next_position_variant

	failures.append(
		(
			"deep boundary search exhausted geometry-seeded physics exploration: "
			+ "ready_cells=%d seam_probes=%d raycasts=%d hits=%d floor_hits=%d "
			+ "multicell_hits=%d physics_attempts=%d records=%d collisions=%d"
		)
		% [
			totals["ready_cells"],
			totals["seam_probes"],
			totals["raycasts"],
			totals["hits"],
			totals["floor_hits"],
			totals["multicell_hits"],
			totals["physics_attempts"],
			runtime.streamer.records.size(),
			runtime.collision_nodes.size(),
		]
	)
	return {}


static func _scan_current_boundary_target(
	runtime,
	player,
	tree: SceneTree,
	handoff_keys: Dictionary,
	safe_player_position: Vector3,
	scanned_collision_keys: Dictionary
) -> Dictionary:
	var result := {
		"target": {},
		"ready_cells": 0,
		"seam_probes": 0,
		"raycasts": 0,
		"hits": 0,
		"floor_hits": 0,
		"multicell_hits": 0,
		"physics_attempts": 0,
	}
	if runtime == null or not runtime.is_inside_tree():
		return result
	var world: World3D = runtime.get_world_3d()
	if world == null:
		return result

	var cell_size: Vector3 = runtime.streamer.cell_size
	var minimum_floor_dot: float = cos(float(player.floor_max_angle))
	var candidates: Array[Dictionary] = []
	var keys: Array = runtime.streamer.records.keys()
	keys.sort()

	for raw_key in keys:
		var key: String = str(raw_key)
		if handoff_keys.has(key) or scanned_collision_keys.has(key):
			continue
		var record = runtime.streamer.records.get(key, null)
		if record == null or record.cell_address == null:
			continue
		var coordinate: Vector3i = record.cell_address.coordinate
		# #394 later removes the legacy global fall threshold. Until then, keep
		# the physically validated candidate above the old -100 defeat boundary.
		if coordinate.y >= 0 or coordinate.y < -3:
			continue
		if not _record_is_gameplay_ready(runtime, record, key):
			continue

		var body_variant: Variant = runtime.collision_nodes.get(key, null)
		if not body_variant is StaticBody3D:
			continue
		var collider_variant: Variant = body_variant.get_node_or_null("CollisionShape3D")
		if not collider_variant is CollisionShape3D:
			continue
		var shape_variant: Variant = collider_variant.shape
		if not shape_variant is ConcavePolygonShape3D:
			continue

		scanned_collision_keys[key] = true
		result["ready_cells"] = int(result["ready_cells"]) + 1
		var cell_min: Vector3 = Vector3(coordinate) * cell_size
		var cell_max: Vector3 = cell_min + cell_size
		var top_y: float = minf(cell_max.y + 0.5, -0.05)
		var bottom_y: float = maxf(cell_min.y - 0.5, -95.0)
		if top_y <= bottom_y:
			continue

		var probes: Array[Vector3] = _collision_seam_probes(
			body_variant,
			shape_variant,
			cell_min,
			cell_max
		)
		result["seam_probes"] = int(result["seam_probes"]) + probes.size()
		for probe in probes:
			var ray_start := Vector3(probe.x, top_y, probe.z)
			var floor_hit: Dictionary = _first_floor_hit(
				world,
				player,
				runtime,
				handoff_keys,
				ray_start,
				bottom_y,
				minimum_floor_dot,
				result
			)
			_add_physics_candidate(
				runtime,
				player,
				floor_hit,
				candidates,
				result
			)

	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if not is_equal_approx(float(left["floor_dot"]), float(right["floor_dot"])):
			return float(left["floor_dot"]) > float(right["floor_dot"])
		var lp: Vector3 = left["position"]
		var rp: Vector3 = right["position"]
		if not is_equal_approx(lp.y, rp.y):
			return lp.y < rp.y
		if not is_equal_approx(lp.x, rp.x):
			return lp.x < rp.x
		return lp.z < rp.z
	)

	var tested: int = 0
	for entry in candidates:
		if tested >= MAX_PHYSICS_CANDIDATES:
			break
		tested += 1
		result["physics_attempts"] = int(result["physics_attempts"]) + 1
		var floor_position: Vector3 = entry["position"]
		player.global_position = floor_position
		player.velocity = Vector3.ZERO
		for _frame in range(3):
			await tree.physics_frame
		if player.has_method("is_defeated") and bool(player.call("is_defeated")):
			_restore_probe_player(player, safe_player_position)
			continue
		var settled: Vector3 = player.global_position
		if (
			Vector2(settled.x, settled.z).distance_to(
				Vector2(floor_position.x, floor_position.z)
			)
			> 0.05
		):
			_restore_probe_player(player, safe_player_position)
			continue
		if absf(settled.y - floor_position.y) > 0.30:
			_restore_probe_player(player, safe_player_position)
			continue

		for _step in range(12):
			runtime.update_player_position(settled)
		var settled_coordinate: Vector3i = runtime.streamer.observer_cell(settled)
		var settled_key: String = _cell_key(settled_coordinate)
		if handoff_keys.has(settled_key):
			_restore_probe_player(player, safe_player_position)
			continue
		var settled_record = runtime.streamer.records.get(settled_key, null)
		if not _record_is_gameplay_ready(runtime, settled_record, settled_key):
			_restore_probe_player(player, safe_player_position)
			continue
		var settled_support: Dictionary = _support_keys_for_player(
			runtime,
			player,
			settled
		)
		if (
			not bool(settled_support.get("success", false))
			or settled_support.get("keys", []).size() < 2
			or not _support_is_ready(runtime, settled_support.get("keys", []))
		):
			_restore_probe_player(player, safe_player_position)
			continue
		result["target"] = {
			"key": settled_key,
			"position": settled,
			"source": settled_record.source_fingerprint,
			"provenance": settled_record.provenance_fingerprint,
		}
		return result

	_restore_probe_player(player, safe_player_position)
	return result


static func _collision_seam_probes(
	body: StaticBody3D,
	shape: ConcavePolygonShape3D,
	cell_min: Vector3,
	cell_max: Vector3
) -> Array[Vector3]:
	var side_seeds := {
		"xmin": {},
		"xmax": {},
		"zmin": {},
		"zmax": {},
	}
	var faces: PackedVector3Array = shape.get_faces()
	for index in range(0, faces.size(), 3):
		if index + 2 >= faces.size():
			break
		var a: Vector3 = body.global_transform * faces[index]
		var b: Vector3 = body.global_transform * faces[index + 1]
		var c: Vector3 = body.global_transform * faces[index + 2]
		var centroid: Vector3 = (a + b + c) / 3.0
		var samples: Array[Vector3] = [
			a,
			b,
			c,
			centroid,
			(a + b) * 0.5,
			(b + c) * 0.5,
			(c + a) * 0.5,
		]
		for sample in samples:
			_register_seam_probe_seeds(
				side_seeds,
				sample,
				cell_min,
				cell_max
			)

	var probes: Array[Vector3] = []
	for side_name in ["xmin", "xmax", "zmin", "zmax"]:
		var seeds_variant: Variant = side_seeds.get(side_name, {})
		if not seeds_variant is Dictionary:
			continue
		var seeds: Dictionary = seeds_variant
		var ordered_keys: Array = seeds.keys()
		ordered_keys.sort()
		var accepted: int = 0
		for raw_key in ordered_keys:
			if accepted >= MAX_SEAM_PROBES_PER_SIDE:
				break
			var probe_variant: Variant = seeds.get(raw_key, null)
			if probe_variant is Vector3:
				probes.append(probe_variant)
				accepted += 1
	return probes


static func _register_seam_probe_seeds(
	side_seeds: Dictionary,
	sample: Vector3,
	cell_min: Vector3,
	cell_max: Vector3
) -> void:
	if absf(sample.x - cell_min.x) <= SEAM_GEOMETRY_BAND:
		for offset in SEAM_TANGENTIAL_OFFSETS:
			var z: float = clampf(
				sample.z + offset,
				cell_min.z + BOUNDARY_INSET,
				cell_max.z - BOUNDARY_INSET
			)
			_store_side_probe(
				side_seeds["xmin"],
				z,
				Vector3(cell_min.x + BOUNDARY_INSET, 0.0, z)
			)
	if absf(sample.x - cell_max.x) <= SEAM_GEOMETRY_BAND:
		for offset in SEAM_TANGENTIAL_OFFSETS:
			var z: float = clampf(
				sample.z + offset,
				cell_min.z + BOUNDARY_INSET,
				cell_max.z - BOUNDARY_INSET
			)
			_store_side_probe(
				side_seeds["xmax"],
				z,
				Vector3(cell_max.x - BOUNDARY_INSET, 0.0, z)
			)
	if absf(sample.z - cell_min.z) <= SEAM_GEOMETRY_BAND:
		for offset in SEAM_TANGENTIAL_OFFSETS:
			var x: float = clampf(
				sample.x + offset,
				cell_min.x + BOUNDARY_INSET,
				cell_max.x - BOUNDARY_INSET
			)
			_store_side_probe(
				side_seeds["zmin"],
				x,
				Vector3(x, 0.0, cell_min.z + BOUNDARY_INSET)
			)
	if absf(sample.z - cell_max.z) <= SEAM_GEOMETRY_BAND:
		for offset in SEAM_TANGENTIAL_OFFSETS:
			var x: float = clampf(
				sample.x + offset,
				cell_min.x + BOUNDARY_INSET,
				cell_max.x - BOUNDARY_INSET
			)
			_store_side_probe(
				side_seeds["zmax"],
				x,
				Vector3(x, 0.0, cell_max.z - BOUNDARY_INSET)
			)


static func _store_side_probe(
	seeds: Dictionary,
	tangential_coordinate: float,
	probe: Vector3
) -> void:
	var quantized: int = roundi(tangential_coordinate / SEAM_QUANTIZATION)
	var key: String = str(quantized)
	if not seeds.has(key):
		seeds[key] = probe


static func _first_floor_hit(
	world: World3D,
	player,
	runtime,
	handoff_keys: Dictionary,
	ray_start: Vector3,
	bottom_y: float,
	minimum_floor_dot: float,
	counters: Dictionary
) -> Dictionary:
	var current_y: float = ray_start.y
	for _attempt in range(MAX_RAY_HITS_PER_PROBE):
		if current_y <= bottom_y:
			break
		counters["raycasts"] = int(counters["raycasts"]) + 1
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(ray_start.x, current_y, ray_start.z),
			Vector3(ray_start.x, bottom_y, ray_start.z)
		)
		query.collision_mask = 1
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.exclude = [player.get_rid()]
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		counters["hits"] = int(counters["hits"]) + 1
		var position_variant: Variant = hit.get("position", null)
		var normal_variant: Variant = hit.get("normal", null)
		var collider_variant: Variant = hit.get("collider", null)
		if not position_variant is Vector3:
			break
		var hit_position: Vector3 = position_variant
		current_y = hit_position.y - 0.08
		if not normal_variant is Vector3 or not collider_variant is StaticBody3D:
			continue
		var collider: StaticBody3D = collider_variant
		if collider.get_parent() != runtime:
			continue
		var hit_key: String = str(collider.get_meta("cell_address", ""))
		if hit_key.is_empty() or handoff_keys.has(hit_key):
			continue
		if (
			not runtime.collision_nodes.has(hit_key)
			or runtime.collision_nodes.get(hit_key) != collider
		):
			continue
		var floor_dot: float = normal_variant.dot(Vector3.UP)
		if floor_dot + 0.0001 < minimum_floor_dot:
			continue
		counters["floor_hits"] = int(counters["floor_hits"]) + 1
		return {
			"position": hit_position + Vector3.UP * FLOOR_CLEARANCE,
			"floor_dot": floor_dot,
			"hit_key": hit_key,
		}
	return {}


static func _add_physics_candidate(
	runtime,
	player,
	hit: Dictionary,
	candidates: Array[Dictionary],
	counters: Dictionary
) -> void:
	if hit.is_empty():
		return
	var position_variant: Variant = hit.get("position", null)
	if not position_variant is Vector3:
		return
	var position: Vector3 = position_variant
	if position.y >= 0.0 or position.y <= -95.0:
		return
	var support: Dictionary = _support_keys_for_player(runtime, player, position)
	if (
		not bool(support.get("success", false))
		or support.get("keys", []).size() < 2
	):
		return
	if not _support_is_ready(runtime, support.get("keys", [])):
		return
	counters["multicell_hits"] = int(counters["multicell_hits"]) + 1
	candidates.append(hit)


static func _next_exploration_position(
	runtime,
	handoff_keys: Dictionary,
	visited_observer_keys: Dictionary,
	anchor_position: Vector3
) -> Variant:
	var best_position: Variant = null
	var best_distance: float = -1.0
	var best_key: String = ""
	var keys: Array = runtime.streamer.records.keys()
	keys.sort()
	for raw_key in keys:
		var key: String = str(raw_key)
		if handoff_keys.has(key) or visited_observer_keys.has(key):
			continue
		var record = runtime.streamer.records.get(key, null)
		if record == null or record.cell_address == null:
			continue
		var coordinate: Vector3i = record.cell_address.coordinate
		if coordinate.y >= 0 or coordinate.y < -3:
			continue
		if not _record_is_gameplay_ready(runtime, record, key):
			continue
		if not runtime.collision_nodes.has(key):
			continue
		var center: Vector3 = (
			Vector3(coordinate) * runtime.streamer.cell_size
			+ runtime.streamer.cell_size * 0.5
		)
		var distance: float = center.distance_squared_to(anchor_position)
		if (
			distance > best_distance
			or (
				is_equal_approx(distance, best_distance)
				and (best_key.is_empty() or key < best_key)
			)
		):
			best_distance = distance
			best_key = key
			best_position = center
	return best_position


static func _support_keys_for_player(runtime, player, position: Vector3) -> Dictionary:
	var support_result: Dictionary = PlayerSupportBounds.bounds_at(player, position)
	if not bool(support_result.get("success", false)):
		return support_result
	var bounds_variant: Variant = support_result.get("bounds", null)
	if not bounds_variant is AABB:
		return {
			"success": false,
			"keys": [],
			"diagnostics": ["support bounds missing AABB"],
		}
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
				keys.append(_cell_key(Vector3i(x, y, z)))
	keys.sort()
	return {"success": true, "keys": keys, "diagnostics": []}


static func _support_is_ready(runtime, keys: Array) -> bool:
	for raw_key in keys:
		var key: String = str(raw_key)
		var record = runtime.streamer.records.get(key, null)
		if not _record_is_gameplay_ready(runtime, record, key):
			return false
	return true


static func _record_is_gameplay_ready(runtime, record, key: String) -> bool:
	if (
		runtime == null
		or record == null
		or bool(record.release_pending)
		or str(record.state) == "failed"
	):
		return false
	if record.source_fingerprint.is_empty() or record.provenance_fingerprint.is_empty():
		return false
	for tier in ["definition", "fragment_plan", "voxel_geometry", "render", "collision"]:
		if not bool(record.readiness.get(tier, false)):
			return false
	return runtime.render_nodes.has(key) and runtime.collision_nodes.has(key)


static func _restore_probe_player(player, position: Vector3) -> void:
	player.global_position = position
	player.velocity = Vector3.ZERO


static func _cell_key(coordinate: Vector3i) -> String:
	return "gcell1:r1:x%d:y%d:z%d" % [coordinate.x, coordinate.y, coordinate.z]


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
		failures.append(
			"deep Continue fixture world context is invalid: %s" % [context_failures]
		)
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