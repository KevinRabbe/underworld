from pathlib import Path

compiler_path = Path("presentation/characters/faceted/faceted_body_compiler.gd")
profile_path = Path("presentation/characters/faceted/faceted_humanoid_body_profile.gd")
palette_path = Path("presentation/characters/voxel/baseline_survivor_factory.gd")
compiler = compiler_path.read_text()
profile = profile_path.read_text()
palette = palette_path.read_text()


def replace_function(text: str, start: str, next_start: str, replacement: str) -> str:
    begin = text.index(start)
    end = text.index(next_start, begin)
    return text[:begin] + replacement.rstrip() + "\n\n\n" + text[end:]


if "const COMPILER_REVISION := 8" not in compiler:
    raise SystemExit("expected compiler revision 8")
compiler = compiler.replace("const COMPILER_REVISION := 8", "const COMPILER_REVISION := 9", 1)

head = r'''static func _build_head(builders: Dictionary, profile) -> void:
	var landmark: Dictionary = profile.anatomy_landmarks()
	var shoulder_y: float = float(landmark["shoulder_y"])
	var neck_y: float = float(landmark["neck_y"])
	var jaw_y: float = float(landmark["jaw_y"])
	var brow_y: float = float(landmark["brow_y"])
	var crown_y: float = float(landmark["crown_y"])
	var head_height: float = crown_y - shoulder_y
	var face_span: float = brow_y - jaw_y
	var skin: Dictionary = _weights(BONE.head)

	# A deliberately planar male skull: narrow neck, visible mandibular angle,
	# broad cheek/brow mass and a fuller rear cranium. The extra rings are spent
	# at silhouette breaks instead of uniformly increasing subdivision.
	var head_rings: Array[Dictionary] = [
		_ring_y_asym(Vector3(0, shoulder_y + 0.008, 0.005), 0.083, 0.068, 0.075, _weights(BONE.neck)),
		_ring_y_asym(Vector3(0, neck_y + 0.012, 0.005), 0.079, 0.066, 0.078, _weights(BONE.neck)),
		_ring_y_asym(Vector3(0, jaw_y - 0.034, 0.004), profile.head_width * 0.29, profile.head_depth * 0.27, profile.head_depth * 0.33, _weights2(BONE.neck, BONE.head, 0.52)),
		_ring_y_asym(Vector3(0, jaw_y - 0.008, 0.004), profile.head_width * 0.37, profile.head_depth * 0.33, profile.head_depth * 0.39, _weights2(BONE.neck, BONE.head, 0.72)),
		_ring_y_asym(Vector3(0, jaw_y + face_span * 0.18, 0.004), profile.head_width * 0.43, profile.head_depth * 0.37, profile.head_depth * 0.44, skin),
		_ring_y_asym(Vector3(0, jaw_y + face_span * 0.42, 0.004), profile.head_width * 0.50, profile.head_depth * 0.42, profile.head_depth * 0.49, skin),
		_ring_y_asym(Vector3(0, jaw_y + face_span * 0.66, 0.005), profile.head_width * 0.535, profile.head_depth * 0.445, profile.head_depth * 0.52, skin),
		_ring_y_asym(Vector3(0, brow_y + 0.004, 0.006), profile.head_width * 0.53, profile.head_depth * 0.455, profile.head_depth * 0.55, skin),
		_ring_y_asym(Vector3(0, lerpf(brow_y, crown_y, 0.42), 0.008), profile.head_width * 0.515, profile.head_depth * 0.445, profile.head_depth * 0.57, skin),
		_ring_y_asym(Vector3(0, crown_y - head_height * 0.10, 0.010), profile.head_width * 0.49, profile.head_depth * 0.42, profile.head_depth * 0.575, skin),
		_ring_y_asym(Vector3(0, crown_y, 0.010), profile.head_width * 0.39, profile.head_depth * 0.35, profile.head_depth * 0.48, skin),
	]
	_add_y_loft(builders, SKIN, head_rings, 14, true, true)

	var face_front: float = -float(profile.head_depth) * 0.485
	var eye_y: float = jaw_y + face_span * 0.79
	var cheek_y: float = jaw_y + face_span * 0.48
	var mouth_y: float = jaw_y + face_span * 0.19

	# Ears remain compact but now project farther in true side view and taper at
	# both ends instead of reading as little rectangular blocks.
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		var ear_x: float = side * float(profile.head_width) * 0.55
		_add_y_loft(builders, SKIN, [
			_ring_y(Vector3(ear_x, jaw_y + face_span * 0.22, 0.010), 0.008, 0.012, skin),
			_ring_y(Vector3(ear_x, jaw_y + face_span * 0.47, 0.012), 0.017, 0.023, skin),
			_ring_y(Vector3(ear_x, jaw_y + face_span * 0.73, 0.010), 0.010, 0.015, skin),
		], 6, true, true)

	# Strong eyebrow/brow planes are the most important facial read at gameplay
	# distance. Small eye slits sit underneath rather than becoming black boxes.
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		var brow_inner := Vector2(side * 0.010, eye_y + 0.020)
		var brow_outer := Vector2(side * 0.062, eye_y + 0.018)
		_add_ribbon_z(builders, FACE, brow_inner, brow_outer, face_front - 0.021, 0.006, skin, skin, -1.0)
		var eye_inner: Vector3 = Vector3(side * 0.016, eye_y - 0.002, face_front - 0.020)
		var eye_outer: Vector3 = Vector3(side * 0.050, eye_y - 0.004, face_front - 0.018)
		var eye_low: Vector3 = Vector3(side * 0.046, eye_y - 0.011, face_front - 0.017)
		_emit_triangle(builders, FACE, eye_inner, eye_outer, eye_low, Vector3(0, 0, -1), skin, skin, skin, Vector2.ZERO, Vector2(1,0), Vector2(0.8,1))

	# Zygomatic and jaw planes give 3/4 view a cheek hollow and mandibular angle.
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		var expected: Vector3 = Vector3(side * 0.38, 0.0, -1.0).normalized()
		var temple := Vector3(side * 0.072, eye_y + 0.010, face_front + 0.002)
		var socket := Vector3(side * 0.054, eye_y - 0.018, face_front - 0.010)
		var cheek_outer := Vector3(side * 0.091, cheek_y + 0.004, face_front + 0.004)
		var cheek_inner := Vector3(side * 0.029, cheek_y - 0.008, face_front - 0.014)
		var jaw_angle := Vector3(side * 0.079, jaw_y + face_span * 0.08, face_front + 0.013)
		var chin_side := Vector3(side * 0.043, jaw_y - 0.010, face_front - 0.006)
		_emit_triangle(builders, SKIN, temple, cheek_outer, socket, expected, skin, skin, skin, Vector2.ZERO, Vector2(1,0), Vector2.ONE)
		_emit_triangle(builders, SKIN, socket, cheek_outer, cheek_inner, expected, skin, skin, skin, Vector2.ZERO, Vector2(1,0), Vector2.ONE)
		_emit_triangle(builders, SKIN, cheek_outer, jaw_angle, cheek_inner, expected, skin, skin, skin, Vector2.ZERO, Vector2(1,0), Vector2.ONE)
		_emit_triangle(builders, SKIN, jaw_angle, chin_side, cheek_inner, expected, skin, skin, skin, Vector2.ZERO, Vector2(1,0), Vector2.ONE)

	# Multi-plane nose with a stronger bridge and tip projection. It changes the
	# profile silhouette but remains compact enough for the faceted art style.
	var nose_top_y: float = jaw_y + face_span * 0.73
	var nose_mid_y: float = jaw_y + face_span * 0.56
	var nose_tip_y: float = jaw_y + face_span * 0.39
	var nose_base_y: float = jaw_y + face_span * 0.28
	var nose_top_l := Vector3(-0.010, nose_top_y, face_front - 0.010)
	var nose_top_r := Vector3(0.010, nose_top_y, face_front - 0.010)
	var nose_mid_l := Vector3(-0.014, nose_mid_y, face_front - 0.032)
	var nose_mid_r := Vector3(0.014, nose_mid_y, face_front - 0.032)
	var nose_tip_l := Vector3(-0.020, nose_tip_y, face_front - 0.060)
	var nose_tip_r := Vector3(0.020, nose_tip_y, face_front - 0.060)
	var nose_base_l := Vector3(-0.025, nose_base_y, face_front - 0.028)
	var nose_base_r := Vector3(0.025, nose_base_y, face_front - 0.028)
	for quad_value in [
		[nose_top_l, nose_top_r, nose_mid_r, nose_mid_l],
		[nose_mid_l, nose_mid_r, nose_tip_r, nose_tip_l],
		[nose_tip_l, nose_tip_r, nose_base_r, nose_base_l],
	]:
		var quad: Array = quad_value
		_emit_triangle(builders, SKIN, Vector3(quad[0]), Vector3(quad[1]), Vector3(quad[2]), Vector3(0, 0, -1), skin, skin, skin, Vector2.ZERO, Vector2(1,0), Vector2.ONE)
		_emit_triangle(builders, SKIN, Vector3(quad[0]), Vector3(quad[2]), Vector3(quad[3]), Vector3(0, 0, -1), skin, skin, skin, Vector2.ZERO, Vector2.ONE, Vector2(0,1))
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		var top: Vector3 = nose_top_l if side < 0.0 else nose_top_r
		var mid: Vector3 = nose_mid_l if side < 0.0 else nose_mid_r
		var tip: Vector3 = nose_tip_l if side < 0.0 else nose_tip_r
		var base: Vector3 = nose_base_l if side < 0.0 else nose_base_r
		var bridge_anchor := Vector3(side * 0.032, nose_mid_y, face_front + 0.002)
		var base_anchor := Vector3(side * 0.037, nose_base_y, face_front + 0.001)
		var expected := Vector3(side, 0.0, -0.40).normalized()
		_emit_triangle(builders, SKIN, top, mid, bridge_anchor, expected, skin, skin, skin, Vector2.ZERO, Vector2(1,0), Vector2.ONE)
		_emit_triangle(builders, SKIN, mid, tip, bridge_anchor, expected, skin, skin, skin, Vector2.ZERO, Vector2(1,0), Vector2.ONE)
		_emit_triangle(builders, SKIN, tip, base, base_anchor, expected, skin, skin, skin, Vector2.ZERO, Vector2(1,0), Vector2.ONE)
		_emit_triangle(builders, SKIN, bridge_anchor, tip, base_anchor, expected, skin, skin, skin, Vector2.ZERO, Vector2(1,0), Vector2.ONE)

	# Chin/lower lip planes keep the expression neutral but human-readable.
	_add_tri_prism_z(builders, SKIN,
		Vector2(-0.050, mouth_y - 0.007),
		Vector2(0.050, mouth_y - 0.007),
		Vector2(0.0, jaw_y - 0.025),
		face_front - 0.016, face_front + 0.004, skin)
	_add_ribbon_z(builders, FACE, Vector2(-0.030, mouth_y), Vector2(0.030, mouth_y), face_front - 0.019, 0.0035, skin, skin, -1.0)

	# Undercut: a narrow dark rear/crown shell leaves the temporal sides exposed.
	# A chain of swept faceted tufts then supplies the distinctive top silhouette
	# from the reference instead of the old helmet-like full hair cap.
	_add_y_loft(builders, HAIR, [
		_ring_y_asym(Vector3(0, brow_y + head_height * 0.11, 0.018), profile.head_width * 0.37, profile.head_depth * 0.22, profile.head_depth * 0.53, skin),
		_ring_y_asym(Vector3(0, crown_y - head_height * 0.12, 0.018), profile.head_width * 0.43, profile.head_depth * 0.30, profile.head_depth * 0.56, skin),
		_ring_y_asym(Vector3(0, crown_y + 0.014, 0.010), profile.head_width * 0.34, profile.head_depth * 0.28, profile.head_depth * 0.48, skin),
	], 12, false, true)
	for tuft_data in [
		[-0.060, -0.060, 0.048, -0.040],
		[-0.025, -0.070, 0.056, -0.018],
		[0.012, -0.064, 0.060, 0.010],
		[0.048, -0.050, 0.052, 0.034],
		[0.078, -0.030, 0.040, 0.052],
	]:
		var tuft_x: float = float(tuft_data[0])
		var tuft_z: float = float(tuft_data[1])
		var tuft_radius: float = float(tuft_data[2])
		var sweep_x: float = float(tuft_data[3])
		_add_y_loft(builders, HAIR, [
			_ring_y(Vector3(tuft_x, crown_y - 0.062, tuft_z), tuft_radius, tuft_radius * 0.62, skin),
			_ring_y(Vector3(tuft_x + sweep_x * 0.35, crown_y - 0.018, tuft_z - 0.012), tuft_radius * 0.63, tuft_radius * 0.42, skin),
			_ring_y(Vector3(tuft_x + sweep_x, crown_y + 0.018, tuft_z - 0.022), tuft_radius * 0.16, tuft_radius * 0.14, skin),
		], 6, true, true)
	# Short front lock keeps the hairline from becoming a straight horizontal cap.
	_add_tri_prism_z(builders, HAIR,
		Vector2(-0.050, brow_y + 0.020),
		Vector2(0.018, brow_y + 0.012),
		Vector2(0.062, brow_y + 0.052),
		-face_front - profile.head_depth * 0.99, -face_front - profile.head_depth * 0.88, skin)'''
