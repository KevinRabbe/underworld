"""Render evidence through temporary IK targets on duplicated production armatures."""
import bpy, math, os
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'..')); OUT=os.path.join(ROOT,'docs/character_visuals/final_comparison')
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'content/characters/base_meshes/underworld_base_bodies.blend'))
def run(g):
 mesh=bpy.data.objects[g+'BaseBody']; rig=bpy.data.objects[g+'BaseBody_Rig']; [o.hide_set(True) for o in bpy.context.scene.objects if o.type in ('MESH','ARMATURE')]
 r=rig.copy(); r.data=rig.data.copy(); bpy.context.collection.objects.link(r); m=mesh.copy(); m.data=mesh.data.copy(); bpy.context.collection.objects.link(m); r.hide_set(False); m.hide_set(False); m.parent=r
 for mod in m.modifiers:
  if mod.type=='ARMATURE': mod.object=r
 for side,b in ((-1,'l'),(1,'r')):
  bpy.ops.object.empty_add(type='PLAIN_AXES',location=(side*.43,-.02,.93)); target=bpy.context.object; target.name='EvidenceHandTarget_'+b
  con=r.pose.bones['hand_'+b].constraints.new('IK'); con.name='EvidenceArmsDownIK'; con.target=target; con.chain_count=3
 for view,loc,rot in [('front',(0,-5.5,1.35),(math.radians(90),0,0)),('side',(5.5,0,1.35),(math.radians(90),0,math.radians(90)))]:
  bpy.ops.object.camera_add(location=loc,rotation=rot); c=bpy.context.object; c.data.type='ORTHO'; c.data.ortho_scale=2.15; bpy.context.scene.camera=c; bpy.context.view_layer.update(); s=bpy.context.scene; s.render.engine='BLENDER_WORKBENCH'; s.display.shading.light='STUDIO'; s.display.shading.color_type='SINGLE'; s.display.shading.single_color=(.82,.82,.82); s.render.resolution_x=s.render.resolution_y=1024; s.render.filepath=os.path.join(OUT,f'{g.lower()}_armsdown_{view}.png'); bpy.ops.render.render(write_still=True); bpy.data.objects.remove(c,do_unlink=True)
 for o in list(bpy.data.objects):
  if o.name.startswith('EvidenceHandTarget_'): bpy.data.objects.remove(o,do_unlink=True)
 bpy.data.objects.remove(m,do_unlink=True); bpy.data.objects.remove(r,do_unlink=True)
run('Male'); run('Female')
