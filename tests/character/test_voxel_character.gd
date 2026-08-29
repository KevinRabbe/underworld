extends RefCounted

const BaselineFactory := preload("res://presentation/characters/voxel/baseline_survivor_factory.gd")
const Compiler := preload("res://presentation/characters/voxel/voxel_module_compiler.gd")
const VoxelPresentation := preload("res://presentation/characters/voxel/voxel_character_presentation.gd")
const PlayerScript := preload("res://gameplay/player/player.gd")
const VoxelProvider := preload("res://presentation/characters/voxel/voxel_character_presentation_provider.gd")
const MannequinProvider := preload("res://presentation/characters/player/prototype_mannequin/prototype_mannequin_presentation_provider.gd")


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_definition_contract(failures)
	_test_compiler_contract(failures)
	_test_runtime_presentation(failures)
	_test_player_default(tree, failures)
	return failures


static func _test_definition_contract(failures: Array[String]) -> void:
	var character = BaselineFactory.build()
	_expect_true(failures, "baseline voxel survivor validates", character.validate_definition().is_empty())
	_expect_equal(failures, "baseline voxel size", character.voxel_size, 0.05)
	_expect_true(failures, "baseline survivor is 36 voxels tall", is_equal_approx(character.presentation_bounds.size.y, 1.8))
	var palette_slots: Array[String] = []
	for entry_value in character.palette.entries:
		palette_slots.append(str(entry_value.get("slot", "")))
	_expect_true(failures, "expedition palette separates canvas and trouser materials", palette_slots.has("canvas_light") and palette_slots.has("trouser"))
	var jacket_parts: Array[String] = []
	for part_value in character.module_for_slot(&"torso_outfit").parts:
		jacket_parts.append(str(part_value.get("part_id", "")))
	_expect_true(failures, "expedition jacket authors connected shoulder, neck, and layered-front parts", jacket_parts.has("shoulder_l") and jacket_parts.has("shoulder_r") and jacket_parts.has("neck_connector") and jacket_parts.has("jacket_front"))
	var accessory_parts: Array[String] = []
	for part_value in character.module_for_slot(&"back_accessory").parts:
		accessory_parts.append(str(part_value.get("part_id", "")))
	_expect_true(failures, "expedition accessory module includes pack, roll, and hip pouch", accessory_parts.has("expedition_pack") and accessory_parts.has("pack_roll") and accessory_parts.has("hip_pouch"))
	var original_fingerprint: String = character.canonical_fingerprint()
	character.modules.reverse()
	_expect_equal(failures, "module order cannot change character fingerprint", character.canonical_fingerprint(), original_fingerprint)
	character.modules.reverse()
	var module = character.modules[0]
	var module_fingerprint: String = module.canonical_fingerprint()
	var first_part: Dictionary = module.parts[0]
	first_part["cells"].reverse()
	module.parts[0] = first_part
	_expect_equal(failures, "cell order cannot change module fingerprint", module.canonical_fingerprint(), module_fingerprint)
	var changed_palette = BaselineFactory.build().palette
	changed_palette.entries[0]["color"] = Color.MAGENTA
	_expect_true(failures, "palette changes presentation fingerprint", changed_palette.canonical_fingerprint() != character.palette.canonical_fingerprint())
	var malformed_module = BaselineFactory.build().modules[0]
	var malformed_part: Dictionary = malformed_module.parts[0]
	malformed_part["pivot"] = Vector3.ZERO
	malformed_part["rig_role"] = "rig_role.not_real"
	malformed_part["cells"][0]["palette_index"] = 999
	malformed_module.parts[0] = malformed_part
	var malformed_failures: Array[String] = malformed_module.validate_definition(character.palette.entries.size())
	_expect_true(failures, "malformed integer pivot fails", malformed_failures.any(func(value: String) -> bool: return value.contains("integer pivot")))
	_expect_true(failures, "unknown semantic rig role fails", malformed_failures.any(func(value: String) -> bool: return value.contains("unknown rig role")))
	_expect_true(failures, "invalid material index fails", malformed_failures.any(func(value: String) -> bool: return value.contains("invalid palette index")))
	_expect_equal(failures, "malformed module diagnostics reproduce canonically", malformed_module.validate_definition(character.palette.entries.size()), malformed_failures)
	var hand_module = character.module_for_slot(&"hands")
	var resolved_hand_parts: Array[Dictionary] = hand_module.resolved_parts()
	_expect_true(failures, "mirror-source module resolves authored cells", resolved_hand_parts[1]["cells"].size() > 0)
	var left_cell: Vector3i = resolved_hand_parts[0]["cells"][0]["position"]
	var right_cell: Vector3i = resolved_hand_parts[1]["cells"][0]["position"]
	_expect_equal(failures, "mirror-source module reflects the integer X coordinate", right_cell, Vector3i(-left_cell.x, left_cell.y, left_cell.z))


