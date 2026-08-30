from pathlib import Path

compiler_path = Path("presentation/characters/faceted/faceted_body_compiler.gd")
factory_path = Path("presentation/characters/voxel/baseline_survivor_factory.gd")
compiler = compiler_path.read_text()
factory = factory_path.read_text()


def replace_between(text: str, start: str, end: str, replacement: str) -> str:
    begin = text.index(start)
    finish = text.index(end, begin)
    return text[:begin] + replacement.rstrip() + "\n\n" + text[finish:]


if "const COMPILER_REVISION := 9" not in compiler:
    raise SystemExit("expected compiler revision 9")
compiler = compiler.replace("const COMPILER_REVISION := 9", "const COMPILER_REVISION := 10", 1)

old_ring_x = '''static func _ring_x(center: Vector3, ry: float, rz: float, skin_weights: Dictionary) -> Dictionary:
\treturn {"center": center, "ry": ry, "rz": rz, "skin": skin_weights}
'''
new_ring_x = '''static func _ring_x(center: Vector3, ry: float, rz: float, skin_weights: Dictionary) -> Dictionary:
\treturn {"center": center, "ry": ry, "rz": rz, "skin": skin_weights}


static func _ring_z(center: Vector3, rx: float, ry: float, skin_weights: Dictionary) -> Dictionary:
\treturn {"center": center, "rx": rx, "ry": ry, "skin": skin_weights}
'''
if old_ring_x not in compiler:
    raise SystemExit("expected ring-x helper")
compiler = compiler.replace(old_ring_x, new_ring_x, 1)

z_loft = r'''static func _add_z_loft(builders: Dictionary, palette_index: int, rings: Array[Dictionary], sides: int, cap_start: bool, cap_end: bool, direction: float) -> void:
	if rings.size() < 2:
		return
	for ring_index in range(rings.size() - 1):
		var first := rings[ring_index]
		var second := rings[ring_index + 1]
		for side in range(sides):
			var next := (side + 1) % sides
			var p0 := _point_z(first, side, sides)
			var p1 := _point_z(first, next, sides)
			var q0 := _point_z(second, side, sides)
			var q1 := _point_z(second, next, sides)
			var mid_angle := (float(side) + 0.5) * TAU / float(sides)
			var expected := Vector3(cos(mid_angle), sin(mid_angle), 0.0).normalized()
			_emit_triangle(builders, palette_index, p0, q0, q1, expected, first["skin"], second["skin"], second["skin"], Vector2(float(side) / sides, 0), Vector2(float(side) / sides, 1), Vector2(float(next) / sides, 1))
			_emit_triangle(builders, palette_index, p0, q1, p1, expected, first["skin"], second["skin"], first["skin"], Vector2(float(side) / sides, 0), Vector2(float(next) / sides, 1), Vector2(float(next) / sides, 0))
	if cap_start:
		_add_z_cap(builders, palette_index, rings[0], sides, -direction)
	if cap_end:
		_add_z_cap(builders, palette_index, rings[-1], sides, direction)


'''
point_y_marker = "static func _point_y(ring: Dictionary, side: int, sides: int) -> Vector3:\n"
if point_y_marker not in compiler:
    raise SystemExit("expected point-y helper")
compiler = compiler.replace(point_y_marker, z_loft + point_y_marker, 1)

old_point_x = '''static func _point_x(ring: Dictionary, side: int, sides: int) -> Vector3:
\tvar angle := float(side) * TAU / float(sides)
\tvar center: Vector3 = ring["center"]
\treturn center + Vector3(0.0, cos(angle) * float(ring["ry"]), sin(angle) * float(ring["rz"]))
'''
new_point_x = '''static func _point_x(ring: Dictionary, side: int, sides: int) -> Vector3:
\tvar angle := float(side) * TAU / float(sides)
\tvar center: Vector3 = ring["center"]
\treturn center + Vector3(0.0, cos(angle) * float(ring["ry"]), sin(angle) * float(ring["rz"]))


static func _point_z(ring: Dictionary, side: int, sides: int) -> Vector3:
\tvar angle := float(side) * TAU / float(sides)
\tvar center: Vector3 = ring["center"]
\treturn center + Vector3(cos(angle) * float(ring["rx"]), sin(angle) * float(ring["ry"]), 0.0)
'''
if old_point_x not in compiler:
    raise SystemExit("expected point-x helper")
