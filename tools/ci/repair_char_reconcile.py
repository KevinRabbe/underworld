from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected exactly one replacement target, found {count}: {old[:120]!r}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


# Current-main Game wins the merge. Reapply only the narrow presentation injection.
replace_once(
    "app/game/game.gd",
    'const PlayerScript := preload("res://gameplay/player/player.gd")\n',
    'const PlayerScript := preload("res://gameplay/player/player.gd")\n'
    'const VoxelCharacterPresentationProviderScript := preload("res://presentation/characters/voxel/voxel_character_presentation_provider.gd")\n',
)
replace_once(
    "app/game/game.gd",
    '\tplayer.name = "Player"\n\tadd_child(player)\n',
    '\tplayer.name = "Player"\n'
    '\t# Presentation is injected before add_child(), so Player._ready() never owns a hard-coded body implementation.\n'
    '\tplayer.character_presentation_provider = VoxelCharacterPresentationProviderScript.new()\n'
    '\tadd_child(player)\n',
)

# Current-main Player wins all gameplay/SAVE/input/lifecycle semantics. Reapply only
# the reviewed neutral presentation/provider and -Z-facing integration hunks.
replace_once(
    "gameplay/player/player.gd",
    'const PrototypeMannequinScript := preload("res://presentation/characters/player/prototype_mannequin/prototype_mannequin.gd")\n'
    'const PrototypeAnimationRuntimeFactoryScript := preload("res://presentation/characters/player/prototype_mannequin/prototype_animation_runtime_factory.gd")\n',
    '',
)
replace_once(
    "gameplay/player/player.gd",
    'var visual_root: Node3D\nvar mannequin\nvar animation_controller\n',
    'var visual_root: Node3D\nvar character_presentation_provider\nvar character_presentation\nvar animation_controller\n',
)
replace_once(
    "gameplay/player/player.gd",
    'func get_mannequin():\n\treturn mannequin\n',
    'func get_mannequin():\n\t# Compatibility name retained for existing gameplay/regression callers.\n\treturn character_presentation\n',
)
replace_once(
    "gameplay/player/player.gd",
    '\tvar forward: Vector3 = visual_root.global_transform.basis.z\n',
    '\t# Gameplay front-arc follows the authored character face: local -Z.\n\tvar forward: Vector3 = -visual_root.global_transform.basis.z\n',
)
replace_once(
    "gameplay/player/player.gd",
    '\t\tanimation_controller.present_attack(total_duration)\n',
    '\t\tanimation_controller.present_attack(total_duration, attack_kind)\n',
)
replace_once(
    "gameplay/player/player.gd",
    '\t\tanimation_controller.present_attack(tool_use_cooldown_duration)\n',
    '\t\tanimation_controller.present_tool_use(tool_use_cooldown_duration)\n',
)
replace_once(
    "gameplay/player/player.gd",
    '\t\tanimation_controller.present_dodge(Vector2(local.x, local.z))\n',
    '\t\t# Presentation dodge space uses +Y for forward; Godot character forward is local -Z.\n'
    '\t\tanimation_controller.present_dodge(Vector2(local.x, -local.z))\n',
)
replace_once(
    "gameplay/player/player.gd",
    '\tvisual_root.rotation.y = atan2(forward.x, forward.z)\n',
    '\t# Map requested world-facing onto authored local -Z without changing gameplay direction.\n'
    '\tvisual_root.rotation.y = atan2(-forward.x, -forward.z)\n',
)
replace_once(
    "gameplay/player/player.gd",
    '\tvar target_yaw: float = atan2(velocity.x, velocity.z)\n',
    '\tvar target_yaw: float = atan2(-velocity.x, -velocity.z)\n',
)
replace_once(
    "gameplay/player/player.gd",
    '\telif mannequin != null:\n\t\tmannequin.reset_pose()\n',
    '\telif character_presentation != null:\n\t\tcharacter_presentation.reset_pose()\n',
)
replace_once(
    "gameplay/player/player.gd",
    '\tmannequin = PrototypeMannequinScript.new()\n'
    '\tmannequin.name = "PrototypeMannequin"\n'
    '\tvisual_root.add_child(mannequin)\n'
    '\tmannequin.build()\n\n'
    '\tvar animation_runtime: Dictionary = PrototypeAnimationRuntimeFactoryScript.build(mannequin)\n',
    '\tif character_presentation_provider == null:\n'
    '\t\tpush_error("Player requires an injected character presentation provider before entering the tree")\n'
    '\t\treturn\n'
    '\tcharacter_presentation = character_presentation_provider.create_presentation()\n'
    '\tif character_presentation == null:\n'
    '\t\tpush_error("Character presentation provider returned no presentation")\n'
    '\t\treturn\n'
    '\tvisual_root.add_child(character_presentation)\n'
    '\tcharacter_presentation.build()\n\n'
    '\tvar animation_runtime: Dictionary = character_presentation_provider.build_animation_runtime(character_presentation)\n',
)
replace_once(
    "gameplay/player/player.gd",
    '\t\ttool_visual_root = mannequin.get_tool_visual_root()\n',
    '\t\ttool_visual_root = character_presentation.get_tool_visual_root()\n',
)
replace_once(
    "gameplay/player/player.gd",
    'func _rebuild_tool_visual() -> void:\n'
    '\tif tool_visual_root == null:\n'
    '\t\treturn\n'
    '\tfor child in tool_visual_root.get_children():\n'
    '\t\tchild.queue_free()\n\n'
    '\tif equipped_tool_visual == "hands":\n'
    '\t\treturn\n\n'
    '\tvar handle_material := StandardMaterial3D.new()\n'
    '\thandle_material.albedo_color = Color(0.30, 0.17, 0.07)\n'
    '\tvar stone_material := StandardMaterial3D.new()\n'
    '\tstone_material.albedo_color = Color(0.36, 0.37, 0.34)\n\n'
    '\tvar handle := MeshInstance3D.new()\n'
    '\tvar handle_mesh := BoxMesh.new()\n'
    '\thandle_mesh.size = Vector3(0.10, 0.72, 0.10)\n'
    '\thandle.mesh = handle_mesh\n'
    '\thandle.material_override = handle_material\n'
    '\ttool_visual_root.add_child(handle)\n\n'
    '\tvar head := MeshInstance3D.new()\n'
    '\tvar head_mesh := BoxMesh.new()\n'
    '\tif equipped_tool_visual == "stone_axe":\n'
    '\t\thead_mesh.size = Vector3(0.38, 0.28, 0.13)\n'
    '\telse:\n'
    '\t\thead_mesh.size = Vector3(0.62, 0.16, 0.13)\n'
    '\thead.mesh = head_mesh\n'
    '\thead.material_override = stone_material\n'
    '\thead.position = Vector3(-0.10, 0.31, 0.0)\n'
    '\thead.rotation_degrees.z = -18.0\n'
    '\ttool_visual_root.add_child(head)\n',
    'func _rebuild_tool_visual() -> void:\n'
    '\tif tool_visual_root == null or character_presentation_provider == null or character_presentation == null:\n'
    '\t\treturn\n'
    '\tif not character_presentation_provider.realize_held_item(character_presentation, tool_visual_root, equipped_tool_visual):\n'
    '\t\tpush_error("Character presentation provider could not realize held item: %s" % equipped_tool_visual)\n',
)

