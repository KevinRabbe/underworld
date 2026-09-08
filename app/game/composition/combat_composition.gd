extends RefCounted

const PlayerDeathRecoveryControllerScript := preload("res://gameplay/player/lifecycle/player_death_recovery_controller.gd")
const CombatResolverScript := preload("res://gameplay/combat/resolution/combat_resolver.gd")
const BurrowerEncounterControllerScript := preload("res://gameplay/creatures/spawning/prototype_burrower_encounter_controller.gd")


static func compose_death_recovery(root: Node3D, player, world, world_settings) -> Dictionary:
	var controller = PlayerDeathRecoveryControllerScript.new()
	controller.name = "DeathRecovery"
	root.add_child(controller)
	var failures: Array[String] = controller.configure(player, world, world_settings)
	if failures.is_empty():
		player.defeat_requested.connect(controller.request_recovery)
	return {
		"success": failures.is_empty(),
		"controller": controller,
		"diagnostics": failures,
	}


static func compose_combat(
	root: Node3D,
	player,
	world,
	world_settings,
	is_continue: bool,
	restored_pending_loot_states: Array,
	recovery_anchor: Vector3
) -> Dictionary:
	var combat_resolver = CombatResolverScript.new()
	combat_resolver.name = "CombatResolver"
	root.add_child(combat_resolver)
	combat_resolver.configure(player)
	player.attack_requested.connect(combat_resolver.try_attack)

	var encounter_controller = BurrowerEncounterControllerScript.new()
	encounter_controller.name = "BurrowerEncounters"
	root.add_child(encounter_controller)
	encounter_controller.configure(world, player, world_settings)

	var import_result: Dictionary = {}
	if is_continue and not restored_pending_loot_states.is_empty():
		import_result = encounter_controller.import_pending_loot_states(
			restored_pending_loot_states,
			recovery_anchor
		)

	return {
		"success": true,
		"combat_resolver": combat_resolver,
		"encounter_controller": encounter_controller,
		"import_result": import_result,
		"diagnostics": [],
	}
