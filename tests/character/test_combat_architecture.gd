extends RefCounted

const CombatResolverScript := preload("res://gameplay/combat/resolution/combat_resolver.gd")
const EncounterControllerScript := preload("res://gameplay/creatures/spawning/prototype_burrower_encounter_controller.gd")
const APP_GAME_PATH := "res://app/game/game.gd"


static func run() -> Array[String]:
	var failures: Array[String] = []
	var resolver: Node = CombatResolverScript.new()
	var encounters: Node = EncounterControllerScript.new()

	_expect_true(failures, "combat resolver owns attack resolution", resolver.has_method("try_attack"))
	_expect_true(
		failures,
		"combat resolver exposes combat message",
		resolver.has_method("get_last_combat_message")
	)
	_expect_true(
		failures,
		"combat resolver does not own enemy lifetime",
		not resolver.has_method("get_active_enemy_count")
	)
	_expect_true(
		failures,
		"encounter controller owns active-enemy lifetime",
		encounters.has_method("get_active_enemy_count")
	)
	_expect_true(
		failures,
		"encounter controller does not resolve player attacks",
		not encounters.has_method("try_attack")
	)

	var app_source: String = FileAccess.get_file_as_string(APP_GAME_PATH)
	_expect_true(failures, "application composition source is readable", not app_source.is_empty())
	_expect_true(
		failures,
		"application composes canonical combat resolver",
		"res://gameplay/combat/resolution/combat_resolver.gd" in app_source
	)
	_expect_true(
		failures,
		"application composes canonical encounter controller",
		"res://gameplay/creatures/spawning/prototype_burrower_encounter_controller.gd" in app_source
	)
	_expect_true(
		failures,
		"application no longer composes legacy combat manager",
		not "res://combat/combat_manager.gd" in app_source
	)
	_expect_true(
		failures,
		"legacy mixed combat manager is retired",
		not FileAccess.file_exists("res://combat/combat_manager.gd")
	)

	resolver.free()
	encounters.free()
	return failures


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