# Reviewer finding 1: one -Z-forward convention through voxel presentation and preview.
replace_once(
    "presentation/characters/voxel/voxel_character_presentation.gd",
    'for point_data in [["idle", Vector2.ZERO], ["walk_forward", Vector2(0,1)], ["walk_backward", Vector2(0,-1)], ["strafe_left", Vector2(-1,0)], ["strafe_right", Vector2(1,0)]]:',
    'for point_data in [["idle", Vector2.ZERO], ["walk_forward", Vector2(0,-1)], ["walk_backward", Vector2(0,1)], ["strafe_left", Vector2(-1,0)], ["strafe_right", Vector2(1,0)]]:',
)
replace_once(
    "tools/character_preview/voxel_character_preview.gd",
    '&"walk_forward": locomotion_velocity = Vector3(0.0, 0.0, 4.0)\n'
    '\t\t&"walk_backward": locomotion_velocity = Vector3(0.0, 0.0, -4.0)\n',
    '&"walk_forward": locomotion_velocity = Vector3(0.0, 0.0, -4.0)\n'
    '\t\t&"walk_backward": locomotion_velocity = Vector3(0.0, 0.0, 4.0)\n',
)
replace_once(
    "tools/character_preview/voxel_character_preview.gd",
    '&"sprint": locomotion_velocity = Vector3(0.0, 0.0, 8.5)\n',
    '&"sprint": locomotion_velocity = Vector3(0.0, 0.0, -8.5)\n',
)
replace_once(
    "tools/character_preview/voxel_character_preview.gd",
    '&"dodge_forward": character.play_dodge(Vector2.UP)\n',
    '&"dodge_forward": character.play_dodge(Vector2.DOWN)\n',
)
replace_once(
    "tests/character/test_voxel_character.gd",
    'locomotion.get_blend_point_position(forward_index).is_equal_approx(Vector2(0, 1))',
    'locomotion.get_blend_point_position(forward_index).is_equal_approx(Vector2(0, -1))',
)
replace_once(
    "tests/character/test_voxel_character.gd",
    'var expected_points := {&"idle": Vector2.ZERO, &"walk_forward": Vector2(0,1), &"walk_backward": Vector2(0,-1), &"strafe_left": Vector2(-1,0), &"strafe_right": Vector2(1,0)}',
    'var expected_points := {&"idle": Vector2.ZERO, &"walk_forward": Vector2(0,-1), &"walk_backward": Vector2(0,1), &"strafe_left": Vector2(-1,0), &"strafe_right": Vector2(1,0)}',
)

