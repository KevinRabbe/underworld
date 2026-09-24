"""Pose-level sanity checks for the Male base body without changing the blend."""
import bpy, math, os, sys
from mathutils import Vector

blend = sys.argv[-1] if sys.argv[-1].lower().endswith('.blend') else os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'content', 'characters', 'base_meshes', 'underworld_base_bodies.blend'))
bpy.ops.wm.open_mainfile(filepath=blend)
mesh = bpy.data.objects['MaleBaseBody']; rig = bpy.data.objects['MaleBaseBody_Rig']
dup_rig = rig.copy(); dup_rig.data = rig.data.copy(); bpy.context.collection.objects.link(dup_rig)
dup_mesh = mesh.copy(); dup_mesh.data = mesh.data.copy(); bpy.context.collection.objects.link(dup_mesh); dup_mesh.parent = dup_rig
for mod in dup_mesh.modifiers:
    if mod.type == 'ARMATURE': mod.object = dup_rig
tests = {
    'arms_up': {'upperarm_l': -0.55, 'upperarm_r': 0.55},
    'elbows': {'forearm_l': -0.65, 'forearm_r': 0.65},
    'knees': {'calf_l': -0.45, 'calf_r': 0.45},
    'hip': {'thigh_l': 0.35, 'thigh_r': -0.35},
}
for label, rotations in tests.items():
    for bone in dup_rig.pose.bones: bone.rotation_mode = 'XYZ'; bone.rotation_euler = (0, 0, 0)
    for name, angle in rotations.items():
        if name in dup_rig.pose.bones: dup_rig.pose.bones[name].rotation_euler[1] = angle
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get(); evaluated = dup_mesh.evaluated_get(depsgraph)
    coords = [evaluated.matrix_world @ v.co for v in evaluated.data.vertices]
    if not coords or any(not all(math.isfinite(c) for c in p) for p in coords):
        raise SystemExit(f'FAIL {label}: non-finite evaluated vertex')
    if max((p.length for p in coords), default=0.0) > 20.0:
        raise SystemExit(f'FAIL {label}: runaway deformation')
print('PASS MaleBaseBody deformation poses:', ', '.join(tests))
