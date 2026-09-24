import bpy, bmesh
import os, math
from mathutils import Vector

OUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "content", "characters", "base_meshes"))
os.makedirs(OUT_DIR, exist_ok=True)

# Explicit (x, y, z) landmarks prevent compact tuple axis swaps.
BONES = {
    "root": ((0.0, 0.08, 0.0), (0.0, 0.08, 0.08)), "pelvis": ((0.0, 0.08, 0.82), (0.0, 0.08, 1.02)),
    "spine_01": ((0.0, 0.08, 1.02), (0.0, 0.08, 1.24)), "spine_02": ((0.0, 0.08, 1.24), (0.0, 0.08, 1.42)),
    "chest": ((0.0, 0.08, 1.42), (0.0, 0.08, 1.56)), "neck": ((0.0, 0.08, 1.56), (0.0, 0.08, 1.70)),
    "head": ((0.0, 0.08, 1.70), (0.0, 0.08, 1.92)), "clavicle_l": ((0.0, 0.08, 1.49), (-0.27, 0.08, 1.49)),
    "upperarm_l": ((-0.27, 0.08, 1.49), (-0.52, 0.08, 1.34)), "forearm_l": ((-0.52, 0.08, 1.34), (-0.72, 0.08, 1.14)),
    "hand_l": ((-0.72, 0.08, 1.14), (-0.82, 0.08, 1.08)), "clavicle_r": ((0.0, 0.08, 1.49), (0.27, 0.08, 1.49)),
    "upperarm_r": ((0.27, 0.08, 1.49), (0.52, 0.08, 1.34)), "forearm_r": ((0.52, 0.08, 1.34), (0.72, 0.08, 1.14)),
    "hand_r": ((0.72, 0.08, 1.14), (0.82, 0.08, 1.08)), "thigh_l": ((-0.16, 0.08, 0.84), (-0.19, 0.08, 0.46)),
    "calf_l": ((-0.19, 0.08, 0.46), (-0.19, 0.08, 0.10)), "foot_l": ((-0.19, 0.08, 0.10), (-0.19, -0.20, 0.06)),
    "thigh_r": ((0.16, 0.08, 0.84), (0.19, 0.08, 0.46)), "calf_r": ((0.19, 0.08, 0.46), (0.19, 0.08, 0.10)),
    "foot_r": ((0.19, 0.08, 0.10), (0.19, -0.20, 0.06)),
}
PARENTS = {"pelvis":"root", "spine_01":"pelvis", "spine_02":"spine_01", "chest":"spine_02", "neck":"chest", "head":"neck", "clavicle_l":"chest", "upperarm_l":"clavicle_l", "forearm_l":"upperarm_l", "hand_l":"forearm_l", "clavicle_r":"chest", "upperarm_r":"clavicle_r", "forearm_r":"upperarm_r", "hand_r":"forearm_r", "thigh_l":"pelvis", "calf_l":"thigh_l", "foot_l":"calf_l", "thigh_r":"pelvis", "calf_r":"thigh_r", "foot_r":"calf_r"}

def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

def skin_material():
    mat = bpy.data.materials.get("Underworld_Base_Skin") or bpy.data.materials.new("Underworld_Base_Skin")
    mat.diffuse_color = (0.42, 0.24, 0.16, 1.0); mat.metallic = 0.0; mat.roughness = 0.82
    return mat

def add_uv(name, loc, scale):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, location=loc)
    obj = bpy.context.object; obj.name = name; obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj

def add_cylinder(name, a, b, radius):
    a, b = Vector(a), Vector(b); delta = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=delta.length, location=(a+b)*0.5)
    obj = bpy.context.object; obj.name = name; obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0,0,1)).rotation_difference(delta.normalized())
    return obj

def add_tapered(name, a, b, radius_a, radius_b, vertices=20):
    a, b = Vector(a), Vector(b); delta = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius_a, radius2=radius_b, depth=delta.length, location=(a+b)*0.5)
    obj = bpy.context.object; obj.name = name; obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0,0,1)).rotation_difference(delta.normalized())
    return obj

