extends RefCounted

const BaselineFactory := preload("res://presentation/characters/voxel/baseline_survivor_factory.gd")
const Compiler := preload("res://presentation/characters/voxel/voxel_module_compiler.gd")
const VoxelPresentation := preload("res://presentation/characters/voxel/voxel_character_presentation.gd")
const PlayerScript := preload("res://gameplay/player/player.gd")


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
	for surface in mesh_data.surfaces:
		var vertices: PackedVector3Array = surface["vertices"]
		var normals: PackedVector3Array = surface["normals"]
		var indices: PackedInt32Array = surface["indices"]
		_expect_equal(failures, "surface vertices and normals align", vertices.size(), normals.size())
		for normal in normals:
			_expect_true(failures, "voxel normals are finite unit vectors", normal.is_finite() and is_equal_approx(normal.length(), 1.0))
		for index in indices:
			_expect_true(failures, "voxel surface index is valid", index >= 0 and index < vertices.size())
	var repeated = Compiler.compile_part(part.duplicate(true), 0.05, character.palette, "fixture")
	_expect_equal(failures, "repeated compiler fingerprint", repeated.source_fingerprint, mesh_data.source_fingerprint)
	part["cells"].append({"position": Vector3i.ZERO, "palette_index": 0})
	var malformed = Compiler.compile_part(part, 0.05, character.palette, "fixture")
	_expect_true(failures, "duplicate voxel cell fails deterministically", not malformed.success and not malformed.diagnostics.is_empty())


static func _test_runtime_presentation(failures: Array[String]) -> void:
	var character := VoxelPresentation.new()
	character.build()
	_expect_true(failures, "voxel presentation preserves semantic rig", character.has_required_rig())
	_expect_true(failures, "voxel presentation owns AnimationTree", character.get_animation_tree() != null)
	_expect_true(failures, "voxel presentation compiles modular parts", int(character.mesh_metrics.get("parts", 0)) >= 16)
	_expect_true(failures, "voxel presentation has canonical source fingerprint", character.presentation_fingerprint().begins_with("vpresentation1:sha256:"))
	var mesh_instances := character.find_children("Voxel*", "MeshInstance3D", true, false)
	_expect_equal(failures, "runtime owns one mesh node per rigid part", mesh_instances.size(), int(character.mesh_metrics.get("parts", 0)))
	_expect_true(failures, "runtime never creates one Node per voxel", mesh_instances.size() < int(character.mesh_metrics.get("cells", 0)))
	character.play_attack(0.6, &"heavy")
	_expect_equal(failures, "heavy attack selects distinct animation state", character.current_animation_state, &"attack_heavy")
	character.reset_pose()
	character.play_attack(0.4, &"light")
	_expect_equal(failures, "light attack selects light animation state", character.current_animation_state, &"attack_light")
	character.reset_pose()
	character.play_tool_use(0.4)
	_expect_equal(failures, "tool use selects dedicated animation state", character.current_animation_state, &"tool_use")
	character.free()


static func _test_player_default(tree: SceneTree, failures: Array[String]) -> void:
	if tree == null or tree.root == null:
		failures.append("voxel player fixture requires SceneTree")
		return
	var root := Node3D.new()
	tree.root.add_child(root)
	var player: Node = PlayerScript.new()
	root.add_child(player)
	_expect_true(failures, "normal Player defaults to voxel presentation", player.get("mannequin") is VoxelPresentation)
	var collision: CollisionShape3D = player.get_node_or_null("CollisionShape3D")
	_expect_true(failures, "Player collision remains gameplay capsule", collision != null and collision.shape is CapsuleShape3D)
	player.call("set_equipped_tool", "stone_axe")
	var voxel_character = player.get("mannequin")
	var tool_root: Node3D = voxel_character.get_tool_visual_root()
	_expect_true(failures, "equipped tool uses semantic hand socket", tool_root != null and tool_root.get_parent() == voxel_character.get_socket(&"hand_r"))
	_expect_true(failures, "equipped axe realizes voxel modules", tool_root != null and tool_root.find_children("VoxelHeld*", "MeshInstance3D", true, false).size() == 2)
	root.free()


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition: failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected: failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])
