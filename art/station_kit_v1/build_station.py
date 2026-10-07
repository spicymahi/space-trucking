"""Authored metric station/hangar kit; run with Blender --background --python.

No game assets or saves are modified. Blender Z is up; ship nose is +Y.
The same hangar collection is instanced in both station berths.
"""
import bpy, math, json, os, random
from mathutils import Vector, Matrix
from collections import defaultdict

OUT = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(os.path.dirname(OUT))
random.seed(21)
S = bpy.context.scene
S.name = '01 • INDUSTRIAL KEEL / exterior'
# This script is run in a fresh background process, never over the live file.
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
for c in list(bpy.data.collections): bpy.data.collections.remove(c)
S.unit_settings.system = 'METRIC'
S.unit_settings.scale_length = 1.0

def col(name, parent=None):
    c=bpy.data.collections.new(name)
    if parent: parent.children.link(c)
    return c
KIT=col('HANGAR • reusable module')
EXT=col('STATION • industrial keel', S.collection)
PRES=col('REVIEW • exterior lighting and cameras', S.collection)
GUIDE=col('INTEGRATION • markers and clearance volumes')
SHIP=col('REFERENCE • existing playable Longhaul')
PROPS=col('REVIEW • cargo and human scale')
FLOOR=col('01 Deck and cargo markings',KIT)
WALL=col('02 Pressure walls and service cassettes',KIT)
ROOF=col('03 Removable ceiling and overhead services',KIT)
DOOR=col('04 Animated pressure door and header',KIT)
SERV=col('05 Dispatch and service terminals',KIT)
SHELL=col('06 Exterior armor and structure',KIT)
HLIGHT=col('07 Interior practical lights',KIT)
M={}
def mat(k,h,metal=0,rough=.6,emission=0):
    rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    rgb=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    m=bpy.data.materials.new(k);m.use_nodes=True;m.diffuse_color=(*rgb,1)
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*rgb,1)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    if emission:
        p.inputs['Emission Color'].default_value=(*rgb,1);p.inputs['Emission Strength'].default_value=emission
    M[k]=m
for args in [('cream','bdbba9',.18),('pale','ded8c2',.08),('olive','657166',.25),('shade','858b80',.3),('red','8f3e32',.18),('yellow','bf984e',.2),('steel','697778',.7,.38),('frame','333d3c',.55),('black','151e20',.1),('deck','646b66',.25),('white','e2dec9'),('teal','557c78',.25),('blue','334958',.4),('glass','152b30',.6,.22),('phosphor','88d9aa',.05,.4,1.5),('lamp','ffdeb1',.05,.4,3),('redlamp','df6d47',0,.4,2),('solar','182c40',.45,.3)]:mat(*args)

# Batch individual fabricated parts into named material/assembly meshes. Every
# section remains editable; shared instances keep both hangars identical.
B=defaultdict(lambda:[[],[]])
def geo(c,m,verts,faces,part='Fabrication'):
    key=(c.name,m,part);v,f=B[key];i=len(v);v.extend(verts);f.extend(tuple(i+j for j in face) for face in faces)
def box(c,m,p,d,rot=None,part='Fabrication'):
    pts=[Vector((a*d[0]/2,b*d[1]/2,e*d[2]/2)) for a,b,e in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    pts=[tuple((rot@v if rot else v)+Vector(p)) for v in pts]
    geo(c,m,pts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],part)
def beam(c,m,a,b,w=.15,h=None,part='Fabrication'):
    a,b=Vector(a),Vector(b);v=b-a
    box(c,m,(a+b)/2,(w,h or w,v.length),v.to_track_quat('Z','Y').to_matrix(),part)
def cyl(c,m,p,r,depth,axis=(0,0,1),n=16,r2=None,part='Fabrication'):
    rot=Vector(axis).to_track_quat('Z','Y').to_matrix();pts=[]
    for z,rad in [(-depth/2,r),(depth/2,r if r2 is None else r2)]:
        pts.extend(tuple(rot@Vector((rad*math.cos(i*2*math.pi/n),rad*math.sin(i*2*math.pi/n),z))+Vector(p)) for i in range(n))
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    geo(c,m,pts,faces,part)
def line(c,m,points,width=.07,part='Conduit'):
    for a,b in zip(points,points[1:]):beam(c,m,a,b,width,part=part)
def chamfer_box(c,m,p,d,cut=.6,part='Fabrication'):
    x,y,z=p;w,l,h=d;cut=min(cut,w/3,l/3)
    ring=[(-w/2+cut,-l/2),(w/2-cut,-l/2),(w/2,-l/2+cut),(w/2,l/2-cut),(w/2-cut,l/2),(-w/2+cut,l/2),(-w/2,l/2-cut),(-w/2,-l/2+cut)]
    verts=[(x+a,y+b,z+zz*h/2) for zz in [-1,1] for a,b in ring]
    faces=[tuple(reversed(range(8))),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
    geo(c,m,verts,faces,part)
def flush():
    for (cn,m,part),(verts,faces) in B.items():
        mesh=bpy.data.meshes.new(cn+' / '+part+' / '+m);mesh.from_pydata(verts,[],faces);mesh.update()
        mesh.materials.append(M[m]);ob=bpy.data.objects.new(mesh.name,mesh);bpy.data.collections[cn].objects.link(ob)
        if part not in ['Paint','Screen artwork','Photovoltaic cells','Fins']:
            bevel=ob.modifiers.new('Manufactured edge radius','BEVEL');bevel.width=.025 if cn.startswith('STATION') else .012;bevel.segments=2
        ob['asset_role']='static_art';ob['material_family']=m
    B.clear()
fontpath='/System/Library/Fonts/Supplemental/DIN Alternate Bold.ttf'
FONT=bpy.data.fonts.load(fontpath) if os.path.exists(fontpath) else None
def text(c,words,p,size=.25,m='white',rot=(90,0,0),name=None):
    curve=bpy.data.curves.new(name or words,'FONT');curve.body=words;curve.size=size;curve.space_character=1.1;curve.extrude=.0006;curve.align_x='CENTER'
    if FONT:curve.font=FONT
    ob=bpy.data.objects.new(name or words,curve);c.objects.link(ob);ob.location=p;ob.rotation_euler=[math.radians(v) for v in rot];curve.materials.append(M[m]);return ob
def marker(name,p,kind,**data):
    o=bpy.data.objects.new(name,None);GUIDE.objects.link(o);o.location=p;o.empty_display_size=.4;o['binding']=kind
    for k,v in data.items():o[k]=v
    return o
def light(c,name,p,target,power,size,color=(1,.82,.62)):
    l=bpy.data.lights.new(name,'AREA');l.energy=power;l.shape='DISK';l.size=size;l.color=color
    o=bpy.data.objects.new(name,l);c.objects.link(o);o.location=p;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();return o
def camera(c,name,p,target,lens=35,ortho=None):
    d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);c.objects.link(o);o.location=p;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.lens=lens;d.clip_end=1500
    if ortho:d.type='ORTHO';d.ortho_scale=ortho
    return o
