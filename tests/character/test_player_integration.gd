extends RefCounted

const PlayerScript := preload("res://player/player.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var player = PlayerScript.new()

	# Build only the visual/collision portion; no viewport or live world is needed
	# to validate the player->mannequin contract headlessly.
	player._build_character_visual()
	_expect_true(
		failures,
		"player builds articulated mannequin",
		player.get_mannequin() != null and player.get_mannequin().has_required_rig()
	)
	_expect_close(failures, "player starts with full stamina", player.get_stamina(), 100.0)

	# Parry resolution must preserve health while the timed active window is open.
	_expect_true(failures, "player parry action starts", player.action_controller.try_start_parry())
	player.action_controller.tick(0.07)
	var health_before: int = player.get_health()
	var parry_result: StringName = player.receive_melee_attack(10, Vector3(1.0, 0.0, 0.0), true)
	_expect_equal(failures, "active parry resolves as parried", parry_result, &"parried")
	_expect_equal(failures, "parry prevents health loss", player.get_health(), health_before)

	# Dodge iframe path is distinct from parry and also preserves health.
	player.action_controller.reset()
	player.stamina.reset()
	_expect_true(
		failures,
		"player dodge action starts",
		player.action_controller.try_start_dodge(Vector3(1.0, 0.0, 0.0))
	)
	player.action_controller.tick(0.10)
	var dodge_result: StringName = player.receive_melee_attack(10, Vector3(1.0, 0.0, 0.0), true)
	_expect_equal(failures, "active dodge iframe resolves as dodged", dodge_result, &"dodged")
	_expect_equal(failures, "dodge iframe prevents health loss", player.get_health(), health_before)

	# Normal melee outside defensive windows still uses the existing damage path.
	player.action_controller.reset()
	var hit_result: StringName = player.receive_melee_attack(10, Vector3(1.0, 0.0, 0.0), true)
	_expect_equal(failures, "undefended melee resolves as hit", hit_result, &"hit")
	_expect_equal(failures, "undefended melee reduces health", player.get_health(), health_before - 10)

	player.free()
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
