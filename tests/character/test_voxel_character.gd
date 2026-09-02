extends RefCounted

const BaselineFactory := preload("res://presentation/characters/voxel/baseline_survivor_factory.gd")
const Compiler := preload("res://presentation/characters/voxel/voxel_module_compiler.gd")
const VoxelPresentation := preload("res://presentation/characters/voxel/voxel_character_presentation.gd")
const HumanoidPresentation := preload("res://presentation/characters/runtime/humanoid_character_presentation.gd")
const PrototypeMannequin := preload("res://presentation/characters/player/prototype_mannequin/prototype_mannequin.gd")
const PlayerScript := preload("res://gameplay/player/player.gd")
const VoxelProvider := preload("res://presentation/characters/voxel/voxel_character_presentation_provider.gd")
const MannequinProvider := preload("res://presentation/characters/player/prototype_mannequin/prototype_mannequin_presentation_provider.gd")
const SliceProfile := preload("res://presentation/characters/voxel/voxel_character_slice_profile.gd")
const FacetedProfile := preload("res://presentation/characters/faceted/faceted_humanoid_body_profile.gd")
const FacetedCompiler := preload("res://presentation/characters/faceted/faceted_body_compiler.gd")


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_definition_contract(failures)
	_test_slice_profile_contract(failures)
	_test_compiler_contract(failures)
	_test_faceted_compiler_contract(failures)
	_test_unarmored_character_creation_contract(failures)
	_test_runtime_presentation(failures)
	_test_player_default(tree, failures)
	return failures


static func _test_slice_profile_contract(failures: Array[String]) -> void:
	var profile = SliceProfile.new().configure("fixture.survivor", [
		{"y": 1, "layers": [{"layer_id": "body", "priority": 0, "palette_index": 0, "semantic": "body", "mask": [".#.", "###"]}]},
		{"y": 0, "layers": [{"layer_id": "body", "priority": 0, "palette_index": 0, "semantic": "body", "mask": ["###", "###"]}]},
	])
	_expect_true(failures, "slice profile validates rectangular layered rows", profile.validate(1).is_empty())
	var cells: Array[Dictionary] = profile.resolved_cells()
	_expect_equal(failures, "slice rows resolve deterministically bottom-to-top", cells[0]["position"], Vector3i(0, 0, 0))
	var fingerprint: String = profile.canonical_fingerprint()
	profile.rows.reverse()
	_expect_equal(failures, "slice row order cannot change fingerprint", profile.canonical_fingerprint(), fingerprint)
	var malformed = SliceProfile.new().configure("fixture.bad", [{"y": 0, "layers": [{"layer_id": "bad", "priority": 0, "palette_index": 4, "mask": ["##", "."]}]}])
	_expect_true(failures, "malformed slice mask diagnostics are deterministic", malformed.validate(1) == malformed.validate(1) and not malformed.validate(1).is_empty())


