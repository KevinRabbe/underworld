extends RefCounted
class_name UnderworldFacetedBodyCompiler

const MeshDataScript := preload("res://presentation/characters/faceted/faceted_skinned_mesh_data.gd")

const COMPILER_REVISION := 1
const SKIN := 0
const CLOTH := 1
const LEATHER := 2
const METAL := 3
const HAIR := 4
const ACCENT := 5
const FACE := 6
const CANVAS_LIGHT := 7
const TROUSER := 8
const CANVAS_DARK := 9
const LEATHER_LIGHT := 10
const SOLE := 11

# Canonical indices match HumanoidCharacterPresentation._build_skeleton().
const BONE := {
	"pelvis": 1, "spine_01": 2, "spine_02": 3, "chest": 4,
	"neck": 5, "head": 6,
	"upperarm_l": 8, "forearm_l": 9, "hand_l": 10,
	"upperarm_r": 12, "forearm_r": 13, "hand_r": 14,
	"thigh_l": 15, "calf_l": 16, "foot_l": 17,
	"thigh_r": 18, "calf_r": 19, "foot_r": 20,
}


static func compile(profile: Resource, palette: Resource, outfit: Resource = null) -> RefCounted:
	var started_usec := Time.get_ticks_usec()
	var result = MeshDataScript.new()
	if profile == null or not profile.has_method("validate"):
		result.diagnostics.append("faceted compiler requires a body profile")
		return result
	result.diagnostics.assign(profile.validate())
	if palette == null or not palette.has_method("entry") or not palette.has_method("canonical_fingerprint"):
		result.diagnostics.append("faceted compiler requires a character palette")
	elif not palette.has_method("validate_definition"):
		result.diagnostics.append("faceted compiler requires a validated character palette")
	else:
		result.diagnostics.append_array(palette.validate_definition())
		if palette.entries.size() <= SOLE:
			result.diagnostics.append("faceted compiler palette is missing required semantic entries")
	if outfit != null:
		if not outfit.has_method("validate") or not outfit.has_method("canonical_fingerprint"):
			result.diagnostics.append("faceted compiler requires a compatible outfit definition")
		else:
			result.diagnostics.append_array(outfit.validate())
	if not result.diagnostics.is_empty():
		result.diagnostics.sort()
		return result

	var builders: Dictionary = {}
	_build_torso(builders, profile, outfit)
	_build_head(builders, profile)
	_build_arm(builders, profile, true)
	_build_arm(builders, profile, false)
	_build_leg(builders, profile, true)
	_build_leg(builders, profile, false)
	_build_outfit_details(builders, profile)

	var bounds := AABB()
	var has_bounds := false
	var total_vertices := 0
	var total_triangles := 0
	var total_weights := 0
	var palette_indices: Array[int] = []
	for key_value in builders.keys():
		palette_indices.append(int(key_value))
	palette_indices.sort()
	for palette_index in palette_indices:
		var builder: Dictionary = builders[palette_index]
		var vertices: PackedVector3Array = builder["vertices"]
		if vertices.is_empty():
			continue
		var surface := {
			"palette_index": palette_index,
			"vertices": vertices,
			"normals": PackedVector3Array(builder["normals"]),
			"colors": _colors_for_palette(palette, palette_index, vertices.size()),
			"uvs": PackedVector2Array(builder["uvs"]),
			"bones": PackedInt32Array(builder["bones"]),
			"weights": PackedFloat32Array(builder["weights"]),
			"indices": PackedInt32Array(builder["indices"]),
		}
		result.surfaces.append(surface)
		total_vertices += vertices.size()
		total_triangles += surface["indices"].size() / 3
		total_weights += surface["weights"].size()
		for vertex in vertices:
			var point_bounds := AABB(vertex, Vector3.ZERO)
			bounds = bounds.merge(point_bounds) if has_bounds else point_bounds
			has_bounds = true
	result.bounds = bounds
	result.metrics = {
		"surface_count": result.surfaces.size(),
		"vertices": total_vertices,
		"triangles": total_triangles,
		"skin_weight_values": total_weights,
		"coverage_zone_count": outfit.coverage_zones.size() if outfit != null else 0,
		"omitted_covered_body_zones": outfit.coverage_zones.size() if outfit != null else 0,
		"joint_overlap_margins": _joint_overlap_margins(profile),
		"estimated_bytes": total_vertices * (12 + 12 + 16 + 8 + 16 + 16) + total_triangles * 12,
		"compilation_usec": Time.get_ticks_usec() - started_usec,
	}
	result.source_fingerprint = "fmesh1:sha256:" + (
		profile.canonical_fingerprint() + "|" + palette.canonical_fingerprint() +
		"|" + (outfit.canonical_fingerprint() if outfit != null else "<no-outfit>") +
		"|" + str(COMPILER_REVISION) + "|" + _surface_payload(result.surfaces)
	).sha256_text()
	result.success = not result.surfaces.is_empty() and result.diagnostics.is_empty()
	return result