def make_armature(name):
    data = bpy.data.armatures.new(name + "_Rig"); arm = bpy.data.objects.new(name + "_Rig", data); bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm; arm.select_set(True); bpy.ops.object.mode_set(mode="EDIT")
    created = {}
    for bone_name, (head, tail) in BONES.items():
        bone = data.edit_bones.new(bone_name); bone.head = head; bone.tail = tail
        parent = PARENTS.get(bone_name)
        if parent:
            bone.parent = created[parent]; bone.use_connect = bone_name not in ("clavicle_l", "clavicle_r", "thigh_l", "thigh_r")
        created[bone_name] = bone
    bpy.ops.object.mode_set(mode="OBJECT"); arm.select_set(False); return arm

def point_segment_distance(point, a, b):
    ab = b - a; t = max(0.0, min(1.0, (point-a).dot(ab) / max(ab.length_squared, 1e-8)))
    return (point - (a + t*ab)).length

def assign_smooth_weights(mesh):
    for bone_name in BONES: mesh.vertex_groups.new(name=bone_name)
    segments = [(name, Vector(head), Vector(tail)) for name, (head, tail) in BONES.items()]
    for vertex in mesh.data.vertices:
        p = vertex.co; candidates = segments
        if p.x < -0.16 and p.z > 1.02: candidates = [s for s in segments if s[0].endswith("_l") or s[0] in ("chest", "spine_02")]
        elif p.x > 0.16 and p.z > 1.02: candidates = [s for s in segments if s[0].endswith("_r") or s[0] in ("chest", "spine_02")]
        elif p.z < 0.88 and abs(p.x) > 0.08:
            side = "_l" if p.x < 0 else "_r"
            candidates = [s for s in segments if s[0].endswith(side) and s[0].startswith(("thigh", "calf", "foot"))] + [s for s in segments if s[0] == "pelvis"]
        chosen = sorted((point_segment_distance(p,a,b), name) for name,a,b in candidates)[:3]
        inv = [1.0/max(d,0.012)**2 for d,_ in chosen]; total = sum(inv)
        for value, (_, bone_name) in zip(inv, chosen): mesh.vertex_groups[bone_name].add([vertex.index], value/total, "REPLACE")

def _ring_surface(verts, faces, rings, sides=16, cap_start=True, cap_end=True):
    """Append a deterministic quad-ring surface from (center, rx, ry) rings."""
    start=len(verts)
    for ring in rings:
        z,cx,cy,rx,ry = ring[:5]; front_bias = ring[5] if len(ring) > 5 else 0.0; back_bias = ring[6] if len(ring) > 6 else 0.0
        for i in range(sides):
            a=2.0*math.pi*i/sides; sy=math.sin(a); bias=front_bias if sy < 0 else back_bias
            verts.append((cx+rx*math.cos(a), cy+(ry+bias)*sy, z))
    for r in range(len(rings)-1):
        for i in range(sides):
            a=start+r*sides+i; b=start+r*sides+(i+1)%sides; c=start+(r+1)*sides+(i+1)%sides; d=start+(r+1)*sides+i; faces.append((a,b,c,d))
    if cap_start: faces.append(tuple(start+i for i in range(sides-1,-1,-1)))
    if cap_end:
        top=start+(len(rings)-1)*sides; faces.append(tuple(top+i for i in range(sides)))

