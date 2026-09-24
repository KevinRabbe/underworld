"""Render evidence through temporary IK targets on duplicated production armatures."""
import bpy, math, os
from mathutils import Vector
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'..')); OUT=os.path.join(ROOT,'docs/character_visuals/final_comparison')
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'content/characters/base_meshes/underworld_base_bodies.blend'))
def run(g):
 mesh=bpy.data.objects[g+'BaseBody']; rig=bpy.data.objects[g+'BaseBody_Rig']
 for o in bpy.context.scene.objects:
  if o.type in ('MESH','ARMATURE'): o.hide_set(True); o.hide_render=True
 r=rig.copy(); r.data=rig.data.copy(); bpy.context.collection.objects.link(r); m=mesh.copy(); m.data=mesh.data.copy(); bpy.context.collection.objects.link(m); r.hide_set(False); r.hide_render=False; m.hide_set(False); m.hide_render=False; m.parent=r
 renderable=[o for o in bpy.context.scene.objects if o.type=='MESH' and not o.hide_render and o.name.startswith(g+'BaseBody')]
 if renderable != [m]: raise RuntimeError(f'FAIL render isolation {g}: {[(o.name,o.hide_render) for o in renderable]}')
 for mod in m.modifiers:
  if mod.type=='ARMATURE': mod.object=r
 for view,loc,rot in [('front',(0,-5.5,1.35),(math.radians(90),0,0)),('side',(5.5,0,1.35),(math.radians(90),0,math.radians(90))),('back',(0,5.5,1.35),(math.radians(90),0,math.radians(180))),('front_3q',(4,-5,1.35),(math.radians(78),0,math.radians(38)))]:
  if view=='front_3q': rot=(Vector((0,0,1.1))-Vector(loc)).to_track_quat('-Z','Y').to_euler()
  bpy.ops.object.camera_add(location=loc,rotation=rot); c=bpy.context.object; c.data.type='ORTHO'; c.data.ortho_scale=2.15; bpy.context.scene.camera=c; bpy.context.view_layer.update(); s=bpy.context.scene; s.render.engine='BLENDER_WORKBENCH'; s.display.shading.light='STUDIO'; s.display.shading.color_type='SINGLE'; s.display.shading.single_color=(.82,.82,.82); s.render.resolution_x=s.render.resolution_y=1024; s.render.filepath=os.path.join(OUT,f'{g.lower()}_rest_diagnostic_{view}.png'); bpy.ops.render.render(write_still=True); bpy.data.objects.remove(c,do_unlink=True)
 for side,b in ((-1,'l'),(1,'r')):
  bpy.ops.object.empty_add(type='PLAIN_AXES',location=(side*.40,-.01,.98)); target=bpy.context.object; target.name='EvidenceWristTarget_'+b
  bpy.ops.object.empty_add(type='PLAIN_AXES',location=(side*.62,.12,1.24)); pole=bpy.context.object; pole.name='EvidenceElbowPole_'+b
  con=r.pose.bones['forearm_'+b].constraints.new('IK'); con.name='EvidenceArmsDownIK'; con.target=target; con.pole_target=pole; con.pole_angle=0.0; con.chain_count=2
 for view,loc,rot in [('front',(0,-5.5,1.35),(math.radians(90),0,0)),('side',(5.5,0,1.35),(math.radians(90),0,math.radians(90))),('back',(0,5.5,1.35),(math.radians(90),0,math.radians(180))),('front_3q',(4,-5,1.35),(math.radians(78),0,math.radians(38)))]:
  if view=='front_3q': rot=(Vector((0,0,1.1))-Vector(loc)).to_track_quat('-Z','Y').to_euler()
  bpy.ops.object.camera_add(location=loc,rotation=rot); c=bpy.context.object; c.data.type='ORTHO'; c.data.ortho_scale=2.15; bpy.context.scene.camera=c; bpy.context.view_layer.update(); s=bpy.context.scene; s.render.engine='BLENDER_WORKBENCH'; s.display.shading.light='STUDIO'; s.display.shading.color_type='SINGLE'; s.display.shading.single_color=(.82,.82,.82); s.render.resolution_x=s.render.resolution_y=1024; s.render.filepath=os.path.join(OUT,f'{g.lower()}_armsdown_{view}.png'); bpy.ops.render.render(write_still=True); bpy.data.objects.remove(c,do_unlink=True)
 for o in list(bpy.data.objects):
  if o.name.startswith('EvidenceWristTarget_') or o.name.startswith('EvidenceElbowPole_'): bpy.data.objects.remove(o,do_unlink=True)
 bpy.data.objects.remove(m,do_unlink=True); bpy.data.objects.remove(r,do_unlink=True)
run('Male'); run('Female')