static func _test_definition_contract(failures: Array[String]) -> void:
	var character = BaselineFactory.build()
	_expect_true(failures, "baseline faceted survivor definition validates", character.validate_definition().is_empty())
	_expect_true(failures, "baseline voxel size is high-detail presentation pitch", is_equal_approx(character.voxel_size, 0.032142857))
	_expect_true(failures, "baseline survivor is 56 authored voxels tall at 1.8 m", is_equal_approx(character.presentation_bounds.size.y, 1.8))
	_expect_true(failures, "faceted survivor is the normal presentation provider", character.use_faceted_body)
	var body_profile = character.faceted_body_profile
	_expect_true(failures, "broad-neutral faceted profile validates", body_profile != null and body_profile.validate().is_empty())
	_expect_equal(failures, "faceted profile derives 56 editor-ready rows", body_profile.derived_rows().size(), 56)
	_expect_true(failures, "faceted profile locks broad-neutral proportions", is_equal_approx(body_profile.shoulder_width, 0.62) and is_equal_approx(body_profile.chest_width, 0.515) and is_equal_approx(body_profile.pelvis_width, 0.45) and is_equal_approx(body_profile.thigh_diameter, 0.225) and is_equal_approx(body_profile.calf_diameter, 0.18))
	var reordered_profile = FacetedProfile.new().configure("character.body.frontier_broad_neutral", {"calf_diameter": 0.18, "shoulder_width": 0.62, "chest_width": 0.515})
	_expect_equal(failures, "profile input ordering cannot change canonical identity", reordered_profile.canonical_fingerprint(), body_profile.canonical_fingerprint())
	var work_variant = BaselineFactory.build_variant("work")
	var armor_variant = BaselineFactory.build_variant("light_armor")
	_expect_true(failures, "preview variants change presentation fingerprints", work_variant.canonical_fingerprint() != character.canonical_fingerprint() and armor_variant.canonical_fingerprint() != character.canonical_fingerprint())
	var slim_variant = BaselineFactory.build_variant("slim")
	var heavy_variant = BaselineFactory.build_variant("heavy")
	_expect_true(failures, "anatomy controls produce deterministic presentation variants", slim_variant.validate_definition().is_empty() and heavy_variant.validate_definition().is_empty() and slim_variant.canonical_fingerprint() != heavy_variant.canonical_fingerprint())
	_expect_true(failures, "anatomy variants preserve presentation height", is_equal_approx(slim_variant.faceted_body_profile.height, 1.8) and is_equal_approx(heavy_variant.faceted_body_profile.height, 1.8))
	var hair_variant = BaselineFactory.build()
	hair_variant.faceted_hair_id = "hair.frontier.cropped.control"
	_expect_true(failures, "hair selection changes presentation identity only", hair_variant.canonical_fingerprint() != character.canonical_fingerprint() and hair_variant.rig_profile_id == character.rig_profile_id)
	var outfit_variant = BaselineFactory.build()
	outfit_variant.faceted_outfit_definition.outfit_id = "outfit.frontier.expedition.control"
	_expect_true(failures, "outfit selection changes presentation identity only", outfit_variant.canonical_fingerprint() != character.canonical_fingerprint() and outfit_variant.rig_profile_id == character.rig_profile_id)
	var palette_slots: Array[String] = []
	for entry_value in character.palette.entries:
		palette_slots.append(str(entry_value.get("slot", "")))
	_expect_true(failures, "expedition palette separates canvas and trouser materials", palette_slots.has("canvas_light") and palette_slots.has("trouser"))
	var jacket_parts: Array[String] = []
	for part_value in character.module_for_slot(&"torso_outfit").parts:
		jacket_parts.append(str(part_value.get("part_id", "")))
	_expect_true(failures, "expedition jacket authors connected shoulder, neck, layered shell, and field details", jacket_parts.has("shoulder_l") and jacket_parts.has("shoulder_r") and jacket_parts.has("neck_connector") and jacket_parts.has("jacket_front") and jacket_parts.has("jacket_lower") and jacket_parts.has("jacket_trim") and jacket_parts.has("belt_buckle"))
	var leg_parts: Array[String] = []
	for part_value in character.module_for_slot(&"leg_outfit").parts:
		leg_parts.append(str(part_value.get("part_id", "")))
	_expect_true(failures, "expedition leg module includes articulated boot shafts", leg_parts.has("boot_shaft_l") and leg_parts.has("boot_shaft_r"))
	var accessory_parts: Array[String] = []
	for part_value in character.module_for_slot(&"back_accessory").parts:
		accessory_parts.append(str(part_value.get("part_id", "")))
	_expect_true(failures, "expedition accessory module includes pack, roll, buckles, and hip pouch", accessory_parts.has("expedition_pack") and accessory_parts.has("pack_roll") and accessory_parts.has("pack_buckles") and accessory_parts.has("hip_pouch"))
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
	_expect_equal(failures, "chamfered merged cuboid emits sixty triangles", int(mesh_data.metrics.get("triangles", 0)), 60)
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


