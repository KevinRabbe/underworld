extends RefCounted

const StaminaScript := preload("res://gameplay/player/components/stamina_component.gd")
const ActionControllerScript := preload("res://gameplay/player/actions/player_action_controller.gd")
const AttackCatalogScript := preload("res://gameplay/combat/attacks/player_attack_catalog.gd")
const PlayerScript := preload("res://gameplay/player/player.gd")


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_profiles(failures)
	_test_transition_contract(failures)
	_test_heavy_stamina_gate(failures)
	_test_live_heavy_attack(tree, failures)
	return failures


static func _test_profiles(failures: Array[String]) -> void:
	for tool_id in ["hands", "stone_axe", "stone_pickaxe"]:
		var light = AttackCatalogScript.for_tool(tool_id)
		var heavy = AttackCatalogScript.for_tool(tool_id, &"heavy")
		_expect_equal(failures, "%s defaults to light" % tool_id, light.get("attack_kind"), &"light")
		_expect_equal(failures, "%s exposes heavy profile" % tool_id, heavy.get("attack_kind"), &"heavy")
		_expect_true(failures, "%s heavy has distinct identity" % tool_id, heavy.get("attack_id") != light.get("attack_id"))
		_expect_true(failures, "%s heavy has meaningful guard pressure" % tool_id, float(heavy.get("guard_pressure")) > 0.0)
		_expect_true(failures, "%s heavy is committed" % tool_id, float(heavy.call("total_duration")) > float(light.call("total_duration")))


static func _test_transition_contract(failures: Array[String]) -> void:
	var actions = ActionControllerScript.new(StaminaScript.new())
	var policy: Dictionary = actions.transition_policy()
	_expect_true(failures, "attack is explicitly bufferable", actions.can_queue_action(&"attack"))
	_expect_true(failures, "dodge is explicitly bufferable", actions.can_queue_action(&"dodge"))
	_expect_true(failures, "active actions are not interruptible", not actions.can_interrupt_action(&"attack"))
	_expect_equal(failures, "transition policy buffer lifetime", float(policy.get("buffer_lifetime")), 0.16)


static func _test_heavy_stamina_gate(failures: Array[String]) -> void:
	var stamina = StaminaScript.new(10.0, 0.0, 0.0)
	var actions = ActionControllerScript.new(stamina)
	_expect_true(
		failures,
		"heavy attack rejects insufficient stamina without entering state",
		not actions.try_start_attack_profile(0.2, 0.1, 0.3, &"heavy", ActionControllerScript.HEAVY_ATTACK_COST)
	)
	_expect_true(failures, "failed heavy attack leaves controller free", actions.is_free())
	_expect_equal(failures, "failed heavy attack does not drain stamina", float(stamina.current_stamina), 10.0)
	stamina.current_stamina = 20.0
	_expect_true(
		failures,
		"heavy attack starts when stamina is available",
		actions.try_start_attack_profile(0.2, 0.1, 0.3, &"heavy", ActionControllerScript.HEAVY_ATTACK_COST)
	)
	_expect_equal(failures, "heavy attack records kind", actions.get_attack_kind(), &"heavy")
	_expect_equal(failures, "heavy attack spends stamina once", float(stamina.current_stamina), 8.0)


static func _test_live_heavy_attack(tree: SceneTree, failures: Array[String]) -> void:
	if tree == null or tree.root == null:
		failures.append("heavy attack integration requires SceneTree root")
		return
	var root := Node3D.new()
	tree.root.add_child(root)
	var player: Node = PlayerScript.new()
	root.add_child(player)
	player.call("set_equipped_tool", "stone_axe")
	var captured: Array[Dictionary] = []
	player.connect("attack_requested", func(execution: Dictionary) -> void: captured.append(execution.duplicate(true)))
	player.call("_request_attack", true)
	var actions = player.get("action_controller")
	_expect_equal(failures, "heavy input enters startup", String(actions.call("state_name")), "ATTACKING/STARTUP")
	_expect_equal(failures, "heavy input commits heavy kind", actions.call("get_attack_kind"), &"heavy")
	actions.call("tick", 0.25)
	player.call("_resolve_pending_attack_activation")
	_expect_equal(failures, "heavy emits one activation", captured.size(), 1)
	if captured.size() == 1:
		_expect_equal(failures, "heavy execution preserves id", captured[0].get("attack_id"), &"stone_axe_heavy")
		_expect_equal(failures, "heavy execution preserves kind", captured[0].get("attack_kind"), &"heavy")
	root.free()


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])
