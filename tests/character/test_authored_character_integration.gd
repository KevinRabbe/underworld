extends RefCounted

const GAME_SCENE := preload("res://app/game/game.tscn")
const AuthoredProvider := preload("res://presentation/characters/authored/authored_character_presentation_provider.gd")
const AuthoredCharacter := preload("res://presentation/characters/authored/authored_character_presentation.gd")

const REQUIRED_BONES: Array[String] = [
	"root", "pelvis", "spine_01", "spine_02", "chest", "neck", "head",
	"clavicle_l", "upperarm_l", "forearm_l", "hand_l",
	"clavicle_r", "upperarm_r", "forearm_r", "hand_r",
	"thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r",
]


static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var provider = AuthoredProvider.new()
	var character = provider.create_presentation()
	if provider.used_fallback():
		failures.append("authored provider unexpectedly used its mannequin fallback")
	if character == null or not character is AuthoredCharacter:
		failures.append("authored provider did not create the production character")
		return failures
	tree.root.add_child(character)
	character.build()
	if character.skeleton == null:
		failures.append("authored GLB did not resolve an imported Skeleton3D")
	else:
		if character.skeleton.get_bone_count() != 41:
			failures.append("authored GLB did not retain its 41-bone rig")
		for bone_name in REQUIRED_BONES:
			if character.skeleton.find_bone(bone_name) < 0:
				failures.append("authored GLB is missing required bone %s" % bone_name)
	if not character.has_required_rig():
		failures.append("authored character failed the humanoid rig contract")
	var runtime: Dictionary = provider.build_animation_runtime(character)
	if not bool(runtime.get("success", false)):
		failures.append("authored animation runtime failed: %s" % [runtime.get("diagnostics", [])])
	var tool_root: Node3D = character.get_tool_visual_root()
	if not provider.realize_held_item(character, tool_root, "stone_axe"):
		failures.append("authored provider could not realize the stone axe")
	if tool_root == null or tool_root.get_node_or_null("ToolHandle") == null:
		failures.append("authored axe was not attached through the right-hand socket")
	if not character.is_tool_grip_active():
		failures.append("authored finger grip did not activate for the axe")
	provider.realize_held_item(character, tool_root, "hands")
	if character.is_tool_grip_active():
		failures.append("authored finger grip remained active with empty hands")
	character.queue_free()
	await tree.process_frame

	var missing_provider = AuthoredProvider.new("res://missing/character.glb")
	var fallback_character = missing_provider.create_presentation()
	if not missing_provider.used_fallback():
		failures.append("missing authored GLB did not activate the mannequin fallback")
	if fallback_character == null or fallback_character is AuthoredCharacter:
		failures.append("missing authored GLB did not return the fallback presentation")
	if fallback_character != null:
		fallback_character.free()

	var game = GAME_SCENE.instantiate()
	if game == null:
		failures.append("production Game scene could not be instantiated")
		return failures
	game.set("enable_debug_hud", false)
	game.call("prepare_new_game")
	tree.root.add_child(game)
	await tree.process_frame
	var player = game.get("player")
	if player == null:
		failures.append("production Game scene did not create its Player")
	else:
		var game_provider = player.get("character_presentation_provider")
		if game_provider == null or not game_provider is AuthoredProvider:
			failures.append("production Player is not using the authored provider")
		elif game_provider.used_fallback():
			failures.append("production Player silently fell back from the authored GLB")
		var game_character = player.get("character_presentation")
		if game_character == null or not game_character is AuthoredCharacter:
			failures.append("production Player did not realize the authored character")
		player.call("set_equipped_tool", "stone_axe")
		await tree.process_frame
		var game_tool_root: Node3D = player.get("tool_visual_root")
		if game_tool_root == null or game_tool_root.get_node_or_null("ToolHandle") == null:
			failures.append("production Player did not attach the axe to hand_r")
		elif game_character != null and not game_character.is_tool_grip_active():
			failures.append("production Player did not activate the authored grip")
	game.queue_free()
	await tree.process_frame
	return failures