compiler = replace_function(compiler, "static func _build_head", "static func _build_arm", head)

old_hand = r'''	var hand_rings: Array[Dictionary] = [
		_ring_x(Vector3(wrist_x, shoulder_y, 0), 0.052, 0.045, _weights2(forearm_bone, hand_bone, 0.75)),
		_ring_x(Vector3(hand_x, shoulder_y, -0.012), 0.061, 0.041, _weights(hand_bone)),
	]
	_add_x_loft(builders, SKIN, hand_rings, 8, true, true, direction)
	var thumb_x_a: float = hand_x - direction * 0.025
	var thumb_x_b: float = hand_x + direction * 0.050
	_add_box(builders, SKIN,
		Vector3(minf(thumb_x_a, thumb_x_b), shoulder_y - 0.055, -0.049),
		Vector3(maxf(thumb_x_a, thumb_x_b), shoulder_y - 0.018, -0.006),
		_weights(hand_bone), 0.010)
'''
new_hand = r'''	var hand_rings: Array[Dictionary] = [
		_ring_x(Vector3(wrist_x, shoulder_y, 0), 0.050, 0.043, _weights2(forearm_bone, hand_bone, 0.78)),
		_ring_x(Vector3(lerpf(wrist_x, hand_x, 0.48), shoulder_y - 0.002, -0.008), 0.058, 0.045, _weights(hand_bone)),
		_ring_x(Vector3(lerpf(wrist_x, hand_x, 0.82), shoulder_y - 0.006, -0.013), 0.052, 0.039, _weights(hand_bone)),
		_ring_x(Vector3(hand_x, shoulder_y - 0.008, -0.015), 0.039, 0.030, _weights(hand_bone)),
	]
	_add_x_loft(builders, SKIN, hand_rings, 8, true, true, direction)
	# A tapered thumb loft reads as a separate digit in 3/4 without trying to
	# model individual fingers at a scale where they would only create noise.
	var thumb_root_x := lerpf(wrist_x, hand_x, 0.47)
	var thumb_tip_x := lerpf(wrist_x, hand_x, 0.82)
	_add_x_loft(builders, SKIN, [
		_ring_x(Vector3(thumb_root_x, shoulder_y - 0.041, -0.031), 0.021, 0.020, _weights(hand_bone)),
		_ring_x(Vector3(thumb_tip_x, shoulder_y - 0.052, -0.039), 0.012, 0.012, _weights(hand_bone)),
	], 6, true, true, direction)
'''
if old_hand not in compiler:
    raise SystemExit("expected rev8 hand block")
