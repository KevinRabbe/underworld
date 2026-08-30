extends RefCounted

const EnemyScript := preload("res://gameplay/creatures/underworld/burrower/burrower.gd")
const LosEnemyScript := preload("res://tests/character/fixtures/test_burrower_los_double.gd")


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


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	if tree == null or tree.root == null:
		failures.append("Burrower defense test requires SceneTree root")
		return failures

	_test_unobstructed_resolution(tree, failures)
	_test_obstructed_resolution(tree, failures)
	_test_obstruction_appears_during_windup(tree, failures)
	_test_obstruction_clears_during_windup(tree, failures)
	_test_final_range_precedes_los(tree, failures)
	_test_ray_query_exclusions(tree, failures)
	_test_missing_physics_world_fails_closed(failures)
	_test_pending_attack_resolves_once(tree, failures)
	_test_parry_response(tree, failures)
	_test_dodge_response(tree, failures)
	_test_block_response(tree, failures)
	return failures


static func _test_unobstructed_resolution(tree: SceneTree, failures: Array[String]) -> void:
	var pair := _los_pair(tree, &"hit", "los_clear")
	var target: DefensiveTarget = pair.target
	var enemy = pair.enemy
	enemy.set_attack_path_clear(true)
	enemy.call("_begin_attack")
	enemy.call("_resolve_pending_attack")
	_expect_equal(failures, "unobstructed Burrower attack resolves exactly once", target.receive_calls, 1)
	_expect_equal(failures, "unobstructed attack samples LOS once at resolution", enemy.attack_path_query_calls, 1)
	pair.root.free()


static func _test_obstructed_resolution(tree: SceneTree, failures: Array[String]) -> void:
	var pair := _los_pair(tree, &"hit", "los_blocked")
	var target: DefensiveTarget = pair.target
	var enemy = pair.enemy
	enemy.set_attack_path_clear(false)
	enemy.call("_begin_attack")
	enemy.call("_resolve_pending_attack")
	_expect_equal(failures, "world obstruction blocks Burrower damage", target.receive_calls, 0)
	_expect_equal(failures, "blocked attack samples LOS once", enemy.attack_path_query_calls, 1)
	pair.root.free()


static func _test_obstruction_appears_during_windup(tree: SceneTree, failures: Array[String]) -> void:
	var pair := _los_pair(tree, &"hit", "los_appears")
	var target: DefensiveTarget = pair.target
	var enemy = pair.enemy
	enemy.set_attack_path_clear(true)
	enemy.call("_begin_attack")
	enemy.set_attack_path_clear(false)
	enemy.call("_resolve_pending_attack")
	_expect_equal(failures, "obstruction appearing during windup blocks hit", target.receive_calls, 0)
	_expect_equal(failures, "windup LOS is recomputed only at resolution", enemy.attack_path_query_calls, 1)
	pair.root.free()


static func _test_obstruction_clears_during_windup(tree: SceneTree, failures: Array[String]) -> void:
	var pair := _los_pair(tree, &"hit", "los_clears")
	var target: DefensiveTarget = pair.target
	var enemy = pair.enemy
	enemy.set_attack_path_clear(false)
	enemy.call("_begin_attack")
	enemy.set_attack_path_clear(true)
	enemy.call("_resolve_pending_attack")
	_expect_equal(failures, "cleared obstruction permits resolution-time hit", target.receive_calls, 1)
	_expect_equal(failures, "attack-start obstruction is not cached", enemy.attack_path_query_calls, 1)
	pair.root.free()


static func _test_final_range_precedes_los(tree: SceneTree, failures: Array[String]) -> void:
	var pair := _los_pair(tree, &"hit", "los_range")
	var target: DefensiveTarget = pair.target
	var enemy = pair.enemy
	enemy.set_attack_path_clear(false)
	enemy.call("_begin_attack")
	enemy.set_attack_path_clear(true)
	target.position = Vector3(0.0, 0.0, 3.0)
	enemy.call("_resolve_pending_attack")
	_expect_equal(failures, "target beyond final range cannot be hit after obstruction clears", target.receive_calls, 0)
	_expect_equal(failures, "out-of-range attack does not perform unnecessary LOS query", enemy.attack_path_query_calls, 0)
	pair.root.free()