static func _test_faceted_compiler_contract(failures: Array[String]) -> void:
	var character = BaselineFactory.build()
	var mesh_data = FacetedCompiler.compile(character.faceted_body_profile, character.palette, character.faceted_outfit_definition)
	_expect_true(failures, "faceted broad-neutral survivor compiles", mesh_data.success and mesh_data.diagnostics.is_empty())
	_expect_true(failures, "faceted compiler emits one multi-surface skinned payload", mesh_data.surfaces.size() >= 8)
	_expect_true(failures, "faceted survivor owns substantial indexed geometry", int(mesh_data.metrics.get("vertices", 0)) > 500 and int(mesh_data.metrics.get("triangles", 0)) > 150)
	_expect_true(failures, "faceted art pass retains compact game-ready geometry", int(mesh_data.metrics.get("vertices", 0)) < 10000 and int(mesh_data.metrics.get("triangles", 0)) < 4000)
	_expect_equal(failures, "covered body zones are omitted beneath outfit shells", int(mesh_data.metrics.get("omitted_covered_body_zones", 0)), character.faceted_outfit_definition.coverage_zones.size())
	var overlap_margins: Dictionary = mesh_data.metrics.get("joint_overlap_margins", {})
	_expect_equal(failures, "faceted compiler records every articulated joint boundary", overlap_margins.size(), 12)
	for joint_name in overlap_margins.keys():
		_expect_true(failures, "faceted joint %s has no uncovered geometric gap" % joint_name, float(overlap_margins[joint_name]) >= 0.0)
	_expect_true(failures, "faceted survivor bounds match grounded 1.8 m target", mesh_data.bounds.position.y >= -0.001 and mesh_data.bounds.end.y >= 1.79 and mesh_data.bounds.end.y <= 1.82)
	var owns_facet_tone_variation := false
	for surface in mesh_data.surfaces:
		var vertices: PackedVector3Array = surface["vertices"]
		var normals: PackedVector3Array = surface["normals"]
		var colors: PackedColorArray = surface["colors"]
		var uvs: PackedVector2Array = surface["uvs"]
		var bones: PackedInt32Array = surface["bones"]
		var weights: PackedFloat32Array = surface["weights"]
		var indices: PackedInt32Array = surface["indices"]
		_expect_equal(failures, "faceted vertices, normals, colors, and UVs align", [normals.size(), colors.size(), uvs.size()], [vertices.size(), vertices.size(), vertices.size()])
		_expect_equal(failures, "faceted mesh stores four bones per vertex", bones.size(), vertices.size() * 4)
		_expect_equal(failures, "faceted mesh stores four weights per vertex", weights.size(), vertices.size() * 4)
		if colors.size() > 1:
			for color_index in range(1, colors.size()):
				if colors[color_index] != colors[0]:
					owns_facet_tone_variation = true
					break
		for vertex_index in range(vertices.size()):
			_expect_true(failures, "faceted vertices are finite", vertices[vertex_index].is_finite())
			_expect_true(failures, "faceted normals are finite and unit length", normals[vertex_index].is_finite() and is_equal_approx(normals[vertex_index].length(), 1.0))
			var weight_sum := 0.0
			for slot in range(4):
				var offset := vertex_index * 4 + slot
				_expect_true(failures, "faceted skin references valid semantic bones", bones[offset] >= 0 and bones[offset] < 21)
				_expect_true(failures, "faceted skin weights are finite and non-negative", is_finite(weights[offset]) and weights[offset] >= 0.0)
				weight_sum += weights[offset]
			_expect_true(failures, "faceted skin weights normalize per vertex", is_equal_approx(weight_sum, 1.0))
		for triangle_index in range(0, indices.size(), 3):
			var ia := indices[triangle_index]
			var ib := indices[triangle_index + 1]
			var ic := indices[triangle_index + 2]
			_expect_true(failures, "faceted indices reference emitted vertices", ia >= 0 and ia < vertices.size() and ib >= 0 and ib < vertices.size() and ic >= 0 and ic < vertices.size())
			if ia >= 0 and ia < vertices.size() and ib >= 0 and ib < vertices.size() and ic >= 0 and ic < vertices.size():
				var face_normal := (vertices[ib] - vertices[ia]).cross(vertices[ic] - vertices[ia])
				_expect_true(failures, "faceted triangles are non-degenerate", face_normal.length_squared() > 0.00000001)
				_expect_true(failures, "faceted winding matches outward flat normals", face_normal.normalized().dot(normals[ia]) > 0.99)
	_expect_true(failures, "faceted palette owns restrained deterministic per-face tonal variation", owns_facet_tone_variation)
	var repeated = FacetedCompiler.compile(character.faceted_body_profile, character.palette, character.faceted_outfit_definition)
	_expect_equal(failures, "faceted compilation reproduces exact fingerprint", repeated.source_fingerprint, mesh_data.source_fingerprint)
	_expect_equal(failures, "faceted compilation reproduces exact surface descriptor", repeated.canonical_surface_descriptor(), mesh_data.canonical_surface_descriptor())
	for surface_index in range(mesh_data.surfaces.size()):
		var original_surface: Dictionary = mesh_data.surfaces[surface_index]
		var repeated_surface: Dictionary = repeated.surfaces[surface_index]
		_expect_true(failures, "faceted compilation reproduces exact packed arrays for surface %d" % surface_index,
			original_surface["vertices"] == repeated_surface["vertices"] and
			original_surface["normals"] == repeated_surface["normals"] and
			original_surface["colors"] == repeated_surface["colors"] and
			original_surface["uvs"] == repeated_surface["uvs"] and
			original_surface["bones"] == repeated_surface["bones"] and
			original_surface["weights"] == repeated_surface["weights"] and
			original_surface["indices"] == repeated_surface["indices"])
	var malformed_profile = FacetedProfile.new().configure("fixture.invalid", {"shoulder_width": 0.30, "chest_width": 0.48, "ankle_width": 0.22})
	var malformed = FacetedCompiler.compile(malformed_profile, character.palette, character.faceted_outfit_definition)
	_expect_true(failures, "malformed anatomy fails deterministically", not malformed.success and malformed.diagnostics == FacetedCompiler.compile(malformed_profile, character.palette, character.faceted_outfit_definition).diagnostics)
	var malformed_outfit = character.faceted_outfit_definition.duplicate(true)
	malformed_outfit.coverage_zones.append(&"unknown_zone")
	malformed_outfit.shell_offsets[&"torso"] = 0.5
	var malformed_outfit_mesh = FacetedCompiler.compile(character.faceted_body_profile, character.palette, malformed_outfit)
	_expect_true(failures, "malformed coverage and shell offsets fail deterministically", not malformed_outfit_mesh.success and malformed_outfit_mesh.diagnostics.any(func(value: String) -> bool: return value.contains("unknown coverage zone")) and malformed_outfit_mesh.diagnostics.any(func(value: String) -> bool: return value.contains("shell offset")))
	var reordered_outfit = character.faceted_outfit_definition.duplicate(true)
	reordered_outfit.coverage_zones.reverse()
	_expect_equal(failures, "coverage input ordering cannot change canonical identity", reordered_outfit.canonical_fingerprint(), character.faceted_outfit_definition.canonical_fingerprint())
	var incomplete_palette = character.palette.duplicate(true)
	incomplete_palette.entries.resize(4)
	var missing_material_mesh = FacetedCompiler.compile(character.faceted_body_profile, incomplete_palette, character.faceted_outfit_definition)
	_expect_true(failures, "missing semantic palette references fail deterministically", not missing_material_mesh.success and missing_material_mesh.diagnostics.any(func(value: String) -> bool: return value.contains("missing required semantic entries")))


