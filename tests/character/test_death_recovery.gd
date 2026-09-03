extends RefCounted

const PlayerScript := preload("res://gameplay/player/player.gd")
const VoxelProvider := preload("res://presentation/characters/voxel/voxel_character_presentation_provider.gd")
const DeathRecoveryControllerScript := preload("res://gameplay/player/lifecycle/player_death_recovery_controller.gd")


class FakeWorldSettings:
	extends RefCounted
	var sea_level: float = 0.0
	var chunk_size: float = 64.0


class FakeSurfaceWorld:
	extends RefCounted
	var spawn_results: Array[Vector3] = []
	var heights: Array[float] = []
	var preferred_calls: Array[Vector3] = []
	var generated: Array[Vector3] = []

	func find_spawn_xz(preferred: Vector3) -> Vector3:
		preferred_calls.append(preferred)
		if spawn_results.is_empty():
			return preferred
		return spawn_results.pop_front()

	func get_height_at_world(_x: float, _z: float) -> float:
		if heights.is_empty():
			return 8.0
		return heights.pop_front()

	func generate_initial(position: Vector3) -> void:
		generated.append(position)


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_player_defeat_and_commit(tree, failures)
	_test_fall_uses_same_defeat_seam(tree, failures)
	_test_surface_recovery_policy(tree, failures)
	return failures


static func _test_player_defeat_and_commit(tree: SceneTree, failures: Array[String]) -> void:
	var player = _spawn_player(tree, failures)
	if player == null:
		return
	var actions = player.get("action_controller")
	var buffer = player.get("input_buffer")
	var defeat_reasons: Array[StringName] = []
	var attacks: Array = []
	var harvests: Array = []
	var hotbars: Array = []
	var crafts: Array = []
	player.defeat_requested.connect(func(reason: StringName) -> void: defeat_reasons.append(reason))
	player.attack_requested.connect(func(execution: Dictionary) -> void: attacks.append(execution))
	player.harvest_requested.connect(func(_o: Vector3, _d: Vector3, _r: float) -> void: harvests.append(true))
	player.hotbar_slot_requested.connect(func(slot: int) -> void: hotbars.append(slot))
	player.craft_requested.connect(func(recipe_id: String) -> void: crafts.append(recipe_id))

	player.global_position = Vector3(12.0, 7.0, -9.0)
	var before_position: Vector3 = player.global_position
	_expect_true(failures, "death fixture starts committed action", bool(actions.try_start_tool_action(0.4)))
	_expect_true(failures, "death fixture seeds buffered action", bool(player.call("_queue_buffered_action", &"attack", {"sentinel": true}, 0.2)))
	player.set("pending_attack_definition", {"sentinel": true})
	player.set("pending_attack_direction", Vector3.FORWARD)
	player.set("velocity", Vector3(4.0, -3.0, 2.0))
	player.call("_apply_damage", 999, before_position + Vector3.RIGHT)

	_expect_true(failures, "lethal damage enters defeated state", bool(player.call("is_defeated")))
	_expect_equal(failures, "lethal damage records semantic reason", player.call("get_defeat_reason"), &"damage")
	_expect_equal(failures, "lethal damage emits one defeat request", defeat_reasons, [&"damage"])
	_expect_vector_close(failures, "lethal damage does not teleport Player", player.global_position, before_position)
	_expect_vector_close(failures, "defeat disables body velocity", player.get("velocity"), Vector3.ZERO)
	_expect_equal(failures, "defeat does not reset action before commit", String(actions.state_name()), "USING_TOOL")
	_expect_equal(failures, "defeat does not reset buffer before commit", String(buffer.peek_action()), "attack")

	player.call("_request_attack")
	player.call("_request_harvest")
	_expect_true(failures, "defeated Player rejects dodge", not bool(player.call("_start_dodge", Vector3.RIGHT)))
	_expect_true(failures, "defeated Player rejects parry", not bool(player.call("_start_parry")))
	_expect_true(failures, "defeated Player rejects tool action", not bool(player.call("_begin_tool_action")))
	var hotbar_event := InputEventKey.new()
	hotbar_event.pressed = true
	hotbar_event.physical_keycode = KEY_1
	player.call("_unhandled_input", hotbar_event)
	var craft_event := InputEventKey.new()
	craft_event.pressed = true
	craft_event.physical_keycode = KEY_C
	player.call("_unhandled_input", craft_event)
	_expect_true(failures, "defeated Player emits no attacks", attacks.is_empty())
	_expect_true(failures, "defeated Player emits no harvest", harvests.is_empty())
	_expect_true(failures, "defeated Player emits no hotbar selection", hotbars.is_empty())
	_expect_true(failures, "defeated Player emits no craft request", crafts.is_empty())
	_expect_equal(
		failures,
		"additional melee while defeated is ignored",
		player.call("receive_melee_attack", 20, before_position + Vector3.FORWARD, true),
		&"ignored"
	)
	_expect_true(failures, "repeated damage defeat is idempotent", not bool(player.call("_enter_defeated", &"damage")))
	_expect_true(failures, "repeated fall defeat is idempotent", not bool(player.call("_enter_defeated", &"fall")))
	_expect_equal(failures, "repeated defeat emits no duplicate request", defeat_reasons.size(), 1)

	_expect_true(
		failures,
		"non-finite respawn target fails closed",
		not bool(player.call("commit_respawn", Vector3(NAN, 4.0, 5.0)))
	)
	_expect_true(failures, "invalid respawn leaves Player defeated", bool(player.call("is_defeated")))

	var target := Vector3(20.0, 11.0, 30.0)
	_expect_true(failures, "validated respawn target commits", bool(player.call("commit_respawn", target)))
	_expect_true(failures, "respawn returns Player alive", not bool(player.call("is_defeated")))
	_expect_equal(failures, "respawn clears semantic defeat reason", player.call("get_defeat_reason"), &"")
	_expect_vector_close(failures, "respawn commits validated target", player.global_position, target)
	_expect_vector_close(failures, "respawn clears velocity", player.get("velocity"), Vector3.ZERO)
	_expect_equal(failures, "respawn restores health", int(player.call("get_health")), int(player.call("get_max_health")))
	_expect_close(failures, "respawn restores stamina", float(player.call("get_stamina")), float(player.call("get_max_stamina")))
	_expect_equal(failures, "respawn resets action controller", String(player.call("get_action_state_name")), "FREE")
	_expect_equal(failures, "respawn clears input buffer", String(player.call("get_buffered_action_name")), "")
	_expect_true(failures, "respawn clears pending attack definition", player.get("pending_attack_definition") == null)
	_expect_vector_close(failures, "respawn clears pending attack direction", player.get("pending_attack_direction"), Vector3.ZERO)
	_expect_true(failures, "respawn enables bounded invulnerability", float(player.get("damage_invulnerability_timer")) > 0.0)
	_expect_true(failures, "second respawn commit is rejected", not bool(player.call("commit_respawn", target + Vector3.ONE)))

	player.get_parent().free()


