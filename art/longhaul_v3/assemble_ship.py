"""Fit a COPY of the approved exterior around the exact interior. v2 remains untouched."""
import bpy, os, math, bmesh
from mathutils import Vector,Matrix
OUT=os.path.dirname(os.path.abspath(__file__))
interior=bpy.data.scenes['LONGHAUL • Interior tour']
if 'LONGHAUL • Complete assembly' in bpy.data.scenes:raise RuntimeError('Assembly already exists.')
assembly=bpy.data.scenes.new('LONGHAUL • Complete assembly')
for name in ['INTERIOR | rooms and fitted equipment','INTERIOR | lighting','REVIEW | cameras']:
    assembly.collection.children.link(bpy.data.collections[name])
exterior=bpy.data.collections.new('EXTERIOR | fitted v3 shell');assembly.collection.children.link(exterior)
source=bpy.data.collections['LONGHAUL | authored exterior'];copies={}
for ob in source.objects:
    cp=ob.copy()
    if ob.data:cp.data=ob.data.copy()
    cp.name='Exterior / '+ob.name
    exterior.objects.link(cp);copies[ob]=cp
    if cp.type=='MESH':
        bm=bmesh.new();bm.from_mesh(cp.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(cp.data);bm.free()
for ob,cp in copies.items():cp.parent=copies.get(ob.parent)
bpy.context.window.scene=assembly
assembly.frame_set(1)
def byname(n):return copies[bpy.data.objects[n]]
def components(mesh):
    bm=bmesh.new();bm.from_mesh(mesh);seen=set();groups=[]
    for v in bm.verts:
        if v in seen:continue
        todo=[v];group=[];seen.add(v)
        while todo:
            v=todo.pop();group.append(v)
            for edge in v.link_edges:
                u=edge.other_vert(v)
                if u not in seen:seen.add(u);todo.append(u)
        groups.append(group)
    return bm,groups
def remove_parts(ob,predicate):
    bm,groups=components(ob.data);remove=[]
    for group in groups:
        lo=Vector(tuple(min(v.co[i] for v in group) for i in range(3)));hi=Vector(tuple(max(v.co[i] for v in group) for i in range(3)))
        if predicate(lo,hi):remove.extend(group)
    if remove:bmesh.ops.delete(bm,geom=remove,context='VERTS')
    bm.to_mesh(ob.data);bm.free();ob.data.update()

# Replace opaque v2 mock window hardware where the walkable rooms require glazing.
for ob in list(exterior.objects):
    if ob.type!='MESH':continue
    if '02 Living hab /' in ob.name:
        remove_parts(ob,lambda lo,hi: (hi.x-lo.x)<.20 and (hi.y-lo.y)<.80 and (hi.z-lo.z)<1.0 and lo.z>3.10 and max(abs(lo.x),abs(hi.x))>2.90)
    if '01 Flight deck /' in ob.name:
        remove_parts(ob,lambda lo,hi:lo.y>12.7 and lo.z>3.01 and (hi.z-lo.z)<1.3)

def cutter(name,lo,hi):
    verts=[(x,y,z) for x,y,z in [(lo[0],lo[1],lo[2]),(hi[0],lo[1],lo[2]),(hi[0],hi[1],lo[2]),(lo[0],hi[1],lo[2]),(lo[0],lo[1],hi[2]),(hi[0],lo[1],hi[2]),(hi[0],hi[1],hi[2]),(lo[0],hi[1],hi[2])]]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
    o=bpy.data.objects.new(name,mesh);exterior.objects.link(o);return o
def subtract(ob,cut):
    bpy.context.view_layer.objects.active=ob
    mod=ob.modifiers.new('Interior clearance','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut
    while list(ob.modifiers).index(mod)>0:bpy.ops.object.modifier_move_up(modifier=mod.name)
    bpy.ops.object.modifier_apply(modifier=mod.name)
def hollow(name,lo,hi,targets):
    cut=cutter(name,lo,hi)
    for ob in list(exterior.objects):
        if ob.type=='MESH' and ob!=cut and any(t in ob.name for t in targets):subtract(ob,cut)
    bpy.data.objects.remove(cut,do_unlink=True)

hollow('Cockpit clearance',(-1.70,8.80,1.24),(1.70,13.70,3.99),['01 Flight deck / ivory'])
hollow('Hab clearance',(-2.07,3.95,1.22),(2.07,9.12,4.03),['02 Living hab / dark','01 Flight deck / ivory'])
hollow('Service clearance',(-2.81,.86,1.22),(2.81,4.18,4.03),['03 Service and airlock / shade','02 Living hab / dark'])
hollow('Engineering clearance',(-2.99,-11.34,1.43),(2.99,-6.99,4.30),['05 Engineering /'])
hollow('Windshield aperture',(-1.56,13.30,2.39),(1.56,15.0,4.13),['01 Flight deck / ivory','01 Flight deck / shade'])
for y,width in [(7.455,2.01),(5.14,.90)]:
    hollow('Hab window',(-3.25,y-width/2,2.465),(-1.90,y+width/2,3.375),['02 Living hab /'])

# A lightweight transparent glass shader, shared by the fitted outer panes.
glass=bpy.data.materials.new('Exterior / clear fitted glazing');glass.use_nodes=True
nodes=glass.node_tree.nodes;nodes.clear();out=nodes.new('ShaderNodeOutputMaterial');tr=nodes.new('ShaderNodeBsdfTransparent');tr.inputs[0].default_value=(.87,.93,.95,1);glass.node_tree.links.new(tr.outputs[0],out.inputs['Surface']);glass.diffuse_color=(.1,.2,.25,.1)
dark=bpy.data.materials['Refinement / rubber'];cream=bpy.data.materials['Refinement / enamel'];orange=bpy.data.materials['Refinement / burnt orange']
ext_root=byname('LONGHAUL_K01')
def fitted_box(name,p,size,material):
    lo=tuple(p[i]-size[i]/2 for i in range(3));hi=tuple(p[i]+size[i]/2 for i in range(3));ob=cutter(name,lo,hi);ob.parent=ext_root;ob.data.materials.append(material)
    b=ob.modifiers.new('Fitted edge','BEVEL');b.width=.009;b.segments=1
    return ob
for y,width in [(7.455,2.01),(5.14,.90)]:
    fitted_box('Exterior / hab window glass',(-3.10,y,2.92),(.014,width,.91),glass)
    for z in [2.43,3.41]:
        fitted_box('Exterior / hab window lining',(-2.55,y,z),(1.12,width+.12,.06),cream)
        fitted_box('Exterior / hab window gasket',(-3.12,y,z),(.06,width+.12,.06),dark)
    for end in [y-width/2-.03,y+width/2+.03]:
        fitted_box('Exterior / hab window lining',(-2.55,end,2.92),(1.12,.06,.98),cream)
        fitted_box('Exterior / hab window gasket',(-3.12,end,2.92),(.06,.06,.98),dark)
    fitted_box('Exterior / hab orange sill',(-3.14,y,2.38),(.08,width+.15,.07),orange)
fitted_box('Exterior / recessed pilot glazing',(0,13.72,3.05),(3.11,.014,1.22),glass)
for x in [-1.565,-.82,.82,1.565]:fitted_box('Exterior / pilot mullion',(x,13.73,3.05),(.075,.10,1.28),dark)
for z in [2.415,3.685]:fitted_box('Exterior / windshield frame',(0,13.73,z),(3.20,.10,.075),dark)
fitted_box('Exterior / rear threshold bridge',(0,-11.32,1.43),(2.82,.45,.13),dark)

# Reuse studio presentation only on the full-assembly scene.
assembly.collection.children.link(bpy.data.collections['PRESENTATION | excluded from export'])
assembly.camera=bpy.data.objects['CAM 01 • Forward three-quarter'];assembly.world=bpy.data.scenes['LONGHAUL • Exterior study'].world
assembly.render.engine='BLENDER_EEVEE';assembly.render.resolution_x=1600;assembly.render.resolution_y=1100;assembly.render.resolution_percentage=100;assembly.render.image_settings.file_format='PNG'
assembly.view_settings.view_transform='AgX';assembly.view_settings.exposure=1
assembly.frame_start=1;assembly.frame_end=80;assembly.frame_set(1)
assembly['fit']='Exterior copied non-destructively from v2, with cockpit/hab/service clearances and matched front and hab glazing. Needs production collision/flight integration.'

# Cutaway is its own scene with linked equipment and walls, but no ceilings or outer hull.
cutaway=bpy.data.scenes.new('LONGHAUL • Cutaway overview')
for child in bpy.data.collections['INTERIOR | rooms and fitted equipment'].children:
    for sub in child.children:
        if not sub.name.endswith(' | Ceiling'):cutaway.collection.children.link(sub)
# Moving pieces live beneath the assembly root but their meshes are in the room collections.
cutaway.collection.children.link(bpy.data.collections['PRESENTATION | excluded from export'])
cutaway.collection.children.link(bpy.data.collections['INTERIOR | lighting'])
col=bpy.data.collections.new('CUTAWAY | camera and labels');cutaway.collection.children.link(col)
c=bpy.data.cameras.new('09 • Cutaway');cam=bpy.data.objects.new(c.name,c);col.objects.link(cam);cam.location=(19,24,29);cam.rotation_euler=(Vector((0,1,2.0))-cam.location).to_track_quat('-Z','Y').to_euler();c.type='ORTHO';c.ortho_scale=29;cutaway.camera=cam
cutaway.world=assembly.world;cutaway.render.engine='BLENDER_EEVEE';cutaway.render.resolution_x=1800;cutaway.render.resolution_y=1400;cutaway.render.resolution_percentage=100;cutaway.render.image_settings.file_format='PNG';cutaway.view_settings.view_transform='AgX';cutaway.view_settings.exposure=.8
cutaway.frame_set(1)
bpy.context.window.scene=interior
interior.camera=bpy.data.objects['01 • Cockpit'];interior.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'longhaul_full_ship.blend'))
print('Complete assembly and independent cutaway created. Original exterior file preserved.')