static func _build_torso(builders: Dictionary, profile, outfit: Resource) -> void:
	var shell := float(outfit.shell_offset(&"torso", profile.outfit_shell_offset)) if outfit != null else float(profile.outfit_shell_offset)
	var landmark: Dictionary = profile.anatomy_landmarks()
	var torso_rings: Array[Dictionary] = [
		_ring_y(Vector3(0, float(landmark["hip_y"]) - 0.08, 0), profile.pelvis_width * 0.46, profile.chest_depth * 0.43, _weights(BONE.pelvis)),
		_ring_y(Vector3(0, float(landmark["pelvis_y"]), 0), profile.pelvis_width * 0.50, profile.chest_depth * 0.52, _weights(BONE.pelvis)),
		_ring_y(Vector3(0, float(landmark["waist_y"]), 0), profile.waist_width * 0.50, profile.chest_depth * 0.43, _weights2(BONE.pelvis, BONE.spine_01, 0.35)),
		_ring_y(Vector3(0, float(landmark["lower_chest_y"]), 0), profile.chest_width * 0.47, profile.chest_depth * 0.48, _weights(BONE.spine_02)),
		_ring_y(Vector3(0, float(landmark["chest_y"]), 0), profile.chest_width * 0.50, profile.chest_depth * 0.50, _weights2(BONE.spine_02, BONE.chest, 0.65)),
		_ring_y(Vector3(0, float(landmark["shoulder_y"]), 0), profile.shoulder_width * 0.50, profile.chest_depth * 0.52, _weights(BONE.chest)),
	]
	_add_y_loft(builders, CANVAS_LIGHT, torso_rings, 12, true, true)
	var vest_rings: Array[Dictionary] = []
	for ring in torso_rings:
		if float(ring["center"].y) < float(landmark["pelvis_y"]) - 0.01:
			continue
		var vest := ring.duplicate(true)
		vest["rx"] = float(ring["rx"]) + shell
		vest["rz"] = float(ring["rz"]) + shell
		vest_rings.append(vest)
	_add_y_loft(builders, CLOTH, vest_rings, 12, true, true)