static func _test_compiler_contract(failures: Array[String]) -> void:
	var character = BaselineFactory.build()
	var part := {
		"part_id": "two_cells", "rig_role": "rig_role.root", "pivot": Vector3i.ZERO,
		"attachment_offset": Vector3.ZERO,
		"cells": [
			{"position": Vector3i.ZERO, "palette_index": 0},
			{"position": Vector3i.RIGHT, "palette_index": 0},
		],
	}
	var mesh_data = Compiler.compile_part(part, 0.05, character.palette, "fixture")
	_expect_true(failures, "two-cell voxel fixture compiles", mesh_data.success)
	_expect_equal(failures, "hidden shared faces are removed", int(mesh_data.metrics.get("visible_faces", 0)), 10)
	_expect_equal(failures, "coplanar faces greedily merge", int(mesh_data.metrics.get("merged_quads", 0)), 6)
	_expect_equal(failures, "merged cuboid emits twelve triangles", int(mesh_data.metrics.get("triangles", 0)), 12)
	_expect_true(failures, "compiled mesh owns finite positive bounds", mesh_data.bounds.position.is_finite() and mesh_data.bounds.size.is_finite() and mesh_data.bounds.get_volume() > 0.0)
	_expect_equal(failures, "compiled mesh metric records material surfaces", int(mesh_data.metrics.get("surface_count", -1)), mesh_data.surfaces.size())
	_expect_true(failures, "compiled mesh records compilation timing", int(mesh_data.metrics.get("compilation_usec", -1)) >= 0)
	for surface in mesh_data.surfaces:
		var vertices: PackedVector3Array = surface["vertices"]
		var normals: PackedVector3Array = surface["normals"]
		var colors: PackedColorArray = surface["colors"]
		var indices: PackedInt32Array = surface["indices"]
		_expect_equal(failures, "surface vertices and normals align", vertices.size(), normals.size())
		_expect_equal(failures, "surface vertices and colors align", vertices.size(), colors.size())
		_expect_equal(failures, "surface indices form triangles", indices.size() % 3, 0)
		for normal in normals:
			_expect_true(failures, "voxel normals are finite unit vectors", normal.is_finite() and is_equal_approx(normal.length(), 1.0))
		for color in colors:
			_expect_true(failures, "voxel colors are finite", is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a))
		for index in indices:
			_expect_true(failures, "voxel surface index is valid", index >= 0 and index < vertices.size())
		for triangle_index in range(0, indices.size(), 3):
			var edge_a: Vector3 = vertices[indices[triangle_index + 1]] - vertices[indices[triangle_index]]
			var edge_b: Vector3 = vertices[indices[triangle_index + 2]] - vertices[indices[triangle_index]]
			_expect_true(failures, "voxel triangles are non-degenerate", edge_a.cross(edge_b).length_squared() > 0.00000001)
	var repeated = Compiler.compile_part(part.duplicate(true), 0.05, character.palette, "fixture")
	_expect_equal(failures, "repeated compiler fingerprint", repeated.source_fingerprint, mesh_data.source_fingerprint)
	var alternate_palette = BaselineFactory.build().palette
	alternate_palette.entries[0]["color"] = Color.MAGENTA
	var recolored = Compiler.compile_part(part.duplicate(true), 0.05, alternate_palette, "fixture")
	_expect_true(failures, "palette changes compiled presentation fingerprint", recolored.source_fingerprint != mesh_data.source_fingerprint)
	var ao_groups: Dictionary = Compiler._visible_face_groups({"0,0,0": 0, "1,0,0": 0, "0,1,1": 0}, 4)
	var base_plane_ao_signatures: int = 0
	for group_key in ao_groups.keys():
		if str(group_key).begins_with("1|0|"):
			base_plane_ao_signatures += 1
	_expect_true(failures, "different baked AO signatures split coplanar greedy groups", base_plane_ao_signatures > 1)
	part["cells"].append({"position": Vector3i.ZERO, "palette_index": 0})
	var malformed = Compiler.compile_part(part, 0.05, character.palette, "fixture")
	_expect_true(failures, "duplicate voxel cell fails deterministically", not malformed.success and not malformed.diagnostics.is_empty())


