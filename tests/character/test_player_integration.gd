extends RefCounted

const PlayerScript := preload("res://player/player.gd")


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
	var player: Node = PlayerScript.new()
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

	# Parry resolution must preserve health while the timed active window is open.
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
		Vector3(1.0, 0.0, 0.0),
		true
	)
	_expect_equal(failures, "active parry resolves as parried", parry_result, &"parried")
	_expect_equal(
		failures,
		"parry prevents health loss",
		int(player.call("get_health")),
		health_before
	)

	# Dodge iframe path is distinct from parry and also preserves health.
	actions.call("reset")
	stamina.call("reset")
	_expect_true(
		failures,
		"player dodge action starts",
		bool(actions.call("try_start_dodge", Vector3(1.0, 0.0, 0.0)))
	)
	actions.call("tick", 0.10)
	var dodge_result: StringName = player.call(
		"receive_melee_attack",
		10,
		Vector3(1.0, 0.0, 0.0),
		true
	)
	_expect_equal(failures, "active dodge iframe resolves as dodged", dodge_result, &"dodged")
	_expect_equal(
		failures,
		"dodge iframe prevents health loss",
		int(player.call("get_health")),
		health_before
	)

	# Normal melee outside defensive windows still uses the existing damage path.
	actions.call("reset")
	var hit_result: StringName = player.call(
		"receive_melee_attack",
		10,
		Vector3(1.0, 0.0, 0.0),
		true
	)
	_expect_equal(failures, "undefended melee resolves as hit", hit_result, &"hit")
	_expect_equal(
		failures,
		"undefended melee reduces health",
		int(player.call("get_health")),
		health_before - 10
	)

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