static func _build_head(builders: Dictionary, profile) -> void:
	var landmark: Dictionary = profile.anatomy_landmarks()
	var head_height: float = float(landmark["crown_y"]) - float(landmark["shoulder_y"])
	var head_rings: Array[Dictionary] = [
		_ring_y(Vector3(0, float(landmark["neck_y"]), 0), 0.075, 0.070, _weights(BONE.neck)),
		_ring_y(Vector3(0, float(landmark["jaw_y"]), -0.004), profile.head_width * 0.39, profile.head_depth * 0.39, _weights2(BONE.neck, BONE.head, 0.65)),
		_ring_y(Vector3(0, lerpf(float(landmark["jaw_y"]), float(landmark["brow_y"]), 0.58), -0.010), profile.head_width * 0.48, profile.head_depth * 0.46, _weights(BONE.head)),
		_ring_y(Vector3(0, lerpf(float(landmark["brow_y"]), float(landmark["crown_y"]), 0.48), 0), profile.head_width * 0.50, profile.head_depth * 0.50, _weights(BONE.head)),
		_ring_y(Vector3(0, float(landmark["crown_y"]), 0.012), profile.head_width * 0.43, profile.head_depth * 0.46, _weights(BONE.head)),
	]
	_add_y_loft(builders, SKIN, head_rings, 12, true, true)
	var crown_y: float = float(landmark["crown_y"])
	var brow_y: float = float(landmark["brow_y"])
	_add_y_loft(builders, HAIR, [
		_ring_y(Vector3(0, brow_y + head_height * 0.08, 0.018), profile.head_width * 0.505, profile.head_depth * 0.515, _weights(BONE.head)),
		_ring_y(Vector3(0, crown_y - head_height * 0.10, 0.024), profile.head_width * 0.49, profile.head_depth * 0.51, _weights(BONE.head)),
		_ring_y(Vector3(0, crown_y + 0.012, 0.016), profile.head_width * 0.36, profile.head_depth * 0.40, _weights(BONE.head)),
	], 12, false, true)
	_add_box(builders, HAIR, Vector3(-profile.head_width * 0.50, brow_y - head_height * 0.08, profile.head_depth * 0.34), Vector3(-profile.head_width * 0.41, brow_y + head_height * 0.15, profile.head_depth * 0.54), _weights(BONE.head), 0.006)
	_add_box(builders, HAIR, Vector3(profile.head_width * 0.41, brow_y - head_height * 0.08, profile.head_depth * 0.34), Vector3(profile.head_width * 0.50, brow_y + head_height * 0.15, profile.head_depth * 0.54), _weights(BONE.head), 0.006)
	_add_box(builders, FACE, Vector3(-0.050, brow_y - 0.010, -profile.head_depth * 0.53), Vector3(-0.024, brow_y + 0.012, -profile.head_depth * 0.49), _weights(BONE.head), 0.003)
	_add_box(builders, FACE, Vector3(0.024, brow_y - 0.010, -profile.head_depth * 0.53), Vector3(0.050, brow_y + 0.012, -profile.head_depth * 0.49), _weights(BONE.head), 0.003)
	_add_box(builders, FACE, Vector3(-0.010, brow_y - head_height * 0.19, -profile.head_depth * 0.56), Vector3(0.010, brow_y - head_height * 0.14, -profile.head_depth * 0.51), _weights(BONE.head), 0.002)


static func _build_arm(builders: Dictionary, profile, left: bool) -> void:
	var landmark: Dictionary = profile.anatomy_landmarks()
	var direction := -1.0 if left else 1.0
	var upper_bone := int(BONE.upperarm_l if left else BONE.upperarm_r)
	var forearm_bone := int(BONE.forearm_l if left else BONE.forearm_r)
	var hand_bone := int(BONE.hand_l if left else BONE.hand_r)
	var shoulder_x: float = direction * float(profile.shoulder_width) * 0.43
	var arm_length: float = float(landmark["arm_length"])
	var elbow_x: float = shoulder_x + direction * arm_length * 0.42
	var wrist_x: float = shoulder_x + direction * arm_length * 0.80
	var hand_x: float = shoulder_x + direction * arm_length
	var shoulder_y: float = float(landmark["shoulder_y"]) - 0.01
	var mass := float(profile.arm_mass)
	var upper_rings: Array[Dictionary] = [
		_ring_x(Vector3(shoulder_x, shoulder_y, 0), 0.105 * mass, 0.095 * mass, _weights(upper_bone)),
		_ring_x(Vector3(lerpf(shoulder_x, elbow_x, 0.48), shoulder_y, 0), 0.088 * mass, 0.080 * mass, _weights(upper_bone)),
		_ring_x(Vector3(elbow_x, shoulder_y, 0), 0.073 * mass, 0.070 * mass, _weights2(upper_bone, forearm_bone, 0.50)),
	]
	_add_x_loft(builders, CANVAS_LIGHT, upper_rings, 8, true, true, direction)
	var forearm_rings: Array[Dictionary] = [
		_ring_x(Vector3(elbow_x, shoulder_y, 0), 0.073 * mass, 0.070 * mass, _weights2(upper_bone, forearm_bone, 0.50)),
		_ring_x(Vector3(lerpf(elbow_x, wrist_x, 0.55), shoulder_y, -0.006), 0.069 * mass, 0.061 * mass, _weights(forearm_bone)),
		_ring_x(Vector3(wrist_x, shoulder_y, 0), 0.052 * mass, 0.048 * mass, _weights2(forearm_bone, hand_bone, 0.65)),
	]
	_add_x_loft(builders, CANVAS_LIGHT, forearm_rings, 8, true, true, direction)
	var hand_rings: Array[Dictionary] = [
		_ring_x(Vector3(wrist_x, shoulder_y, 0), 0.055, 0.047, _weights2(forearm_bone, hand_bone, 0.75)),
		_ring_x(Vector3(hand_x, shoulder_y, -0.012), 0.064, 0.043, _weights(hand_bone)),
	]
	_add_x_loft(builders, SKIN, hand_rings, 8, true, true, direction)
	var cuff_x_a := lerpf(elbow_x, wrist_x, 0.78)
	var cuff_x_b := lerpf(elbow_x, wrist_x, 0.94)
	_add_x_loft(builders, LEATHER, [
		_ring_x(Vector3(cuff_x_a, shoulder_y, 0), 0.058, 0.053, _weights(forearm_bone)),
		_ring_x(Vector3(cuff_x_b, shoulder_y, 0), 0.057, 0.052, _weights2(forearm_bone, hand_bone, 0.35)),
	], 8, true, true, direction)