static func _test_unarmored_character_creation_contract(failures: Array[String]) -> void:
	var clothed = BaselineFactory.build()
	var unarmored = BaselineFactory.build_variant("unarmored")
	_expect_true(failures, "unarmored character-creation definition validates", unarmored.validate_definition().is_empty())
	_expect_true(failures, "unarmored mode is explicit and presentation-only", unarmored.allow_unarmored_faceted_body and unarmored.faceted_outfit_definition == null)
	var mesh = FacetedCompiler.compile(unarmored.faceted_body_profile, unarmored.palette, unarmored.faceted_outfit_definition)
	_expect_true(failures, "unarmored body compiles without clothing resource", mesh.success and mesh.diagnostics.is_empty())
	_expect_equal(failures, "unarmored body reports no covered zones", int(mesh.metrics.get("coverage_zone_count", -1)), 0)
	var clothing_palette_indices := [1, 2, 3, 7, 8, 9, 10, 11]
	var has_clothing_surface := false
	for surface in mesh.surfaces:
		if clothing_palette_indices.has(int(surface["palette_index"])):
			has_clothing_surface = true
	_expect_true(failures, "unarmored compile contains no clothing surfaces", not has_clothing_surface)
	var clothed_mesh = FacetedCompiler.compile(clothed.faceted_body_profile, clothed.palette, clothed.faceted_outfit_definition)
	_expect_true(failures, "removing outfit changes presentation geometry identity", clothed_mesh.source_fingerprint != mesh.source_fingerprint)
	_expect_equal(failures, "unarmored gameplay rig identity is unchanged", unarmored.rig_profile_id, clothed.rig_profile_id)


