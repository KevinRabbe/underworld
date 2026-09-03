extends RefCounted

const PlayerScript := preload("res://gameplay/player/player.gd")
const GameplayInputGateScript := preload("res://app/input/gameplay_input_gate.gd")
const VoxelProvider := preload("res://presentation/characters/voxel/voxel_character_presentation_provider.gd")


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	if tree == null or tree.root == null:
		failures.append("player integration test requires SceneTree root")
		return failures

	var fixture_root := Node3D.new()
	tree.root.add_child(fixture_root)

	# Keep player.gd preloaded so the full integration script must compile, but
	# invoke custom members dynamically. Fresh Godot headless imports can otherwise
	# reject statically inferred custom members on a preloaded external script.
	var gameplay_input_gate: Node = GameplayInputGateScript.new()
	fixture_root.add_child(gameplay_input_gate)
	var player: Node = PlayerScript.new()
	player.set("character_presentation_provider", VoxelProvider.new())
	_expect_true(
		failures,
		"player accepts explicit gameplay input gate before entering SceneTree",
		bool(player.call("configure_gameplay_input_gate", gameplay_input_gate))
	)
	fixture_root.add_child(player)
	var mannequin = player.call("get_mannequin")
	_expect_true(
		failures,
		"player builds articulated mannequin",
		mannequin != null and bool(mannequin.call("has_required_rig"))
	)
	_expect_close(
		failures,
		"player starts with full stamina",
		float(player.call("get_stamina")),
		100.0
	)

	var actions = player.get("action_controller")
	var stamina = player.get("stamina")
	_expect_true(failures, "player exposes action controller", actions != null)
	_expect_true(failures, "player exposes stamina component", stamina != null)
	if actions == null or stamina == null:
		fixture_root.free()
		return failures

	# The real Player/provider/controller chain must share one local -Z forward convention.
	var directional_controller = player.get("animation_controller")
	var directional_presentation = player.call("get_mannequin")
	_expect_true(failures, "real Player exposes configured animation controller", directional_controller != null)
	if directional_controller != null and directional_presentation != null:
		_expect_true(
			failures,
			"real Player controller accepts local -Z forward locomotion",
			bool(directional_controller.call("update_locomotion", 1.0 / 60.0, Vector3(0.0, 0.0, -4.0), 0.0, true, false))
		)
		_expect_equal(
			failures,
			"real Player local -Z resolves semantic walk-forward",
			String(directional_controller.call("last_locomotion_role")),
			"animation_role.locomotion.walk_forward"
		)
		var directional_tree = directional_presentation.get("animation_tree")
		_expect_true(
			failures,
			"voxel adapter receives -Z forward blend",
			directional_tree != null and Vector2(directional_tree.get("parameters/locomotion/blend_position")).is_equal_approx(Vector2(0.0, -1.0))
		)
		directional_controller.call("update_locomotion", 1.0 / 60.0, Vector3(0.0, 0.0, 4.0), 0.0, true, false)
		_expect_equal(
			failures,
			"real Player local +Z resolves semantic walk-backward",
			String(directional_controller.call("last_locomotion_role")),
			"animation_role.locomotion.walk_backward"
		)
		_expect_true(
			failures,
			"voxel adapter receives +Z backward blend",
			Vector2(directional_tree.get("parameters/locomotion/blend_position")).is_equal_approx(Vector2(0.0, 1.0))
		)
		actions.call("reset")
		stamina.call("reset")
		player.get("visual_root").set("rotation", Vector3.ZERO)
		_expect_true(failures, "real Player forward dodge starts", bool(player.call("_start_dodge", Vector3.FORWARD)))
		_expect_equal(
			failures,
			"real Player forward dodge resolves semantic forward role",
			String(directional_controller.call("last_animation_role")),
			"animation_role.action.dodge.forward"
		)
		_expect_equal(
			failures,
			"real Player forward dodge reaches voxel forward presentation",
			String(directional_presentation.get("current_animation_state")),
			"dodge_forward"
		)
		actions.call("reset")
		stamina.call("reset")
		directional_presentation.call("reset_pose")

	# Combat actions establish a camera-facing direction. Directional defense then
	# resolves against that visual forward rather than a fixed world axis.
	var visual_root: Node3D = player.get("visual_root")
	var camera_yaw: Node3D = player.get("camera_yaw")
	player.call("_face_combat_camera")
	var camera_forward: Vector3 = -camera_yaw.global_transform.basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var combat_forward: Vector3 = -visual_root.global_transform.basis.z
	combat_forward.y = 0.0
	combat_forward = combat_forward.normalized()
	_expect_true(
		failures,
		"combat facing aligns mannequin forward to camera forward",
		combat_forward.dot(camera_forward) > 0.999
	)

	var player_position: Vector3 = player.get("global_position")
	var front_source: Vector3 = player_position + combat_forward
	var rear_source: Vector3 = player_position - combat_forward

	# Parry resolution must preserve health while the timed active window is open
	# and the melee source is inside the frontal parry arc.
	_expect_true(
		failures,
		"player parry action starts",
		bool(actions.call("try_start_parry"))
	)
	actions.call("tick", 0.07)
	var health_before: int = int(player.call("get_health"))
	var parry_result: StringName = player.call(
		"receive_melee_attack",
		10,
		front_source,
		true
	)
	_expect_equal(failures, "frontal active parry resolves as parried", parry_result, &"parried")
	_expect_equal(
		failures,
		"parry prevents health loss",
		int(player.call("get_health")),
		health_before
	)

	# Parry is not a 360-degree immunity field. The same active window does not
	# protect an attack coming from behind.
	actions.call("reset")
	stamina.call("reset")
	player.set("damage_invulnerability_timer", 0.0)
	_expect_true(failures, "rear-parry fixture starts parry", bool(actions.call("try_start_parry")))
	actions.call("tick", 0.07)
	var rear_parry_health: int = int(player.call("get_health"))
	var rear_parry_result: StringName = player.call(
		"receive_melee_attack",
		10,
		rear_source,
		true
	)
	_expect_equal(failures, "rear melee bypasses active parry", rear_parry_result, &"hit")
	_expect_equal(
		failures,
		"rear melee damages parrying player",
		int(player.call("get_health")),
		rear_parry_health - 10
	)

	# Dodge iframe path is distinct from directional defenses and remains valid
	# independent of attack direction.
	actions.call("reset")
	stamina.call("reset")
	player.set("damage_invulnerability_timer", 0.0)
	_expect_true(
		failures,
		"player dodge action starts",
		bool(actions.call("try_start_dodge", Vector3(1.0, 0.0, 0.0)))
	)
	actions.call("tick", 0.10)
	var dodge_health_before: int = int(player.call("get_health"))
	var dodge_result: StringName = player.call(
		"receive_melee_attack",
		10,
		rear_source,
		true
	)
	_expect_equal(failures, "active dodge iframe resolves as dodged", dodge_result, &"dodged")
	_expect_equal(
		failures,
		"dodge iframe prevents health loss",
		int(player.call("get_health")),
		dodge_health_before
	)

	# Held block protects only the front arc, pays stamina on impact, and propagates
	# to the visual mannequin without allowing locomotion to rotate the guard cone.
	actions.call("reset")
	stamina.call("reset")
	player.set("damage_invulnerability_timer", 0.0)
	_expect_true(failures, "player block starts", bool(actions.call("try_start_block")))
	player.call("_update_mannequin", 1.0 / 60.0)
	_expect_true(
		failures,
		"player block state reaches mannequin guard pose",
		bool(mannequin.call("is_block_pose_active"))
	)
	var guard_yaw: float = visual_root.rotation.y
	player.set("velocity", Vector3(4.0, 0.0, 0.0))
	player.call("_update_visual_facing", 1.0)
	_expect_close(
		failures,
		"held guard preserves facing while strafing",
		visual_root.rotation.y,
		guard_yaw
	)
	player.set("velocity", Vector3.ZERO)

	var block_health_before: int = int(player.call("get_health"))
	var block_result: StringName = player.call(
		"receive_melee_attack",
		10,
		front_source,
		true
	)
	_expect_equal(failures, "front melee resolves as blocked", block_result, &"blocked")
	_expect_equal(
		failures,
		"successful block prevents health loss",
		int(player.call("get_health")),
		block_health_before
	)
	_expect_close(failures, "10-damage block spends configured stamina", float(player.call("get_stamina")), 82.5)

	# The same held guard does not protect the rear hemisphere.
	player.set("damage_invulnerability_timer", 0.0)
	var rear_health_before: int = int(player.call("get_health"))
	var rear_result: StringName = player.call(
		"receive_melee_attack",
		10,
		rear_source,
		true
	)
	_expect_equal(failures, "rear melee bypasses block", rear_result, &"hit")
	_expect_equal(
		failures,
		"rear melee damages blocking player",
		int(player.call("get_health")),
		rear_health_before - 10
	)

	# Insufficient impact stamina breaks guard, drains the remainder, and the hit
	# continues through the normal damage path.
	actions.call("reset")
	stamina.call("reset")
	stamina.set("current_stamina", 4.0)
	player.set("damage_invulnerability_timer", 0.0)
	_expect_true(failures, "low-stamina player can raise guard", bool(actions.call("try_start_block")))
	var break_health_before: int = int(player.call("get_health"))
	var break_result: StringName = player.call(
		"receive_melee_attack",
		10,
		front_source,
		true
	)
	_expect_equal(failures, "unaffordable block resolves attack as hit", break_result, &"hit")
	_expect_equal(
		failures,
		"guard-break hit reduces health",
		int(player.call("get_health")),
		break_health_before - 10
	)
	_expect_true(failures, "guard break exits blocking state", not bool(actions.call("is_blocking")))
	_expect_close(failures, "guard break drains remaining stamina", float(player.call("get_stamina")), 0.0)
	player.call("_update_mannequin", 1.0 / 60.0)
	_expect_true(
		failures,
		"guard break clears mannequin guard pose",
		not bool(mannequin.call("is_block_pose_active"))
	)

	# Normal melee outside defensive windows still uses the existing damage path.
	actions.call("reset")
	stamina.call("reset")
	player.set("damage_invulnerability_timer", 0.0)
	var normal_health_before: int = int(player.call("get_health"))
	var hit_result: StringName = player.call(
		"receive_melee_attack",
		10,
		front_source,
		true
	)
	_expect_equal(failures, "undefended melee resolves as hit", hit_result, &"hit")
	_expect_equal(
		failures,
		"undefended melee reduces health",
		int(player.call("get_health")),
		normal_health_before - 10
	)

	# Accepted LMB/RMB-style swings now own a short committed action state instead
	# of existing only as a visual/cooldown side effect.
	actions.call("reset")
	stamina.call("reset")
	player.set("tool_use_cooldown_timer", 0.0)
	visual_root.rotation.y = 0.0
	_expect_true(failures, "live player tool action starts", bool(player.call("_begin_tool_action")))
	var attack_forward: Vector3 = -visual_root.global_transform.basis.z
	attack_forward.y = 0.0
	attack_forward = attack_forward.normalized()
	_expect_true(
		failures,
		"tool action establishes camera-facing combat direction",
		attack_forward.dot(camera_forward) > 0.999
	)
	_expect_equal(
		failures,
		"live player exposes USING_TOOL state",
		String(player.call("get_action_state_name")),
		"USING_TOOL"
	)
	_expect_true(
		failures,
		"live tool commitment rejects dodge",
		not bool(actions.call("try_start_dodge", Vector3.RIGHT))
	)
	_expect_true(failures, "live tool commitment rejects parry", not bool(actions.call("try_start_parry")))
	_expect_true(failures, "live tool commitment rejects block", not bool(actions.call("try_start_block")))
	_expect_close(failures, "tool commitment itself costs no stamina", float(player.call("get_stamina")), 100.0)
	actions.call("tick", 0.20)
	player.call("_update_tool_use_feedback", 0.20)
	_expect_true(failures, "live tool action remains committed mid-swing", bool(actions.call("is_using_tool")))
	actions.call("tick", 0.18)
	player.call("_update_tool_use_feedback", 0.18)
	_expect_true(failures, "live tool action ends with existing cooldown", bool(actions.call("is_free")))
	_expect_close(
		failures,
		"tool cooldown and commitment finish together",
		float(player.get("tool_use_cooldown_timer")),
		0.0
	)

	# Interactive UI capture is tokenized and suppresses both event-driven and
	# frame-polled Player intent without becoming a second pause/simulation gate.
	actions.call("reset")
	stamina.call("reset")
	player.set("velocity", Vector3.ZERO)
	player.set("jump_buffer_timer", 0.08)
	var input_buffer = player.get("input_buffer")
	_expect_true(
		failures,
		"input-gate fixture can seed one uncommitted buffered action",
		input_buffer != null and bool(input_buffer.call("push", &"parry", {}, 0.12))
	)
	var hotbar_requests: Array[int] = []
	player.hotbar_slot_requested.connect(func(slot: int) -> void: hotbar_requests.append(slot))

	var inventory_token: int = int(gameplay_input_gate.call("acquire", &"inventory"))
	var modal_token: int = int(gameplay_input_gate.call("acquire", &"modal"))
	_expect_true(failures, "nested UI captures allocate distinct positive tokens", inventory_token > 0 and modal_token > 0 and inventory_token != modal_token)
	_expect_equal(failures, "nested UI captures remain independently owned", int(gameplay_input_gate.call("active_capture_count")), 2)
	_expect_true(failures, "captured UI suppresses Player input", not bool(player.call("gameplay_input_enabled")))
	player.call("_sync_input_suppression")
	_expect_equal(failures, "capture clears uncommitted jump buffer", float(player.get("jump_buffer_timer")), 0.0)
	_expect_true(failures, "capture clears uncommitted action buffer", input_buffer != null and not bool(input_buffer.call("has_pending")))

	var hotbar_event := InputEventAction.new()
	hotbar_event.action = &"hotbar_slot_1"
	hotbar_event.pressed = true
	hotbar_event.strength = 1.0
	player.call("_unhandled_input", hotbar_event)
	_expect_equal(failures, "captured UI blocks event-driven hotbar request", hotbar_requests.size(), 0)

	Input.action_press(&"move_right")
	player.set("velocity", Vector3.ZERO)
	player.call("_update_horizontal_velocity", 0.1)
	_expect_close(failures, "captured UI blocks frame-polled movement", float(player.call("get_horizontal_speed")), 0.0)
	Input.action_release(&"move_right")

	_expect_true(failures, "releasing one nested capture succeeds", bool(gameplay_input_gate.call("release", inventory_token)))
	_expect_equal(failures, "remaining nested capture keeps gate blocked", int(gameplay_input_gate.call("active_capture_count")), 1)
	_expect_true(failures, "one remaining capture still suppresses Player input", not bool(player.call("gameplay_input_enabled")))
	_expect_true(failures, "releasing final nested capture succeeds", bool(gameplay_input_gate.call("release", modal_token)))
	_expect_equal(failures, "final release clears capture ownership", int(gameplay_input_gate.call("active_capture_count")), 0)
	_expect_true(failures, "final release guard prevents same-tick gameplay replay", not bool(player.call("gameplay_input_enabled")))
	gameplay_input_gate.call("_physics_process", 0.0)
	_expect_true(failures, "release guard spans one complete physics tick", not bool(player.call("gameplay_input_enabled")))
	gameplay_input_gate.call("_physics_process", 0.0)
	_expect_true(failures, "Player input resumes after bounded release guard", bool(player.call("gameplay_input_enabled")))
	player.call("_unhandled_input", hotbar_event)
	_expect_equal(failures, "same hotbar event reaches Player after release guard", hotbar_requests, [1])

	Input.action_press(&"move_right")
	player.set("velocity", Vector3.ZERO)
	player.call("_update_horizontal_velocity", 0.1)
	_expect_true(failures, "frame-polled movement resumes after capture release", float(player.call("get_horizontal_speed")) > 0.0)
	Input.action_release(&"move_right")
	player.set("velocity", Vector3.ZERO)

	# Capture begins after a committed action starts: it must block new intent but
	# must not cancel the already-authoritative action timeline.
	actions.call("reset")
	player.set("tool_use_cooldown_timer", 0.0)
	_expect_true(failures, "pre-capture committed tool action starts", bool(player.call("_begin_tool_action")))
	var committed_token: int = int(gameplay_input_gate.call("acquire", &"inventory"))
	player.call("_sync_input_suppression")
	_expect_true(failures, "UI capture does not cancel committed tool action", bool(actions.call("is_using_tool")))
	actions.call("tick", 0.40)
	player.call("_update_tool_use_feedback", 0.40)
	_expect_true(failures, "committed action completes normally under UI capture", bool(actions.call("is_free")))
	_expect_true(failures, "committed-action capture releases exactly once", bool(gameplay_input_gate.call("release", committed_token)))
	gameplay_input_gate.call("_physics_process", 0.0)
	gameplay_input_gate.call("_physics_process", 0.0)

	fixture_root.free()
	return failures


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


static func _expect_close(
	failures: Array[String],
	label: String,
	actual: float,
	expected: float
) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s — expected %.4f, got %.4f" % [label, expected, actual])
