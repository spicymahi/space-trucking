"""Refine the actual approved game layout into editable Blender room assets.
Run through Blender MCP with the v2 Longhaul file open. Never runs the game or saves progress.
"""
import bpy, math, os, json, bmesh
from mathutils import Matrix, Vector
from collections import defaultdict

OUT=os.path.dirname(os.path.abspath(__file__))
PROJECT=os.path.abspath(os.path.join(OUT,'../..'))
with open(os.path.join(OUT,'source','interior_layout.json')) as f:D=json.load(f)
if 'LONGHAUL • Interior tour' in bpy.data.scenes:raise RuntimeError('Interior already exists; refine it in place.')
scene=bpy.data.scenes.new('LONGHAUL • Interior tour');bpy.context.window.scene=scene
scene.unit_settings.system='METRIC'
scene.unit_settings.scale_length=1
assembly=bpy.data.collections.new('INTERIOR | rooms and fitted equipment');scene.collection.children.link(assembly)
lights_col=bpy.data.collections.new('INTERIOR | lighting');scene.collection.children.link(lights_col)
rig_col=bpy.data.collections.new('REVIEW | cameras');scene.collection.children.link(rig_col)
anchors_col=bpy.data.collections.new('INTEGRATION | interaction anchors');scene.collection.children.link(anchors_col)
anchors_col.hide_render=True
collisions_col=bpy.data.collections.new('INTEGRATION | original collision envelopes');scene.collection.children.link(collisions_col)
collisions_col.hide_render=True;collisions_col.hide_viewport=True
root=bpy.data.objects.new('LONGHAUL_INTERIOR',None);assembly.objects.link(root)
root['source']='Exact approved Godot room layout, refined in Blender'
root['coordinates']='Blender (x,-Godot_z,Godot_y+1.4); GLB root compensates deck offset.'
root['integration']='Display meshes and mechanical pivots are separate. Game code remains authoritative.'
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,1.4),(0,0,0,1)))
R=C.to_3x3()
def transform(t):
    return C@Matrix(((t[0][0],t[1][0],t[2][0],t[3][0]),(t[0][1],t[1][1],t[2][1],t[3][1]),(t[0][2],t[1][2],t[2][2],t[3][2]),(0,0,0,1)))