def setup_scene(s,world_strength=.08):
    s.unit_settings.system='METRIC';s.unit_settings.scale_length=1
    # Confirm the engine against the installed Blender at runtime.
    try:s.render.engine='BLENDER_EEVEE'
    except TypeError as e:raise RuntimeError(str(e))
    s.render.resolution_x=1600;s.render.resolution_y=1000;s.render.resolution_percentage=100
    assert 'PNG' in [i.identifier for i in bpy.types.ImageFormatSettings.bl_rna.properties['file_format'].enum_items]
    s.render.image_settings.file_format='PNG';s.render.film_transparent=False
    try:s.view_settings.view_transform='AgX'
    except TypeError:pass
    s.view_settings.exposure=0
    w=bpy.data.worlds.new(s.name);w.use_nodes=True;bg=next(n for n in w.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.2,.26,.32,1);bg.inputs['Strength'].default_value=world_strength;s.world=w
    s.frame_start=1;s.frame_end=120;s.frame_set(1)
setup_scene(S)

# HANGAR metric envelope: X +-14 m, Y -33..19 m, Z 0..10 m.
# All cargo grids retain the current 45 cm pitch and twelve pads per side.
box(FLOOR,'frame',(0,-7,-.36),(31,56,.72),part='Deck substrate')
for ix in range(14):
    for iy in range(26):
        x=-13+ix*2;y=-32+iy*2
        box(FLOOR,'deck' if random.random()<.82 else 'shade',(x,y,-.031),(1.982,1.982,.06),part='Deck plates')
        if iy%3==0:
            for dx in [-.86,.86]:box(FLOOR,'frame',(x+dx,y+.85,.004),(.055,.055,.008),part='Deck fasteners')
for x in [-6.7,6.7]:
    box(FLOOR,'white',(x,1.4,.01),(.09,30,.012),part='Paint')
    for y in range(-13,17,2):box(FLOOR,'yellow',(x+( .20 if x>0 else -.20),y,.012),(.12,.65,.015),part='Paint')
for x in [-2,2]:
    box(FLOOR,'white',(x,-24,.011),(.08,17,.014),part='Paint')
    for y in range(-31,-15):box(FLOOR,'yellow',(x+(.16 if x>0 else -.16),y,.013),(.09,.4,.012),part='Paint')
text(FLOOR,'4 M / KEEP CLEAR',(0,-29,.023),.44,'white',(0,0,0))
text(FLOOR,'RAMP ACCESS',(0,-19,.024),.38,'white',(0,0,0))
text(FLOOR,'LONGHAUL / CLASS B',(0,16.8,.024),.5,'white',(0,0,180))
# Docking target and non-obstructive landing marks.
for x,y in [(-1.68,10.4),(1.68,10.4),(-2.8,.2),(2.8,.2),(-2.83,-9.3),(2.83,-9.3)]:
    for dx in [-.75,.75]:box(FLOOR,'yellow',(x+dx,y,.019),(.09,2,.012),part='Paint')
    for dy in [-1,1]:box(FLOOR,'yellow',(x,y+dy,.019),(1.6,.09,.012),part='Paint')

grid_positions={'pickup':[],'delivery':[]}
for side,kind,tint in [(-1,'pickup','yellow'),(1,'delivery','teal')]:
    for row in range(4):
        for column in range(3):
            x=side*(5.35+column*2.6);y=-(21.05+row*2.55);idx=row*3+column+1
            grid_positions[kind].append((x,y,0))
            for i in range(5):
                t=-.9+i*.45
                box(FLOOR,tint,(x+t,y,.013),(.014,1.8,.01),part='Paint')
                box(FLOOR,tint,(x,y+t,.013),(1.8,.014,.01),part='Paint')
            for t in [-1,1]:
                box(FLOOR,tint,(x+t,y,.014),(.045,2.04,.014),part='Paint');box(FLOOR,tint,(x,y+t,.014),(2.04,.045,.014),part='Paint')
            text(FLOOR,'%02d'%idx,(x,y-1.20,.025),.17,'white',(0,0,0))
            marker(kind.upper()+'_%02d'%idx,(x-.9,y+.9,0),kind+'_grid',cell_m=.45,grid_cells=[4,3,4],origin_convention='low Godot X/Z corner')
    text(FLOOR,kind.upper(),(side*8,-19.35,.025),.58,'white',(0,0,0))