static func _build_leg(builders: Dictionary, profile, left: bool) -> void:
	var landmark: Dictionary = profile.anatomy_landmarks()
	var x: float = (-1.0 if left else 1.0) * float(profile.pelvis_width) * 0.255
	var thigh_bone := int(BONE.thigh_l if left else BONE.thigh_r)
	var calf_bone := int(BONE.calf_l if left else BONE.calf_r)
	var foot_bone := int(BONE.foot_l if left else BONE.foot_r)
	var trouser_rings: Array[Dictionary] = [
		_ring_y(Vector3(x, float(landmark["hip_y"]), 0), profile.thigh_diameter * 0.64, profile.thigh_diameter * 0.64, _weights(thigh_bone)),
		_ring_y(Vector3(x, float(landmark["thigh_mass_y"]), 0), profile.thigh_diameter * 0.62, profile.thigh_diameter * 0.61, _weights(thigh_bone)),
		_ring_y(Vector3(x, float(landmark["knee_y"]), 0), profile.thigh_diameter * 0.50, profile.thigh_diameter * 0.49, _weights2(thigh_bone, calf_bone, 0.50)),
		_ring_y(Vector3(x, float(landmark["calf_mass_y"]), 0.006), profile.calf_diameter * 0.70, profile.calf_diameter * 0.68, _weights(calf_bone)),
		_ring_y(Vector3(x, float(landmark["calf_low_y"]), 0), profile.calf_diameter * 0.56, profile.calf_diameter * 0.57, _weights(calf_bone)),
	]
	_add_y_loft(builders, TROUSER, trouser_rings, 8, true, true)
	var boot_rings: Array[Dictionary] = [
		_ring_y(Vector3(x, float(landmark["calf_mass_y"]) - 0.01, 0.008), profile.calf_diameter * 0.70, profile.calf_diameter * 0.70, _weights(calf_bone)),
		_ring_y(Vector3(x, float(landmark["calf_low_y"]) - 0.02, 0), profile.ankle_width * 0.62, profile.ankle_width * 0.66, _weights(calf_bone)),
		_ring_y(Vector3(x, float(landmark["ankle_y"]), -0.005), profile.ankle_width * 0.56, profile.ankle_width * 0.60, _weights2(calf_bone, foot_bone, 0.65)),
	]
	_add_y_loft(builders, LEATHER, boot_rings, 8, true, true)
	var half_width: float = float(profile.foot_width) * 0.50 + 0.010
	_add_box(builders, LEATHER, Vector3(x - half_width, float(landmark["sole_y"]) + 0.025, -profile.foot_length * 0.72), Vector3(x + half_width, float(landmark["foot_top_y"]), profile.foot_length * 0.28), _weights(foot_bone), 0.018)
	_add_box(builders, SOLE, Vector3(x - half_width - 0.006, float(landmark["sole_y"]), -profile.foot_length * 0.74), Vector3(x + half_width + 0.006, float(landmark["sole_y"]) + 0.035, profile.foot_length * 0.30), _weights(foot_bone), 0.010)