def point(p):return C@Vector(p)
def linear(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
def mat(name,color,metal=0,rough=.68,emit=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    rgb=tuple(linear(c) for c in color[:3]);m.diffuse_color=(*rgb,1)
    p.inputs['Base Color'].default_value=(*rgb,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    if emit:p.inputs['Emission Color'].default_value=(*rgb,1);p.inputs['Emission Strength'].default_value=emit
    return m
materials={};material_keys={}
for key,data in D['materials'].items():
    signature=json.dumps(data,sort_keys=True)
    if signature in material_keys:materials[key]=material_keys[signature];continue
    c=data['color'];m=mat('Interior / '+('screen '+os.path.basename(data['texture']) if data['texture'] else ''.join('%02x'%round(v*255) for v in c[:3])),c,rough=.67,emit=.7 if data['emission_strength'] else 0)
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    if data['texture']:
        image=bpy.data.images.load(os.path.join(PROJECT,data['texture'].replace('res://','')),check_existing=True)
        tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Closest'
        m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
        m.node_tree.links.new(tex.outputs['Color'],p.inputs['Emission Color']);p.inputs['Emission Strength'].default_value=.8
        p.inputs['Roughness'].default_value=.3
    if data['transparent']:
        # Truly clear panes; do not bake the old dark-blue placeholder over the view.
        nodes=m.node_tree.nodes;nodes.clear();out=nodes.new('ShaderNodeOutputMaterial');tr=nodes.new('ShaderNodeBsdfTransparent');tr.inputs[0].default_value=(.90,.96,.97,1);m.node_tree.links.new(tr.outputs[0],out.inputs['Surface'])
        m.diffuse_color=(.1,.24,.28,.09)
    materials[key]=m;material_keys[signature]=m
fallback=mat('Interior / fallback',(.7,.67,.57));materials['fallback']=fallback
refined={
 'steel':mat('Refinement / brushed warm steel',(.50,.53,.48),.6,.36),
 'rubber':mat('Refinement / rubber',(.12,.16,.14),0,.84),
 'cream':mat('Refinement / enamel',(.83,.78,.66),.1,.58),
 'orange':mat('Refinement / burnt orange',(.66,.37,.17),.12,.62),
 'cloth':mat('Refinement / woven ochre',(.61,.46,.23),0,.92),
 'screen':mat('Refinement / phosphor green',(.61,.88,.66),0,.42,.65),
}
rooms={};parts={};pivots={}
for name in ['Cockpit','Hab','Washroom','Airlock','Corridor','Cargo','Engineering','Loading','Structure']:
    col=bpy.data.collections.new('ROOM | '+name);assembly.children.link(col);rooms[name]=col
    empty=bpy.data.objects.new(name,None);col.objects.link(empty);empty.parent=root;parts[name]=empty
    for kind in ['Equipment','Shell','Ceiling']:
        c=bpy.data.collections.new(name+' | '+kind);col.children.link(c);parts[(name,kind)]=c
def roomof(rec):
    room=rec['room'];x=rec['transform'][3][0]
    if room=='Service':return 'Washroom' if x<-.78 else ('Airlock' if x>.78 else 'Corridor')
    if room=='Structure':
        z=rec['transform'][3][2]
        return 'Cockpit' if z<-9 else ('Hab' if z<-4 else ('Corridor' if z<-1 else ('Cargo' if z<7 else 'Engineering')))
    return room
for data in D['pivots']:
    ob=bpy.data.objects.new(data['name'],None);assembly.objects.link(ob);ob.parent=root;ob.matrix_world=transform(data['transform']);pivots[data['name']]=ob
    ob['source_path']=data['source_path'];ob['function']=data['name'];ob.empty_display_size=.15
def category(rec):
    if rec['type']!='box':return 'Equipment'
    sx,sy,sz=rec['size'];x,y,z=rec['transform'][3]
    if y>2.22:return 'Ceiling'
    if (sy>1.9 and min(sx,sz)<.3 and max(sx,sz)>1.9) or (sy<.35 and max(sx,sz)>3.1):return 'Shell'
    return 'Equipment'

buffers=defaultdict(lambda:{'vertices':[],'faces':[],'uvs':[],'sources':[],'records':0})
box_vertices=[(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]
box_faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
font=bpy.data.fonts.load(os.path.join(PROJECT,'assets/fonts/VT323-Regular.ttf'))
surface_records=[]
for rec in D['meshes']:
    room=roomof(rec);kind=category(rec);mover=rec['mover'];T=transform(rec['transform'])
    # Old external hab/cockpit skin strips stay excluded from the interior kit.
    if rec['type']=='box' and rec['room'] in ['Hab','Cockpit']:
        x,y,z=rec['transform'][3]
        if y>2.56 or (rec['room']=='Hab' and abs(x)>2.07) or (rec['room']=='Cockpit' and abs(x)>1.71):continue
    parent=pivots[mover] if mover else parts[room]
    localT=parent.matrix_world.inverted()@T if mover else T
    if rec['type']=='text':
        if not rec['text']:continue
        c=bpy.data.curves.new(rec['text'][:48],'FONT');c.body=rec['text'];c.font=font;c.size=rec['size'];c.align_x='CENTER';c.align_y='CENTER';c.extrude=.0002;c.resolution_u=2
        ob=bpy.data.objects.new(room+' / '+rec['text'].replace('\n',' ')[:45],c);parts[(room,kind)].objects.link(ob);ob.parent=parent
        # Godot text XY with +Z normal; Blender text is also XY/+Z.
        ob.matrix_local=localT
        col=rec['color'];sig=tuple(round(x,3) for x in col[:3]);name='Label '+str(sig)
        m=bpy.data.materials.get(name) or mat(name,col,rough=.85,emit=.45 if col[1]>col[0]*1.12 else 0)
        c.materials.append(m);ob['source_path']=rec['source_path'];continue
    material=materials[rec['material']]
    smallest=min(rec.get('size',[.02,.02,.02]));bevel=min(.012,max(.0008,smallest*.14))
    if kind=='Shell':bevel=.004
    if rec.get('binding') or rec['type']!='box':bevel=0
    # Upholstery has soft stitched edges while remaining intentionally blocky.
    if room=='Hab' and rec['type']=='box' and material.diffuse_color[0]>.2 and rec['transform'][3][1]<1.4:
        if .10<rec['size'][1]<.25 and rec['size'][0]>.7:bevel=.023
    bucket=(room,kind,mover,material.name,round(bevel,4),rec.get('binding',''))
    data=buffers[bucket];start=len(data['vertices'])
    if rec['type']=='box':
        vertices=[Vector(tuple(a*b/2 for a,b in zip(v,rec['size']))) for v in box_vertices];faces=box_faces;uvs=[(0,0)]*8
    else:
        vertices=[Vector(v) for v in rec['vertices']];indices=rec['indices'] or list(range(len(vertices)))
        # Godot triangles are clockwise; Blender expects counterclockwise.
        faces=[tuple(reversed(indices[i:i+3])) for i in range(0,len(indices),3)]
        uvs=[(uv[0],1-uv[1]) for uv in rec['uvs']] or [(0,0)]*len(vertices)
    data['vertices'].extend([tuple(localT@v) for v in vertices]);data['faces'].extend([tuple(i+start for i in f) for f in faces]);data['uvs'].extend(uvs);data['records']+=1;data['sources'].append(rec['source_path'])
    if rec.get('binding'):surface_records.append((rec,bucket))

mesh_map={}
for (room,kind,mover,matname,bevel,binding),data in buffers.items():
    name=binding or (room+' / '+kind+' / '+matname.split('/')[-1].strip()+' / '+str(bevel))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(data['vertices'],[],data['faces']);mesh.update()
    ob=bpy.data.objects.new(name,mesh);parts[(room,kind)].objects.link(ob);ob.parent=pivots[mover] if mover else parts[room]
    mesh.materials.append(bpy.data.materials[matname]);ob['source_parts']=data['records'];ob['source_paths']='\n'.join(data['sources']);ob['room']=room
    if any(uv!=(0,0) for uv in data['uvs']):
        uv=mesh.uv_layers.new(name='UVMap')
        for poly in mesh.polygons:
            for li in poly.loop_indices:uv.data[li].uv=data['uvs'][mesh.loops[li].vertex_index]
    if bevel:
        mod=ob.modifiers.new('Machined edges / restrained bevel','BEVEL');mod.width=bevel;mod.segments=2 if bevel>.02 else 1
        mod=ob.modifiers.new('Broad panel normals','WEIGHTED_NORMAL');mod.keep_sharp=True
    if binding:ob['display_binding']=binding;ob['replace_material_with']='Godot terminal SubViewport texture at runtime'
    mesh_map[(room,kind,mover,matname,bevel,binding)]=ob

# Integration anchors use exact game transforms. They are not pretend Blender interactions.
for i,rec in enumerate(D['colliders']):
    T=transform(rec['transform']);name=next(iter(rec['metadata'].values()),'collision_%03d'%i)
    ob=bpy.data.objects.new('COLLISION | '+str(name),None);collisions_col.objects.link(ob);ob.matrix_world=T;ob.empty_display_type='CUBE';ob.empty_display_size=1
    if 'size' in rec:ob.scale=Vector(rec['size'])*.5
    ob['source_path']=rec['source_path'];ob['metadata']=json.dumps(rec['metadata']);ob['godot_shape']=rec['shape']
    if rec['metadata']:
        anchor=bpy.data.objects.new('USE | '+str(name),None);anchors_col.objects.link(anchor);anchor.matrix_world=T;anchor.empty_display_size=.08;anchor['metadata']=json.dumps(rec['metadata']);anchor['source_path']=rec['source_path']
for binding in D['bindings']:
    ob=bpy.data.objects.new('SOCKET | '+binding['name'],None);anchors_col.objects.link(ob);ob.matrix_world=transform(binding['transform']);ob.empty_display_size=.08
    ob['role']=binding['role'];ob['display_size_m']=binding['display_size']

# A reusable local solid helper adds tangible refinements at original Godot positions.
def detail(name,room,pos,size,material='steel',bevel=.005,rot=None):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([tuple(v[i]*size[i]/2 for i in range(3)) for v in box_vertices],[],box_faces);mesh.update()
    ob=bpy.data.objects.new(name,mesh);parts[(room,'Equipment')].objects.link(ob);ob.parent=parts[room];ob.location=point(pos);ob.rotation_euler=R.to_euler()
    if rot:ob.rotation_euler=(R@rot.to_3x3()).to_euler()
    mesh.materials.append(refined[material])
    if bevel:
        b=ob.modifiers.new('Formed edge','BEVEL');b.width=bevel;b.segments=2
        b=ob.modifiers.new('Weighted face normals','WEIGHTED_NORMAL');b.keep_sharp=True
    return ob
def line(name,room,a,b,r=.012,material='steel'):
    a,b=point(a),point(b);d=b-a
    verts=[];faces=[];rot=d.to_track_quat('Z','Y').to_matrix()
    for z in [-d.length/2,d.length/2]:
        for i in range(8):verts.append(tuple(rot@Vector((r*math.cos(i*math.tau/8),r*math.sin(i*math.tau/8),z))+(a+b)/2))
    faces=[tuple(reversed(range(8))),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.materials.append(refined[material]);ob=bpy.data.objects.new(name,mesh);parts[(room,'Equipment')].objects.link(ob);ob.parent=parts[room]
    return ob

# Galley basin refinement: raised metal lip, dark inset, actual faucet outlet, drain.
for x in [1.095,1.705]:detail('Galley / formed sink rim','Hab',(x,1.036,-8.12),(.022,.035,.55),'steel',.005)
for z in [-8.385,-7.855]:detail('Galley / formed sink rim','Hab',(1.4,1.036,z),(.63,.035,.022),'steel',.005)
detail('Galley / drain inset','Hab',(1.4,1.034,-8.12),(.09,.009,.09),'rubber',.008)
for x in [1.37,1.4,1.43]:detail('Galley / drain grille','Hab',(x,1.04,-8.12),(.006,.006,.07),'steel',.001)
detail('Galley / faucet aerator','Hab',(1.506,1.309,-8.12),(.055,.042,.06),'rubber',.006)
# Mattress piping and pillow seam: gentle refinement, no loss of cozy block shapes.
for x in [-1.84,-.80]:line('Bunk / stitched edging','Hab',(x,.767,-8.17),(x,.767,-6.44),.007,'cream')
for z in [-8.17,-6.44]:line('Bunk / stitched edging','Hab',(-1.84,.767,z),(-.8,.767,z),.007,'cream')
detail('Bunk / pillow folded hem','Hab',(-1.32,.826,-8.20),(.69,.012,.022),'cloth',.004)
# Dinette restrained mug and a belt-fastened notebook are safely outside the walking lane.
detail('Dinette / secured notebook','Hab',(-1.52,.858,-5.02),(.28,.04,.20),'orange',.012)
detail('Dinette / notebook strap','Hab',(-1.52,.884,-5.02),(.035,.012,.21),'rubber',.002)
# These objects follow the folding surface, rather than floating when it moves.
for ob in list(parts[('Hab','Equipment')].objects):
    if ob.name.startswith('Dinette /'):
        world=ob.matrix_world.copy();ob.parent=pivots['Hab_FoldingTable'];ob.matrix_world=world
# Cockpit: a robust chair rail, seat seam and service fasteners.
for x in [-.24,.24]:
    detail('Pilot / seat rail','Cockpit',(x,.084,-11.55),(.055,.045,.75),'steel',.005)
for x in [-.30,.30]:line('Pilot / stitched seat edging','Cockpit',(x,.71,-11.26),(x,.71,-11.8),.008,'cream')
for binding in D['bindings']:
    T=transform(binding['transform']);w,h=binding['display_size']
    for x in [-w/2+.055,w/2-.055]:
        # Small machined corner protectors frame each CRT without narrowing its display.
        size=(.035,.035,.014);p=T@Vector((x,-h/2-.052,.139))
        ob=detail('CRT / captive fastener','Cockpit',(0,0,0),size,'steel',.003);ob.matrix_world=T@Matrix.Translation((x,-h/2-.052,.139))
# Cargo: guide rails mark the existing free lane, preserving the floor height.
for x in [-.70,.70]:
    detail('Cargo / recessed lane edge','Cargo',(x,.042,3.0),(.035,.008,7.56),'steel',.001)
for z in [-.52,1.35,3.20,5.10,6.50]:
    for x in [-.59,.59]:detail('Cargo / tie-down socket','Cargo',(x,.043,z),(.16,.012,.10),'rubber',.01)
# Proper collars on the exposed rigid plumbing, rather than unjoined square rods.
for z in [7.5,8.15,8.8,9.45,10.1,10.65]:
    for x in [-2.84,2.84]:detail('Engineering / conduit saddle','Engineering',(x,2.37,z),(.15,.10,.08),'steel',.007)
# Washroom fittings: drain slots and squared safety grip.
for z in [-3.6,-3.48,-3.36,-3.24,-3.12]:detail('Washroom / wet-deck drain','Washroom',(-2.02,.051,z),(.75,.006,.014),'steel',.002)
line('Washroom / grab rail','Washroom',(-2.54,1.03,-2.7),(-2.54,1.54,-2.7),.022,'steel')
for y in [1.03,1.54]:line('Washroom / rail standoff','Washroom',(-2.6,y,-2.7),(-2.54,y,-2.7),.023,'rubber')

# Preserve and demonstrate independent movement (Blender animation, not game behavior).
motions={
 'Hab_FoldingTable':('rotation_euler',None),
 'Hab_Drawer':('location',Vector((.32,0,0))),
 'Engineering_ServiceCover':('location',Vector((0,0,.845))),
}
for name,(prop,delta) in motions.items():
    ob=pivots[name];base=getattr(ob,prop).copy();ob.keyframe_insert(data_path=prop,frame=1)
    if delta is not None:setattr(ob,prop,base+delta)
    else:ob.rotation_euler=(ob.rotation_euler.to_matrix()@Matrix.Rotation(math.pi/2,3,'Z')).to_euler()
    ob.keyframe_insert(data_path=prop,frame=80);setattr(ob,prop,base);ob.keyframe_insert(data_path=prop,frame=100)
    if ob.animation_data:ob.animation_data.action.name=name+'_Demo'
for name,ob in pivots.items():
    if '_Door_' in name or 'Loading_Hatch_' in name:
        base=ob.location.copy();ob.keyframe_insert(data_path='location',frame=1)
        if '_Door_' in name:
            # Doors start open; both leaves slide 0.59m toward the doorway center.
            ob.location.y+=.595 if name.endswith('_1') else -.595
        else:ob.location.x=math.copysign(.70,base.x)
        ob.keyframe_insert(data_path='location',frame=80);ob.location=base;ob.keyframe_insert(data_path='location',frame=100)
        ob.animation_data.action.name=name+'_Close'

# Practical warm pools of light at the original fixture positions.
for i,data in enumerate(D['lights']):
    l=bpy.data.lights.new('Fixture %02d'%i,'POINT');l.energy=data['energy']*75;l.color=tuple(data['color'][:3]);l.shadow_soft_size=.12
    ob=bpy.data.objects.new(l.name,l);lights_col.objects.link(ob);ob.location=point(data['position'])
world=bpy.data.worlds.new('Interior / dark orbital sky');world.use_nodes=True
world.node_tree.nodes.get('Background').inputs[0].default_value=(.017,.027,.040,1);world.node_tree.nodes.get('Background').inputs[1].default_value=.25;scene.world=world

def camera(name,p,target,lens=22):
    c=bpy.data.cameras.new(name);ob=bpy.data.objects.new(name,c);rig_col.objects.link(ob);ob.location=point(p);target=point(target);ob.rotation_euler=(target-ob.location).to_track_quat('-Z','Y').to_euler();c.lens=lens;c.clip_start=.045;c.clip_end=500;return ob
cameras=[
 camera('01 • Cockpit',(0,1.67,-11.55),(0,1.60,-13.7),15.5),
 camera('02 • Living hab',(.30,1.72,-4.30),(.05,1.10,-7.70),19),
 camera('03 • Washroom',(-.87,1.65,-2.08),(-2.20,1.14,-2.93),17),
 camera('04 • Airlock',(.88,1.64,-2.09),(2.17,1.20,-2.95),17),
 camera('05 • Cargo hold',(0,1.78,-.50),(0,1.37,5.5),20),
 camera('06 • Engineering',(0,1.72,10.64),(.12,1.35,8.10),18),
 camera('07 • Hab galley',(-.2,1.59,-7.98),(1.4,1.2,-7.42),20),
 camera('08 • Engineering service',(0,1.60,9.45),(-2.0,1.4,9.4),20),
]
for i,c in enumerate(cameras):
    marker=scene.timeline_markers.new(c.name,frame=101+i*20);marker.camera=c
scene.camera=cameras[0];scene.frame_start=1;scene.frame_end=241;scene.frame_set(1);scene.render.fps=24
scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1600;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.8
for a in bpy.context.screen.areas:
    if a.type=='VIEW_3D':
        a.spaces.active.region_3d.view_perspective='CAMERA';a.spaces.active.shading.type='RENDERED';a.spaces.active.overlay.show_overlays=False
bpy.context.view_layer.objects.active=root;root.select_set(True)
scene['review']='Room cameras on timeline markers 101–241. Frame 1 initial state; 80 demonstrates independent moving parts. Screen content is a visual placeholder for runtime terminals.'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'longhaul_full_ship.blend'))
print('Interior created:',len(buffers),'batched surfaces,',len(D['meshes']),'source objects,',len(D['pivots']),'preserved mechanical roots; file:',bpy.data.filepath)
