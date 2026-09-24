import os

# The repaired generator is kept in a separately auditable module while this
# historical entrypoint remains the documented command used by CI/artists.
_repaired = os.path.join(os.path.dirname(__file__), "create_base_bodies_repaired.py")
exec(compile(open(_repaired, "rb").read(), _repaired, "exec"), globals(), globals())
raise SystemExit

import bpy
import os
from mathutils import Vector

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "content", "characters", "base_meshes")
OUT_DIR = os.path.abspath(OUT_DIR)
os.makedirs(OUT_DIR, exist_ok=True)

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.armatures, bpy.data.materials):
        # Keep no generated scene data so reruns are deterministic.
        pass

def material(name, color):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.metallic = 0.0
    mat.roughness = 0.82
    return mat

SKIN = material("Underworld_Base_Skin", (0.42, 0.24, 0.16))

BONES = {
    "root": (0.0, 0.0, 0.0, 0.0, 0.08),
    "pelvis": (0.0, 0.08, 0.88, 0.0, 0.08),
    "spine_01": (0.0, 0.08, 0.88, 0.0, 1.10),
    "spine_02": (0.0, 0.08, 1.10, 0.0, 1.38),
    "chest": (0.0, 0.08, 1.38, 0.0, 1.56),
    "neck": (0.0, 0.08, 1.56, 0.0, 1.70),
    "head": (0.0, 0.08, 1.70, 0.0, 1.88),
    "clavicle_l": (0.0, 0.08, 1.50, -0.28, 1.50),
    "upperarm_l": (-0.28, 1.50, -0.53, 1.34, 0.0),
    "forearm_l": (-0.53, 1.34, -0.73, 1.16, 0.0),
    "hand_l": (-0.73, 1.16, -0.82, 1.08, 0.0),
    "clavicle_r": (0.0, 0.08, 1.50, 0.28, 1.50),
    "upperarm_r": (0.28, 1.50, 0.53, 1.34, 0.0),
    "forearm_r": (0.53, 1.34, 0.73, 1.16, 0.0),
    "hand_r": (0.73, 1.16, 0.82, 1.08, 0.0),
    "thigh_l": (0.0, 0.0, 0.86, -0.20, 0.0),
    "calf_l": (-0.20, 0.0, 0.46, -0.20, 0.0),
    "foot_l": (-0.20, 0.0, 0.08, -0.20, -0.24),
    "thigh_r": (0.0, 0.0, 0.86, 0.20, 0.0),
    "calf_r": (0.20, 0.0, 0.46, 0.20, 0.0),
    "foot_r": (0.20, 0.0, 0.08, 0.20, -0.24),
}

