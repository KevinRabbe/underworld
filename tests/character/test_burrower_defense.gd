extends RefCounted

const EnemyScript := preload("res://combat/enemy.gd")


class DefensiveTarget:
	extends Node3D

	var response: StringName = &"hit"
	var receive_calls: int = 0

	func _init(defensive_response: StringName) -> void:
		response = defensive_response

	func receive_melee_attack(
		_amount: int,
		_source_position: Vector3,
		_parryable: bool = true
	) -> StringName:
		receive_calls += 1
		return response


static func run() -> Array[String]:
	var failures: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		failures.append("Burrower defense test requires SceneTree main loop")
		return failures

	_test_parry_response(tree, failures)
	_test_dodge_response(tree, failures)
	return failures


static func _test_parry_response(tree: SceneTree, failures: Array[String]) -> void:
	var root := Node3D.new()
	tree.root.add_child(root)

	var target := DefensiveTarget.new(&"parried")
	target.position = Vector3(0.0, 0.0, 0.75)
	root.add_child(target)

	var enemy = EnemyScript.new()
	enemy.call("configure", "test_parry", target, Vector3.ZERO, {})
	root.add_child(enemy)
	enemy.call("_begin_attack")
	enemy.call("_resolve_pending_attack")

	_expect_equal(failures, "Burrower sends one melee resolution request", target.receive_calls, 1)
	_expect_true(
		failures,
		"Burrower enters parry-specific stagger",
		bool(enemy.call("is_parry_staggered"))
	)
	_expect_true(
		failures,
		"Burrower parry stagger is substantially longer than hit stagger",
		float(enemy.call("get_stagger_remaining")) >= 0.80
	)
	var recoil_velocity: Vector3 = enemy.get("velocity")
	_expect_true(
		failures,
		"successful parry gives Burrower recoil",
		Vector2(recoil_velocity.x, recoil_velocity.z).length() > 0.1
	)

	root.free()


static func _test_dodge_response(tree: SceneTree, failures: Array[String]) -> void:
	var root := Node3D.new()
	tree.root.add_child(root)

	var target := DefensiveTarget.new(&"dodged")
	target.position = Vector3(0.0, 0.0, 0.75)
	root.add_child(target)

	var enemy = EnemyScript.new()
	enemy.call("configure", "test_dodge", target, Vector3.ZERO, {})
	root.add_child(enemy)
	enemy.call("_begin_attack")
	enemy.call("_resolve_pending_attack")

	_expect_equal(failures, "dodged Burrower attack resolves once", target.receive_calls, 1)
	_expect_true(
		failures,
		"dodge does not grant the Burrower parry stagger",
		not bool(enemy.call("is_parry_staggered"))
	)
	_expect_close(
		failures,
		"dodge does not add generic stagger",
		float(enemy.call("get_stagger_remaining")),
		0.0
	)

	root.free()


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
