import bpy
import os
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

def build_body(kind):
    male = kind == "male"
    shoulder = 0.240 if male else 0.205
    rib_x, rib_y = (0.250, 0.145) if male else (0.205, 0.130)
    waist_x, waist_y = (0.190, 0.110) if male else (0.170, 0.100)
    pelvis_x, pelvis_y = (0.210, 0.140) if male else (0.230, 0.150)
    arm = 0.070 if male else 0.058
    thigh = 0.115 if male else 0.112
    neck_radius = 0.092 if male else 0.073
    head_radius = 0.108 if male else 0.105
    # Deliberately separate anatomical masses: ribcage -> waist -> pelvis.
    # The overlaps are structural and are fused by the deterministic remesh.
    parts = [
        add_uv("Ribcage", (0, 0.08, 1.43), (rib_x, rib_y, 0.220)),
        add_uv("UpperBack", (0, 0.14, 1.45), (rib_x * 0.93, 0.083 if male else 0.074, 0.18)),
        add_uv("Abdomen", (0, 0.08, 1.27), (0.220 if male else 0.190, 0.120 if male else 0.110, 0.155)),
        add_uv("Waist", (0, 0.08, 1.135), (waist_x, waist_y, 0.110)),
        add_uv("Pelvis", (0, 0.08, 1.005), (pelvis_x, pelvis_y, 0.130)),
        add_uv("GlutealMass", (0, 0.145, 0.96), (pelvis_x * 0.88, 0.075 if male else 0.090, 0.115)),
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
            add_uv("ThighMass", (side * 0.150, 0.08, 0.72), (0.108 if male else 0.112, 0.112 if male else 0.108, 0.205)),
            add_tapered("Thigh", (side * 0.150, 0.08, 0.95), (side * 0.19, 0.08, 0.46), thigh * 0.92, thigh * 0.62),
            add_uv("Knee", (side * 0.19, 0.055, 0.445), (thigh * 0.50, 0.085, 0.065)),
            add_tapered("Calf", (side * 0.19, 0.09, 0.46), (side * 0.19, 0.08, 0.10), thigh * 0.60, thigh * 0.32),
            add_uv("CalfDiamond", (side * 0.19, 0.13, 0.33), (thigh * 0.50, 0.070, 0.15)),
            add_uv("Ankle", (side * 0.19, 0.08, 0.105), (thigh * 0.285, 0.050, 0.058)),
            add_uv("Heel", (side * 0.19, 0.020, 0.055), (0.062 if male else 0.058, 0.070 if male else 0.068, 0.050 if male else 0.048)),
            add_uv("Instep", (side * 0.19, -0.040, 0.080), (0.058 if male else 0.054, 0.075 if male else 0.070, 0.045 if male else 0.042)),
            add_uv("ToeBlock", (side * 0.19, -0.105, 0.050), (0.074 if male else 0.069, 0.100 if male else 0.095, 0.036 if male else 0.034)),
        ]
        if not male:
            parts += [add_uv("ChestVolume", (side * 0.078, -0.048, 1.41), (0.072, 0.033, 0.058))]
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