# Shell wall pockets have real depth; panels/vents sit entirely outside the
# clear cargo aisle. Repeated frames are connected to deck and roof.
for side in [-1,1]:
    x=side*14.55
    box(WALL,'frame',(x,-7,5),(1.1,52,10),part='Pressure shell')
    for j in range(13):
        y=-31+4*j
        box(WALL,'cream',(side*14.02,y,5),(.12,3.82,9.75),part='Wall lining')
        box(WALL,'red',(side*13.92,y,1),(.11,3.80,1.8),part='Kick panels')
        for z in [2.12,8.2]:box(WALL,'frame',(side*13.82,y,z),(.17,3.82,.13),part='Cable distribution')
        box(WALL,'frame',(side*13.70,y+1.93,5),(.36,.20,10),part='Wall frames')
        for z in [2.4,5,8.7]:box(WALL,'yellow',(side*13.48,y+1.93,z),(.12,.27,.21),part='Frame clamps')
        # Tall switchgear cassettes alternating with connected duct modules.
        if j%3!=0:
            box(WALL,'frame',(side*13.71,y,5.7),(.42,2.35,3.8),part='Service backboards')
            box(WALL,'shade',(side*13.43,y,6.4),(.22,2.0,1.82),part='Removable cassettes')
            for zy in range(7):box(WALL,'black',(side*13.29,y,5.72+zy*.22),(.035,1.64,.07),part='Air return louvers')
            box(WALL,'cream',(side*13.40,y,4.25),(.25,1.96,1.26),part='Switchgear')
            for a in [-.62,0,.62]:
                box(WALL,'black',(side*13.24,y+a,4.30),(.03,.37,.65),part='Breaker sockets')
                box(WALL,'yellow',(side*13.18,y+a,4.38),(.12,.13,.29),part='Breaker handles')
            for z in [3.48,7.85]:line(WALL,'steel',[(side*13.72,y-.8,z),(side*13.72,y+1.6,z),(side*13.72,y+1.6,8.2)],.065)
        else:
            for z in [3.4,6.6]:
                box(WALL,'frame',(side*13.76,y,z),(.25,2.5,2.05),part='Vent frames')
                for a in range(9):box(WALL,'shade',(side*13.52,y,z-.76+a*.19),(.28,2.22,.095),part='Heat exchanger slats')
        # Visible pressure pipes with brackets, all high enough to walk under.
        for z in [8.7,9.15]:
            cyl(WALL,'steel',(side*13.32,y,z),.09,3.95,(0,1,0),10,part='Pressure pipe')
            for dy in [-1.65,1.65]:box(WALL,'frame',(side*13.38,y+dy,z),(.34,.10,.34),part='Pipe bracket')
    # Integrated external side armor; its width includes the wall cavity.
    for j in range(8):
        y=-31+7*j
        box(SHELL,'olive' if j in [0,5] else 'cream',(side*15.12,y,5.3),(.22,6.75,10.3),part='Side armor')
        for z in [.45,10.25]:box(SHELL,'frame',(side*15.29,y,z),(.18,6.7,.22),part='Armor edge')
        for dy in [-3.1,3.1]:
            for z in [1.2,9.4]:box(SHELL,'steel',(side*15.29,y+dy,z),(.15,.18,.22),part='Captive latches')
        box(SHELL,'shade',(side*15.34,y,4.7),(.30,2.6,2.2),part='External service hatch')
        box(SHELL,'black',(side*15.51,y,4.7),(.025,1.95,1.5),part='External vent')
        for dz in range(6):box(SHELL,'steel',(side*15.56,y,4.12+dz*.23),(.12,1.9,.07),part='External vent')
    for z in [-.5,11.2]:beam(SHELL,'frame',(side*14.5,-34,z),(side*14.5,20,z),.65)

# Nose-end pressure bulkhead, inset sealing panels and wall graphic.
box(WALL,'frame',(0,19.35,5),(29,.7,10),part='End pressure wall')
for x in [-10.5,-3.5,3.5,10.5]:
    box(WALL,'cream',(x,18.94,5),(6.8,.13,9.7),part='End pressure wall panels')
    for z in [2.5,5,7.5]:box(WALL,'frame',(x,18.83,z),(6.72,.09,.08),part='Panel joints')
    for xx in [-3.15,3.15]:
        for z in [1,4,7,9]:box(WALL,'steel',(x+xx,18.78,z),(.13,.06,.22),part='Panel bolts')
text(WALL,'BERTH 01',(0,18.70,7.7),1.25,'frame')
text(WALL,'PRESSURIZED / STANDARD FREIGHT MODULE',(0,18.69,6.8),.33,'frame')
text(WALL,'NOSE ALIGNMENT',(0,18.68,2.4),.28,'red')
box(WALL,'yellow',(0,18.75,4),( .12,.08,2.1),part='Nose alignment')
for x in [-11.8,11.8]:
    box(WALL,'frame',(x,18.71,5),(1.3,.45,7.0),part='End services')
    for z in [2,3.5,5,6.5,8]:box(WALL,'shade',(x,18.41,z),(1.10,.25,1.28),part='End services')

# Removable roof, spanning beams, utility trunks and practical lighting.
box(ROOF,'frame',(0,-6.2,10.85),(30,52.4,1.15),part='Roof structure')
for j in range(9):
    y=-31+6*j
    box(ROOF,'cream',(0,y+.8 if j==0 else y,10.21),(27.8,4.20 if j==0 else 5.80,.10),part='Ceiling panels')
    box(ROOF,'frame',(0,-32.25 if j==0 else y-2.9,9.82),(27.8,.23,.60),part='Transverse roof ribs')
    for side in [-1,1]:
        beam(ROOF,'shade',(side*13.65,y-2.9,8.65),(side*12.2,y-2.9,9.83),.25,.35)
        box(ROOF,'frame',(side*10.65,y,9.73),(1.65,5.92,.46),part='Supply trunks')
        for dz in [-.3,.3]:box(ROOF,'shade',(side*10.65+dz,y,9.44),(.10,5.74,.06),part='Trunk straps')
        box(ROOF,'black',(side*7.5,y,9.80),(4,.7,.20),part='Lamp housings')
        box(ROOF,'lamp',(side*7.5,y,9.68),(3.7,.44,.05),part='Lamp diffusers')
    if j%2==0:light(HLIGHT,'Overhead work light %02d'%j,(0,y,9.35),(0,y,0),1550,10)
for x in [-12.2,12.2]:
    beam(ROOF,'yellow',(x,-32,8.9),(x,18,8.9),.16,.26)
for i in range(7):
    x=-12+i*4
    for j in range(7):box(SHELL,'cream' if (i+j)%6 else 'shade',(x,-29.25 if j==0 else -30+j*8,11.54),(3.84,6.30 if j==0 else 7.83,.17),part='Roof armor')
for x in [-10,10]:
    box(SHELL,'frame',(x,-7,11.7),(1.65,43,.30),part='Roof raceway')
    for y in [-23,-9,5]:box(SHELL,'olive',(x,y,12.0),(2.25,4.0,.60),part='Roof equipment')
    for y in [-29,15]:box(SHELL,'yellow',(x,y,11.88),(1.0,.8,.5),part='Lifting attachments')

# 18 x 9 m door. Four independent leaves rise and nest within the 12.5 m
# header: an actual opening, not a painted solid box. Shared animation demo.
# Hollow header accommodates all retracted leaves without intersection.
for y in [-35.25,-32.65]:box(DOOR,'frame',(0,y,10.95),(31,.20,3.3),part='Header machinery')
box(DOOR,'frame',(0,-33.95,12.55),(31,2.8,.2),part='Header roof')
for x in [-15.3,15.3]:box(DOOR,'frame',(x,-33.95,10.95),(.4,2.8,3.3),part='Header ends')
for x in [-12,12]:
    box(DOOR,'frame',(x,-33.9,4.6),(6,2.2,9.2),part='Jamb pockets')
    box(DOOR,'olive',(x,-35.04,4.6),(5.6,.18,8.9),part='Jamb armor')
    box(DOOR,'shade',(x,-35.18,4.1),(3.9,.15,4.9),part='Jamb access')
    box(DOOR,'black',(x,-35.28,4.5),(1.5,.08,1.4),part='Jamb screen backing')
    text(DOOR,'B / 01',(x,-35.34,4.35),.5,'white')
    for z in [1.0,7.2]:box(DOOR,'lamp',(x,-35.20,z),(.12,.16,1.1),part='Approach lamps')
