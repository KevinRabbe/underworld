extends RefCounted

const StaminaScript := preload("res://gameplay/player/components/stamina_component.gd")
const ActionControllerScript := preload("res://gameplay/player/actions/player_action_controller.gd")
const AttackCatalogScript := preload("res://gameplay/combat/attacks/player_attack_catalog.gd")
const AttackDefinitionScript := preload("res://gameplay/combat/attacks/player_attack_definition.gd")
const WeaponDefinitionScript := preload("res://gameplay/items/weapons/definitions/weapon_definition.gd")
const WeaponAttackSetScript := preload("res://gameplay/items/weapons/definitions/weapon_attack_set_definition.gd")
const WeaponAttackResolverScript := preload("res://gameplay/items/weapons/runtime/weapon_attack_resolver.gd")
const PlayerScript := preload("res://gameplay/player/player.gd")


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_profiles(failures)
	_test_transition_contract(failures)
	_test_heavy_stamina_gate(failures)
	_test_exact_dodge_iframe_boundaries(failures)
	_test_live_heavy_attack(tree, failures)
	_test_semantic_attack_inputs_and_generic_sword(tree, failures)
	return failures


static func _test_profiles(failures: Array[String]) -> void:
	for tool_id in ["hands", "stone_axe", "stone_pickaxe"]:
		var light = AttackCatalogScript.for_tool(tool_id)
		var heavy = AttackCatalogScript.for_tool(tool_id, &"heavy")
		_expect_equal(failures, "%s defaults to light" % tool_id, light.get("attack_kind"), &"light")
		_expect_equal(failures, "%s exposes heavy profile" % tool_id, heavy.get("attack_kind"), &"heavy")
		_expect_true(failures, "%s heavy has distinct identity" % tool_id, heavy.get("attack_id") != light.get("attack_id"))
		_expect_true(failures, "%s heavy owns stamina cost" % tool_id, float(heavy.get("stamina_cost")) > 0.0)
		_expect_true(failures, "%s light remains stamina-free" % tool_id, is_zero_approx(float(light.get("stamina_cost"))))
		_expect_true(failures, "%s profile has no inert guard pressure" % tool_id, not _has_property(heavy, "guard_pressure"))
		_expect_true(failures, "%s heavy is committed" % tool_id, float(heavy.call("total_duration")) > float(light.call("total_duration")))


static func _test_transition_contract(failures: Array[String]) -> void:
	var actions = ActionControllerScript.new(StaminaScript.new())
	var policy: Dictionary = actions.transition_policy()
	_expect_true(failures, "attack is explicitly bufferable", actions.can_queue_action(&"attack"))
	_expect_true(failures, "dodge is explicitly bufferable", actions.can_queue_action(&"dodge"))
	_expect_true(failures, "active actions are not interruptible", not actions.can_interrupt_action(&"attack"))
	_expect_true(failures, "dodge cannot be replaced by parry", not actions.can_replace_buffered_action(&"parry", &"dodge"))
	_expect_true(failures, "dodge cannot be replaced by attack", not actions.can_replace_buffered_action(&"attack", &"dodge"))
	_expect_true(failures, "parry cannot be replaced by attack", not actions.can_replace_buffered_action(&"attack", &"parry"))
	_expect_true(failures, "dodge can replace pending attack", actions.can_replace_buffered_action(&"dodge", &"attack"))
	_expect_true(failures, "parry can replace pending attack", actions.can_replace_buffered_action(&"parry", &"attack"))
	_expect_equal(failures, "transition policy buffer lifetime", float(policy.get("buffer_lifetime")), 0.16)
	_expect_equal(failures, "transition policy exposes enforced priority", policy.get("priority"), [&"dodge", &"parry", &"attack"])

	_expect_true(failures, "attack starts for no-interrupt proof", actions.try_start_attack(0.1, 0.1, 0.2))
	_expect_true(failures, "dodge cannot interrupt active attack", not actions.try_start_dodge(Vector3.FORWARD))
	_expect_true(failures, "parry cannot interrupt active attack", not actions.try_start_parry())
	_expect_equal(failures, "failed interrupts preserve committed attack", actions.state_name(), "ATTACKING/STARTUP")


static func _test_heavy_stamina_gate(failures: Array[String]) -> void:
	var stamina = StaminaScript.new(10.0, 0.0, 0.0)
	var actions = ActionControllerScript.new(stamina)
	var heavy = AttackCatalogScript.for_tool("stone_axe", &"heavy")
	var heavy_cost: float = float(heavy.get("stamina_cost"))
	_expect_true(
		failures,
		"heavy attack rejects insufficient stamina without entering state",
		not actions.try_start_attack_profile(0.2, 0.1, 0.3, &"heavy", heavy_cost)
	)
	_expect_true(failures, "failed heavy attack leaves controller free", actions.is_free())
	_expect_equal(failures, "failed heavy attack does not drain stamina", float(stamina.current_stamina), 10.0)
	stamina.current_stamina = 20.0
	_expect_true(
		failures,
		"heavy attack starts when stamina is available",
		actions.try_start_attack_profile(0.2, 0.1, 0.3, &"heavy", heavy_cost)
	)
	_expect_equal(failures, "heavy attack records kind", actions.get_attack_kind(), &"heavy")
	_expect_equal(failures, "heavy attack spends definition-owned stamina once", float(stamina.current_stamina), 20.0 - heavy_cost)