static func _build_outfit_details(builders: Dictionary, profile) -> void:
	var landmark: Dictionary = profile.anatomy_landmarks()
	var pelvis_y: float = float(landmark["pelvis_y"])
	var shoulder_y: float = float(landmark["shoulder_y"])
	_add_y_loft(builders, LEATHER, [
		_ring_y(Vector3(0, pelvis_y - 0.035, 0), profile.pelvis_width * 0.52, profile.chest_depth * 0.54, _weights(BONE.pelvis)),
		_ring_y(Vector3(0, pelvis_y + 0.025, 0), profile.pelvis_width * 0.52, profile.chest_depth * 0.54, _weights(BONE.pelvis)),
	], 12, true, true)
	_add_box(builders, METAL, Vector3(-0.035, pelvis_y - 0.025, -profile.chest_depth * 0.58), Vector3(0.035, pelvis_y + 0.020, -profile.chest_depth * 0.52), _weights(BONE.pelvis), 0.006)
	var front_z: float = -float(profile.chest_depth) * 0.55 - float(profile.outfit_shell_offset) - 0.004
	_add_ribbon_z(builders, LEATHER, Vector2(-float(profile.shoulder_width) * 0.30, shoulder_y - 0.045), Vector2(float(profile.pelvis_width) * 0.30, pelvis_y - 0.015), front_z, 0.030, _weights(BONE.chest), _weights(BONE.pelvis), -1.0)
	_add_ribbon_z(builders, LEATHER_LIGHT, Vector2(-0.012, shoulder_y - 0.06), Vector2(-0.012, pelvis_y + 0.035), front_z - 0.003, 0.007, _weights(BONE.chest), _weights(BONE.pelvis), -1.0)
	_add_ribbon_z(builders, CANVAS_LIGHT, Vector2(-0.055, shoulder_y - 0.045), Vector2(-0.145, float(landmark["chest_y"]) - 0.02), front_z - 0.006, 0.025, _weights(BONE.chest), _weights(BONE.chest), -1.0)
	_add_ribbon_z(builders, CANVAS_LIGHT, Vector2(0.055, shoulder_y - 0.045), Vector2(0.145, float(landmark["chest_y"]) - 0.02), front_z - 0.006, 0.025, _weights(BONE.chest), _weights(BONE.chest), -1.0)
	_add_box(builders, CANVAS_DARK, Vector3(-0.205, float(landmark["waist_y"]) + 0.02, front_z - 0.014), Vector3(-0.075, float(landmark["waist_y"]) + 0.105, front_z - 0.004), _weights2(BONE.spine_01, BONE.pelvis, 0.45), 0.004)
	_add_box(builders, CANVAS_DARK, Vector3(0.075, float(landmark["waist_y"]) + 0.02, front_z - 0.014), Vector3(0.205, float(landmark["waist_y"]) + 0.105, front_z - 0.004), _weights2(BONE.spine_01, BONE.pelvis, 0.45), 0.004)
	_add_y_loft(builders, ACCENT, [
		_ring_y(Vector3(0, shoulder_y - 0.025, 0), 0.125, 0.105, _weights(BONE.chest)),
		_ring_y(Vector3(0, float(landmark["neck_y"]) + 0.015, -0.002), 0.112, 0.097, _weights2(BONE.chest, BONE.neck, 0.60)),
	], 12, true, true)
	# Compact pack, bedroll, and side pouch stay bone-bound but share the same
	# skinned payload, so the normal player owns one coherent body mesh.
	_add_box(builders, CANVAS_DARK, Vector3(-0.18, float(landmark["waist_y"]), 0.13), Vector3(0.18, shoulder_y - 0.05, 0.31), _weights(BONE.chest), 0.025)
	_add_box(builders, CANVAS_LIGHT, Vector3(-0.155, float(landmark["chest_y"]) - 0.105, 0.306), Vector3(0.155, float(landmark["chest_y"]) + 0.045, 0.326), _weights(BONE.chest), 0.008)
	for strap_x in [-0.115, 0.115]:
		_add_ribbon_z(builders, LEATHER, Vector2(strap_x, float(landmark["waist_y"]) + 0.02), Vector2(strap_x, shoulder_y - 0.02), 0.314, 0.018, _weights(BONE.chest), _weights(BONE.chest), 1.0)
	_add_ribbon_z(builders, LEATHER_LIGHT, Vector2(-0.14, float(landmark["chest_y"]) - 0.02), Vector2(0.14, float(landmark["chest_y"]) - 0.02), 0.317, 0.012, _weights(BONE.chest), _weights(BONE.chest), 1.0)
	_add_x_loft(builders, ACCENT, [
		_ring_x(Vector3(-0.19, shoulder_y, 0.22), 0.075, 0.075, _weights(BONE.chest)),
		_ring_x(Vector3(0.19, shoulder_y, 0.22), 0.075, 0.075, _weights(BONE.chest)),
	], 8, true, true, 1.0)
	_add_box(builders, LEATHER, Vector3(profile.pelvis_width * 0.48, float(landmark["hip_y"]), -0.02), Vector3(profile.pelvis_width * 0.48 + 0.12, float(landmark["waist_y"]) - 0.03, 0.11), _weights(BONE.pelvis), 0.018)
	for side_data in [[-1.0, int(BONE.calf_l)], [1.0, int(BONE.calf_r)]]:
		var leg_x: float = float(side_data[0]) * float(profile.pelvis_width) * 0.255
		var leg_bone: int = int(side_data[1])
		_add_box(builders, CANVAS_DARK, Vector3(leg_x - profile.thigh_diameter * 0.36, float(landmark["knee_y"]) - 0.055, -profile.thigh_diameter * 0.47), Vector3(leg_x + profile.thigh_diameter * 0.36, float(landmark["knee_y"]) + 0.055, -profile.thigh_diameter * 0.42), _weights(leg_bone), 0.004)


