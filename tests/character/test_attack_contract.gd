extends RefCounted

const StaminaScript := preload("res://gameplay/player/components/stamina_component.gd")
const ActionControllerScript := preload("res://gameplay/player/actions/player_action_controller.gd")
const AttackCatalogScript := preload("res://gameplay/combat/attacks/player_attack_catalog.gd")
const CombatResolverScript := preload("res://gameplay/combat/resolution/combat_resolver.gd")
const PlayerScript := preload("res://gameplay/player/player.gd")


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_attack_catalog(failures)
	_test_attack_phase_controller(failures)
	_test_attack_phase_edge_cases(failures)
	_test_live_player_activation(tree, failures)
	return failures


static func _test_attack_catalog(failures: Array[String]) -> void:
	var hands = AttackCatalogScript.for_tool("hands")
	var axe = AttackCatalogScript.for_tool("stone_axe")
	var pickaxe = AttackCatalogScript.for_tool("stone_pickaxe")
	_expect_true(failures, "hands attack definition is valid", bool(hands.call("is_valid")))
	_expect_true(failures, "axe attack definition is valid", bool(axe.call("is_valid")))
	_expect_true(failures, "pickaxe attack definition is valid", bool(pickaxe.call("is_valid")))
	_expect_equal(failures, "hands damage contract", int(hands.get("damage")), 7)
	_expect_equal(failures, "axe damage contract", int(axe.get("damage")), 16)
	_expect_equal(failures, "pickaxe damage contract", int(pickaxe.get("damage")), 13)
	_expect_true(
		failures,
		"prototype attack profiles can vary timing",
		not is_equal_approx(float(hands.call("total_duration")), float(pickaxe.call("total_duration")))
	)

	var execution: Dictionary = axe.call(
		"make_execution",
		Vector3(3.0, 4.0, 5.0),
		Vector3(0.0, 8.0, -4.0)
	)
	_expect_equal(failures, "execution captures attack id", execution.get("attack_id"), &"stone_axe_light")
	_expect_equal(failures, "execution captures damage", int(execution.get("damage", 0)), 16)
	_expect_vector_close(
		failures,
		"execution stores normalized horizontal direction",
		execution.get("direction", Vector3.ZERO),
		Vector3(0.0, 0.0, -1.0)
	)


static func _test_attack_phase_controller(failures: Array[String]) -> void:
	var stamina = StaminaScript.new()
	var actions = ActionControllerScript.new(stamina)
	_expect_true(failures, "phased attack starts", actions.try_start_attack(0.10, 0.05, 0.20))
	_expect_equal(failures, "attack begins in startup", actions.get_attack_phase_name(), "STARTUP")
	_expect_true(failures, "startup emits no early activation", not actions.consume_attack_activation())
	_expect_true(
		failures,
		"attack commitment rejects dodge",
		not actions.try_start_dodge(Vector3.RIGHT)
	)
	_expect_true(failures, "attack commitment rejects parry", not actions.try_start_parry())
	_expect_true(failures, "attack commitment rejects block", not actions.try_start_block())
	_expect_true(failures, "attack commitment rejects tool use", not actions.try_start_tool_action(0.2))

	actions.tick(0.099)
	_expect_equal(failures, "attack remains startup before boundary", actions.get_attack_phase_name(), "STARTUP")
	_expect_true(failures, "activation still closed before startup ends", not actions.consume_attack_activation())
	actions.tick(0.002)
	_expect_equal(failures, "attack enters active phase", actions.get_attack_phase_name(), "ACTIVE")
	_expect_true(failures, "active boundary emits exactly once", actions.consume_attack_activation())
	_expect_true(failures, "activation cannot be consumed twice", not actions.consume_attack_activation())
	actions.tick(0.050)
	_expect_equal(failures, "attack enters recovery", actions.get_attack_phase_name(), "RECOVERY")
	actions.tick(0.200)
	_expect_true(failures, "attack returns to free after recovery", actions.is_free())
	_expect_true(failures, "finished attack has no extra activation", not actions.consume_attack_activation())