for x in [-9.12,9.12]:
    box(DOOR,'steel',(x,-34.0,4.6),(.21,1.75,9.2),part='Door guides')
    box(DOOR,'yellow',(x,-35.02,4.6),(.15,.12,9.0),part='Door warning')
box(DOOR,'steel',(0,-34,-.04),(18.2,2,.08),part='Door sill')
for y in [-35.25,-32.65]:box(DOOR,'steel',(0,y,9.25),(18.2,.18,.15),part='Upper door reveal')
for i in range(4):
    leafcol=col('Door leaf %d'%(i+1),DOOR)
    root=bpy.data.objects.new('HangarDoorLeaf_%d'%(i+1),None);leafcol.objects.link(root)
    root['binding']='hangar_door_leaf';root['closed_height_m']=1.125+i*2.25;root['open_height_m']=10.60;root['sweep']='vertical'
    box(leafcol,'frame',(0,0,0),(17.95,.28,2.235),part='Door leaf')
    for k in range(6):
        x=-7.5+k*3
        for face in [-1,1]:
            box(leafcol,'shade' if (i+k)%4 else 'cream',(x,face*.17,0),(2.91,.06,2.11),part='Door face')
            for dx in [-1.28,1.28]:box(leafcol,'steel',(x+dx,face*.22,0),(.11,.06,.24),part='Door locks')
    flush()
    for o in leafcol.objects:
        if o!=root:o.parent=root
    root.location=(0,-34.7+i*.50,1.125+i*2.25)
    root.keyframe_insert(data_path='location',frame=1)
    root.location.z=10.60;root.keyframe_insert(data_path='location',frame=80)
    root.keyframe_insert(data_path='location',frame=120)
text(DOOR,'STANDARD FREIGHT / 18 x 9 M',(0,-35.05,11.2),.52,'white')
for x in [-7,0,7]:box(DOOR,'lamp',(x,-35.20,9.12),(3,.10,.13),part='Threshold lights')
# Purposeful cassette hardware on the entrance, including a chamfered
# reinforcing frame, twin door motors and connected supply lines.
for side in [-1,1]:
    beam(DOOR,'cream',(side*14.85,-35.50,.3),(side*14.85,-35.50,9.8),.40,.48,part='Entrance armor frame')
    beam(DOOR,'cream',(side*14.85,-35.50,9.8),(side*12.65,-35.50,12.0),.40,.48,part='Entrance armor frame')
    box(DOOR,'cream',(side*6.3,-35.50,12.0),(12.6,.48,.40),part='Entrance armor frame')
    for z in [.5,7.6,10.7]:box(DOOR,'yellow',(side*14.86,-35.78,z),(.25,.06,.40),part='Corner identification')
    box(DOOR,'black',(side*9.8,-35.40,5.3),(.75,.38,2.6),part='Door actuator cassette')
    for z in [4.6,5.3,6]:box(DOOR,'steel',(side*9.8,-35.64,z),(.56,.13,.43),part='Actuator covers')
    line(DOOR,'yellow',[(side*10.2,-35.38,4),(side*10.2,-35.38,7.5),(side*11.1,-35.38,7.5),(side*11.1,-35.38,9.9)],.07)
    for z in [1.7,3.3,6.1]:
        for x in [side*10.8,side*13.1]:box(DOOR,'steel',(x,-35.34,z),(.10,.065,.17),part='Access fasteners')

# Dispatch booth: reachable terminal counters face the clear central aisle.
# A wall-mounted counter lives beside the cargo areas, not across them.
box(SERV,'frame',(12.80,-11,1.25),(1.7,9.6,2.5),part='Dispatch booth carcass')
box(SERV,'cream',(11.89,-11,1.35),(.10,9.4,2.1),part='Dispatch panels')
box(SERV,'red',(11.80,-11,2.55),(.16,9.8,.45),part='Dispatch fascia')
text(SERV,'DISPATCH / PORT SERVICES',(11.69,-11,2.48),.26,'white',(90,0,-90))
for y in [-14.2,-11,-7.8]:
    box(SERV,'black',(11.72,y,1.85),(.10,2.6,.82),part='Booth windows')
    box(SERV,'glass',(11.65,y,1.85),(.04,2.47,.71),part='Booth glazing')
box(SERV,'frame',(11.25,-11,1.00),(1.1,9.5,.13),part='Service counter')

def terminal(name,y,action,color='phosphor'):
    c=col('Terminal / '+name,SERV)
    # Display plane faces -X; centered 1.46 m above the walking surface.
    box(c,'cream',(11.44,y,.48),(.76,1.10,.92),part='Pedestal')
    box(c,'red',(10.99,y,1.04),(.45,1.12,.10),part='Keyboard shelf')
    box(c,'frame',(11.35,y,1.52),(.48,.98,.75),part='CRT housing')
    box(c,'black',(11.095,y,1.52),(.05,.86,.62),part='Screen gasket')
    box(c,'glass',(11.062,y,1.52),(.024,.77,.53),part='Screen surface')
    text(c,name,(11.043,y,1.64),.079,color,(90,0,-90))
    text(c,'READY / SELECT',(11.040,y,1.40),.050,color,(90,0,-90))
    for row in range(3):
        for k in range(10):box(c,'shade',(10.89+row*.08,y-.35+k*.076,1.103),(.06,.057,.023),part='Keyboard keys')
    text(c,name,(10.73,y,1.01),.095,'white',(90,0,-90))
    marker('TERMINAL_'+action.upper(),(10.84,y,1.48),action,approach_position=[9.9,y,0],screen_facing='-X',screen_size_m=[.77,.53])