# Reviewer finding 2: restore accepted death/recovery regression ownership.
replace_once(
    "tests/character/test_death_recovery.gd",
    'const PlayerScript := preload("res://gameplay/player/player.gd")\n',
    'const PlayerScript := preload("res://gameplay/player/player.gd")\n'
    'const VoxelProvider := preload("res://presentation/characters/voxel/voxel_character_presentation_provider.gd")\n',
)
replace_once(
    "tests/character/test_death_recovery.gd",
    '\tvar player = PlayerScript.new()\n\tfixture_root.add_child(player)\n',
    '\tvar player = PlayerScript.new()\n'
    '\tplayer.set("character_presentation_provider", VoxelProvider.new())\n'
    '\tfixture_root.add_child(player)\n',
)
replace_once(
    "tests/run_character.gd",
    'const InputBufferTests := preload("res://tests/character/test_input_buffer.gd")\n',
    'const InputBufferTests := preload("res://tests/character/test_input_buffer.gd")\n'
    'const DeathRecoveryTests := preload("res://tests/character/test_death_recovery.gd")\n',
)
replace_once(
    "tests/run_character.gd",
    '\tfailures.append_array(InputBufferTests.run(self))\n',
    '\tfailures.append_array(InputBufferTests.run(self))\n'
    '\tfailures.append_array(DeathRecoveryTests.run(self))\n',
)
replace_once(
    "tests/character/test_input_buffer.gd",
    '\t# Respawn/reset is a hard boundary: buffered input must never leak through it.\n',
    '\t# Respawn commit is the hard reset boundary: buffered input must never leak\n'
    '\t# through defeat/recovery. Entering defeat alone deliberately does not create\n'
    '\t# a second reset authority; the validated commit owns the reset exactly once.\n',
)
replace_once(
    "tests/character/test_input_buffer.gd",
    '\t_expect_true(failures, "defeat boundary commits before respawn", bool(player.call("_enter_defeated", &"damage")))\n'
    '\t_expect_true(failures, "accepted respawn commits", bool(player.call("commit_respawn", player.global_position)))\n',
    '\t_expect_true(failures, "defeat boundary enters disabled state", bool(player.call("_enter_defeated", &"damage")))\n'
    '\t_expect_equal(failures, "defeat entry preserves buffer until commit", String(player.call("get_buffered_action_name")), "attack")\n'
    '\t_expect_true(failures, "validated respawn commit succeeds", bool(player.call("commit_respawn", Vector3(2.0, 4.0, 6.0))))\n',
)