def _segment_surface(verts, faces, points, radii, sides=10, cap_start=True, cap_end=True):
    """Append a multi-landmark limb with circular quad rings and caps."""
    start=len(verts); rings=[]
    for j,p in enumerate(points):
        p=Vector(p); tangent=(Vector(points[min(j+1,len(points)-1)])-Vector(points[max(0,j-1)])).normalized(); axis=Vector((0,0,1)) if abs(tangent.z)<0.9 else Vector((0,1,0)); u=tangent.cross(axis).normalized(); v=tangent.cross(u).normalized(); rings.append(len(verts))
        for i in range(sides):
            a=2.0*math.pi*i/sides; q=p+radii[j]*(math.cos(a)*u+math.sin(a)*v); verts.append(tuple(q))
    for j in range(len(points)-1):
        for i in range(sides):
            a=rings[j]+i; b=rings[j]+(i+1)%sides; c=rings[j+1]+(i+1)%sides; d=rings[j+1]+i; faces.append((a,b,c,d))
    if cap_start: faces.append(tuple(rings[0]+i for i in range(sides-1,-1,-1)))
    if cap_end: faces.append(tuple(rings[-1]+i for i in range(sides)))

def build_male_topology():
    verts=[]; faces=[]
    # Torso cage: broad chest, explicit abdomen and a real chest-to-waist taper.
    _ring_surface(verts,faces,[(0.48,0,.105,.205,.135),(0.56,0,.105,.225,.150),(0.66,0,.100,.220,.145),(0.76,0,.095,.180,.125),(0.84,0,.090,.205,.138),(0.96,0,.085,.220,.145),(1.08,0,.08,.175,.105),(1.20,0,.08,.180,.108),(1.32,0,.08,.205,.120,.016,.010),(1.44,0,.08,.270,.145,.040,.024),(1.54,0,.08,.285,.140,.032,.020),(1.61,0,.08,.205,.105,.014,.008),(1.68,0,.08,.120,.090),(1.73,0,.08,.085,.075)],16,True,True)
    _ring_surface(verts,faces,[(1.70,0,.08,.095,.065,.026,.004),(1.77,0,.08,.115,.078,.042,.006),(1.88,0,.08,.105,.085,.028,.004),(1.96,0,.08,.075,.068,.008,.002),(2.00,0,.08,.035,.032)],14,True,True)
    # Arms: shoulder, elbow and wrist landmarks are explicit rings, not tubes.
    for s in (-1,1):
        _segment_surface(verts,faces,[(s*.18,.08,1.54),(s*.29,.08,1.50),(s*.47,.08,1.39)],[.145,.112,.068],10,True,True)
        _segment_surface(verts,faces,[(s*.30,.08,1.50),(s*.47,.08,1.39),(s*.66,.08,1.18),(s*.75,.06,1.10),(s*.82,.045,1.065),(s*.87,.035,1.045)],[.095,.068,.050,.034,.038,.022],10,True,True)
        _segment_surface(verts,faces,[(s*.16,.08,.62),(s*.18,.08,.56),(s*.195,.08,.47),(s*.19,.08,.38),(s*.19,.08,.12)],[.160,.145,.100,.085,.050],10,True,True)
        _segment_surface(verts,faces,[(s*.19,.08,.12),(s*.19,-.035,.07),(s*.19,-.105,.055)],[.055,.060,.052],8,True,True)
    mesh=bpy.data.meshes.new("MaleControlledTopology"); mesh.from_pydata(verts,[],faces); mesh.update(); obj=bpy.data.objects.new("MaleBaseBody",mesh); bpy.context.collection.objects.link(obj); obj.data.materials.append(skin_material())
    for poly in mesh.polygons: poly.use_smooth=True
    # Join the authored closed ring/segment volumes with exact Boolean unions.
    # This preserves the explicit construction while producing one connected,
    # manifold Male surface instead of overlapping loose shells.
    bpy.context.view_layer.objects.active=obj; obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.separate(type="LOOSE"); bpy.ops.object.mode_set(mode="OBJECT")
    parts=[o for o in bpy.context.selected_objects if o.type=="MESH"]
    base=max(parts,key=lambda o: len(o.data.vertices))
    for part in list(parts):
        if part==base: continue
        bpy.context.view_layer.objects.active=base
        mod=base.modifiers.new("AuthoredBridgeUnion","BOOLEAN"); mod.operation="UNION"; mod.solver="EXACT"; mod.object=part
        try: bpy.ops.object.modifier_apply(modifier=mod.name)
        except RuntimeError: pass
        bpy.data.objects.remove(part, do_unlink=True)
    obj=base; obj.name="MaleBaseBody"; obj.data.materials.clear(); obj.data.materials.append(skin_material())
    cleanup=bmesh.new(); cleanup.from_mesh(obj.data); cleanup.verts.ensure_lookup_table(); bmesh.ops.remove_doubles(cleanup, verts=cleanup.verts, dist=1e-5); cleanup.faces.ensure_lookup_table()
    degenerate=[f for f in cleanup.faces if f.calc_area() <= 1e-8]
    if degenerate: bmesh.ops.delete(cleanup, geom=degenerate, context='FACES')
    boundary_edges=[e for e in cleanup.edges if len(e.link_faces)==1]
    if boundary_edges: bmesh.ops.holes_fill(cleanup, edges=boundary_edges, sides=0)
    cleanup.to_mesh(obj.data); cleanup.free(); obj.data.update()
    # Smooth anatomical shaping on the connected torso surface.  This is a
    # vertex-space falloff, not an added shell: it preserves the single
    # manifold body while giving the male chest and abdomen readable planes.
    for vertex in obj.data.vertices:
        x, y, z = vertex.co
        if y < 0.02:
            if 1.30 <= z <= 1.54:
                pectoral = math.exp(-(((abs(x) - 0.090) / 0.095) ** 2) - (((z - 1.435) / 0.125) ** 2))
                vertex.co.y -= 0.070 * pectoral
            if 1.08 <= z <= 1.36:
                abdomen = math.exp(-((x / 0.145) ** 2) - (((z - 1.225) / 0.145) ** 2))
                vertex.co.y -= 0.028 * abdomen
                sternum = math.exp(-((x / 0.030) ** 2) - (((z - 1.405) / 0.165) ** 2))
                vertex.co.y += 0.012 * sternum
        elif y > 0.10 and 1.20 <= z <= 1.58:
            lat = math.exp(-(((abs(x) - 0.16) / 0.16) ** 2) - (((z - 1.40) / 0.22) ** 2))
            trap = math.exp(-(((abs(x) - 0.095) / 0.090) ** 2) - (((z - 1.56) / 0.095) ** 2))
            vertex.co.y += 0.024 * lat + 0.012 * trap
        if y < 0.02 and 1.68 <= z <= 1.90:
            nose = math.exp(-((x / 0.042) ** 2) - (((z - 1.785) / 0.060) ** 2))
            brow = math.exp(-(((abs(x) - 0.040) / 0.050) ** 2) - (((z - 1.835) / 0.028) ** 2))
            chin = math.exp(-((x / 0.060) ** 2) - (((z - 1.710) / 0.032) ** 2))
            vertex.co.y -= 0.020 * nose + 0.008 * brow + 0.010 * chin
        if y > 0.08 and 0.76 <= z <= 1.16:
            glute = math.exp(-((x / 0.215) ** 2) - (((z - 0.965) / 0.190) ** 2))
            vertex.co.y += 0.022 * glute
    obj.data.update()
    for poly in obj.data.polygons: poly.use_smooth=True
    smooth=obj.modifiers.new("MaleTopologySubdivision","SUBSURF"); smooth.subdivision_type='CATMULL_CLARK'; smooth.levels=1; smooth.render_levels=1
    armature=make_armature("MaleBaseBody"); assign_smooth_weights(obj); mod=obj.modifiers.new("SharedHumanoidRig","ARMATURE"); mod.object=armature; obj.parent=armature; return obj,armature