def make_armature(name):
    data = bpy.data.armatures.new(name + "_Rig")
    arm = bpy.data.objects.new(name + "_Rig", data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for bone_name, values in BONES.items():
        bone = data.edit_bones.new(bone_name)
        x1, z1, x2, z2, y2 = values
        # Arguments intentionally encode x/y/z as a compact tuple above.
        if bone_name == "root":
            bone.head = (0, 0, 0)
            bone.tail = (0, 0.08, 0)
        elif bone_name in ("pelvis", "spine_01", "spine_02", "chest", "neck", "head"):
            bone.head = (0, 0.08, z1)
            bone.tail = (0, 0.08, z2)
        else:
            bone.head = (x1, y1 if False else z1, x2)
            # Rebuild limb coordinates explicitly from the tuple's readable form.
            if bone_name == "clavicle_l": bone.head, bone.tail = ((0, 0.08, 1.50), (-0.28, 0.08, 1.50))
            elif bone_name == "clavicle_r": bone.head, bone.tail = ((0, 0.08, 1.50), (0.28, 0.08, 1.50))
            elif bone_name == "upperarm_l": bone.head, bone.tail = ((-0.28, 0.08, 1.50), (-0.53, 0.08, 1.34))
            elif bone_name == "forearm_l": bone.head, bone.tail = ((-0.53, 0.08, 1.34), (-0.73, 0.08, 1.16))
            elif bone_name == "hand_l": bone.head, bone.tail = ((-0.73, 0.08, 1.16), (-0.82, 0.08, 1.08))
            elif bone_name == "upperarm_r": bone.head, bone.tail = ((0.28, 0.08, 1.50), (0.53, 0.08, 1.34))
            elif bone_name == "forearm_r": bone.head, bone.tail = ((0.53, 0.08, 1.34), (0.73, 0.08, 1.16))
            elif bone_name == "hand_r": bone.head, bone.tail = ((0.73, 0.08, 1.16), (0.82, 0.08, 1.08))
            elif bone_name == "thigh_l": bone.head, bone.tail = ((-0.20, 0.0, 0.86), (-0.20, 0.0, 0.46))
            elif bone_name == "calf_l": bone.head, bone.tail = ((-0.20, 0.0, 0.46), (-0.20, 0.0, 0.08))
            elif bone_name == "foot_l": bone.head, bone.tail = ((-0.20, 0.0, 0.08), (-0.20, -0.24, 0.08))
            elif bone_name == "thigh_r": bone.head, bone.tail = ((0.20, 0.0, 0.86), (0.20, 0.0, 0.46))
            elif bone_name == "calf_r": bone.head, bone.tail = ((0.20, 0.0, 0.46), (0.20, 0.0, 0.08))
            elif bone_name == "foot_r": bone.head, bone.tail = ((0.20, 0.0, 0.08), (0.20, -0.24, 0.08))
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.select_set(False)
    return arm

def add_uv(name, loc, scale, segments=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj

def add_cylinder(name, a, b, radius, vertices=12):
    a, b = Vector(a), Vector(b)
    delta = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=delta.length, location=(a+b)*0.5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = Vector((0,0,1)).rotation_difference(delta.normalized())
    return obj

def build_body(kind):
    male = kind == "male"
    shoulder = 0.31 if male else 0.255
    chest = (0.29, 0.18) if male else (0.245, 0.16)
    waist = 0.205 if male else 0.18
    pelvis = 0.235 if male else 0.255
    arm = 0.085 if male else 0.073
    thigh = 0.135 if male else 0.125
    parts = []
    parts += [add_uv("Torso", (0, 0.08, 1.25), (chest[0], chest[1], 0.40)), add_uv("Pelvis", (0, 0.08, 0.91), (pelvis, 0.17, 0.22)), add_uv("Head", (0, 0.08, 1.78), (0.135 if male else 0.125, 0.125, 0.16))]
    # tapered waist insert keeps the silhouette grounded without clothing.
    parts.append(add_uv("Waist", (0, 0.08, 1.02), (waist, 0.155, 0.18)))
    for side in (-1, 1):
        sx = side
        parts += [add_cylinder("UpperArm", (sx*shoulder,0.08,1.48), (sx*0.52,0.08,1.30), arm), add_cylinder("Forearm", (sx*0.52,0.08,1.30), (sx*0.71,0.08,1.10), arm*0.88), add_uv("Hand", (sx*0.76,0.08,1.07), (arm*0.72,0.08,arm*0.82))]
        parts += [add_cylinder("Thigh", (sx*0.17,0.08,0.84), (sx*0.19,0.08,0.46), thigh), add_cylinder("Calf", (sx*0.19,0.08,0.46), (sx*0.19,0.08,0.10), thigh*0.72), add_uv("Foot", (sx*0.19,-0.05,0.07), (0.105,0.19,0.055))]
    # Neck is stronger on male, narrower on female while staying on the same landmark.
    parts.append(add_cylinder("Neck", (0,0.08,1.56), (0,0.08,1.68), 0.095 if male else 0.075))
    for obj in parts:
        obj.data.materials.append(SKIN)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts: obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    mesh = bpy.context.object
    mesh.name = ("Male" if male else "Female") + "BaseBody"
    armature = make_armature(("Male" if male else "Female") + "BaseBody")
    modifier = mesh.modifiers.new("SharedHumanoidRig", 'ARMATURE')
    modifier.object = armature
    for bone_name in BONES:
        mesh.vertex_groups.new(name=bone_name)
    # Deterministic region assignment to named shared-rig landmarks.
    for vertex in mesh.data.vertices:
        z = vertex.co.z
        x = vertex.co.x
        if z < 0.14: bone = "foot_l" if x < 0 else "foot_r"
        elif z < 0.48: bone = "calf_l" if x < 0 else "calf_r"
        elif z < 0.87: bone = "thigh_l" if x < 0 else "thigh_r"
        elif z < 1.08: bone = "pelvis"
        elif z < 1.38: bone = "spine_01"
        elif z < 1.56: bone = "chest"
        elif z < 1.70: bone = "neck"
        else: bone = "head"
        mesh.vertex_groups[bone].add([vertex.index], 1.0, 'REPLACE')
    mesh.parent = armature
    return mesh, armature

def export_pair(mesh, armature, filename):
    bpy.ops.object.select_all(action='DESELECT')
    mesh.select_set(True); armature.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_DIR, filename), export_format='GLB', use_selection=True, export_yup=True, export_apply=False)

clear_scene()
male_mesh, male_arm = build_body("male")
female_mesh, female_arm = build_body("female")
export_pair(male_mesh, male_arm, "underworld_male_base_body.glb")
export_pair(female_mesh, female_arm, "underworld_female_base_body.glb")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "underworld_base_bodies.blend"))
print("BASE_BODIES_READY", OUT_DIR)