compiler = compiler.replace(old_point_x, new_point_x, 1)

old_x_cap = '''static func _add_x_cap(builders: Dictionary, palette_index: int, ring: Dictionary, sides: int, direction: float) -> void:
\tvar center: Vector3 = ring["center"]
\tvar normal := Vector3(direction, 0, 0)
\tfor side in range(sides):
\t\tvar p0 := _point_x(ring, side, sides)
\t\tvar p1 := _point_x(ring, (side + 1) % sides, sides)
\t\t_emit_triangle(builders, palette_index, center, p0, p1, normal, ring["skin"], ring["skin"], ring["skin"], Vector2(0.5,0.5), Vector2.ZERO, Vector2.ONE)
'''
new_x_cap = '''static func _add_x_cap(builders: Dictionary, palette_index: int, ring: Dictionary, sides: int, direction: float) -> void:
\tvar center: Vector3 = ring["center"]
\tvar normal := Vector3(direction, 0, 0)
\tfor side in range(sides):
\t\tvar p0 := _point_x(ring, side, sides)
\t\tvar p1 := _point_x(ring, (side + 1) % sides, sides)
\t\t_emit_triangle(builders, palette_index, center, p0, p1, normal, ring["skin"], ring["skin"], ring["skin"], Vector2(0.5,0.5), Vector2.ZERO, Vector2.ONE)


static func _add_z_cap(builders: Dictionary, palette_index: int, ring: Dictionary, sides: int, direction: float) -> void:
\tvar center: Vector3 = ring["center"]
\tvar normal := Vector3(0, 0, direction)
\tfor side in range(sides):
\t\tvar p0 := _point_z(ring, side, sides)
\t\tvar p1 := _point_z(ring, (side + 1) % sides, sides)
\t\t_emit_triangle(builders, palette_index, center, p0, p1, normal, ring["skin"], ring["skin"], ring["skin"], Vector2(0.5,0.5), Vector2.ZERO, Vector2.ONE)
'''
if old_x_cap not in compiler:
    raise SystemExit("expected x-cap helper")
compiler = compiler.replace(old_x_cap, new_x_cap, 1)

old_foot = '''\tvar half_width: float = float(profile.foot_width) * 0.50 + 0.010
\t_add_box(builders, LEATHER, Vector3(x - half_width, float(landmark["sole_y"]) + 0.025, -profile.foot_length * 0.72), Vector3(x + half_width, float(landmark["foot_top_y"]), profile.foot_length * 0.28), _weights(foot_bone), 0.018)
\t_add_box(builders, SOLE, Vector3(x - half_width - 0.006, float(landmark["sole_y"]), -profile.foot_length * 0.74), Vector3(x + half_width + 0.006, float(landmark["sole_y"]) + 0.035, profile.foot_length * 0.30), _weights(foot_bone), 0.010)
'''
new_foot = '''\t# The shoe is a true heel-to-toe faceted volume.  Ring widths and vertical
\t# mass describe heel, instep, ball and tapered toe instead of ending the leg
\t# in the former rectangular leather/sole slabs.
\tvar sole_y: float = float(landmark["sole_y"])
\tvar foot_top_y: float = float(landmark["foot_top_y"])
\tvar foot_skin: Dictionary = _weights(foot_bone)
\tvar heel_z: float = float(profile.foot_length) * 0.27
\tvar instep_z: float = float(profile.foot_length) * 0.06
\tvar ball_z: float = -float(profile.foot_length) * 0.39
\tvar toe_z: float = -float(profile.foot_length) * 0.73
\tvar foot_rings: Array[Dictionary] = [
\t\t_ring_z(Vector3(x, sole_y + 0.067, heel_z), profile.foot_width * 0.47, 0.047, foot_skin),
\t\t_ring_z(Vector3(x, sole_y + 0.079, instep_z), profile.foot_width * 0.53, minf(0.064, foot_top_y - sole_y - 0.020), foot_skin),
\t\t_ring_z(Vector3(x, sole_y + 0.066, ball_z), profile.foot_width * 0.59, 0.052, foot_skin),
\t\t_ring_z(Vector3(x, sole_y + 0.052, toe_z), profile.foot_width * 0.43, 0.036, foot_skin),
\t]
\t_add_z_loft(builders, LEATHER, foot_rings, 8, true, true, -1.0)

\t# Separate low sole follows the same taper so the planted silhouette stays
\t# rugged without becoming a dark rectangular platform.
\tvar sole_rings: Array[Dictionary] = [
\t\t_ring_z(Vector3(x, sole_y + 0.018, heel_z + 0.006), profile.foot_width * 0.52, 0.018, foot_skin),
\t\t_ring_z(Vector3(x, sole_y + 0.018, instep_z), profile.foot_width * 0.58, 0.018, foot_skin),
\t\t_ring_z(Vector3(x, sole_y + 0.018, ball_z - 0.004), profile.foot_width * 0.64, 0.018, foot_skin),
\t\t_ring_z(Vector3(x, sole_y + 0.017, toe_z - 0.008), profile.foot_width * 0.47, 0.017, foot_skin),
\t]
\t_add_z_loft(builders, SOLE, sole_rings, 8, true, true, -1.0)
'''
if old_foot not in compiler:
    raise SystemExit("expected rev9 foot block")