static func _test_runtime_presentation(failures: Array[String]) -> void:
	var character := VoxelPresentation.new()
	character.build()
	_expect_true(failures, "voxel presentation preserves semantic rig", character.has_required_rig())
	_expect_true(failures, "voxel presentation owns AnimationTree", character.get_animation_tree() != null)
	var library: AnimationLibrary = character.animation_player.get_animation_library("")
	for clip_name in ["idle", "walk_forward", "walk_backward", "strafe_left", "strafe_right", "sprint", "jump", "fall", "dodge_forward", "dodge_backward", "dodge_left", "dodge_right", "attack_light", "attack_heavy", "block", "parry", "hit", "death", "tool_use"]:
		_expect_true(failures, "%s owns authored pose tracks" % clip_name, library.has_animation(clip_name) and library.get_animation(clip_name).get_track_count() > 0)
	_expect_true(failures, "heavy attack owns a fuller silhouette than light attack", library.get_animation("attack_heavy").get_track_count() > library.get_animation("attack_light").get_track_count())
	_expect_true(failures, "directional dodge poses include torso and all leg chains", library.get_animation("dodge_forward").get_track_count() >= 5 and library.get_animation("dodge_left").get_track_count() >= 5)
	_expect_true(failures, "tool-use pose coordinates torso, arm, forearm, and gaze", library.get_animation("tool_use").get_track_count() >= 4)
	var state_machine: AnimationNodeStateMachine = character.animation_tree.tree_root
	var locomotion: AnimationNodeBlendSpace2D = state_machine.get_node("locomotion")
	_expect_equal(failures, "directional locomotion blend owns five canonical points", locomotion.get_blend_point_count(), 5)
	_expect_equal(failures, "forward locomotion point has stable name", locomotion.find_blend_point_by_name(&"walk_forward"), 1)
	_expect_true(failures, "voxel presentation compiles modular parts", int(character.mesh_metrics.get("parts", 0)) >= 16)
	_expect_true(failures, "voxel presentation records main-thread resource timing", int(character.mesh_metrics.get("resource_creation_usec", -1)) >= 0)
	_expect_true(failures, "voxel presentation has canonical source fingerprint", character.presentation_fingerprint().begins_with("vpresentation1:sha256:"))
	var mesh_instances := character.find_children("Voxel*", "MeshInstance3D", true, false)
	_expect_equal(failures, "runtime owns one mesh node per rigid part", mesh_instances.size(), int(character.mesh_metrics.get("parts", 0)))
	var all_body_meshes := character.find_children("*", "MeshInstance3D", true, false)
	_expect_equal(failures, "voxel presentation contains no hidden mannequin duplicate meshes", all_body_meshes.size(), mesh_instances.size())
	_expect_true(failures, "runtime never creates one Node per voxel", mesh_instances.size() < int(character.mesh_metrics.get("cells", 0)))
	character.play_attack(0.6, &"heavy")
	_expect_equal(failures, "heavy attack selects distinct animation state", character.current_animation_state, &"attack_heavy")
	_expect_true(failures, "gameplay attack duration controls presentation playback", is_equal_approx(character.animation_player.speed_scale, 1.0 / 0.6))
	character.reset_pose()
	character.play_attack(0.4, &"light")
	_expect_equal(failures, "light attack selects light animation state", character.current_animation_state, &"attack_light")
	character.reset_pose()
	character.play_tool_use(0.4)
	_expect_equal(failures, "tool use selects dedicated animation state", character.current_animation_state, &"tool_use")
	character.reset_pose()
	character.play_dodge(Vector2.LEFT)
	_expect_equal(failures, "left dodge maps to directional animation state", character.current_animation_state, &"dodge_left")
	character.reset_pose()
	character.play_dodge(Vector2.UP)
	_expect_equal(failures, "backward dodge maps to directional animation state", character.current_animation_state, &"dodge_backward")
	character.reset_pose()
	character.update_voxel_visual(1.0 / 60.0, Vector3.ZERO, 4.0, false, false)
	_expect_equal(failures, "positive airborne velocity selects jump", character.current_animation_state, &"jump")
	character.update_voxel_visual(1.0 / 60.0, Vector3.ZERO, -4.0, false, false)
	_expect_equal(failures, "negative airborne velocity selects fall", character.current_animation_state, &"fall")
	character.play_death()
	character.update_voxel_visual(1.0 / 60.0, Vector3(0,0,4), 0.0, true, false)
	_expect_equal(failures, "death pose cannot be replaced by later locomotion", character.current_animation_state, &"death")
	character.reset_pose()
	_expect_equal(failures, "explicit presentation reset releases death pose", character.current_animation_state, &"locomotion")
	var recolored_definition = BaselineFactory.build()
	recolored_definition.palette.entries[0]["color"] = Color.MAGENTA
	var recolored_character := VoxelPresentation.new(recolored_definition)
	recolored_character.build()
	_expect_true(failures, "palette swap changes cached presentation fingerprint", recolored_character.presentation_fingerprint() != character.presentation_fingerprint())
	var base_head: MeshInstance3D = character.find_child("VoxelHeadSkin", true, false)
	var recolored_head: MeshInstance3D = recolored_character.find_child("VoxelHeadSkin", true, false)
	var base_colors: PackedColorArray = base_head.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var recolored_colors: PackedColorArray = recolored_head.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	_expect_true(failures, "palette swap bypasses stale global mesh cache colors", not base_colors.is_empty() and not recolored_colors.is_empty() and base_colors[0] != recolored_colors[0])
	recolored_character.free()
	character.free()