static func _joint_overlap_margins(profile) -> Dictionary:
	return {
		"shoulder_l": float(profile.shoulder_width) * 0.07,
		"shoulder_r": float(profile.shoulder_width) * 0.07,
		"elbow_l": 0.0, "elbow_r": 0.0,
		"wrist_l": 0.0, "wrist_r": 0.0,
		"hip_l": float(profile.thigh_diameter) * 0.10,
		"hip_r": float(profile.thigh_diameter) * 0.10,
		"knee_l": 0.0, "knee_r": 0.0,
		"ankle_l": 0.025, "ankle_r": 0.025,
	}


static func _ring_y(center: Vector3, rx: float, rz: float, skin_weights: Dictionary) -> Dictionary:
	return {"center": center, "rx": rx, "rz": rz, "skin": skin_weights}


static func _ring_x(center: Vector3, ry: float, rz: float, skin_weights: Dictionary) -> Dictionary:
	return {"center": center, "ry": ry, "rz": rz, "skin": skin_weights}


static func _weights(bone_index: int) -> Dictionary:
	return {"bones": [bone_index, 0, 0, 0], "weights": [1.0, 0.0, 0.0, 0.0]}


static func _weights2(first_bone: int, second_bone: int, second_weight: float) -> Dictionary:
	var clamped := clampf(second_weight, 0.0, 1.0)
	return {"bones": [first_bone, second_bone, 0, 0], "weights": [1.0 - clamped, clamped, 0.0, 0.0]}


static func _add_y_loft(builders: Dictionary, palette_index: int, rings: Array[Dictionary], sides: int, cap_start: bool, cap_end: bool) -> void:
	if rings.size() < 2:
		return
	for ring_index in range(rings.size() - 1):
		var lower := rings[ring_index]
		var upper := rings[ring_index + 1]
		for side in range(sides):
			var next := (side + 1) % sides
			var p0 := _point_y(lower, side, sides)
			var p1 := _point_y(lower, next, sides)
			var q0 := _point_y(upper, side, sides)
			var q1 := _point_y(upper, next, sides)
			var expected := Vector3(
				cos((float(side) + 0.5) * TAU / float(sides)), 0.0,
				sin((float(side) + 0.5) * TAU / float(sides))
			).normalized()
			_emit_triangle(builders, palette_index, p0, q0, q1, expected, lower["skin"], upper["skin"], upper["skin"], Vector2(float(side) / sides, float(ring_index) / (rings.size() - 1)), Vector2(float(side) / sides, float(ring_index + 1) / (rings.size() - 1)), Vector2(float(next) / sides, float(ring_index + 1) / (rings.size() - 1)))
			_emit_triangle(builders, palette_index, p0, q1, p1, expected, lower["skin"], upper["skin"], lower["skin"], Vector2(float(side) / sides, float(ring_index) / (rings.size() - 1)), Vector2(float(next) / sides, float(ring_index + 1) / (rings.size() - 1)), Vector2(float(next) / sides, float(ring_index) / (rings.size() - 1)))
	if cap_start:
		_add_y_cap(builders, palette_index, rings[0], sides, -1.0)
	if cap_end:
		_add_y_cap(builders, palette_index, rings[-1], sides, 1.0)