compiler = compiler.replace(old_foot, new_foot, 1)

pack = r'''\t# The pack now owns a deliberate expedition silhouette: broad canvas body,
\t# tapered shoulders, a raised flap and lower pocket, visible straps/buckles,
\t# and a bedroll that reads as attached gear rather than the entire rear mass.
\t_add_y_loft(builders, CANVAS_DARK, [
\t\t_ring_y(Vector3(0, waist_y - 0.020, 0.220), 0.145, 0.070, _weights(BONE.chest)),
\t\t_ring_y(Vector3(0, lerpf(waist_y, lower_chest_y, 0.48), 0.238), 0.190, 0.105, _weights(BONE.chest)),
\t\t_ring_y(Vector3(0, chest_y - 0.045, 0.242), 0.205, 0.112, _weights(BONE.chest)),
\t\t_ring_y(Vector3(0, shoulder_y - 0.155, 0.235), 0.192, 0.105, _weights(BONE.chest)),
\t\t_ring_y(Vector3(0, shoulder_y - 0.070, 0.218), 0.158, 0.082, _weights(BONE.chest)),
\t], 8, true, true)

\t# Tapered rear flap and lower pocket are separate prismatic garment layers,
\t# producing useful planes in back/3-4 views instead of rectangular blocks.
\t_add_quad_prism_z(builders, CANVAS_LIGHT,
\t\tVector2(-0.170, chest_y + 0.060),
\t\tVector2(0.170, chest_y + 0.060),
\t\tVector2(0.145, chest_y - 0.105),
\t\tVector2(-0.145, chest_y - 0.105),
\t\t0.338, 0.372, _weights(BONE.chest))
\t_add_quad_prism_z(builders, CANVAS_DARK,
\t\tVector2(-0.135, waist_y + 0.175),
\t\tVector2(0.135, waist_y + 0.175),
\t\tVector2(0.115, waist_y + 0.035),
\t\tVector2(-0.115, waist_y + 0.035),
\t\t0.344, 0.382, _weights(BONE.chest))

\tfor strap_x in [-0.112, 0.112]:
\t\t_add_ribbon_z(builders, LEATHER_LIGHT,
\t\t\tVector2(strap_x, waist_y + 0.030),
\t\t\tVector2(strap_x, shoulder_y - 0.085),
\t\t\t0.386, 0.015, _weights(BONE.chest), _weights(BONE.chest), 1.0)
\t\t_add_box(builders, METAL,
\t\t\tVector3(strap_x - 0.018, lower_chest_y - 0.010, 0.384),
\t\t\tVector3(strap_x + 0.018, lower_chest_y + 0.024, 0.397),
\t\t\t_weights(BONE.chest), 0.004)

\t# Teal bedroll sits across the pack crown and extends just beyond the pack
\t# shoulders, matching the locked turnaround's recognizable rear silhouette.
\t_add_x_loft(builders, ACCENT, [
\t\t_ring_x(Vector3(-0.205, shoulder_y - 0.010, 0.305), 0.064, 0.066, _weights(BONE.chest)),
\t\t_ring_x(Vector3(0.205, shoulder_y - 0.010, 0.305), 0.064, 0.066, _weights(BONE.chest)),
\t], 8, true, true, 1.0)
\tfor roll_strap_x in [-0.112, 0.112]:
\t\t_add_ribbon_z(builders, LEATHER,
\t\t\tVector2(roll_strap_x, shoulder_y - 0.072),
\t\t\tVector2(roll_strap_x, shoulder_y + 0.052),
\t\t\t0.374, 0.014, _weights(BONE.chest), _weights(BONE.chest), 1.0)
\t\t_add_box(builders, METAL,
\t\t\tVector3(roll_strap_x - 0.014, shoulder_y - 0.016, 0.373),
\t\t\tVector3(roll_strap_x + 0.014, shoulder_y + 0.012, 0.385),
\t\t\t_weights(BONE.chest), 0.003)
'''.replace('\\t', '\t')
compiler = replace_between(
    compiler,
    "\t# Pack/bedroll stay bone-bound while the torso front converges.\n",
    "\t# Two balanced utility pouches stay clear of hand sockets/collision.\n",
    pack,
)