static func _test_runtime_presentation(failures: Array[String]) -> void:
	var character := VoxelPresentation.new()
	character.build()
	var mannequin := PrototypeMannequin.new()
	mannequin.build()
	_expect_true(failures, "voxel and mannequin are sibling humanoid presentations", character is HumanoidPresentation and mannequin is HumanoidPresentation and character.get_script().get_base_script() == HumanoidPresentation and mannequin.get_script().get_base_script() == HumanoidPresentation)
	mannequin.free()
	_expect_true(failures, "voxel presentation preserves semantic rig", character.has_required_rig())
	character.skeleton.force_update_all_bone_transforms()
	var pelvis_pose: Vector3 = character.skeleton.get_bone_global_pose(character.skeleton.find_bone("pelvis")).origin
	var head_pose: Vector3 = character.skeleton.get_bone_global_pose(character.skeleton.find_bone("head")).origin
	var foot_pose: Vector3 = character.skeleton.get_bone_global_pose(character.skeleton.find_bone("foot_l")).origin
	_expect_true(failures, "profile-derived bone translations remain assembled after reset", pelvis_pose.y > 0.8 and head_pose.y >= 1.59 and foot_pose.y > 0.05 and foot_pose.y < 0.15)
	_expect_true(failures, "voxel presentation owns AnimationTree", character.get_animation_tree() != null)
	var library: AnimationLibrary = character.animation_player.get_animation_library("")
	for clip_name in ["idle", "walk_forward", "walk_backward", "strafe_left", "strafe_right", "sprint", "jump", "fall", "dodge_forward", "dodge_backward", "dodge_left", "dodge_right", "attack_light", "attack_heavy", "block", "parry", "hit", "death", "tool_use"]:
		_expect_true(failures, "%s owns authored pose tracks" % clip_name, library.has_animation(clip_name) and library.get_animation(clip_name).get_track_count() > 0)
		var clip: Animation = library.get_animation(clip_name)
		for track_index in range(clip.get_track_count()):
			_expect_true(failures, "%s remains rotation-only with no root motion" % clip_name, str(clip.track_get_path(track_index)).ends_with("/rotation"))
	for action_clip_name in ["jump", "fall", "dodge_forward", "dodge_backward", "dodge_left", "dodge_right", "attack_light", "attack_heavy", "block", "parry", "hit", "death", "tool_use"]:
		var action_clip: Animation = library.get_animation(action_clip_name)
		_expect_true(failures, "%s owns complete left/right upper-arm silhouette tracks" % action_clip_name, _has_bone_rotation_track(action_clip, character.skeleton, "upperarm_l") and _has_bone_rotation_track(action_clip, character.skeleton, "upperarm_r"))
	_expect_true(failures, "heavy attack owns a fuller silhouette than light attack", library.get_animation("attack_heavy").get_track_count() > library.get_animation("attack_light").get_track_count())
	_expect_true(failures, "idle pose lowers both articulated arm chains", library.get_animation("idle").get_track_count() >= 6)
	_expect_true(failures, "directional dodge poses include torso and all leg chains", library.get_animation("dodge_forward").get_track_count() >= 5 and library.get_animation("dodge_left").get_track_count() >= 5)
	_expect_true(failures, "tool-use pose coordinates torso, arm, forearm, and gaze", library.get_animation("tool_use").get_track_count() >= 4)
	var state_machine: AnimationNodeStateMachine = character.animation_tree.tree_root
	var locomotion: AnimationNodeBlendSpace2D = state_machine.get_node("locomotion")
	_expect_equal(failures, "directional locomotion blend owns five canonical points", locomotion.get_blend_point_count(), 5)
	var forward_index: int = int(character.locomotion_point_indices.get(&"walk_forward", -1))
	_expect_equal(failures, "project-owned forward locomotion point has stable index", forward_index, 1)
	_expect_true(failures, "forward locomotion node and position resolve without engine-specific names", forward_index >= 0 and locomotion.get_blend_point_node(forward_index).animation == &"walk_forward" and locomotion.get_blend_point_position(forward_index).is_equal_approx(Vector2(0, 1)))
	var expected_points := {&"idle": Vector2.ZERO, &"walk_forward": Vector2(0,1), &"walk_backward": Vector2(0,-1), &"strafe_left": Vector2(-1,0), &"strafe_right": Vector2(1,0)}
	for point_name in expected_points.keys():
		var point_index: int = int(character.locomotion_point_indices.get(point_name, -1))
		_expect_true(failures, "%s locomotion point resolves canonically" % point_name, point_index >= 0 and locomotion.get_blend_point_node(point_index).animation == point_name and locomotion.get_blend_point_position(point_index).is_equal_approx(expected_points[point_name]))
	_expect_equal(failures, "faceted presentation realizes one coherent body mesh", int(character.mesh_metrics.get("parts", 0)), 1)
	_expect_true(failures, "voxel presentation records main-thread resource timing", int(character.mesh_metrics.get("resource_creation_usec", -1)) >= 0)
	_expect_true(failures, "voxel presentation has canonical source fingerprint", character.presentation_fingerprint().begins_with("vpresentation1:sha256:"))
	var mesh_instances := character.find_children("FacetedSurvivorBody", "MeshInstance3D", true, false)
	_expect_equal(failures, "runtime owns exactly one faceted body mesh", mesh_instances.size(), 1)
	var all_body_meshes := character.find_children("*", "MeshInstance3D", true, false)
	_expect_equal(failures, "voxel presentation contains no hidden mannequin duplicate meshes", all_body_meshes.size(), mesh_instances.size())
	_expect_true(failures, "runtime never creates one Node per faceted triangle", mesh_instances.size() < int(character.mesh_metrics.get("triangles", 0)))
	var cached_character := VoxelPresentation.new(BaselineFactory.build())
	cached_character.build()
	_expect_true(failures, "faceted runtime cache is keyed by presentation inputs", int(cached_character.mesh_metrics.get("cache_hits", 0)) >= 1 and cached_character.presentation_fingerprint() == character.presentation_fingerprint())
	cached_character.free()
	var legacy_character := VoxelPresentation.new(BaselineFactory.build_legacy_voxel())
	legacy_character.build()
	var legacy_meshes := legacy_character.find_children("Voxel*", "MeshInstance3D", true, false)
	_expect_true(failures, "legacy voxel body remains an explicit regression fixture", legacy_meshes.size() >= 16 and legacy_character.find_child("FacetedSurvivorBody", true, false) == null)
	legacy_character.free()
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
	var base_head: MeshInstance3D = character.find_child("FacetedSurvivorBody", true, false)
	var recolored_head: MeshInstance3D = recolored_character.find_child("FacetedSurvivorBody", true, false)
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
	_expect_true(failures, "faceted survivor fills the gameplay capsule height (got %.3f)" % visual_bounds.end.y, visual_bounds.end.y >= 1.65 and visual_bounds.end.y <= 1.95)
	voxel_character.reset_pose()
	var reset_bounds: AABB = voxel_character.realized_visual_bounds()
	_expect_true(failures, "reset pose keeps voxel feet at ground origin (got %.3f)" % reset_bounds.position.y, reset_bounds.position.y >= -0.15 and reset_bounds.position.y <= 0.05)
	_expect_true(failures, "reset pose keeps full faceted survivor height (got %.3f)" % reset_bounds.end.y, reset_bounds.end.y >= 1.65 and reset_bounds.end.y <= 1.95)
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
	for variant_id in ["slim", "heavy"]:
		var variant_player: Node = PlayerScript.new()
		variant_player.set("character_presentation_provider", VoxelProvider.new(BaselineFactory.build_variant(variant_id)))
		root.add_child(variant_player)
		var variant_collision: CollisionShape3D = variant_player.get_node_or_null("CollisionShape3D")
		var variant_actions = variant_player.get("action_controller")
		_expect_true(failures, "%s anatomy keeps gameplay collision unchanged" % variant_id, variant_collision != null and is_equal_approx(variant_collision.shape.radius, collision_radius) and is_equal_approx(variant_collision.shape.height, collision_height))
		_expect_equal(failures, "%s anatomy keeps gameplay action acceptance unchanged" % variant_id, variant_actions.try_start_attack(0.12, 0.08, 0.30), true)

	var scaled_definition = BaselineFactory.build()
	scaled_definition.presentation_scale = 1.25
	var scaled_player: Node = PlayerScript.new()
	var scaled_provider = VoxelProvider.new(scaled_definition)
	scaled_player.set("character_presentation_provider", scaled_provider)
	root.add_child(scaled_player)
	var scaled_collision: CollisionShape3D = scaled_player.get_node_or_null("CollisionShape3D")
	var scaled_character = scaled_player.get("character_presentation")
	var scaled_root: Node3D = scaled_character.get_tool_visual_root()
	var wrong_root := Node3D.new()
	scaled_character.add_child(wrong_root)
	_expect_true(failures, "voxel provider rejects a non-semantic attachment root", not scaled_provider.realize_held_item(scaled_character, wrong_root, "stone_axe") and wrong_root.get_child_count() == 0)
	_expect_true(failures, "voxel provider realizes held items through the supplied semantic root", scaled_provider.realize_held_item(scaled_character, scaled_root, "stone_axe"))
	var scaled_body: MeshInstance3D = scaled_character.find_child("FacetedSurvivorBody", true, false)
	var scaled_tool: MeshInstance3D = scaled_root.find_child("VoxelHeldAxeHandle", true, false)
	_expect_true(failures, "body and held-item meshes apply the same presentation scale", scaled_body != null and scaled_tool != null and scaled_body.scale.is_equal_approx(Vector3.ONE * 1.25) and scaled_tool.scale.is_equal_approx(Vector3.ONE * 1.25))
	_expect_true(failures, "non-default presentation scale cannot alter Player collision", scaled_collision != null and is_equal_approx(scaled_collision.shape.radius, collision_radius) and is_equal_approx(scaled_collision.shape.height, collision_height))

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


static func _has_bone_rotation_track(animation: Animation, skeleton: Skeleton3D, bone_name: String) -> bool:
	var bone_index: int = skeleton.find_bone(bone_name)
	if bone_index < 0:
		return false
	var expected_path := NodePath("Skeleton3D:bones/%d/rotation" % bone_index)
	return animation.find_track(expected_path, Animation.TYPE_VALUE) >= 0