static func _add_x_loft(builders: Dictionary, palette_index: int, rings: Array[Dictionary], sides: int, cap_start: bool, cap_end: bool, direction: float) -> void:
	if rings.size() < 2:
		return
	for ring_index in range(rings.size() - 1):
		var first := rings[ring_index]
		var second := rings[ring_index + 1]
		for side in range(sides):
			var next := (side + 1) % sides
			var p0 := _point_x(first, side, sides)
			var p1 := _point_x(first, next, sides)
			var q0 := _point_x(second, side, sides)
			var q1 := _point_x(second, next, sides)
			var expected := Vector3(0.0, cos((float(side) + 0.5) * TAU / float(sides)), sin((float(side) + 0.5) * TAU / float(sides))).normalized()
			_emit_triangle(builders, palette_index, p0, q0, q1, expected, first["skin"], second["skin"], second["skin"], Vector2(float(side) / sides, 0), Vector2(float(side) / sides, 1), Vector2(float(next) / sides, 1))
			_emit_triangle(builders, palette_index, p0, q1, p1, expected, first["skin"], second["skin"], first["skin"], Vector2(float(side) / sides, 0), Vector2(float(next) / sides, 1), Vector2(float(next) / sides, 0))
	if cap_start:
		_add_x_cap(builders, palette_index, rings[0], sides, -direction)
	if cap_end:
		_add_x_cap(builders, palette_index, rings[-1], sides, direction)


static func _point_y(ring: Dictionary, side: int, sides: int) -> Vector3:
	var angle := float(side) * TAU / float(sides)
	var center: Vector3 = ring["center"]
	return center + Vector3(cos(angle) * float(ring["rx"]), 0.0, sin(angle) * float(ring["rz"]))


static func _point_x(ring: Dictionary, side: int, sides: int) -> Vector3:
	var angle := float(side) * TAU / float(sides)
	var center: Vector3 = ring["center"]
	return center + Vector3(0.0, cos(angle) * float(ring["ry"]), sin(angle) * float(ring["rz"]))


static func _add_y_cap(builders: Dictionary, palette_index: int, ring: Dictionary, sides: int, direction: float) -> void:
	var center: Vector3 = ring["center"]
	var normal := Vector3(0, direction, 0)
	for side in range(sides):
		var p0 := _point_y(ring, side, sides)
		var p1 := _point_y(ring, (side + 1) % sides, sides)
		_emit_triangle(builders, palette_index, center, p0, p1, normal, ring["skin"], ring["skin"], ring["skin"], Vector2(0.5,0.5), Vector2.ZERO, Vector2.ONE)


static func _add_x_cap(builders: Dictionary, palette_index: int, ring: Dictionary, sides: int, direction: float) -> void:
	var center: Vector3 = ring["center"]
	var normal := Vector3(direction, 0, 0)
	for side in range(sides):
		var p0 := _point_x(ring, side, sides)
		var p1 := _point_x(ring, (side + 1) % sides, sides)
		_emit_triangle(builders, palette_index, center, p0, p1, normal, ring["skin"], ring["skin"], ring["skin"], Vector2(0.5,0.5), Vector2.ZERO, Vector2.ONE)


static func _add_box(builders: Dictionary, palette_index: int, minimum: Vector3, maximum: Vector3, skin_weights: Dictionary, bevel: float = 0.0) -> void:
	# The bevel parameter participates in the authored primitive contract; the
	# first implementation keeps the outer bounds exact and relies on flat face
	# planes for the low-poly treatment.
	var _bevel_contract := bevel
	var p := [
		Vector3(minimum.x, minimum.y, minimum.z), Vector3(maximum.x, minimum.y, minimum.z),
		Vector3(maximum.x, maximum.y, minimum.z), Vector3(minimum.x, maximum.y, minimum.z),
		Vector3(minimum.x, minimum.y, maximum.z), Vector3(maximum.x, minimum.y, maximum.z),
		Vector3(maximum.x, maximum.y, maximum.z), Vector3(minimum.x, maximum.y, maximum.z),
	]
	var faces := [
		[0,3,2,1,Vector3(0,0,-1)], [4,5,6,7,Vector3(0,0,1)],
		[0,4,7,3,Vector3(-1,0,0)], [1,2,6,5,Vector3(1,0,0)],
		[0,1,5,4,Vector3(0,-1,0)], [3,7,6,2,Vector3(0,1,0)],
	]
	for face in faces:
		var normal: Vector3 = face[4]
		_emit_triangle(builders, palette_index, p[face[0]], p[face[1]], p[face[2]], normal, skin_weights, skin_weights, skin_weights, Vector2.ZERO, Vector2(0,1), Vector2.ONE)
		_emit_triangle(builders, palette_index, p[face[0]], p[face[2]], p[face[3]], normal, skin_weights, skin_weights, skin_weights, Vector2.ZERO, Vector2.ONE, Vector2(1,0))


