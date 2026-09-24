"""Fail-closed structural validation for exported base-body meshes."""
import bpy, bmesh, os, sys

blend = sys.argv[-1] if sys.argv[-1].lower().endswith('.blend') else os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'content', 'characters', 'base_meshes', 'underworld_base_bodies.blend'))
bpy.ops.wm.open_mainfile(filepath=blend)
mesh_objects = [o for o in bpy.data.objects if o.type == 'MESH' and o.name == 'MaleBaseBody']
if len(mesh_objects) != 1:
    raise SystemExit(f'FAIL MaleBaseBody count={len(mesh_objects)}')
obj = mesh_objects[0]
bm = bmesh.new(); bm.from_mesh(obj.data); bm.verts.ensure_lookup_table(); bm.edges.ensure_lookup_table(); bm.faces.ensure_lookup_table()
boundary = sum(1 for e in bm.edges if len(e.link_faces) == 1)
nonmanifold = sum(1 for e in bm.edges if len(e.link_faces) > 2)
zero_area = sum(1 for f in bm.faces if f.calc_area() <= 1e-8)
if boundary or nonmanifold or zero_area:
    raise SystemExit(f'FAIL boundary={boundary} nonmanifold={nonmanifold} zero_area={zero_area}')
required = {'pelvis','spine_01','spine_02','chest','neck','head','clavicle_l','upperarm_l','forearm_l','hand_l','clavicle_r','upperarm_r','forearm_r','hand_r','thigh_l','calf_l','foot_l','thigh_r','calf_r','foot_r'}
missing = sorted(required - {g.name for g in obj.vertex_groups})
if missing or not any(m.type == 'ARMATURE' for m in obj.modifiers):
    raise SystemExit(f'FAIL missing_groups={missing} armature_modifier={any(m.type == "ARMATURE" for m in obj.modifiers)}')
print(f'PASS MaleBaseBody verts={len(bm.verts)} faces={len(bm.faces)} boundary=0 nonmanifold=0 zero_area=0')
