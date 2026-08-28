extends RefCounted

const AppGameScript := preload("res://app/game/game.gd")
const CombatResolverScript := preload("res://gameplay/combat/resolution/combat_resolver.gd")
const EncounterControllerScript := preload("res://gameplay/creatures/spawning/prototype_burrower_encounter_controller.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var resolver: Node = CombatResolverScript.new()
	var encounters: Node = EncounterControllerScript.new()
	var app: Node = AppGameScript.new()

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
	_expect_true(failures, "application composition script compiles", app != null)
	_expect_true(
		failures,
		"legacy mixed combat manager is retired",
		not ResourceLoader.exists("res://combat/combat_manager.gd")
	)

	resolver.free()
	encounters.free()
	app.free()
	return failures


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
