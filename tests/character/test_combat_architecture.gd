extends RefCounted

const CombatResolverScript := preload("res://gameplay/combat/resolution/combat_resolver.gd")
const EncounterControllerScript := preload("res://gameplay/creatures/spawning/prototype_burrower_encounter_controller.gd")
const APP_GAME_PATH := "res://app/game/game.gd"
const COMBAT_COMPOSITION_PATH := "res://app/game/composition/combat_composition.gd"
const COMBAT_RESOLVER_PATH := "res://gameplay/combat/resolution/combat_resolver.gd"
const ENCOUNTER_CONTROLLER_PATH := "res://gameplay/creatures/spawning/prototype_burrower_encounter_controller.gd"


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
	var composition_source: String = FileAccess.get_file_as_string(COMBAT_COMPOSITION_PATH)
	_expect_true(failures, "application composition source is readable", not app_source.is_empty())
	_expect_true(failures, "combat composition helper source is readable", not composition_source.is_empty())
	_expect_true(
		failures,
		"application delegates combat construction to canonical composition helper",
		COMBAT_COMPOSITION_PATH in app_source and "CombatCompositionScript.compose_combat(" in app_source
	)
	_expect_true(
		failures,
		"combat composition helper owns canonical combat resolver dependency",
		COMBAT_RESOLVER_PATH in composition_source
	)
	_expect_true(
		failures,
		"combat composition helper owns canonical encounter controller dependency",
		ENCOUNTER_CONTROLLER_PATH in composition_source
	)

	resolver.free()
	encounters.free()
	return failures


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)