static func _test_player_default(tree: SceneTree, failures: Array[String]) -> void:
	if tree == null or tree.root == null:
		failures.append("voxel player fixture requires SceneTree")
		return
	var root := Node3D.new()
	tree.root.add_child(root)
	var player: Node = PlayerScript.new()
	player.set("character_presentation_provider", VoxelProvider.new())
	root.add_child(player)
	_expect_true(failures, "app-injected provider selects voxel presentation", player.get("character_presentation") is VoxelPresentation)
	var collision: CollisionShape3D = player.get_node_or_null("CollisionShape3D")
	_expect_true(failures, "Player collision remains gameplay capsule", collision != null and collision.shape is CapsuleShape3D)
	var collision_radius: float = collision.shape.radius
	var collision_height: float = collision.shape.height
	player.call("set_equipped_tool", "stone_axe")
	var voxel_character = player.get("character_presentation")
	var visual_root: Node3D = player.get("visual_root")
	_expect_equal(failures, "Player owns exactly one character presentation", visual_root.get_child_count(), 1)
	var visual_bounds: AABB = voxel_character.realized_visual_bounds()
	_expect_true(failures, "voxel feet align with Player ground origin (got %.3f)" % visual_bounds.position.y, visual_bounds.position.y >= -0.15 and visual_bounds.position.y <= 0.05)
	_expect_true(failures, "voxel survivor fills the gameplay capsule height (got %.3f)" % visual_bounds.end.y, visual_bounds.end.y >= 1.65 and visual_bounds.end.y <= 1.95)
	voxel_character.reset_pose()
	var reset_bounds: AABB = voxel_character.realized_visual_bounds()
	_expect_true(failures, "reset pose keeps voxel feet at ground origin (got %.3f)" % reset_bounds.position.y, reset_bounds.position.y >= -0.15 and reset_bounds.position.y <= 0.05)
	_expect_true(failures, "reset pose keeps full voxel survivor height (got %.3f)" % reset_bounds.end.y, reset_bounds.end.y >= 1.65 and reset_bounds.end.y <= 1.95)
	var tool_root: Node3D = voxel_character.get_tool_visual_root()
	_expect_true(failures, "equipped tool uses semantic hand socket", tool_root != null and tool_root.get_parent() == voxel_character.get_socket(&"hand_r"))
	_expect_true(failures, "equipped axe realizes voxel modules", tool_root != null and tool_root.find_children("VoxelHeld*", "MeshInstance3D", true, false).size() == 2)
	var player_meshes := player.find_children("*", "MeshInstance3D", true, false)
	var mesh_names: Dictionary = {}
	for mesh_value in player_meshes:
		var mesh: MeshInstance3D = mesh_value
		_expect_true(failures, "Player visual mesh names remain unique (%s)" % mesh.name, not mesh_names.has(mesh.name))
		mesh_names[mesh.name] = true
	voxel_character.set_held_item("stone_axe")
	_expect_equal(failures, "rapid held-item replacement cannot duplicate runtime tool parts", tool_root.find_children("VoxelHeld*", "MeshInstance3D", true, false).size(), 2)
	_expect_equal(failures, "rapid axe replacement owns one handle", tool_root.find_children("VoxelHeldAxeHandle", "MeshInstance3D", true, false).size(), 1)
	_expect_equal(failures, "rapid axe replacement owns one head", tool_root.find_children("VoxelHeldAxeHead", "MeshInstance3D", true, false).size(), 1)
	voxel_character.character_definition.palette.entries[0]["color"] = Color.MAGENTA
	_expect_true(failures, "palette replacement cannot alter Player collision", is_equal_approx(collision.shape.radius, collision_radius) and is_equal_approx(collision.shape.height, collision_height))

	var mannequin_player: Node = PlayerScript.new()
	mannequin_player.set("character_presentation_provider", MannequinProvider.new())
	root.add_child(mannequin_player)
	var mannequin_collision: CollisionShape3D = mannequin_player.get_node_or_null("CollisionShape3D")
	_expect_true(failures, "mannequin provider retains the same gameplay collision", mannequin_collision != null and is_equal_approx(mannequin_collision.shape.radius, collision_radius) and is_equal_approx(mannequin_collision.shape.height, collision_height))
	var voxel_actions = player.get("action_controller")
	var mannequin_actions = mannequin_player.get("action_controller")
	var voxel_started: bool = voxel_actions.try_start_attack(0.12, 0.08, 0.30)
	var mannequin_started: bool = mannequin_actions.try_start_attack(0.12, 0.08, 0.30)
	_expect_equal(failures, "voxel and mannequin providers produce identical gameplay action acceptance", voxel_started, mannequin_started)
	_expect_equal(failures, "voxel and mannequin providers produce identical gameplay action state", voxel_actions.state_name(), mannequin_actions.state_name())
	_expect_equal(failures, "voxel and mannequin providers produce identical gameplay action timing", voxel_actions.get_attack_total_duration(), mannequin_actions.get_attack_total_duration())
	root.free()


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition: failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected: failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])