if '_entry("metal", Color("858b8e"), 0.38, 0.62),' not in factory:
    raise SystemExit("expected rev9 metal palette")
factory = factory.replace(
    '_entry("metal", Color("858b8e"), 0.38, 0.62),',
    '_entry("metal", Color("777d7b"), 0.82, 0.18),',
    1,
)
if '_entry("canvas_dark", Color("5f5544"), 0.96, 0.0),' not in factory:
    raise SystemExit("expected rev9 dark-canvas palette")
factory = factory.replace(
    '_entry("canvas_dark", Color("5f5544"), 0.96, 0.0),',
    '_entry("canvas_dark", Color("6c624f"), 0.96, 0.0),',
    1,
)

old_axe = '''static func _axe_head_cells() -> Array[Dictionary]:
\tvar cells: Array[Dictionary] = []
\t# A compact one-sided stone blade with a small rear poll.  The silhouette
\t# stays readable after greedy compilation without returning to a debug box.
\tfor z in range(0, 2):
\t\tfor y in range(3, 7):
\t\t\tvar minimum_x: int = -2 if y in [4, 5] else -1
\t\t\tvar maximum_x: int = 1 if y in [3, 4] else 0
\t\t\tfor x in range(minimum_x, maximum_x + 1):
\t\t\t\tvar palette_index: int = LEATHER_LIGHT if x == 0 and y in [3, 4] else METAL
\t\t\t\tcells.append({"position": Vector3i(x, y, z), "palette_index": palette_index})
\treturn cells'''
new_axe = '''static func _axe_head_cells() -> Array[Dictionary]:
\tvar cells: Array[Dictionary] = []
\t# Broad asymmetric stone blade: the cutting edge fans to the left while a
\t# short rear poll and leather lash keep the haft relationship obvious.
\tvar rows := {
\t\t3: [-1, 1],
\t\t4: [-3, 2],
\t\t5: [-4, 1],
\t\t6: [-4, 0],
\t\t7: [-3, -1],
\t}
\tfor z in range(0, 2):
\t\tfor y_value in rows.keys():
\t\t\tvar y: int = int(y_value)
\t\t\tvar span: Array = rows[y_value]
\t\t\tfor x in range(int(span[0]), int(span[1]) + 1):
\t\t\t\tvar is_lash: bool = x in [0, 1] and y in [3, 4]
\t\t\t\tvar palette_index: int = LEATHER_LIGHT if is_lash else METAL
\t\t\t\tcells.append({"position": Vector3i(x, y, z), "palette_index": palette_index})
\treturn cells'''
if old_axe not in factory:
    raise SystemExit("expected rev9 axe block")
factory = factory.replace(old_axe, new_axe, 1)

compiler_path.write_text(compiler)
factory_path.write_text(factory)