static func _test_attack_phase_edge_cases(failures: Array[String]) -> void:
	var stamina = StaminaScript.new()
	var actions = ActionControllerScript.new(stamina)

	# A hitch/large frame may cross startup, active and recovery at once. The
	# attack still owes exactly one activation even though the state is already free.
	_expect_true(failures, "large-frame attack starts", actions.try_start_attack(0.10, 0.05, 0.20))
	actions.tick(0.50)
	_expect_true(failures, "large-frame attack can finish in one tick", actions.is_free())
	_expect_true(
		failures,
		"large-frame crossing preserves one activation",
		actions.consume_attack_activation()
	)
	_expect_true(
		failures,
		"large-frame activation remains one-shot",
		not actions.consume_attack_activation()
	)

	# A hard reset (respawn/defeat) cancels all pending combat work.
	_expect_true(failures, "reset-edge attack starts", actions.try_start_attack(0.10, 0.05, 0.20))
	actions.tick(0.12)
	actions.reset()
	_expect_true(failures, "reset returns attack controller to free", actions.is_free())
	_expect_true(
		failures,
		"reset discards pending attack activation",
		not actions.consume_attack_activation()
	)


static func _test_live_player_activation(tree: SceneTree, failures: Array[String]) -> void:
	if tree == null or tree.root == null:
		failures.append("attack integration test requires SceneTree root")
		return

	var fixture_root := Node3D.new()
	tree.root.add_child(fixture_root)
	var player: Node = PlayerScript.new()
	fixture_root.add_child(player)
	player.call("set_equipped_tool", "stone_axe")

	var captured: Array[Dictionary] = []
	player.connect(
		"attack_requested",
		func(execution: Dictionary) -> void:
			captured.append(execution.duplicate(true))
	)

	player.call("_request_attack")
	_expect_equal(
		failures,
		"live RMB enters attack startup",
		String(player.call("get_action_state_name")),
		"ATTACKING/STARTUP"
	)
	_expect_equal(failures, "live attack does not resolve on input frame", captured.size(), 0)

	# Changing equipment after commitment must not mutate the already captured
	# attack definition; the active frame still resolves the axe attack.
	player.call("set_equipped_tool", "stone_pickaxe")
	var actions = player.get("action_controller")
	actions.call("tick", 0.11)
	player.call("_resolve_pending_attack_activation")
	_expect_equal(failures, "live attack remains silent during startup", captured.size(), 0)
	actions.call("tick", 0.02)
	player.call("_resolve_pending_attack_activation")
	_expect_equal(failures, "live attack emits once on active boundary", captured.size(), 1)
	if captured.size() == 1:
		_expect_equal(
			failures,
			"committed attack keeps original axe id",
			captured[0].get("attack_id"),
			&"stone_axe_light"
		)
		_expect_equal(
			failures,
			"committed attack keeps original axe damage",
			int(captured[0].get("damage", 0)),
			16
		)

		# Exercise the isolated combat-resolution consumer in a live World3D.
		# No enemy exists in this fixture, so a valid execution should resolve as
		# a clean miss rather than parser/runtime failure.
		var combat_resolver: Node = CombatResolverScript.new()
		fixture_root.add_child(combat_resolver)
		combat_resolver.call("configure", player)
		combat_resolver.call("try_attack", captured[0])
		_expect_equal(
			failures,
			"CombatResolver consumes supplied execution",
			String(combat_resolver.call("get_last_combat_message")),
			"Attack missed"
		)

	actions.call("tick", 0.40)
	player.call("_resolve_pending_attack_activation")
	_expect_true(failures, "live attack finishes after recovery", bool(actions.call("is_free")))
	_expect_equal(failures, "live attack never emits twice", captured.size(), 1)

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