static func _test_ray_query_exclusions(tree: SceneTree, failures: Array[String]) -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var target := DefensiveTarget.new(&"hit")
	target.position = Vector3(0.0, 0.0, 0.75)
	root.add_child(target)
	var target_child := Node3D.new()
	target.add_child(target_child)
	var enemy = EnemyScript.new()
	enemy.call("configure", "los_query_contract", target, Vector3.ZERO, {})
	root.add_child(enemy)
	var query = enemy.call("_build_attack_ray_query")
	_expect_true(failures, "Burrower builds physics ray while in a live world", query != null)
	if query != null:
		_expect_true(failures, "Burrower ray excludes attacking collider RID", query.exclude.has(enemy.get_rid()))
		_expect_true(failures, "Burrower ray checks colliding bodies", query.collide_with_bodies)
		_expect_true(failures, "Burrower ray does not treat Areas as walls", not query.collide_with_areas)
	_expect_true(failures, "intended Player target collider is not treated as obstruction", bool(enemy.call("_collider_belongs_to_target", target)))
	_expect_true(failures, "target-owned collider descendants are not treated as walls", bool(enemy.call("_collider_belongs_to_target", target_child)))
	root.free()


static func _test_missing_physics_world_fails_closed(failures: Array[String]) -> void:
	var target := DefensiveTarget.new(&"hit")
	var enemy = EnemyScript.new()
	enemy.call("configure", "los_no_world", target, Vector3.ZERO, {})
	_expect_true(failures, "Burrower LOS fails closed without physics world", not bool(enemy.call("_attack_path_is_clear")))
	enemy.free()
	target.free()


static func _test_pending_attack_resolves_once(tree: SceneTree, failures: Array[String]) -> void:
	var pair := _los_pair(tree, &"hit", "los_once")
	var target: DefensiveTarget = pair.target
	var enemy = pair.enemy
	enemy.set_attack_path_clear(true)
	enemy.call("_begin_attack")
	enemy.call("_resolve_pending_attack")
	enemy.call("_resolve_pending_attack")
	_expect_equal(failures, "one pending Burrower attack cannot double-resolve", target.receive_calls, 1)
	_expect_equal(failures, "duplicate resolution does not repeat LOS query", enemy.attack_path_query_calls, 1)
	pair.root.free()


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


static func _test_block_response(tree: SceneTree, failures: Array[String]) -> void:
	var root := Node3D.new()
	tree.root.add_child(root)

	var target := DefensiveTarget.new(&"blocked")
	target.position = Vector3(0.0, 0.0, 0.75)
	root.add_child(target)

	var enemy = EnemyScript.new()
	enemy.call("configure", "test_block", target, Vector3.ZERO, {})
	root.add_child(enemy)
	enemy.call("_begin_attack")
	enemy.call("_resolve_pending_attack")

	_expect_equal(failures, "blocked Burrower attack resolves once", target.receive_calls, 1)
	_expect_true(
		failures,
		"block does not grant the Burrower parry stagger",
		not bool(enemy.call("is_parry_staggered"))
	)
	_expect_close(
		failures,
		"block does not add enemy stagger",
		float(enemy.call("get_stagger_remaining")),
		0.0
	)

	root.free()


static func _los_pair(tree: SceneTree, response: StringName, id: String) -> Dictionary:
	var root := Node3D.new()
	tree.root.add_child(root)
	var target := DefensiveTarget.new(response)
	target.position = Vector3(0.0, 0.0, 0.75)
	root.add_child(target)
	var enemy = LosEnemyScript.new()
	enemy.call("configure", id, target, Vector3.ZERO, {})
	root.add_child(enemy)
	return {"root": root, "target": target, "enemy": enemy}


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