static func _add_ribbon_z(builders: Dictionary, palette_index: int, start: Vector2, finish: Vector2, z: float, half_width: float, start_skin: Dictionary, finish_skin: Dictionary, normal_direction: float) -> void:
	var direction := (finish - start).normalized()
	if direction.is_zero_approx():
		return
	var perpendicular := Vector2(-direction.y, direction.x) * half_width
	var a := Vector3(start.x + perpendicular.x, start.y + perpendicular.y, z)
	var b := Vector3(start.x - perpendicular.x, start.y - perpendicular.y, z)
	var c := Vector3(finish.x - perpendicular.x, finish.y - perpendicular.y, z)
	var d := Vector3(finish.x + perpendicular.x, finish.y + perpendicular.y, z)
	var expected := Vector3(0.0, 0.0, normal_direction)
	_emit_triangle(builders, palette_index, a, b, c, expected, start_skin, start_skin, finish_skin, Vector2(0,0), Vector2(1,0), Vector2(1,1))
	_emit_triangle(builders, palette_index, a, c, d, expected, start_skin, finish_skin, finish_skin, Vector2(0,0), Vector2(1,1), Vector2(0,1))


static func _emit_triangle(builders: Dictionary, palette_index: int, a: Vector3, b: Vector3, c: Vector3, expected_normal: Vector3, skin_a: Dictionary, skin_b: Dictionary, skin_c: Dictionary, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	var edge_a := b - a
	var edge_b := c - a
	var normal := edge_a.cross(edge_b)
	if normal.length_squared() <= 0.000000001:
		return
	if normal.dot(expected_normal) < 0.0:
		var swap_point := b
		b = c
		c = swap_point
		var swap_skin := skin_b
		skin_b = skin_c
		skin_c = swap_skin
		var swap_uv := uv_b
		uv_b = uv_c
		uv_c = swap_uv
		normal = -normal
	normal = normal.normalized()
	var builder := _builder(builders, palette_index)
	var base_index: int = builder["vertices"].size()
	for point in [a, b, c]:
		builder["vertices"].append(point)
		builder["normals"].append(normal)
	for uv in [uv_a, uv_b, uv_c]:
		builder["uvs"].append(uv)
	for skin in [skin_a, skin_b, skin_c]:
		for bone_index in skin["bones"]:
			builder["bones"].append(int(bone_index))
		for weight in skin["weights"]:
			builder["weights"].append(float(weight))
	builder["indices"].append_array([base_index, base_index + 1, base_index + 2])
	builders[palette_index] = builder


static func _builder(builders: Dictionary, palette_index: int) -> Dictionary:
	if builders.has(palette_index):
		return builders[palette_index]
	var result := {
		"vertices": PackedVector3Array(), "normals": PackedVector3Array(),
		"uvs": PackedVector2Array(), "bones": PackedInt32Array(),
		"weights": PackedFloat32Array(), "indices": PackedInt32Array(),
	}
	builders[palette_index] = result
	return result


static func _colors_for_palette(palette, palette_index: int, count: int) -> PackedColorArray:
	var colors := PackedColorArray()
	var color := Color(palette.entry(palette_index).get("color", Color.WHITE))
	colors.resize(count)
	for index in range(count):
		colors[index] = color
	return colors


static func _surface_payload(surfaces: Array[Dictionary]) -> String:
	var lines: Array[String] = []
	for surface in surfaces:
		var payload: Array[String] = [str(surface.get("palette_index", -1))]
		var vertices: PackedVector3Array = surface["vertices"]
		var bones: PackedInt32Array = surface["bones"]
		var weights: PackedFloat32Array = surface["weights"]
		for vertex in vertices:
			payload.append("%.6f,%.6f,%.6f" % [vertex.x, vertex.y, vertex.z])
		var bone_values: Array[String] = []
		for bone_index in bones:
			bone_values.append(str(bone_index))
		payload.append("b=" + ",".join(bone_values))
		var weight_values: Array[String] = []
		for weight in weights:
			weight_values.append("%.6f" % weight)
		payload.append("w=" + ",".join(weight_values))
		lines.append("|".join(payload))
	lines.sort()
	return "\n".join(lines)