for name,y,action in [('CONTRACTS',-7.5,'contracts'),('PROVISIONS',-9.3,'provisions'),('REPAIRS',-11.1,'repairs'),('REFUEL',-12.9,'refuel'),('DELIVERY',-14.7,'complete')]:terminal(name,y,action)
# Smaller berth-control pedestal safely to the side of the ramp.
box(SERV,'cream',(-3.4,-17.7,.65),(.75,.70,1.3),part='Berth-control pedestal')
box(SERV,'frame',(-3.4,-17.7,1.46),(.88,.53,.55),part='Berth-control CRT')
box(SERV,'glass',(-3.4,-17.98,1.46),(.72,.03,.41),part='Berth-control screen')
text(SERV,'BERTH CONTROL',(-3.4,-18.01,1.5),.075,'phosphor')
text(SERV,'SEAL / DEPART',(-3.4,-18.01,1.36),.06,'phosphor')
marker('TERMINAL_DEPARTURE',(-3.4,-18.05,1.45),'depart')
# Personnel access and emergency equipment, on the service wall above grids.
box(SERV,'frame',(13.35,-26,1.55),(.44,2.05,3.10),part='Crew hatch')
box(SERV,'cream',(13.08,-26,1.55),(.12,1.76,2.8),part='Crew hatch')
box(SERV,'glass',(12.99,-26,2.14),(.05,.63,.44),part='Crew hatch')
text(SERV,'CREW ACCESS',(12.97,-26,3.25),.20,'white',(90,0,-90))
marker('CREW_ACCESS',(12.0,-26,0),'future_station_connection')
for y in [-24,-29.7]:
    box(SERV,'red',(13.3,y,.85),(.7,.8,1.7),part='Safety cabinet')
    text(SERV,'FIRE',(12.92,y,1.2),.16,'white',(90,0,-90))
    cyl(SERV,'red',(12.93,y,.7),.13,.64,n=12,part='Fire bottle')
text(WALL,'WORK WELL.\nRETURN HOME.',(-13.76,-17,4.8),.48,'frame',(90,0,90))
text(WALL,'KEPLER / INDUSTRIAL COOPERATIVE',(-13.73,-17,4.2),.16,'red',(90,0,90))
# Low-level hardware has hand-sized handles, tags, gauges and hose reels.
# It all sits outside the cargo footprint and the central walking spine.
for side in [-1,1]:
    for j,y in enumerate([-26,-18,-10,-2,6,14]):
        if side==1 and -17<y<-5:continue
        box(WALL,'frame',(side*13.75,y,1.25),(.35,1.35,1.55),part='Low level utility cassettes')
        box(WALL,'shade',(side*13.52,y,1.25),(.15,1.2,1.36),part='Low level utility cassettes')
        for yy in [-.45,.45]:box(WALL,'black',(side*13.40,y+yy,1.24),(.09,.06,.60),part='Cabinet handles')
        text(WALL,'UTIL / %02d'%j,(side*13.42,y,1.67),.11,'white',(90,0,90 if side<0 else -90))
        for yy in [-.24,.24]:
            cyl(WALL,'black',(side*13.39,y+yy,1.22),.14,.05,(1,0,0),12,part='Analog gauge')
            cyl(WALL,'pale',(side*13.35,y+yy,1.22),.115,.06,(1,0,0),12,part='Analog gauge')
            beam(WALL,'red',(side*13.29,y+yy,1.22),(side*13.29,y+yy+.05,1.29),.014,part='Gauge needles')
    for y in [-30,-22,-14,-6,2,10,18]:
        box(WALL,'black',(side*13.52,y,3.0),(.18,.85,.17),part='Wall work lamps')
        box(WALL,'lamp',(side*13.40,y,2.98),(.025,.70,.095),part='Wall work lamps')

# Simple physical cargo references occupy approved grid cells, not circulation.
def crate(p,size,tint='teal'):
    x,y,z=p;w,l,h=size
    box(PROPS,tint,(x,y,z+h/2),(w-.025,l-.025,h-.025),part='Example cargo')
    for dx in [-w*.43,w*.43]:
        box(PROPS,'frame',(x+dx,y,z+h/2),(.045,l,h),part='Cargo corner guards')
    for dy in [-l*.43,l*.43]:box(PROPS,'yellow',(x,y+dy,z+h/2),(w,.04,h),part='Cargo straps')
    box(PROPS,'pale',(x,y-l/2-.001,z+h*.58),(w*.50,.008,h*.25),part='Cargo labels')
for kind in ['pickup','delivery']:
    for j in ([0,3,5,7,11] if kind=='pickup' else [3,8]):
        x,y,z=grid_positions[kind][j]
        crate((x,y,0),( .9,1.8,.45),'teal' if kind=='pickup' else 'olive')
        if j in [3,7]:crate((x,y,.45),(.9,1.8,.45),'shade')

# The in-game ramp is not baked into the playable GLB, so recreate its exact
# 2.8 m width / 4.2 m run as an explicit reference object.
theta=math.atan(1.315/4.2)
box(PROPS,'frame',(0,-13.2,.6275),(2.8,4.4,.18),Matrix.Rotation(theta,3,'X'),part='Runtime ramp reference')
for x in [-1.32,1.32]:
    beam(PROPS,'yellow',(x,-11.1,1.385),(x,-15.3,.07),.085,.04,part='Runtime ramp reference')
for i in range(13):
    t=i/12;y=-11.2-t*4.1;z=1.374-t*1.304
    beam(PROPS,'steel',(-1.22,y,z),(1.22,y,z),.045,.02,part='Runtime ramp reference')

# 1.8 m person reference: excluded from future export along with example cargo.
def person(x,y):
    for dx in [-.13,.13]:
        beam(PROPS,'frame',(x+dx,y,.10),(x+dx,y,.85),.16,.19,part='1.8 m scale figure')
        box(PROPS,'black',(x+dx,y-.06,.085),(.20,.33,.17),part='1.8 m scale figure')
    box(PROPS,'red',(x,y,1.16),(.50,.28,.62),part='1.8 m scale figure')
    cyl(PROPS,'pale',(x,y,1.66),.14,.28,n=8,part='1.8 m scale figure')
    for dx in [-.34,.34]:beam(PROPS,'red',(x+dx,y,1.40),(x+dx,y-.04,.88),.13,.15,part='1.8 m scale figure')
person(8.5,-15.8)

marker('SHIP_DOCK_ORIGIN',(0,0,1.315),'ship_root',nose='+Y',godot_height=0.0)
marker('APPROACH_GATE',(0,-45,3.315),'approach_gate')
marker('TOUCHDOWN',(0,0,1.315),'touchdown')
marker('RAMP_CLEARANCE',(0,-16.8,0),'keep_clear',width_m=4.0)
flush()

# Import the actual production asset solely as a true-scale review reference.
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=os.path.join(PROJECT,'assets/ships/longhaul/longhaul_playable.glb'))
shipobs=set(bpy.data.objects)-before
shiproot=bpy.data.objects.new('LONGHAUL / game-scale reference',None);SHIP.objects.link(shiproot);shiproot.location.z=1.315
for o in shipobs:
    for c in list(o.users_collection):c.objects.unlink(o)
    SHIP.objects.link(o)
    if o.parent not in shipobs:o.parent=shiproot
    # Two unbound notebook props in the original capture lie below its floor.
    # Hide only these review copies; game geometry remains untouched.
    if 'Dinette / notebook strap' in o.name or 'Dinette / secured notebook' in o.name:
        o.hide_render=True;o.hide_viewport=True
