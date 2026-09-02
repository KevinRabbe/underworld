from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


player_path = Path("gameplay/player/player.gd")
player = player_path.read_text()
player = replace_once(
    player,
    'const PrototypeMannequinScript := preload("res://presentation/characters/player/prototype_mannequin/prototype_mannequin.gd")\nconst PrototypeAnimationRuntimeFactoryScript := preload("res://presentation/characters/player/prototype_mannequin/prototype_animation_runtime_factory.gd")\n',
    '',
    "remove hard-coded mannequin preloads",
)
player = replace_once(
    player,
    'var visual_root: Node3D\nvar mannequin\nvar animation_controller\n',
    'var visual_root: Node3D\nvar character_presentation_provider\nvar character_presentation\nvar animation_controller\n',
    "inject presentation provider state",
)
player = replace_once(
    player,
    'func get_mannequin():\n\treturn mannequin\n',
    'func get_mannequin():\n\t# Compatibility name retained for existing gameplay/regression callers.\n\treturn character_presentation\n',
    "compatibility presentation getter",
)
player = replace_once(
    player,
    '\tvar forward: Vector3 = visual_root.global_transform.basis.z\n',
    '\t# Gameplay front-arc follows the authored character face: local -Z.\n\tvar forward: Vector3 = -visual_root.global_transform.basis.z\n',
    "front arc visual convention",
)
player = replace_once(
    player,
    '\t\tanimation_controller.present_attack(total_duration)\n',
    '\t\tanimation_controller.present_attack(total_duration, attack_kind)\n',
    "attack kind presentation",
)
player = replace_once(
    player,
    '\t\tanimation_controller.present_attack(tool_use_cooldown_duration)\n',
    '\t\tanimation_controller.present_tool_use(tool_use_cooldown_duration)\n',
    "tool-use presentation",
)
player = replace_once(
    player,
    '\t\tanimation_controller.present_dodge(Vector2(local.x, local.z))\n',
    '\t\t# Presentation dodge space uses +Y for forward; Godot character forward is local -Z.\n\t\tanimation_controller.present_dodge(Vector2(local.x, -local.z))\n',
    "dodge presentation direction",
)
player = replace_once(
    player,
    '\tvisual_root.rotation.y = atan2(forward.x, forward.z)\n',
    '\t# Map requested world-facing onto authored local -Z without changing gameplay direction.\n\tvisual_root.rotation.y = atan2(-forward.x, -forward.z)\n',
    "combat facing convention",
)
player = replace_once(
    player,
    '\tvar target_yaw: float = atan2(velocity.x, velocity.z)\n',
    '\tvar target_yaw: float = atan2(-velocity.x, -velocity.z)\n',
    "locomotion facing convention",
)
player = replace_once(
    player,
    '\tif animation_controller != null:\n\t\tanimation_controller.reset_presentation()\n\telif mannequin != null:\n\t\tmannequin.reset_pose()\n',
    '\tif animation_controller != null:\n\t\tanimation_controller.reset_presentation()\n\telif character_presentation != null:\n\t\tcharacter_presentation.reset_pose()\n',
    "respawn presentation reset",
)
player = replace_once(
    player,
    '\tmannequin = PrototypeMannequinScript.new()\n\tmannequin.name = "PrototypeMannequin"\n\tvisual_root.add_child(mannequin)\n\tmannequin.build()\n\n\tvar animation_runtime: Dictionary = PrototypeAnimationRuntimeFactoryScript.build(mannequin)\n',
    '\tif character_presentation_provider == null:\n\t\tpush_error("Player requires an injected character presentation provider before entering the tree")\n\t\treturn\n\tcharacter_presentation = character_presentation_provider.create_presentation()\n\tif character_presentation == null:\n\t\tpush_error("Character presentation provider returned no presentation")\n\t\treturn\n\tvisual_root.add_child(character_presentation)\n\tcharacter_presentation.build()\n\n\tvar animation_runtime: Dictionary = character_presentation_provider.build_animation_runtime(character_presentation)\n',
    "provider-driven character creation",
)
player = replace_once(
    player,
    '\t\ttool_visual_root = mannequin.get_tool_visual_root()\n',
    '\t\ttool_visual_root = character_presentation.get_tool_visual_root()\n',
    "semantic tool-root fallback",
)
start = player.find('func _rebuild_tool_visual() -> void:\n')
end = player.find('\n\nfunc _build_camera() -> void:', start)
if start < 0 or end < 0:
    raise SystemExit("held-item presentation function boundary not found")
player = player[:start] + '''func _rebuild_tool_visual() -> void:
\tif tool_visual_root == null or character_presentation_provider == null or character_presentation == null:
\t\treturn
\tif not character_presentation_provider.realize_held_item(character_presentation, tool_visual_root, equipped_tool_visual):
\t\tpush_error("Character presentation provider could not realize held item: %s" % equipped_tool_visual)
''' + player[end:]
player_path.write_text(player)

controller_path = Path("presentation/characters/animation/character_animation_controller.gd")
controller = controller_path.read_text()
controller = replace_once(
    controller,
    '\treturn ROLE_WALK_FORWARD if horizontal.y >= 0.0 else ROLE_WALK_BACKWARD\n',
    '\t# Neutral humanoid presentation faces local -Z; negative local Z is forward travel.\n\treturn ROLE_WALK_FORWARD if horizontal.y <= 0.0 else ROLE_WALK_BACKWARD\n',
    "locomotion semantic forward convention",
)
controller_path.write_text(controller)

game_path = Path("app/game/game.gd")
game = game_path.read_text()
game = replace_once(
    game,
    'const PlayerScript := preload("res://gameplay/player/player.gd")\nconst PlayerDeathRecoveryControllerScript := preload("res://gameplay/player/lifecycle/player_death_recovery_controller.gd")\n',
    'const PlayerScript := preload("res://gameplay/player/player.gd")\nconst VoxelCharacterPresentationProviderScript := preload("res://presentation/characters/voxel/voxel_character_presentation_provider.gd")\nconst PlayerDeathRecoveryControllerScript := preload("res://gameplay/player/lifecycle/player_death_recovery_controller.gd")\n',
    "game presentation provider preload",
)
game = replace_once(
    game,
    '\tplayer = PlayerScript.new()\n\tplayer.name = "Player"\n\tadd_child(player)\n',
    '\tplayer = PlayerScript.new()\n\tplayer.name = "Player"\n\t# Presentation is injected before add_child(), so Player._ready() never owns a hard-coded body implementation.\n\tplayer.character_presentation_provider = VoxelCharacterPresentationProviderScript.new()\n\tadd_child(player)\n',
    "game presentation provider injection",
)
game_path.write_text(game)

print("character reconciliation edits applied")
