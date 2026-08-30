extends SceneTree

const GAME_SCENE_PATH := "res://app/game/game.tscn"
const NaturalEntranceRouteTests := preload("res://tests/geometry/test_natural_entrance_route.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = NaturalEntranceRouteTests.run()
	await _run_live_new_game(failures)
	if failures.is_empty():
		print("[ENTRANCE UX VALIDATION] PASS")
		print("  deterministic selection / bounded approach / source identity / runtime backtrack / live NEW Game route passed")
		quit(0)
		return
	printerr("[ENTRANCE UX VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)


func _run_live_new_game(failures: Array[String]) -> void:
	var packed = ResourceLoader.load(GAME_SCENE_PATH)
	if packed == null or not packed is PackedScene:
		failures.append("live/new production Game scene did not load")
		return
	var game: Node = packed.instantiate()
	if game == null:
		failures.append("live/new production Game scene did not instantiate")
		return
	if not game.has_method("prepare_new_game") or not bool(game.call("prepare_new_game")):
		failures.append("live/new production Game did not accept NEW preparation")
		game.free()
		return
	if bool(game.get("enable_map015_fixture")):
		failures.append("live/new production Game unexpectedly enables MAP-015 fixture")
		game.free()
		return

	root.add_child(game)
	await process_frame

	var route_controller := game.get_node_or_null("NaturalEntranceRoute")
	if route_controller == null:
		failures.append("live/new production Game is missing NaturalEntranceRoute")
		_teardown_game(game)
		return
	if not bool(route_controller.call("route_is_ready")):
		failures.append("live/new production Game did not activate a natural entrance route: %s" % [route_controller.call("diagnostics")])
		_teardown_game(game)
		return
	var route_variant: Variant = route_controller.call("route_snapshot")
	if not route_variant is Dictionary:
		failures.append("live/new natural entrance route snapshot is malformed")
		_teardown_game(game)
		return
	var route: Dictionary = route_variant
	var entrance_id: String = str(route.get("entrance_id", ""))
	if entrance_id.is_empty():
		failures.append("live/new natural entrance route has no generated entrance id")
	if int(route.get("world_seed", -1)) != 12345:
		failures.append("live/new natural entrance route did not use ordinary default seed 12345")

	var player = game.get("player")
	var runtime = game.get("underworld_runtime")
	if player == null or runtime == null:
		failures.append("live/new natural entrance route requires live Player and cave runtime")
	else:
		var player_position: Vector3 = player.global_position
		if not _finite_vector3(player_position):
			failures.append("live/new Player spawn is non-finite")
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
			failures.append("live/new Game did not commit selected entrance approach spawn")
	else:
		failures.append("live/new route/Game spawn values are malformed")

	_teardown_game(game)
	await process_frame


func _teardown_game(game: Node) -> void:
	if game == null or not is_instance_valid(game):
		return
	if game.get_parent() != null:
		game.get_parent().remove_child(game)
	game.free()


func _finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)
