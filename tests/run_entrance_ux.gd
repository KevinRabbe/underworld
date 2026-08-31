extends SceneTree

const GAME_SCENE_PATH := "res://app/game/game.tscn"
const TEST_SLOT := "user://entrance_ux_continue.json"
const NaturalEntranceRouteTests := preload("res://tests/geometry/test_natural_entrance_route.gd")
const GameSaveSlotService := preload("res://gameplay/persistence/game_save_slot_service.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_slot()
	var failures: Array[String] = NaturalEntranceRouteTests.run()
	var live_new: Dictionary = await _run_live_new_game(failures)
	if not live_new.is_empty():
		await _run_live_continue(live_new, failures)
	_cleanup_slot()
	if failures.is_empty():
		print("[ENTRANCE UX VALIDATION] PASS")
		print("  deterministic selection / viable fallback / generic bootstrap / single NEW surface start / Continue preservation / runtime backtrack passed")
		quit(0)
		return
	printerr("[ENTRANCE UX VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)


func _run_live_new_game(failures: Array[String]) -> Dictionary:
	var packed = ResourceLoader.load(GAME_SCENE_PATH)
	if packed == null or not packed is PackedScene:
		failures.append("live/new production Game scene did not load")
		return {}
	var game: Node = packed.instantiate()
	if game == null:
		failures.append("live/new production Game scene did not instantiate")
		return {}
	game.set("enable_debug_hud", false)
	if not game.has_method("prepare_new_game") or not bool(game.call("prepare_new_game")):
		failures.append("live/new production Game did not accept NEW preparation")
		game.free()
		return {}
	if bool(game.get("enable_map015_fixture")):
		failures.append("live/new production Game unexpectedly enables MAP-015 fixture")
		game.free()
		return {}

	# Game._ready() is realized synchronously by add_child(). Assert startup state
	# before the first physics frame so Player gravity cannot obscure spawn truth.
	root.add_child(game)

	if not game.has_method("natural_entrance_route_ready") or not bool(game.call("natural_entrance_route_ready")):
		failures.append("live/new production Game did not activate a natural entrance route: %s" % [
			game.call("natural_entrance_route_diagnostics") if game.has_method("natural_entrance_route_diagnostics") else [],
		])
		_teardown_game(game)
		return {}
	if not game.has_method("initial_surface_bootstrap_count") or int(game.call("initial_surface_bootstrap_count")) != 1:
		failures.append("live/new production Game did not perform exactly one initial surface bootstrap")

	var route_variant: Variant = game.call("selected_entrance_route_snapshot")
	if not route_variant is Dictionary:
		failures.append("live/new natural entrance route snapshot is malformed")
		_teardown_game(game)
		return {}
	var route: Dictionary = route_variant
	var entrance_id: String = str(route.get("entrance_id", ""))
	if entrance_id.is_empty():
		failures.append("live/new natural entrance route has no generated entrance id")
	if int(route.get("world_seed", -1)) != 12345:
		failures.append("live/new natural entrance route did not use ordinary default seed 12345")

	var player = game.get("player")
	var runtime = game.get("underworld_runtime")
	var world_settings = game.get("world_settings")
	if player == null or runtime == null or world_settings == null:
		failures.append("live/new natural entrance route requires live Player, cave runtime and world settings")
	else:
		var player_position: Vector3 = player.global_position
		if not _finite_vector3(player_position):
			failures.append("live/new Player spawn is non-finite")
		elif player_position.y <= float(world_settings.sea_level):
			failures.append("live/new Player spawn is not above water")
		if not entrance_id.is_empty() and not bool(runtime.call("gate_is_open", entrance_id)):
			failures.append("live/new selected entrance traversal gate is not ready at approach spawn")
		var surface_variant: Variant = route.get("surface_world_position", null)
		if surface_variant is Vector3:
			var surface: Vector3 = surface_variant
			var distance: float = Vector2(
				player_position.x - surface.x,
				player_position.z - surface.z
			).length()
			if distance < 24.0 or distance > 64.0:
				failures.append("live/new Player spawn is outside bounded entrance approach distance: %.3f" % distance)
		else:
			failures.append("live/new route is missing generated surface position")

	var selected_spawn_variant: Variant = route.get("recommended_spawn_xz", null)
	var committed_spawn_variant: Variant = game.get("spawn_xz")
	if selected_spawn_variant is Vector3 and committed_spawn_variant is Vector3:
		if not selected_spawn_variant.is_equal_approx(committed_spawn_variant):
			failures.append("live/new Game did not commit selected entrance approach before initial surface bootstrap")
	else:
		failures.append("live/new route/Game spawn values are malformed")

	# Build the Continue candidate exclusively through the production SAVE/slot
	# path. Move first so the resumed position cannot accidentally equal the
	# entrance-relative NEW spawn and mask a post-start relocation regression.
	var expected_resume := Vector3(8.0, 44.0, 8.0)
	if player != null:
		player.global_position = expected_resume
	var request_variant: Variant = game.call("build_save_request")
	if not request_variant is Dictionary or not bool(request_variant.get("success", false)):
		failures.append("live/new Game could not build Continue fixture SAVE request: %s" % [
			request_variant.get("diagnostics", []) if request_variant is Dictionary else [],
		])
		_teardown_game(game)
		return {}
	var request: Dictionary = request_variant
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
		failures.append("live/new entrance SAVE fixture failed atomically: %s" % [saved.get("diagnostics", [])])
		_teardown_game(game)
		return {}
	var loaded: Dictionary = service.load_slot(TEST_SLOT)
	if not bool(loaded.get("success", false)):
		failures.append("live/new entrance SAVE fixture did not reload: %s" % [loaded.get("diagnostics", [])])
		_teardown_game(game)
		return {}
	var candidate_variant: Variant = loaded.get("candidate", null)
	if not candidate_variant is Dictionary:
		failures.append("live/new entrance SAVE reload did not return detached Continue candidate")
		_teardown_game(game)
		return {}
	var candidate: Dictionary = candidate_variant
	var result := {
		"candidate": candidate,
		"expected_resume": expected_resume,
		"entrance_id": entrance_id,
		"selection_fingerprint": str(route.get("selection_fingerprint", "")),
		"recommended_spawn_xz": route.get("recommended_spawn_xz", Vector3.ZERO),
	}
	_teardown_game(game)
	await process_frame
	return result


func _run_live_continue(live_new: Dictionary, failures: Array[String]) -> void:
	var packed = ResourceLoader.load(GAME_SCENE_PATH)
	if packed == null or not packed is PackedScene:
		failures.append("live/continue production Game scene did not load")
		return
	var resumed: Node = packed.instantiate()
	if resumed == null:
		failures.append("live/continue production Game scene did not instantiate")
		return
	resumed.set("enable_debug_hud", false)
	var candidate_variant: Variant = live_new.get("candidate", null)
	if not candidate_variant is Dictionary:
		failures.append("live/continue fixture candidate is malformed")
		resumed.free()
		return
	var candidate: Dictionary = candidate_variant
	if not bool(resumed.call("prepare_continue", candidate)):
		failures.append("live/continue production Game rejected valid detached candidate")
		resumed.free()
		return

	# prepare_continue owns a deep clone; mutation after preparation must not alter
	# the committed durable resume point used by the live Game.
	candidate["resume_position"] = Vector3(999.0, 999.0, 999.0)
	# add_child() synchronously completes Game._ready(). Verify the exact durable
	# resume point now, before CharacterBody3D gravity advances the first physics frame.
	root.add_child(resumed)

	if str(resumed.call("startup_mode")) != "continue":
		failures.append("live/continue Game did not retain Continue startup mode")
	if not resumed.has_method("initial_surface_bootstrap_count") or int(resumed.call("initial_surface_bootstrap_count")) != 1:
		failures.append("live/continue production Game did not perform exactly one initial surface bootstrap")
	if not resumed.has_method("natural_entrance_route_ready") or not bool(resumed.call("natural_entrance_route_ready")):
		failures.append("live/continue Game did not reconstruct natural route identity: %s" % [
			resumed.call("natural_entrance_route_diagnostics") if resumed.has_method("natural_entrance_route_diagnostics") else [],
		])

	var expected_resume: Vector3 = live_new.get("expected_resume", Vector3.INF)
	var player = resumed.get("player")
	if player == null or not player.global_position.is_equal_approx(expected_resume):
		failures.append("live/continue natural route reconstruction changed exact durable Player resume position")
	var committed_spawn_variant: Variant = resumed.get("spawn_xz")
	var expected_resume_xz := Vector3(expected_resume.x, 0.0, expected_resume.z)
	if not committed_spawn_variant is Vector3 or not committed_spawn_variant.is_equal_approx(expected_resume_xz):
		failures.append("live/continue initial surface authority did not remain anchored to durable resume XZ")

	var route_variant: Variant = resumed.call("selected_entrance_route_snapshot")
	if not route_variant is Dictionary:
		failures.append("live/continue reconstructed route snapshot is malformed")
	else:
		var route: Dictionary = route_variant
		if str(route.get("entrance_id", "")) != str(live_new.get("entrance_id", "")):
			failures.append("live/continue route reconstruction changed generated entrance identity")
		if str(route.get("selection_fingerprint", "")) != str(live_new.get("selection_fingerprint", "")):
			failures.append("live/continue route reconstruction changed deterministic selection fingerprint")
		var recommended_variant: Variant = route.get("recommended_spawn_xz", null)
		if recommended_variant is Vector3 and committed_spawn_variant is Vector3:
			if committed_spawn_variant.is_equal_approx(recommended_variant):
				failures.append("live/continue route guidance replaced durable resume with NEW entrance approach spawn")

	_teardown_game(resumed)
	await process_frame


func _teardown_game(game: Node) -> void:
	if game == null or not is_instance_valid(game):
		return
	if game.get_parent() != null:
		game.get_parent().remove_child(game)
	game.free()


func _cleanup_slot() -> void:
	for path in [
		TEST_SLOT,
		TEST_SLOT + GameSaveSlotService.CANDIDATE_SUFFIX,
		TEST_SLOT + GameSaveSlotService.BACKUP_SUFFIX,
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)
