"""Build the approved Character 2 styling as a Godot-compatible skinned GLB."""

import math
import os

import bpy
from mathutils import Vector


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(
    ROOT, "variants", "character2_styled", "source", "character2_styled_v3.blend")
OUTPUT = os.path.join(ROOT, "rigged")
BLEND_PATH = os.path.join(OUTPUT, "source", "character2_authored_rig_v3.blend")
GLB_PATH = os.path.join(OUTPUT, "character2_authored_rig_v3.glb")


def add_bone(edit_bones, name, head, tail, parent=None):
    bone = edit_bones.new(name)
    bone.head = head
    bone.tail = tail
    bone.parent = parent
    bone.use_connect = False
    return bone


def build_armature():
    data = bpy.data.armatures.new("Character2Rig")
    armature = bpy.data.objects.new("Character2Rig", data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bones = data.edit_bones

    root = add_bone(bones, "root", (0, 0, 0), (0, 0, 0.16))
    pelvis = add_bone(bones, "pelvis", (0, 0, 0.93), (0, 0, 1.08), root)
    spine_01 = add_bone(bones, "spine_01", (0, 0, 1.08), (0, 0, 1.25), pelvis)
    spine_02 = add_bone(bones, "spine_02", (0, 0, 1.25), (0, 0, 1.43), spine_01)
    chest = add_bone(bones, "chest", (0, 0, 1.43), (0, 0, 1.63), spine_02)
    neck = add_bone(bones, "neck", (0, 0, 1.63), (0, 0, 1.76), chest)
    head = add_bone(bones, "head", (0, 0, 1.76), (0, 0, 2.04), neck)

    limb_bones = {}
    for suffix, sign in (("l", -1.0), ("r", 1.0)):
        clavicle = add_bone(
            bones, "clavicle_" + suffix, (0, 0, 1.60),
            (sign * 0.30, -0.015, 1.58), chest)
        upperarm = add_bone(
            bones, "upperarm_" + suffix, (sign * 0.30, -0.015, 1.58),
            (sign * 0.40, -0.035, 1.34), clavicle)
        forearm = add_bone(
            bones, "forearm_" + suffix, (sign * 0.40, -0.035, 1.34),
            (sign * 0.47, -0.045, 1.08), upperarm)
        hand = add_bone(
            bones, "hand_" + suffix, (sign * 0.47, -0.045, 1.08),
            (sign * 0.48, -0.060, 0.91), forearm)
        thigh = add_bone(
            bones, "thigh_" + suffix, (sign * 0.11, 0, 0.97),
            (sign * 0.12, 0, 0.57), pelvis)
        calf = add_bone(
            bones, "calf_" + suffix, (sign * 0.12, 0, 0.57),
            (sign * 0.12, 0, 0.16), thigh)
        foot = add_bone(
            bones, "foot_" + suffix, (sign * 0.12, 0, 0.16),
            (sign * 0.12, -0.20, 0.075), calf)
        limb_bones[suffix] = hand

    # Internal-only grip bones. Public semantic roles remain unchanged.
    for suffix, sign in (("l", -1.0), ("r", 1.0)):
        hand = limb_bones[suffix]
        for finger, x_offset in (
                ("index", 0.020), ("middle", 0.007),
                ("ring", -0.007), ("little", -0.020)):
            x = sign * (0.48 + x_offset)
            first = add_bone(
                bones, f"finger_{finger}_01_{suffix}",
                (x, -0.045, 0.955), (x, -0.055, 0.910), hand)
            add_bone(
                bones, f"finger_{finger}_02_{suffix}",
                (x, -0.055, 0.910), (x, -0.060, 0.875), first)
        thumb_x = sign * 0.508
        thumb = add_bone(
            bones, f"thumb_01_{suffix}",
            (thumb_x, -0.055, 1.005), (sign * 0.525, -0.080, 0.970), hand)
        add_bone(
            bones, f"thumb_02_{suffix}",
            (sign * 0.525, -0.080, 0.970),
            (sign * 0.530, -0.090, 0.940), thumb)

    bpy.ops.object.mode_set(mode="OBJECT")
    armature.show_in_front = True
    armature["rig_profile_id"] = "rig_profile.humanoid.prototype"
    armature["public_bone_contract_locked"] = True
    return armature


def blend_pair(value, pivot, radius, lower, upper):
    t = max(0.0, min(1.0, (value - (pivot - radius)) / (radius * 2.0)))
    return ((lower, 1.0 - t), (upper, t))


def polish_arm_shape(obj):
    """Regularize the approved skin's arm silhouette without changing topology."""
    for vertex in obj.data.vertices:
        x, y, z = vertex.co
        ax = abs(x)
        if ax < 0.255 or z < 1.075 or z > 1.645:
            continue
        sign = -1.0 if x < 0.0 else 1.0

        if z >= 1.48:
            # Deltoid cap: retain the torso seam and shoulder width, but reduce
            # the primitive outer bulge and front/back ballooning.
            t = max(0.0, min(1.0, (z - 1.48) / 0.165))
            center_x = 0.34 - 0.025 * t
            if ax > center_x:
                ax = center_x + (ax - center_x) * 0.84
            if ax > center_x - 0.055:
                y_center = -0.025
                y = y_center + (y - y_center) * 0.90
        elif z >= 1.30:
            # Upper arm into elbow: slightly reduce the outer wedge while giving
            # the elbow band enough mass to avoid an hourglass/broken-joint read.
            t = (z - 1.30) / 0.18
            center_x = 0.405 - 0.065 * t
            radial = ax - center_x
            scale = 1.04 if z < 1.355 else 0.92
            if abs(radial) < 0.11:
                ax = center_x + radial * scale
            y_center = -0.040
            y = y_center + (y - y_center) * (1.03 if z < 1.355 else 0.95)
        else:
            # Forearm: preserve the muscular upper third and make the taper into
            # the wrist gradual rather than triangular.
            t = (z - 1.075) / 0.225
            center_x = 0.47 - 0.065 * t
            radial = ax - center_x
            target_scale = 0.94 + 0.08 * t
            if abs(radial) < 0.10:
                ax = center_x + radial * target_scale
            y_center = -0.045
            y = y_center + (y - y_center) * (0.94 + 0.07 * t)

        vertex.co.x = sign * ax
        vertex.co.y = y


def body_weights(co):
    x, _y, z = co
    side = "l" if x < 0.0 else "r"
    ax = abs(x)

    # Resolve the lateral arm chain before the lower-body height bands. Hands
    # and fingers extend below z=1.02; classifying by height first incorrectly
    # attached those vertices to the thigh bones.
    arm_threshold = 0.31 if z < 1.38 else 0.25
    if ax > arm_threshold:
        if z < 1.125:
            if ax > 0.515 and z < 1.035:
                return [("thumb_01_" + side, 1.0)]
            if z < 0.955:
                finger_centers = {
                    "little": 0.460,
                    "ring": 0.473,
                    "middle": 0.487,
                    "index": 0.500,
                }
                finger = min(finger_centers, key=lambda name: abs(ax - finger_centers[name]))
                section = "02" if z < 0.900 else "01"
                return [(f"finger_{finger}_{section}_{side}", 1.0)]
            if z > 1.055:
                return list(blend_pair(z, 1.09, 0.035, "hand_" + side, "forearm_" + side))
            return [("hand_" + side, 1.0)]
        if z < 1.40:
            return list(blend_pair(z, 1.34, 0.065, "forearm_" + side, "upperarm_" + side))
        if z < 1.50:
            return [("upperarm_" + side, 1.0)]
        shoulder_t = max(0.0, min(1.0, (z - 1.50) / 0.14))
        return [
            ("upperarm_" + side, 1.0 - shoulder_t),
            ("clavicle_" + side, shoulder_t * 0.38),
            ("chest", shoulder_t * 0.62),
        ]

    if z < 1.02:
        if ax < 0.045 and z > 0.88:
            return [("pelvis", 1.0)]
        if z < 0.13:
            return [("foot_" + side, 1.0)]
        if z < 0.60:
            return list(blend_pair(z, 0.56, 0.055, "calf_" + side, "thigh_" + side))
        return [("thigh_" + side, 1.0)]

    if z > 1.73:
        return list(blend_pair(z, 1.76, 0.045, "neck", "head"))
    if z > 1.59:
        return list(blend_pair(z, 1.64, 0.055, "chest", "neck"))
    if z > 1.40:
        return list(blend_pair(z, 1.43, 0.07, "spine_02", "chest"))
    if z > 1.22:
        return list(blend_pair(z, 1.25, 0.07, "spine_01", "spine_02"))
    if z > 1.05:
        return list(blend_pair(z, 1.08, 0.06, "pelvis", "spine_01"))
    return [("pelvis", 1.0)]


def bind_mesh(obj, armature, rigid_bone=None):
    for group in list(obj.vertex_groups):
        obj.vertex_groups.remove(group)
    group_cache = {}

    def group(name):
        if name not in group_cache:
            group_cache[name] = obj.vertex_groups.new(name=name)
        return group_cache[name]

    for vertex in obj.data.vertices:
        weights = [(rigid_bone, 1.0)] if rigid_bone else body_weights(vertex.co)
        total = sum(weight for _name, weight in weights)
        for name, weight in weights[:4]:
            if weight > 0.0:
                group(name).add([vertex.index], weight / total, "REPLACE")
    modifier = obj.modifiers.new("Character2Armature", "ARMATURE")
    modifier.object = armature
    obj.parent = armature


def validate(meshes, armature):
    required = {
        "root", "pelvis", "spine_01", "spine_02", "chest", "neck", "head",
        "clavicle_l", "upperarm_l", "forearm_l", "hand_l",
        "clavicle_r", "upperarm_r", "forearm_r", "hand_r",
        "thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r",
    }
    names = {bone.name for bone in armature.data.bones}
    missing = sorted(required - names)
    if missing:
        raise RuntimeError("Missing required rig bones: " + ", ".join(missing))
    for obj in meshes:
        if not obj.vertex_groups:
            raise RuntimeError(obj.name + " has no skin weights")
        for vertex in obj.data.vertices:
            if not vertex.groups:
                raise RuntimeError(f"{obj.name} vertex {vertex.index} is unweighted")
            if len(vertex.groups) > 4:
                raise RuntimeError(f"{obj.name} vertex {vertex.index} exceeds four influences")
            if obj.name == "CharacterSkin" and abs(vertex.co.x) > 0.31 and vertex.co.z < 1.02:
                assigned_names = {
                    obj.vertex_groups[item.group].name for item in vertex.groups
                    if item.weight > 0.0
                }
                invalid = {
                    name for name in assigned_names
                    if name == "pelvis" or name.startswith(("thigh_", "calf_", "foot_"))
                }
                if invalid:
                    raise RuntimeError(
                        f"Hand vertex {vertex.index} has lower-body weights: {sorted(invalid)}")
        if obj.name == "CharacterSkin":
            required_hand_groups = {
                f"finger_{finger}_01_{side}"
                for side in ("l", "r")
                for finger in ("index", "middle", "ring", "little")
            }
            required_hand_groups.update({"thumb_01_l", "thumb_01_r"})
            populated = {
                obj.vertex_groups[item.group].name
                for vertex in obj.data.vertices
                for item in vertex.groups
                if item.weight > 0.0
            }
            missing_hand_groups = sorted(required_hand_groups - populated)
            if missing_hand_groups:
                raise RuntimeError(
                    "Missing populated primary hand groups: " + ", ".join(missing_hand_groups))
    print("[CHARACTER2 RIG] required_bones", len(required))
    print("[CHARACTER2 RIG] total_bones", len(armature.data.bones))
    print("[CHARACTER2 RIG] skinned_meshes", len(meshes))
    print("[CHARACTER2 RIG] unweighted_vertices 0")
    print("[CHARACTER2 RIG] max_influences 4")


def main():
    os.makedirs(os.path.dirname(BLEND_PATH), exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=SOURCE)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    armature = build_armature()
    rigid = {
        "CharacterDetails": "head",
        "Character2Hair": "head",
        "Character2Beard": "head",
        "Character2Clothing": "pelvis",
    }
    for obj in meshes:
        if obj.name == "CharacterSkin":
            polish_arm_shape(obj)
        bind_mesh(obj, armature, rigid.get(obj.name))
    validate(meshes, armature)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes + [armature]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_skins=True,
        export_all_influences=False,
        export_animations=False,
    )
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    print("[CHARACTER2 RIG] exported", GLB_PATH)
    print("[CHARACTER2 RIG] saved", BLEND_PATH)


if __name__ == "__main__":
    main()