compiler = compiler.replace(old_hand, new_hand, 1)

profile_replacements = {
    '@export var head_width: float = 0.195': '@export var head_width: float = 0.205',
    '@export var head_depth: float = 0.205': '@export var head_depth: float = 0.215',
    '@export var arm_mass: float = 0.94': '@export var arm_mass: float = 1.00',
}
for old, new in profile_replacements.items():
    if old not in profile:
        raise SystemExit(f"missing profile seam: {old}")
    profile = profile.replace(old, new, 1)

palette_replacements = {
    '_entry("cloth", Color("80684d"), 0.93, 0.0)': '_entry("cloth", Color("927958"), 0.93, 0.0)',
    '_entry("accent", Color("3f8790"), 0.84, 0.0)': '_entry("accent", Color("356f78"), 0.84, 0.0)',
    '_entry("canvas_light", Color("c4b59a"), 0.95, 0.0)': '_entry("canvas_light", Color("b5a486"), 0.95, 0.0)',
    '_entry("trouser", Color("444a49"), 0.92, 0.0)': '_entry("trouser", Color("373c3b"), 0.92, 0.0)',
}
for old, new in palette_replacements.items():
    if old not in palette:
        raise SystemExit(f"missing palette seam: {old}")
    palette = palette.replace(old, new, 1)

compiler_path.write_text(compiler)
profile_path.write_text(profile)
palette_path.write_text(palette)