static func _test_fall_uses_same_defeat_seam(tree: SceneTree, failures: Array[String]) -> void:
	var player = _spawn_player(tree, failures)
	if player == null:
		return
	var reasons: Array[StringName] = []
	player.defeat_requested.connect(func(reason: StringName) -> void: reasons.append(reason))
	player.global_position = Vector3(3.0, -101.0, 7.0)
	var fallen_position: Vector3 = player.global_position
	player.call("_check_fall_respawn")
	_expect_true(failures, "fall enters same defeated state", bool(player.call("is_defeated")))
	_expect_equal(failures, "fall records semantic reason", player.call("get_defeat_reason"), &"fall")
	_expect_equal(failures, "fall emits one defeat request", reasons, [&"fall"])
	_expect_vector_close(failures, "fall does not self-teleport", player.global_position, fallen_position)
	player.call("_check_fall_respawn")
	_expect_equal(failures, "repeated fall callback is idempotent", reasons.size(), 1)
	player.get_parent().free()


static func _test_surface_recovery_policy(tree: SceneTree, failures: Array[String]) -> void:
	var settings := FakeWorldSettings.new()

	var player = _spawn_player(tree, failures)
	if player == null:
		return
	player.global_position = Vector3(40.0, -20.0, -24.0)
	player.call("_enter_defeated", &"fall")
	var world := FakeSurfaceWorld.new()
	world.spawn_results = [Vector3(48.0, 0.0, -16.0)]
	world.heights = [9.0]
	var controller = DeathRecoveryControllerScript.new()
	var config_failures: Array[String] = controller.configure(player, world, settings)
	_expect_true(failures, "death controller accepts Player/surface authority", config_failures.is_empty())
	_expect_true(failures, "first recovery request is accepted", controller.request_recovery(&"fall"))
	_expect_true(failures, "duplicate recovery request is rejected", not controller.request_recovery(&"fall"))
	var primary: Dictionary = controller.try_commit_recovery()
	_expect_true(failures, "current-XZ recovery succeeds", bool(primary.get("success", false)))
	_expect_true(failures, "current-XZ recovery does not report fallback", not bool(primary.get("fallback_used", true)))
	_expect_vector_close(failures, "current-XZ preference is Player projection", world.preferred_calls[0], Vector3(40.0, 0.0, -24.0))
	_expect_vector_close(failures, "current-XZ recovery applies startup clearance", player.global_position, Vector3(48.0, 12.0, -16.0))
	_expect_equal(failures, "surface target is realized before commit", world.generated.size(), 1)
	player.get_parent().free()
	controller.free()

	var fallback_player = _spawn_player(tree, failures)
	if fallback_player == null:
		return
	fallback_player.global_position = Vector3(100.0, -30.0, 200.0)
	fallback_player.call("_enter_defeated", &"damage")
	var fallback_world := FakeSurfaceWorld.new()
	fallback_world.spawn_results = [Vector3(104.0, 0.0, 200.0), Vector3(32.0, 0.0, 32.0)]
	fallback_world.heights = [NAN, 6.0]
	var fallback_controller = DeathRecoveryControllerScript.new()
	fallback_controller.configure(fallback_player, fallback_world, settings)
	fallback_controller.request_recovery(&"damage")
	var fallback: Dictionary = fallback_controller.try_commit_recovery()
	_expect_true(failures, "invalid primary target uses deterministic fallback", bool(fallback.get("success", false)))
	_expect_true(failures, "fallback result is identified", bool(fallback.get("fallback_used", false)))
	_expect_equal(failures, "fallback performs exactly two surface searches", fallback_world.preferred_calls.size(), 2)
	_expect_vector_close(failures, "fallback preference uses normal initial center", fallback_world.preferred_calls[1], Vector3(32.0, 0.0, 32.0))
	_expect_vector_close(failures, "fallback recovery commits finite target", fallback_player.global_position, Vector3(32.0, 9.0, 32.0))
	fallback_player.get_parent().free()
	fallback_controller.free()

	var failed_player = _spawn_player(tree, failures)
	if failed_player == null:
		return
	failed_player.global_position = Vector3(8.0, -50.0, 8.0)
	failed_player.call("_enter_defeated", &"fall")
	var failed_world := FakeSurfaceWorld.new()
	failed_world.spawn_results = [Vector3(8.0, 0.0, 8.0), Vector3(32.0, 0.0, 32.0)]
	failed_world.heights = [0.5, 1.0]
	var failed_controller = DeathRecoveryControllerScript.new()
	failed_controller.configure(failed_player, failed_world, settings)
	failed_controller.request_recovery(&"fall")
	var failed: Dictionary = failed_controller.try_commit_recovery()
	_expect_true(failures, "invalid primary and fallback fail closed", not bool(failed.get("success", false)))
	_expect_true(failures, "failed recovery leaves Player defeated", bool(failed_player.call("is_defeated")))
	_expect_true(failures, "failed recovery stays pending for explicit retry", failed_controller.is_recovery_pending())
	_expect_equal(failures, "failed recovery never realizes invalid geometry", failed_world.generated.size(), 0)
	failed_player.get_parent().free()
	failed_controller.free()


static func _spawn_player(tree: SceneTree, failures: Array[String]):
	if tree == null or tree.root == null:
		failures.append("death recovery test requires SceneTree root")
		return null
	var fixture_root := Node3D.new()
	tree.root.add_child(fixture_root)
	var player = PlayerScript.new()
	player.set("character_presentation_provider", VoxelProvider.new())
	fixture_root.add_child(player)
	return player


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])


static func _expect_close(failures: Array[String], label: String, actual: float, expected: float) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])


static func _expect_vector_close(failures: Array[String], label: String, actual: Vector3, expected: Vector3) -> void:
	if not actual.is_equal_approx(expected):
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])