# Real composed-direction regression: use the controller/provider created by an actual Player,
# drive both locomotion directions through that controller, then start a real Player forward dodge.
marker = '\tif actions == null or stamina == null:\n\t\tfixture_root.free()\n\t\treturn failures\n\n'
insertion = marker + '''\t# The real Player/provider/controller chain must share one local -Z forward convention.\n\tvar directional_controller = player.get("animation_controller")\n\tvar directional_presentation = player.call("get_mannequin")\n\t_expect_true(failures, "real Player exposes configured animation controller", directional_controller != null)\n\tif directional_controller != null and directional_presentation != null:\n\t\t_expect_true(\n\t\t\tfailures,\n\t\t\t"real Player controller accepts local -Z forward locomotion",\n\t\t\tbool(directional_controller.call("update_locomotion", 1.0 / 60.0, Vector3(0.0, 0.0, -4.0), 0.0, true, false))\n\t\t)\n\t\t_expect_equal(\n\t\t\tfailures,\n\t\t\t"real Player local -Z resolves semantic walk-forward",\n\t\t\tString(directional_controller.call("last_locomotion_role")),\n\t\t\t"animation_role.locomotion.walk_forward"\n\t\t)\n\t\tvar directional_tree = directional_presentation.get("animation_tree")\n\t\t_expect_true(\n\t\t\tfailures,\n\t\t\t"voxel adapter receives -Z forward blend",\n\t\t\tdirectional_tree != null and Vector2(directional_tree.get("parameters/locomotion/blend_position")).is_equal_approx(Vector2(0.0, -1.0))\n\t\t)\n\t\tdirectional_controller.call("update_locomotion", 1.0 / 60.0, Vector3(0.0, 0.0, 4.0), 0.0, true, false)\n\t\t_expect_equal(\n\t\t\tfailures,\n\t\t\t"real Player local +Z resolves semantic walk-backward",\n\t\t\tString(directional_controller.call("last_locomotion_role")),\n\t\t\t"animation_role.locomotion.walk_backward"\n\t\t)\n\t\t_expect_true(\n\t\t\tfailures,\n\t\t\t"voxel adapter receives +Z backward blend",\n\t\t\tVector2(directional_tree.get("parameters/locomotion/blend_position")).is_equal_approx(Vector2(0.0, 1.0))\n\t\t)\n\t\tactions.call("reset")\n\t\tstamina.call("reset")\n\t\tplayer.get("visual_root").set("rotation", Vector3.ZERO)\n\t\t_expect_true(failures, "real Player forward dodge starts", bool(player.call("_start_dodge", Vector3.FORWARD)))\n\t\t_expect_equal(\n\t\t\tfailures,\n\t\t\t"real Player forward dodge resolves semantic forward role",\n\t\t\tString(directional_controller.call("last_animation_role")),\n\t\t\t"animation_role.action.dodge.forward"\n\t\t)\n\t\t_expect_equal(\n\t\t\tfailures,\n\t\t\t"real Player forward dodge reaches voxel forward presentation",\n\t\t\tString(directional_presentation.get("current_animation_state")),\n\t\t\t"dodge_forward"\n\t\t)\n\t\tactions.call("reset")\n\t\tstamina.call("reset")\n\t\tdirectional_presentation.call("reset_pose")\n\n'''
replace_once("tests/character/test_player_integration.gd", marker, insertion)

print("CHAR-RECONCILE repair patch applied")
