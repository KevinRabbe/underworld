extends RefCounted

const InputBufferScript := preload("res://gameplay/player/input/player_input_buffer.gd")
const PlayerScript := preload("res://gameplay/player/player.gd")
const VoxelProvider := preload("res://presentation/characters/voxel/voxel_character_presentation_provider.gd")


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_buffer_component(failures)
	_test_live_attack_buffer(tree, failures)
	_test_live_priority_and_expiry(tree, failures)
	return failures


static func _test_buffer_component(failures: Array[String]) -> void:
	var buffer = InputBufferScript.new()
	_expect_true(failures, "empty input buffer starts clear", not buffer.has_pending())
	_expect_true(failures, "blank action is rejected", not buffer.push(&""))
	_expect_true(failures, "non-positive lifetime is rejected", not buffer.push(&"attack", {}, 0.0))

	var original_payload: Dictionary = {
		"direction": Vector3.RIGHT,
		"nested": {"value": 3},
	}
	_expect_true(
		failures,
		"valid input enters one-slot buffer",
		buffer.push(&"dodge", original_payload, 0.12)
	)
	original_payload["nested"]["value"] = 99
	_expect_equal(failures, "buffer exposes pending action", buffer.peek_action(), &"dodge")
	buffer.tick(0.119)
	_expect_true(failures, "input survives inside lifetime", buffer.has_pending())
	var consumed: Dictionary = buffer.consume()
	_expect_equal(failures, "consume returns buffered action", consumed.get("action"), &"dodge")
	var consumed_payload: Dictionary = consumed.get("payload", {})
	var nested: Dictionary = consumed_payload.get("nested", {})
	_expect_equal(failures, "payload is snapshotted deeply", int(nested.get("value", 0)), 3)
	_expect_true(failures, "consume is one-shot", not buffer.has_pending())
	_expect_true(failures, "second consume is empty", buffer.consume().is_empty())

	buffer.push(&"attack", {"sequence": 1}, 0.12)
	buffer.push(&"parry", {"sequence": 2}, 0.12)
	_expect_equal(failures, "newest input replaces older slot", buffer.peek_action(), &"parry")
	var replacement: Dictionary = buffer.consume()
	_expect_equal(
		failures,
		"replacement keeps newest payload",
		int(Dictionary(replacement.get("payload", {})).get("sequence", 0)),
		2
	)

	buffer.push(&"dodge", {}, 0.12)
	buffer.tick(0.121)
	_expect_true(failures, "expired input is discarded", not buffer.has_pending())

	buffer.push(&"attack", {}, 0.12)
	buffer.reset()
	_expect_true(failures, "hard reset clears input buffer", not buffer.has_pending())


static func _test_live_attack_buffer(tree: SceneTree, failures: Array[String]) -> void:
	if tree == null or tree.root == null:
		failures.append("live input-buffer test requires SceneTree root")
		return

	var fixture_root := Node3D.new()
	tree.root.add_child(fixture_root)
	var player: Node = PlayerScript.new()
	player.set("character_presentation_provider", VoxelProvider.new())
	fixture_root.add_child(player)
	player.call("set_equipped_tool", "stone_axe")

	var captured: Array[Dictionary] = []
	player.connect(
		"attack_requested",
		func(execution: Dictionary) -> void:
			captured.append(execution.duplicate(true))
	)

	var actions = player.get("action_controller")
	var buffer = player.get("input_buffer")
	_expect_true(
		failures,
		"fixture commitment starts",
		bool(actions.call("try_start_tool_action", 0.10))
	)
	var expected_direction: Vector3 = player.call("_get_combat_forward")
	player.call("_request_attack")
	_expect_equal(
		failures,
		"busy attack input enters buffer",
		String(player.call("get_buffered_action_name")),
		"attack"
	)
	_expect_equal(failures, "buffered attack does not start immediately", String(actions.call("state_name")), "USING_TOOL")
	_expect_equal(failures, "buffered attack emits nothing immediately", captured.size(), 0)

	# Buffered attack intent is immutable: facing is snapshotted when input is
	# accepted. A later camera change must not silently rewrite the request.
	var camera_yaw = player.get("camera_yaw")
	camera_yaw.set("rotation", Vector3(0.0, 0.45, 0.0))
	var changed_live_direction: Vector3 = player.call("_get_combat_forward")
	_expect_true(failures, "camera rotation changes live facing for snapshot proof", not changed_live_direction.is_equal_approx(expected_direction))

	actions.call("tick", 0.05)
	buffer.call("tick", 0.05)
	player.call("_try_consume_buffered_action")
	_expect_equal(failures, "buffer waits while commitment remains active", String(actions.call("state_name")), "USING_TOOL")
	_expect_equal(failures, "buffer remains alive before expiry", String(player.call("get_buffered_action_name")), "attack")

	actions.call("tick", 0.051)
	buffer.call("tick", 0.051)
	player.call("_try_consume_buffered_action")
	_expect_equal(
		failures,
		"buffered attack starts when controller becomes free",
		String(actions.call("state_name")),
		"ATTACKING/STARTUP"
	)
	_expect_equal(failures, "buffer slot clears after consumption", String(player.call("get_buffered_action_name")), "")
	_expect_vector_close(
		failures,
		"buffered attack preserves input-time facing",
		player.get("pending_attack_direction"),
		expected_direction
	)

	actions.call("tick", 0.15)
	player.call("_resolve_pending_attack_activation")
	_expect_equal(failures, "buffered attack emits once at active boundary", captured.size(), 1)
	if captured.size() == 1:
		_expect_equal(
			failures,
			"buffered attack preserves input-time weapon",
			captured[0].get("attack_id"),
			&"stone_axe_light"
		)

	# Respawn/reset is a hard boundary: buffered input must never leak through it.
	actions.call("reset")
	player.call("set_equipped_tool", "stone_axe")
	_expect_true(
		failures,
		"second fixture commitment starts",
		bool(actions.call("try_start_tool_action", 0.20))
	)
	player.call("_request_attack")
	_expect_equal(failures, "pre-reset buffer exists", String(player.call("get_buffered_action_name")), "attack")
	player.call("_respawn_after_defeat")
	_expect_equal(failures, "respawn clears buffered intent", String(player.call("get_buffered_action_name")), "")
	_expect_true(failures, "respawn returns action controller to free", bool(actions.call("is_free")))

	fixture_root.free()


