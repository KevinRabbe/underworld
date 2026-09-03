extends RefCounted

const GAME_SCENE_PATH := "res://app/game/game.tscn"


class TestGameplayInputGate:
	extends Node
	func allows_player_input() -> bool:
		return true


static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var packed = ResourceLoader.load(GAME_SCENE_PATH)
	if packed == null or not packed is PackedScene:
		return ["weapon Game-session proof could not load ordinary Game scene"]
	var game: Node = packed.instantiate()
	var gate = TestGameplayInputGate.new()
	tree.root.add_child(gate)
	if not bool(game.call("configure_gameplay_input_gate", gate)):
		failures.append("ordinary Game rejected exact gameplay-input authority before tree entry")
		game.free()
		gate.queue_free()
		await tree.process_frame
		return failures
	if not bool(game.call("prepare_new_game")):
		failures.append("ordinary Game rejected clean NEW preparation")
		game.free()
		gate.queue_free()
		await tree.process_frame
		return failures

	tree.root.add_child(game)
	await tree.process_frame
	await tree.process_frame
	var player = game.get("player")
	if player == null or not is_instance_valid(player):
		failures.append("ordinary Game did not realize the prepared production Player")
	else:
		if player.get("_gameplay_input_gate") != gate:
			failures.append("weapon composition changed exact AppRoot-style GameplayInputGate identity")
	var weapon_session := game.get_node_or_null("WeaponRuntimeSession")
	if weapon_session == null:
		failures.append("ordinary Game is missing WeaponRuntimeSession composition child")
	elif not bool(weapon_session.call("is_configured")):
		failures.append("ordinary Game WeaponRuntimeSession did not bind canonical Player/inventory/equipment state")
	else:
		var capabilities: Array = weapon_session.call("craft_capabilities")
		if capabilities.size() != 1 or str(capabilities[0].get("recipe_id", "")) != "recipe.hand.iron_sword":
			failures.append("ordinary Game does not expose semantic iron-sword craft capability")

	game.queue_free()
	gate.queue_free()
	await tree.process_frame
	return failures