shiproot['export_exclude']=True

# INDUSTRIAL KEEL. Main truss runs X, bays face -Y with unobstructed approaches.
for bay,x in enumerate([-27,27],1):
    inst=bpy.data.objects.new('BAY %02d / shared standard module'%bay,None);EXT.objects.link(inst);inst.instance_type='COLLECTION';inst.instance_collection=KIT;inst.location=(x,0,0);inst['bay_index']=bay
    for xx in [x-11,x+11]:
        beam(EXT,'frame',(xx,-12,23),(xx,13,23),.9,1.25,part='Bay overhead girders')
        for y in [-12,13]:
            beam(EXT,'frame',(xx,y,11.8),(xx,y,23),1.1,1.4,part='Bay suspension')
            beam(EXT,'shade',(xx,y,12.4),(xx+(-6 if xx>x else 6),y,22.1),.75,.85,part='Bay suspension')
            box(EXT,'olive',(xx,y,12.1),(2.5,2.5,1.0),part='Load transfer blocks')
    text(EXT,'%02d'%bay,(x+11.9,-35.39,3.1),.8,'white')
    # Enclosed aft lift trunk into keel; does not intersect the landing lane.
    box(EXT,'frame',(x,19,17),(5,4,11),part='Hangar service lift')
    box(EXT,'cream',(x,16.89,17),(4.6,.17,9.9),part='Hangar service lift')
    text(EXT,'LIFT',(x,16.77,17),.7,'frame')

def truss(a,b,width=4,height=4,steps=8):
    # X-aligned rectangular open beam, all diagonal struts terminate at nodes.
    x0,y,z=a;x1=b[0]
    for dy in [-width/2,width/2]:
        for dz in [-height/2,height/2]:beam(EXT,'frame',(x0,y+dy,z+dz),(x1,y+dy,z+dz),.55,part='Keel truss')
    for k in range(steps):
        u=x0+(x1-x0)*k/steps;v=x0+(x1-x0)*(k+1)/steps
        for dy in [-width/2,width/2]:
            beam(EXT,'steel',(u,y+dy,z-height/2),(v,y+dy,z+height/2),.32,part='Keel diagonals')
            beam(EXT,'steel',(u,y+dy,z+height/2),(v,y+dy,z-height/2),.32,part='Keel diagonals')
        for dz in [-height/2,height/2]:beam(EXT,'steel',(u,y-width/2,z+dz),(v,y+width/2,z+dz),.25,part='Keel diagonals')
        box(EXT,'shade',(u,y,z),( .5,width+.5,height+.5),part='Keel node plates')
truss((-61,10,23),(66,10,23),7,6,13)
for x in [-52,-33,-14,5,24,43,62]:
    box(EXT,'frame',(x,5.4,23),(11,3.2,6.9),part='Keel service modules')
    box(EXT,'cream',(x,3.71,23),(10.5,.2,6.5),part='Keel service modules')
    box(EXT,'olive',(x,3.52,23),(7.6,.15,4.5),part='Keel access panels')
    for dx in [-4.5,4.5]:
        for z in [20.8,25.2]:box(EXT,'steel',(x+dx,3.38,z),(.45,.18,.35),part='Keel panel locks')
    box(EXT,'yellow',(x-3.4,3.32,23),(.4,.22,4.3),part='Keel panel locks')
    for k in range(5):box(EXT,'black',(x+2.5,3.37,21.8+k*.42),(1.45,.12,.16),part='Keel vents')
# Pressurized corridor physically links the two bay lift trunks.
cyl(EXT,'cream',(0,18.5,23),2.25,109,(1,0,0),12,part='Transfer corridor')
for x in range(-54,55,9):cyl(EXT,'frame',(x,18.5,23),2.4,.38,(1,0,0),12,part='Corridor collars')

# Two faceted industrial pressure drums, with shells and connected saddles.
for index,cx in enumerate([-29,23],1):
    cyl(EXT,'olive',(cx,10,39),9.1,39,(1,0,0),20,part='Pressure drum shell')
    for xx,sgn in [(cx-21,-1),(cx+21,1)]:
        cyl(EXT,'cream',(xx,10,39),9.1,3,(1,0,0),20,r2=7.4 if sgn==1 else 9.1,part='Pressure drum end')
        cyl(EXT,'shade',(xx+sgn*1.55,10,39),7.4,.35,(1,0,0),20,part='Pressure end cap')
        cyl(EXT,'frame',(xx+sgn*1.8,10,39),2.5,.35,(1,0,0),12,part='Pressure service port')
        cyl(EXT,'cream',(xx+sgn*2.0,10,39),1.85,.18,(1,0,0),12,part='Pressure service port')
    for dx in [-17,16]:
        cyl(EXT,'frame',(cx+dx,10,39),9.3,.55,(1,0,0),20,part='Drum collars')
        cyl(EXT,'yellow',(cx+dx-1,10,39),9.23,1.1,(1,0,0),20,part='Drum identification band')
        for yy in [4,16]:
            beam(EXT,'frame',(cx+dx,yy,29.8),(cx+dx,yy,26.1),.7,1,part='Drum saddles')
            beam(EXT,'shade',(cx+dx,yy,30),(cx+dx+3,yy,26.1),.5,.6,part='Drum saddles')
    # Longitudinal seams and service fittings conform to the faceted cylinder.
    for k in range(20):
        a=2*math.pi*k/20;yy=10+9.13*math.cos(a);zz=39+9.13*math.sin(a)
        beam(EXT,'frame',(cx-18,yy,zz),(cx+18,yy,zz),.065,part='Drum seams')
        for xx in [cx-10,cx,cx+10]:
            cyl(EXT,'steel',(xx,yy,zz),.095,.10,(0,math.cos(a),math.sin(a)),6,part='Drum fasteners')
    for xx in [cx-9,cx+7]:
        box(EXT,'shade',(xx,.86,39),(4.5,.3,3.5),part='Drum inspection ports')
        box(EXT,'black',(xx,.67,39),(3.3,.12,2.2),part='Drum inspection ports')
        for z in [38.3,39,39.7]:box(EXT,'steel',(xx,.55,z),(2.9,.20,.15),part='Drum inspection ports')
    text(EXT,str(index),(cx+1,.58,40),3.0,'white')
    text(EXT,'PROCESS / %02d'%index,(cx+1,.53,36.8),.55,'white')
    cyl(EXT,'frame',(cx,10,29.5),1.6,7,(0,0,1),12,part='Drum utility connection')
    # rooftop intake instrumentation
    box(EXT,'frame',(cx-8,10,48.4),(5,4,1),part='Drum roof service')
    box(EXT,'cream',(cx-8,10,49.3),(3.6,2.8,1.2),part='Drum roof service')