static func _test_live_priority_and_expiry(tree: SceneTree, failures: Array[String]) -> void:
	if tree == null or tree.root == null:
		failures.append("live priority/expiry test requires SceneTree root")
		return
	var fixture_root := Node3D.new()
	tree.root.add_child(fixture_root)
	var player: Node = PlayerScript.new()
	fixture_root.add_child(player)
	var actions = player.get("action_controller")
	var buffer = player.get("input_buffer")

	_expect_true(failures, "priority fixture commitment starts", actions.try_start_tool_action(0.20))
	_expect_true(failures, "attack enters empty player buffer", player.call("_queue_buffered_action", &"attack", {"attack_kind": &"light"}, 0.16))
	_expect_true(failures, "parry replaces lower-priority attack", player.call("_queue_buffered_action", &"parry"))
	_expect_equal(failures, "parry is pending after priority replacement", buffer.peek_action(), &"parry")
	_expect_true(failures, "attack cannot replace buffered parry", not player.call("_queue_buffered_action", &"attack", {"attack_kind": &"heavy"}, 0.16))
	_expect_equal(failures, "failed lower-priority replacement preserves parry", buffer.peek_action(), &"parry")
	_expect_true(failures, "dodge replaces buffered parry", player.call("_queue_buffered_action", &"dodge", {"direction": Vector3.FORWARD}))
	_expect_true(failures, "parry cannot replace buffered dodge", not player.call("_queue_buffered_action", &"parry"))
	_expect_true(failures, "attack cannot replace buffered dodge", not player.call("_queue_buffered_action", &"attack"))
	_expect_equal(failures, "highest-priority dodge remains pending", buffer.peek_action(), &"dodge")

	for attack_kind in [&"light", &"heavy"]:
		actions.reset()
		buffer.reset()
		_expect_true(failures, "%s expiry fixture commitment starts" % attack_kind, actions.try_start_tool_action(0.05))
		player.call("_request_attack", attack_kind == &"heavy")
		_expect_equal(failures, "%s intent is initially buffered" % attack_kind, buffer.peek_action(), &"attack")
		buffer.tick(0.161)
		actions.tick(0.051)
		player.call("_try_consume_buffered_action")
		_expect_true(failures, "%s intent expires before becoming legal" % attack_kind, not buffer.has_pending())
		_expect_true(failures, "%s expired intent never fires late" % attack_kind, actions.is_free())

	# A heavy intent submitted near the end of commitment remains legal and fires once.
	actions.reset()
	buffer.reset()
	_expect_true(failures, "late-heavy fixture commitment starts", actions.try_start_tool_action(0.10))
	actions.tick(0.08)
	player.call("_request_attack", true)
	buffer.tick(0.019)
	player.call("_try_consume_buffered_action")
	_expect_equal(failures, "late heavy waits until commitment ends", actions.state_name(), "USING_TOOL")
	actions.tick(0.021)
	buffer.tick(0.021)
	player.call("_try_consume_buffered_action")
	_expect_equal(failures, "late legal heavy executes after commitment", actions.state_name(), "ATTACKING/STARTUP")
	_expect_equal(failures, "late heavy buffer is consumed once", buffer.peek_action(), &"")

	fixture_root.free()


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(
	failures: Array[String],
	label: String,
	actual: Variant,
	expected: Variant
) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])


static func _expect_vector_close(
	failures: Array[String],
	label: String,
	actual: Vector3,
	expected: Vector3
) -> void:
	if not actual.is_equal_approx(expected):
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])
