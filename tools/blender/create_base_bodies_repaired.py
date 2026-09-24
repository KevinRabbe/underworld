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
    shoulder = 0.32 if male else 0.265
    rib_x, rib_y = (0.30, 0.16) if male else (0.255, 0.145)
    waist_x, waist_y = (0.21, 0.13) if male else (0.18, 0.12)
    pelvis_x, pelvis_y = (0.24, 0.16) if male else (0.27, 0.17)
    arm = 0.082 if male else 0.070
    thigh = 0.145 if male else 0.132
    neck_radius = 0.092 if male else 0.073
    head_radius = 0.108 if male else 0.105
    # Deliberately separate anatomical masses: ribcage -> waist -> pelvis.
    # The overlaps are structural and are fused by the deterministic remesh.
    parts = [
        add_uv("Ribcage", (0, 0.08, 1.38), (rib_x, rib_y, 0.255)),
        add_uv("UpperBack", (0, 0.14, 1.42), (rib_x * 0.93, 0.10 if male else 0.09, 0.21)),
        add_uv("Waist", (0, 0.08, 1.10), (waist_x, waist_y, 0.17)),
        add_uv("Pelvis", (0, 0.08, 0.88), (pelvis_x, pelvis_y, 0.205)),
        add_uv("GlutealMass", (0, 0.15, 0.83), (pelvis_x * 0.90, 0.10 if male else 0.105, 0.17)),
        add_uv("Head", (0, 0.08, 1.815), (head_radius, 0.102, 0.118)),
        add_tapered("Neck", (0, 0.08, 1.54), (0, 0.08, 1.70), neck_radius, neck_radius * 0.83),
    ]
    for side in (-1,1):
        parts += [
            add_uv("Deltoid", (side * shoulder, 0.08, 1.48), (0.12 if male else 0.105, 0.12, 0.115)),
            add_tapered("UpperArm", (side * shoulder, 0.08, 1.48), (side * 0.52, 0.08, 1.34), arm, arm * 0.78),
            add_uv("Elbow", (side * 0.535, 0.08, 1.325), (arm * 0.82, arm * 1.05, arm * 0.82)),
            add_tapered("Forearm", (side * 0.52, 0.08, 1.34), (side * 0.71, 0.08, 1.14), arm * 0.82, arm * 0.53),
            add_tapered("Wrist", (side * 0.71, 0.08, 1.14), (side * 0.755, 0.08, 1.085), arm * 0.55, arm * 0.42),
            add_uv("Hand", (side * 0.79, 0.065, 1.065), (arm * 0.62, 0.085, arm * 0.68)),
            add_uv("ThighMass", (side * 0.17, 0.08, 0.70), (thigh, 0.14 if male else 0.13, 0.24)),
            add_tapered("Thigh", (side * 0.17, 0.08, 0.84), (side * 0.19, 0.08, 0.46), thigh, thigh * 0.66),
            add_uv("Knee", (side * 0.19, 0.055, 0.445), (thigh * 0.70, 0.12, 0.095)),
            add_tapered("Calf", (side * 0.19, 0.09, 0.46), (side * 0.19, 0.08, 0.10), thigh * 0.72, thigh * 0.40),
            add_uv("Ankle", (side * 0.19, 0.08, 0.105), (thigh * 0.40, 0.075, 0.075)),
            add_uv("Foot", (side * 0.19, -0.06, 0.065), (0.105, 0.20, 0.06)),
        ]
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