static func _test_exact_dodge_iframe_boundaries(failures: Array[String]) -> void:
	var actions = ActionControllerScript.new(StaminaScript.new())
	_expect_true(failures, "dodge starts for iframe-start proof", actions.try_start_dodge(Vector3.FORWARD))
	actions.tick(ActionControllerScript.DODGE_IFRAME_START - 0.0001)
	_expect_true(failures, "dodge iframe is closed immediately before exact start", not actions.is_dodge_iframe_active())
	actions.tick(0.0001)
	_expect_true(failures, "dodge iframe opens at exact start", actions.is_dodge_iframe_active())
	actions.tick(ActionControllerScript.DODGE_IFRAME_END - ActionControllerScript.DODGE_IFRAME_START - 0.0001)
	_expect_true(failures, "dodge iframe remains open immediately before exact end", actions.is_dodge_iframe_active())
	actions.tick(0.0001)
	_expect_true(failures, "dodge iframe closes at exact end", not actions.is_dodge_iframe_active())


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


static func _test_semantic_attack_inputs_and_generic_sword(tree: SceneTree, failures: Array[String]) -> void:
	if tree == null or tree.root == null:
		failures.append("generic sword integration requires SceneTree root")
		return
	var root := Node3D.new()
	tree.root.add_child(root)
	var player: Node = PlayerScript.new()
	root.add_child(player)
	_expect_true(failures, "light attack is a semantic InputMap action", InputMap.has_action(&"attack_light"))
	_expect_true(failures, "heavy attack is a semantic InputMap action", InputMap.has_action(&"attack_heavy"))
	var original_heavy_events: Array[InputEvent] = InputMap.action_get_events(&"attack_heavy")
	InputMap.action_erase_events(&"attack_heavy")
	var rebound := InputEventKey.new()
	rebound.physical_keycode = KEY_R
	InputMap.action_add_event(&"attack_heavy", rebound)
	var second_player: Node = PlayerScript.new()
	root.add_child(second_player)
	_expect_true(failures, "custom heavy binding survives player initialization", _has_key_binding(&"attack_heavy", KEY_R))
	_expect_true(failures, "player initialization does not restore physical E authority", not _has_key_binding(&"attack_heavy", KEY_E))
	second_player.free()
	InputMap.action_erase_events(&"attack_heavy")
	for original_event in original_heavy_events:
		InputMap.action_add_event(&"attack_heavy", original_event)

	var light = AttackDefinitionScript.new(
		&"expedition_sword_light", 0.12, 0.10, 0.20, 18, 2.8, 1.6, 1.0, 0.1, &"light", 3.0
	)
	var heavy = AttackDefinitionScript.new(
		&"expedition_sword_heavy", 0.24, 0.12, 0.34, 31, 3.0, 1.75, 1.15, 0.06, &"heavy", 17.0
	)
	var attack_set = WeaponAttackSetScript.new()
	attack_set.configure_attack_set("attack_set.weapon.expedition_sword", {
		"weapon_technique.light.primary": "expedition_sword_light",
		"weapon_technique.heavy.primary": "expedition_sword_heavy",
	})
	var weapon = WeaponDefinitionScript.new()
	weapon.configure_weapon(
		"item.weapon.expedition_sword",
		attack_set.content_id,
		"archetype.weapon.expedition_sword"
	)
	var resolver = WeaponAttackResolverScript.new()
	resolver.configure_attack_definitions([light, heavy])
	player.call("configure_equipped_weapon_attack_source", weapon, attack_set, resolver)

	var resolved_light = player.call("_resolve_attack_definition", "ignored_presentation_id", &"light")
	var resolved_heavy = player.call("_resolve_attack_definition", "ignored_presentation_id", &"heavy")
	_expect_true(failures, "generic weapon boundary resolves authored sword light", resolved_light == light)
	_expect_true(failures, "generic weapon boundary resolves authored sword heavy", resolved_heavy == heavy)

	var stamina = player.get("stamina")
	var before: float = float(stamina.current_stamina)
	player.call("_request_attack", true)
	_expect_equal(failures, "generic sword heavy enters committed heavy state", player.call("get_action_state_name"), "ATTACKING/STARTUP")
	_expect_equal(failures, "generic sword spends its own authored stamina cost", float(stamina.current_stamina), before - heavy.stamina_cost)
	root.free()


static func _has_property(target: Object, property_name: String) -> bool:
	for property in target.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false


static func _has_key_binding(action: StringName, key: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == key:
			return true
	return false


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])