# Forward operations block; windows, stepped armor and antenna mast.
box(EXT,'frame',(-65,10,26),(17,18,18),part='Operations pressure core')
for z,w in [(20,15),(26,18),(32,15)]:
    chamfer_box(EXT,'cream',(-65,8,z),(w,16,5.5),1.4,part='Operations decks')
    box(EXT,'olive',(-65,-.25,z),(w-.4,.5,3.6),part='Operations fascia')
    for k in range(5):
        x=-65-(w-3)/2+k*(w-3)/4
        box(EXT,'frame',(x,-.61,z+.4),(1.6,.18,1.1),part='Observation window frames')
        box(EXT,'lamp',(x,-.72,z+.4),(1.36,.06,.77),part='Observation windows')
    for x in [-65-w/2+.5,-65+w/2-.5]:box(EXT,'shade',(x,-.38,z),(.45,.32,5.1),part='Deck armor')
text(EXT,'KEPLER WORKS',(-65,-.60,29.5),.76,'white')
text(EXT,'INDUSTRIAL KEEL / K-04',(-65,-.58,18.5),.40,'white')
box(EXT,'frame',(-63,10,37),(7,8,4),part='Communications roof')
cyl(EXT,'cream',(-63,10,41),2.8,5,n=12,r2=.7,part='Radome')
for x,y,h in [(-70,8,11),(-60,15,8),(-67,14,14)]:
    cyl(EXT,'steel',(x,y,36+h/2),.12,h,n=8,part='Antenna mast')
    for z in [38,41,44]:beam(EXT,'steel',(x-1.3,y,z),(x+1.3,y,z),.07,part='Antenna element')

# Aft power plant separated from the inhabited pressure drums by an open boom.
truss((65,10,23),(106,10,23),5,5,5)
for yy in [6,14]:
    cyl(EXT,'steel',(68,yy,29),2.4,10,(1,0,0),16,part='Buffer tanks')
    for xx in [64,72]:cyl(EXT,'frame',(xx,yy,29),2.48,.35,(1,0,0),16,part='Tank straps')
    line(EXT,'yellow',[(63,yy,29),(61,yy,29),(61,yy,26),(78,yy,26)],.24,part='Power coolant lines')
chamfer_box(EXT,'frame',(103,10,23),(15,11,11),1.4,part='Power block')
for side in [-1,1]:
    box(EXT,'cream',(103,10+side*5.6,23),(13.5,.28,9.5),part='Power block armor')
    box(EXT,'olive',(103,10+side*5.81,23),(9,.2,6),part='Power block armor')
for x in [99,107]:
    # Four separated rectangular thermal radiator banks.
    beam(EXT,'frame',(x,10,-13),(x,10,62),.65,part='Radiator mast')
    for z in [1,45]:
        box(EXT,'frame',(x,10,z),(5.3,.65,24),part='Radiator frame')
        box(EXT,'black',(x,9.60,z),(4.8,.20,23.4),part='Radiator panels')
        for dx in [-2.15,2.15]:beam(EXT,'yellow',(x+dx,9.42,z-11.5),(x+dx,9.42,z+11.5),.11,part='Coolant headers')
        for k in range(42):box(EXT,'steel',(x,9.46,z-11.3+k*.55),(4.2,.10,.045),part='Fins')
        for zz in [z-8,z+8]:beam(EXT,'frame',(x,10,23),(x,10,zz),.3,part='Radiator supports')
# Engineering detail is grouped by purpose: removable service cassettes,
# pressure lines and isolated thruster pods, rather than random surface noise.
for cx in [-29,23]:
    for k in range(5):
        x=cx-13+k*6.5
        for a in [math.radians(135),math.radians(225)]:
            y=10+9.16*math.cos(a);z=39+9.16*math.sin(a)
            n=Vector((0,math.cos(a),math.sin(a)))
            rotation=n.to_track_quat('Z','Y').to_matrix()
            box(EXT,'olive' if k%2 else 'shade',(x,y,z),(5.95,4.7,.10),rotation,part='Replaceable drum panels')
            for dx in [-2.7,2.7]:
                for dy in [-1.9,1.9]:
                    p=Vector((x,y,z))+rotation@Vector((dx,dy,.12))
                    cyl(EXT,'steel',p,.11,.10,n,6,part='Drum panel latches')
    line(EXT,'steel',[(cx-18,3.3,45.3),(cx+18,3.3,45.3),(cx+18,5.1,47.1)],.12,part='Drum service conduit')
    for x in [cx-13,cx,cx+13]:
        box(EXT,'frame',(x,3.2,45.3),(.25,.5,.5),part='Conduit saddles')
for bayx in [-27,27]:
    for side in [-1,1]:
        x=bayx+side*15.6
        for z in [2.1,8.5]:
            line(EXT,'steel',[(x,-30,z),(x,16,z),(x,18,z+1)],.13,part='Bay exterior pressure lines')
            for y in [-28,-20,-12,-4,4,12]:box(EXT,'frame',(x,y,z),(.35,.30,.48),part='Exterior pipe saddles')
        for y in [-26,-2,16]:
            box(EXT,'olive',(x,y,6.5),(.45,2.2,1.0),part='Electrical junction housings')
            for yy in [-.85,.85]:box(EXT,'yellow',(x+side*.25,y+yy,6.5),(.08,.14,.75),part='Electrical housing latches')
    for x in [bayx-14,bayx+14]:
        box(EXT,'frame',(x,19,1),(1.8,2.4,2),part='Station keeping pod')
        cyl(EXT,'steel',(x,20.3,1),.57,.45,(0,1,0),12,r2=.70,part='Cold gas nozzle')
        cyl(EXT,'black',(x,20.55,1),.48,.05,(0,1,0),12,part='Thruster cavity')
# Modest auxiliary photovoltaic wings behind the drums; no approach obstruction.
for side in [-1,1]:
    yy=42+side*13
    beam(EXT,'frame',(-10,18,26),(-10,yy,26),.55,part='Solar yoke')
    box(EXT,'frame',(-10,yy,26),(30,14,.45),part='Solar wing frame')
    for i in range(10):
        for j in range(4):box(EXT,'solar',(-23.5+i*3,yy-5.25+j*3.5,26.26),(2.85,3.33,.05),part='Photovoltaic cells')
    for xx in [-25,5]:beam(EXT,'yellow',(xx,yy-7,26.30),(xx,yy+7,26.30),.10,part='Solar frame')