def build_body(kind):
    male = kind == "male"
    if male:
        return build_male_topology()
    shoulder = 0.275 if male else 0.255
    rib_x, rib_y = (0.285, 0.145) if male else (0.260, 0.145)
    # First isolated geometry turn: tighten only the torso waist mass. Ribcage,
    # pelvis, glute/upper-thigh, height, shoulders, head/neck and rig stay fixed.
    waist_x, waist_y = (0.185, 0.105) if male else (0.180, 0.100)
    pelvis_x, pelvis_y = (0.220, 0.140) if male else (0.290, 0.170)
    arm = 0.060 if male else 0.058
    thigh = 0.120 if male else 0.130
    neck_radius = 0.080 if male else 0.073
    head_radius = 0.102 if male else 0.105
    # Deliberately separate anatomical masses: ribcage -> waist -> pelvis.
    # The overlaps are structural and are fused by the deterministic remesh.
    parts = [
        add_uv("Ribcage", (0, 0.08, 1.43), (rib_x, rib_y, 0.220)),
        add_uv("UpperBack", (0, 0.14, 1.45), (rib_x * 0.93, 0.083 if male else 0.074, 0.18)),
        add_uv("Abdomen", (0, 0.08, 1.27), (0.220 if male else 0.190, 0.120 if male else 0.110, 0.155)),
        add_uv("Waist", (0, 0.08, 1.135), (waist_x, waist_y, 0.110)),
        add_uv("Pelvis", (0, 0.08, 1.005), (pelvis_x, pelvis_y, 0.130)),
        add_uv("GlutealMass", (0, 0.145, 0.96), (pelvis_x * 0.84, 0.070 if male else 0.084, 0.115)),
        add_uv("HeadCranium", (0, 0.065, 1.85), (head_radius, 0.094, 0.098)),
        add_uv("UpperFace", (0, -0.030, 1.815), (head_radius * 0.56, 0.040, 0.070)),
        add_uv("Jaw", (0, -0.010, 1.755), (head_radius * (0.74 if male else 0.70), 0.054, 0.056)),
        add_uv("Chin", (0, -0.045, 1.725), (head_radius * (0.40 if male else 0.36), 0.029, 0.025)),
        add_tapered("Neck", (0, 0.08, 1.57), (0, 0.08, 1.70), neck_radius, neck_radius * 0.83),
    ]
    for side in (-1,1):
        parts += [
            add_uv("Trap", (side * (0.112 if male else 0.098), 0.095 if male else 0.088, 1.565), (0.112 if male else 0.098, 0.058 if male else 0.050, 0.062 if male else 0.052)),
            add_uv("ClavicleBridge", (side * (0.125 if male else 0.11), 0.005, 1.525), (0.125 if male else 0.11, 0.040 if male else 0.035, 0.030 if male else 0.027)),
            add_uv("Deltoid", (side * shoulder, 0.08, 1.48), (0.070 if male else 0.055, 0.080 if male else 0.070, 0.075 if male else 0.065)),
            add_tapered("UpperArm", (side * shoulder, 0.08, 1.48), (side * 0.52, 0.08, 1.34), arm, arm * 0.78),
            add_uv("Elbow", (side * 0.535, 0.08, 1.325), (arm * 0.82, arm * 1.05, arm * 0.82)),
            add_tapered("Forearm", (side * 0.52, 0.08, 1.34), (side * 0.71, 0.08, 1.14), arm * 0.82, arm * 0.53),
            add_tapered("Wrist", (side * 0.71, 0.08, 1.14), (side * 0.755, 0.08, 1.085), arm * 0.55, arm * 0.42),
            add_uv("Palm", (side * 0.795, 0.065, 1.065), ((0.043 if male else 0.039), 0.048 if male else 0.044, 0.038 if male else 0.035)),
            add_uv("Thumb", (side * 0.815, -0.010, 1.075), (0.023 if male else 0.021, 0.025 if male else 0.023, 0.028 if male else 0.026)),
            add_uv("FingerBlock", (side * 0.858, 0.065, 1.045), (0.050 if male else 0.045, 0.038 if male else 0.034, 0.024 if male else 0.022)),
            add_uv("ArmpitTransition", (side * (0.205 if male else 0.175), 0.075 if male else 0.070, 1.405), (0.055 if male else 0.045, 0.050 if male else 0.045, 0.075 if male else 0.065)),
            add_uv("ThighMass", (side * 0.150, 0.08, 0.72), (0.095 if male else 0.112, 0.098 if male else 0.108, 0.205)),
            add_tapered("Thigh", (side * 0.150, 0.08, 0.95), (side * 0.19, 0.08, 0.46), thigh * 0.92, thigh * 0.62),
            add_uv("Knee", (side * 0.19, 0.055, 0.445), (thigh * 0.50, 0.085, 0.065)),
            add_tapered("Calf", (side * 0.19, 0.09, 0.46), (side * 0.19, 0.08, 0.10), thigh * 0.60, thigh * 0.32),
            add_uv("CalfDiamond", (side * 0.19, 0.13, 0.33), (thigh * 0.50, 0.070, 0.15)),
            add_uv("Ankle", (side * 0.19, 0.08, 0.105), (thigh * 0.285, 0.050, 0.058)),
            add_uv("Heel", (side * 0.19, 0.020, 0.055), (0.062 if male else 0.058, 0.070 if male else 0.068, 0.050 if male else 0.048)),
            add_uv("Instep", (side * 0.19, -0.040, 0.080), (0.058 if male else 0.054, 0.075 if male else 0.070, 0.045 if male else 0.042)),
            add_uv("ToeBlock", (side * 0.19, -0.105, 0.050), (0.074 if male else 0.069, 0.100 if male else 0.095, 0.036 if male else 0.034)),
        ]
        if male:
            parts += [add_uv("PectoralMass", (side * 0.080, -0.050, 1.405), (0.085, 0.035, 0.055))]
        else:
            parts += [add_uv("ChestVolume", (side * 0.078, -0.048, 1.41), (0.072, 0.033, 0.058))]
    if male:
        parts += [add_uv("MaleAbsUpper", (0, -0.040, 1.285), (0.145, 0.030, 0.070)), add_uv("MaleAbsLower", (0, -0.035, 1.190), (0.125, 0.028, 0.065)), add_uv("MaleNose", (0, -0.092, 1.795), (0.026, 0.040, 0.030)), add_uv("MaleBrow", (0, -0.070, 1.835), (0.070, 0.025, 0.022))]
    mat = skin_material(); bpy.ops.object.select_all(action="DESELECT")
    for obj in parts: obj.select_set(True); obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = parts[0]; bpy.ops.object.join(); mesh = bpy.context.object; mesh.name = ("Male" if male else "Female") + "BaseBody"
    # Joining into the torso keeps its object transform.  Apply it before
    # remeshing so mesh vertices stay in the same world space as the rig.
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    remesh = mesh.modifiers.new("ContinuousBodySurface","REMESH"); remesh.mode = "VOXEL"; remesh.voxel_size = 0.035; remesh.adaptivity = 0.0
    bpy.context.view_layer.objects.active = mesh; bpy.ops.object.modifier_apply(modifier=remesh.name)
    for poly in mesh.data.polygons: poly.use_smooth = True
    armature = make_armature(("Male" if male else "Female") + "BaseBody"); assign_smooth_weights(mesh)
    modifier = mesh.modifiers.new("SharedHumanoidRig","ARMATURE"); modifier.object = armature; mesh.parent = armature
    return mesh, armature

def export_pair(mesh, armature, filename):
    bpy.ops.object.select_all(action="DESELECT"); mesh.select_set(True); armature.select_set(True); bpy.context.view_layer.objects.active = mesh
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_DIR, filename), export_format="GLB", use_selection=True, export_yup=True, export_apply=False)

clear_scene(); male_mesh, male_arm = build_body("male"); female_mesh, female_arm = build_body("female")
export_pair(male_mesh, male_arm, "underworld_male_base_body.glb"); export_pair(female_mesh, female_arm, "underworld_female_base_body.glb")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "underworld_base_bodies.blend")); print("BASE_BODIES_READY", OUT_DIR)