flush()

# Scene collections keep the station, bay, and scale references independently
# reviewable. Interior scene has no hidden exterior copy blocking the camera.
H=bpy.data.scenes.new('02 • HANGAR / interior walkthrough');setup_scene(H,.18)
for c in [KIT,SHIP,PROPS,GUIDE]:H.collection.children.link(c)
HC=col('REVIEW • interior cameras',H.collection)
cam_h=camera(HC,'CAM / Cargo floor',(-11.7,-29.8,5.6),(2,1.5,2.4),21)
cam_eye=camera(HC,'CAM / Player eye',(3,-24,1.70),(0,-10,2),25)
cam_service=camera(HC,'CAM / Dispatch',(6.2,-16.8,1.72),(11.3,-10.8,1.6),28)
H.camera=cam_h
for frame,cam in [(1,cam_h),(30,cam_eye),(60,cam_service)]:H.timeline_markers.new(cam.name,frame=frame).camera=cam
H['review']='Frames 1 cargo overview / 30 human eye height / 60 service counter. Door opens by frame 80. No gameplay logic in this asset.'
# Manual art-only hemisphere fill for legibility in a work bay.
light(HLIGHT,'Ramp area practical',(0,-19,7),(0,-20,0),1700,8)
light(HLIGHT,'Dispatch practical',(9.6,-11,4.6),(11,-11,1),650,5)
light(HLIGHT,'Forward fill',(0,15,8),(0,3,1),1600,9,(.72,.85,1))
PLAN=bpy.data.scenes.new('03 • HANGAR / clearance plan');setup_scene(PLAN,.35)
for c in [FLOOR,WALL,SERV,SHIP,PROPS,GUIDE]:PLAN.collection.children.link(c)
PC=col('REVIEW • plan cameras and lights',PLAN.collection)
PLAN.camera=camera(PC,'CAM / Dimension plan',(0,-7,70),(0,-7,0),ortho=64)
PLAN.render.resolution_x=1000;PLAN.render.resolution_y=1600
light(PC,'Plan key',(0,-7,30),(0,-7,0),9000,40)
text(PC,'28 M CLEAR WIDTH',(0,21,.02),1.0,'white',(0,0,0))
text(PC,'52 M CLEAR LENGTH',(-16,-7,.02),.85,'white',(0,0,90))
text(PC,'18 x 9 M DOOR',(0,-35.8,.02),.70,'white',(0,0,0))
PLAN['dimensions']='28 x 52 x 10 m clear interior. 18 x 9 m door. 4 m cargo circulation spine. 12 + 12 stackable pads. Metres.'
# Exterior cameras and a restrained space-light setup.
cam_ext=camera(PRES,'CAM / Station three-quarter',(163,-224,137),(13,3,22),48)
cam_front=camera(PRES,'CAM / Station approach',(35,-255,61),(15,0,26),53)
S.camera=cam_ext
S.timeline_markers.new('Exterior / closed pressure doors',frame=1).camera=cam_ext
S.timeline_markers.new('Approach / open pressure doors',frame=80).camera=cam_front
sun=bpy.data.lights.new('Distant sun','SUN');sun.energy=2.2;sun.angle=.12
o=bpy.data.objects.new('Distant sun',sun);PRES.objects.link(o);o.rotation_euler=(.55,-.5,-.3)
light(PRES,'Broad bounce',(5,-100,100),(10,0,20),400000,130,(.72,.82,1))
light(PRES,'Warm rim',(-80,40,65),(0,5,25),300000,90,(1,.77,.48))
S['scope']='Blender art and dimensional review only. No Godot integration or functional pressure/docking/cargo logic yet.'
S['bay_module']='HANGAR • reusable module; two linked collection instances, same full-depth interior.'

# Use a small Longhaul silhouette near the bay to make exterior scale explicit.
ship_instance=bpy.data.objects.new('Longhaul / approaching reference',None);EXT.objects.link(ship_instance);ship_instance.instance_type='COLLECTION';ship_instance.instance_collection=SHIP;ship_instance.location=(-27,-58,1)
ship_instance['export_exclude']=True

# Bind markers survive as documented anchors; no collision claims before Godot.
envelopes={
 'hangar_clear':{'min':[-14,-33,0],'max':[14,19,10]},
 'door_clear':{'min':[-9,-35,0],'max':[9,-33,9]},
 'cargo_spine':{'min':[-2,-32,0],'max':[2,-15.5,2.4]},
 'ship_source_bbox_m':{'min':[-5.438,-11.72,0],'max':[5.438,14.739,5.745]},
 'game_to_blender':{'x':'x','y':'-z','z':'y + 1.315'},
 'grid':{'cell_m':.45,'dimensions':[4,3,4],'pickup_count':12,'delivery_count':12},
 'station_bay_origins':[[-27,0,0],[27,0,0]],
 'terminal_bindings':{o.name:{'position':list(o.location),'binding':o.get('binding')} for o in GUIDE.objects if o.get('binding')},
 'limitations':['Blender only: no live terminal UI, physics or docking controller.', 'Docking begins nose-first along +Y; departure reverses along -Y.', 'Dock-root height is 1.315 m so existing landing feet meet floor: 0.115 m above the previous test apron alignment. Match ramp/collisions during integration.', 'Two below-floor notebook reference meshes are hidden in this review only.', 'Door animation is a review demonstration; runtime interlocks must be implemented during integration.']}
with open(os.path.join(OUT,'integration_manifest.json'),'w') as f:json.dump(envelopes,f,indent=2)

# Save a clean editable file and put its opening view on the exterior camera.
bpy.context.window.scene=S;S.frame_set(1)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.shading.type='MATERIAL'
            area.spaces.active.overlay.show_overlays=False
            area.spaces.active.clip_end=1500
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'industrial_keel_and_hangar.blend'),compress=True)
print('STATION_BUILD_COMPLETE',len(bpy.data.objects),'objects',flush=True)
if os.environ.get('STATION_RENDER','1')=='1':
    for scene,path in [(S,'01-station-exterior.png'),(H,'02-hangar-interior.png'),(PLAN,'03-clearance-plan.png')]:
        bpy.context.window.scene=scene;scene.frame_set(1);scene.render.filepath=os.path.join(OUT,'renders',path);bpy.ops.render.render(write_still=True)
    H.frame_set(60);H.render.filepath=os.path.join(OUT,'renders','04-dispatch-player-view.png');bpy.context.window.scene=H;bpy.ops.render.render(write_still=True)
    print('STATION_RENDERS_COMPLETE',flush=True)
