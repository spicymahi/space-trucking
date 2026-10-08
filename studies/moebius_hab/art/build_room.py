"""Fresh Blender-authored illustration study. No existing game data is read.
Blender units: metres, Z up, +Y down the room. Godot export maps (x,z,-y).
Run: Blender --background --factory-startup --python art/build_room.py
"""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector
from math import sin, cos, pi
ROOT=Path(__file__).resolve().parents[1]
rng=random.Random(709)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for m in list(bpy.data.materials): bpy.data.materials.remove(m)
scene=bpy.context.scene
scene.unit_settings.system='METRIC'
M={}; collision=[]
def linear(v): return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
def mat(name,hex,emit=False):
    rgb=[linear(int(hex[i:i+2],16)/255) for i in (0,2,4)]
    m=bpy.data.materials.new(name); m.diffuse_color=(*rgb,1); m.use_nodes=True
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'); p.inputs['Base Color'].default_value=(*rgb,1);p.inputs['Roughness'].default_value=.83
    if emit:p.inputs['Emission Color'].default_value=(*rgb,1);p.inputs['Emission Strength'].default_value=1
    M[name]=m;return m
for name,h in [('Ivory','e3dcc3'),('Porcelain','eee9d4'),('WarmShadow','b6ad91'),('Sand','c7bb9d'),('Blue','527999'),('BlueDark','38596f'),('Floor','7892aa'),('Steel','8d9b9b'),('Ink','2a353b'),('Seam','59646a'),('Rubber','34414b'),('Rust','b56546'),('Red','b87556'),('Green','8d9c80'),('Leaf','587c5e'),('LeafLight','86a66c'),('Gold','cbb581'),('Paper','f3eacf'),('WhiteCloth','e3deca'),('Book','c69a63')]:mat(name,h)
mat('CRT','1b4b46',True);mat('Phosphor','79bd9b',True);mat('Light','ffe9ae',True)
COL=bpy.data.collections.new('01 / Newly modelled hab');scene.collection.children.link(COL)
def own(o,name,material):
    o.name=name
    for c in list(o.users_collection):c.objects.unlink(o)
    COL.objects.link(o)
    if material:o.data.materials.append(M[material])
    return o
def box(name,loc,scale,material='Ivory',bevel=.02):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=own(bpy.context.object,name,material);o.dimensions=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Manufactured edge radii','BEVEL');mod.width=bevel;mod.segments=3
        mod=o.modifiers.new('Face weighted normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=30
    return o
def mesh(name,verts,faces,material,smooth=False):
    m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update();o=bpy.data.objects.new(name,m);COL.objects.link(o);m.materials.append(M[material])
    for p in m.polygons:p.use_smooth=smooth
    return o
def line(name,points,material='Ink',r=.0014,closed=False):
    c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=1;c.bevel_depth=r;c.bevel_resolution=1
    s=c.splines.new('POLY');s.points.add(len(points)-1)
    for p,co in zip(s.points,points):p.co=(*co,1)
    s.use_cyclic_u=closed
    o=bpy.data.objects.new(name,c);COL.objects.link(o);c.materials.append(M[material]);return o
def tube(name,points,r=.022,material='Steel'):
    return line(name,points,material,r)
def cyl(name,loc,r,depth,material='Steel',direction=(0,0,1),vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc);o=own(bpy.context.object,name,material)
    o.rotation_euler=Vector(direction).to_track_quat('Z','Y').to_euler();mod=o.modifiers.new('Machined lip','BEVEL');mod.width=min(.008,r*.12);mod.segments=2
    mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');return o
def sphere(name,loc,scale,material='Ivory',segments=24,rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=loc);o=own(bpy.context.object,name,material);o.scale=scale
    for p in o.data.polygons:p.use_smooth=True
    return o
def mappt(axis,depth,u,v):
    if axis=='x':return (depth,u,v)
    if axis=='y':return (u,depth,v)
    return (u,v,depth)
def rr(w,h,r,n=7):
    pts=[]
    for cx,cy,a in [(w/2-r,h/2-r,0),(-w/2+r,h/2-r,90),(-w/2+r,-h/2+r,180),(w/2-r,-h/2+r,270)]:
        for j in range(n+1):
            ang=math.radians(a+j*90/n);pts.append((cx+r*cos(ang),cy+r*sin(ang)))
    return pts
# rr starts at right edge upper corner, moves anticlockwise.
def outline(name,axis,depth,center,size,radius=.035,material='Ink',thick=.0014):
    return line(name,[mappt(axis,depth,center[0]+u,center[1]+v) for u,v in rr(*size,radius)],material,thick,True)
def panel(name,axis,depth,center,size,material='Ivory',thick=.025,radius=.035,detail=True):
    loc=mappt(axis,depth,center[0],center[1]);dims=(thick,*size) if axis=='x' else ((size[0],thick,size[1]) if axis=='y' else (*size,thick))
    o=box(name,loc,dims,material,min(radius,thick*.42))
    sign=-1 if (axis=='x' and depth>0) or (axis=='y' and depth>0) or axis=='z' else 1
    face=depth+sign*(thick/2+.001)
    if detail:
        outline(name+' / gasket',axis,face,center,(size[0]-.015,size[1]-.015),min(radius,.05))
    return o

def frame(name,axis,depth,center,outer,inner,radius,material='Ivory',thick=.10):
    # True open aperture, front and back, with a rounded rectangular reveal.
    a=rr(*outer,radius);b=rr(*inner,max(.02,radius-(outer[0]-inner[0])/2));verts=[]
    for d,points in [(depth-thick/2,a),(depth-thick/2,b),(depth+thick/2,a),(depth+thick/2,b)]:verts += [mappt(axis,d,center[0]+u,center[1]+v) for u,v in points]
    n=len(a);faces=[]
    for i in range(n):
        j=(i+1)%n
        faces.extend([(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),(i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)])
    o=mesh(name,verts,faces,material)
    # Recalculate orientation for open ring.
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False)
    for delta in [-1,1]:
        outline(name+' / outside ink',axis,depth+delta*(thick/2+.001),center,outer,radius)
        outline(name+' / reveal ink',axis,depth+delta*(thick/2+.001),center,inner,max(.02,radius-(outer[0]-inner[0])/2))
    return o

def bolt(name,axis,d,u,v,r=.006):
    direction={'x':(1,0,0),'y':(0,1,0),'z':(0,0,1)}[axis]
    cyl(name,mappt(axis,d,u,v),r,.003,'Sand',direction,12)
    line(name+' slot',[mappt(axis,d+.002,u-r*.5,v),mappt(axis,d+.002,u+r*.5,v)],'Ink',.0007)
def handle(name,axis,d,u,v,w=.13):
    # Recess with a visible pull, no textual identifier.
    panel(name+' pocket',axis,d,(u,v),(w+.035,.052),'BlueDark',.012,.02,False)
    sign=-1 if axis=='x' and d>0 else 1
    tube(name+' pull',[mappt(axis,d+sign*.028,u-w/2,v-.008),mappt(axis,d+sign*.04,u-w/2,v+.008),mappt(axis,d+sign*.04,u+w/2,v+.008),mappt(axis,d+sign*.028,u+w/2,v-.008)],.008,'Steel')
def col(name,center,size):collision.append({'name':name,'center':[center[0],center[2],-center[1]],'size':[size[0],size[2],size[1]]})
# Shell: the left wall has a real window opening; 4.8 m x 7m clear room.
box('Hull / floor',(0,1.6,-.105),(4.84,7.4,.2),'Floor',.012);col('Deck',(0,1.6,-.105),(4.84,7.4,.2))
box('Hull / ceiling',(0,1.6,2.77),(4.84,7.4,.14),'Ivory',.025);col('Ceiling',(0,1.6,2.77),(4.84,7.4,.14))
box('Hull / right wall',(2.47,1.6,1.33),(.15,7.4,2.86),'Ivory',.02);col('Starboard wall',(2.47,1.6,1.33),(.15,7.4,2.86))
box('Hull / front wall',(0,-2.1,1.33),(4.95,.15,2.86),'Ivory',.02);col('Forward wall',(0,-2.1,1.33),(4.95,.15,2.86))
# Window runs y=-.95..1.2, z=1.12..2.36.
for name,loc,dim in [('window sill',(-2.47,1.6,.53),(.15,7.4,1.16)),('window lintel',(-2.47,1.6,2.57),(.15,7.4,.40)),('front pier',(-2.47,-1.25,1.75),(.15,1.7,1.38)),('aft pier',(-2.47,3.59,1.75),(.15,3.54,1.38))]:box('Hull / '+name,loc,dim,'Ivory',.02);col(name,loc,dim)
frame('Window / outer flange','x',-2.35,(.70,1.78),(2.4,1.55),(2.13,1.27),.21,'Blue',.14)
frame('Window / ivory pressure frame','x',-2.26,(.70,1.78),(2.25,1.4),(2.05,1.2),.19,'Porcelain',.09)
frame('Window / dark pressure seal','x',-2.32,(.70,1.78),(2.09,1.24),(2.05,1.20),.13,'Rubber',.012)
# Invisible physical safety barrier only; clear vacuum view, no reflective pane.
col('Window glass',(-2.39,.70,1.75),(.10,2.3,1.4))
for yy in [-.34,1.74]:
    for zz in [1.19,2.36]:bolt('Window fastening','x',-2.20,yy,zz,.014)
# Deck plate seams, flush hatches and inset finger pulls.
for yi in range(6):
    yy=-1.42+yi*1.22
    for xx in [-1.6,0,1.6]:
        outline('Deck / plate perimeter','z',.003,(xx,yy),(1.59,1.21),.04,'Seam',.0012)
        if xx==0:
            outline('Deck / hatch pull','z',.006,(xx+.44,yy+.42),(.15,.065),.016,'Ink',.001)
            box('Deck / inset handle',(xx+.44,yy+.42,.005),(.11,.018,.006),'Steel',.005)
# Quiet framed ceiling panels, restrained side pipes.
for yy in [-1.15,.30,1.75,3.20,4.5]:
    panel('Ceiling / removable panel','z',2.679,(0,yy),(2.7,1.3),'Porcelain',.02,.045)
for xx in [-2.19,2.18]:
    for j,(r,ma) in enumerate([(.038,'Blue'),(.027,'Rust'),(.018,'Steel')]):
        tube('Services / longitudinal conduit',[(xx+j*.085,-1.96,2.56),(xx+j*.085,4.97,2.56)],r,ma)
    for yy in [-1.55,.3,2.0,3.65,4.9]:
        box('Services / pipe saddle',(xx+.075,yy,2.56),(.30,.055,.12),'Sand',.015)
# Ceiling practicals.
for yy in [-.9,2.0,4.4]:
    box('Light / ceiling bezel',(.2,yy,2.665),(.70,.28,.045),'Sand',.025)
    box('Light / warm diffuser',(.2,yy,2.633),(.58,.19,.015),'Light',.008)
# Back wall around rounded door; real walkable corridor beyond.
for name,loc,dim in [('left',(-1.47,5.23,1.3),(1.96,.16,2.8)),('right',(1.92,5.23,1.3),(1.10,.16,2.8)),('header',(.42,5.23,2.53),(1.9,.16,.48))]:box('Bulkhead / '+name,loc,dim,'Ivory',.025);col('Bulkhead '+name,loc,dim)
frame('Passage / blue surround','y',5.15,(.42,1.18),(1.89,2.46),(1.58,2.24),.28,'Blue',.16)
frame('Passage / pressure flange','y',5.025,(.42,1.18),(1.73,2.34),(1.52,2.17),.23,'Porcelain',.08)
# Corridor wall/floor/ceiling, capped at the far end; no fake gameplay doorway.
box('Passage / floor',(.42,6.68,-.10),(1.80,2.9,.2),'Floor',.015);col('Passage floor',(.42,6.68,-.10),(1.80,2.9,.2))
for xx in [-.52,1.36]:
    box('Passage / side wall',(xx,6.72,1.2),(.15,3.0,2.55),'Ivory',.02);col('Passage wall',(xx,6.72,1.2),(.15,3.,2.55))
    for yy in [5.9,6.7,7.5]:
        panel('Passage / locker','x',xx+(.09 if xx<0 else -.09),(yy,1.35),(.64,1.52),'Sand',.035,.045)
box('Passage / end wall',(.42,8.2,1.2),(2.0,.16,2.6),'Ivory',.02);col('Passage end',(.42,8.2,1.2),(2.,.16,2.6))
box('Passage / ceiling',(.42,6.70,2.49),(2.,3.,.14),'Sand',.02)
for yy in [6.0,7.3]:
    panel('Passage / floor mat','z',.015,(.42,yy),(1.3,.97),'Rust',.016,.03)
    box('Passage / ceiling glow',(.42,yy,2.40),(.55,.21,.025),'Light',.01)
frame('Passage / end door frame','y',8.08,(.42,1.18),(1.47,2.32),(1.23,2.09),.21,'Blue',.07)
panel('Passage / sealed door','y',8.08,(.42,1.18),(1.21,2.08),'Sand',.06,.07)
# Bunk housing along the port wall, open niche in the upper half.
box('Bunk / base cabinet',(-1.82,3.10,.39),(1.22,2.55,.78),'Ivory',.09);col('Bunk',(-1.78,3.10,.83),(1.33,2.64,1.66))
for yy in [2.45,3.72]:
    panel('Bunk / drawer','x',-1.189,(yy,.39),(1.19,.57),'Porcelain',.035,.07)
    handle('Bunk / drawer pull','x',-1.16,yy,.56,.22)
box('Bunk / foot enclosure',(-1.83,1.77,1.52),(1.15,.11,1.47),'Ivory',.045)
frame('Bunk / rounded niche face','x',-1.185,(3.11,1.53),(2.80,1.60),(2.55,1.38),.22,'Ivory',.12)
box('Bunk / overhead lockers',(-1.82,3.11,2.44),(1.21,2.52,.44),'Ivory',.055)
for yy in [2.32,3.13,3.95]:
    panel('Bunk / overhead door','x',-1.191,(yy,2.43),(.78,.39),'Porcelain',.028,.04)
    handle('Bunk / upper latch','x',-1.171,yy,2.32,.09)

# Mattress and shaped fabrics: explicitly authored curved, wrinkled surfaces.
box('Bunk / mattress',(-1.81,3.11,.89),(1.12,2.46,.24),'WhiteCloth',.10)
outline('Bunk / mattress piping','x',-1.238,(3.11,.91),(2.37,.12),.04,'Sand',.003)
def cloth(name,ymin,ymax,material,zbase,drop,phase):
    nu,nv=46,72;verts=[]
    for j in range(nv+1):
        t=j/nv;y=ymin+(ymax-ymin)*t
        for i in range(nu+1):
            s=i/nu
            if s<.80:
                x=-2.37+(1.22)*(s/.80);z=zbase+.025*sin(pi*s/.8)
            else:
                a=(s-.8)/.2*pi/2;x=-1.15+.07*sin(a);z=zbase-drop*(1-cos(a))
            # Folds radiate along the edge; restrained top undulation.
            fold=(.007+.018*max(0,s-.5)*2)*sin(t*39+phase+s*5+sin(t*13)*1.5)+.0025*sin(t*83+s*19)
            z+=fold+.007*sin(t*17+s*14)*sin(pi*t)
            x+=.006*sin(t*39+phase)*max(0,(s-.7)/.3)
            if material=='Blue':x+=.045
            verts.append((x,y,z))
    faces=[]
    for j in range(nv):
        for i in range(nu):a=j*(nu+1)+i;faces.append((a,a+1,a+nu+2,a+nu+1))
    o=mesh(name,verts,faces,material,True)
    sol=o.modifiers.new('Fabric thickness','SOLIDIFY');sol.thickness=.006
    line(name+' / stitched edge',[verts[j*(nu+1)+nu] for j in range(nv+1)],'BlueDark' if material=='Blue' else 'Sand',.0015)
    for j in [8,23,41,58]:
        pts=[verts[j*(nu+1)+i] for i in range(32,47)]
        pts=[(x+.001,y,z+.002) for x,y,z in pts]
        line(name+' / drawn fold',pts,'BlueDark' if material=='Blue' else 'Sand',.001)
    return o
cloth('Bedding / ivory cover',1.9,4.25,'WhiteCloth',1.035,.26,1)
cloth('Bedding / blue wool throw',1.93,3.34,'Blue',1.09,.44,1)
# Pillow is a pinched rectangular cushion, not a cube.
def pillow(name,center,size,material):
    nx,ny=28,20;verts=[]
    for side in [-1,1]:
        for j in range(ny+1):
            t=j/ny
            for i in range(nx+1):
                s=i/nx;u=(s-.5)*size[0];v=(t-.5)*size[1]
                bulge=(sin(pi*s)*sin(pi*t))**.48
                z=side*(.018+size[2]*.5*bulge)+.002*sin(s*40+t*20)*(1-bulge)
                verts.append((center[0]+u,center[1]+v,center[2]+z))
    faces=[];n=(nx+1)*(ny+1)
    for side in range(2):
        for j in range(ny):
            for i in range(nx):a=side*n+j*(nx+1)+i;face=(a,a+1,a+nx+2,a+nx+1);faces.append(face if side else face[::-1])
    # Stitch perimeter.
    per=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,ny+1)]+[ny*(nx+1)+i for i in range(nx-1,-1,-1)]+[j*(nx+1) for j in range(ny-1,0,-1)]
    for i,a in enumerate(per):b=per[(i+1)%len(per)];faces.append((a,b,b+n,a+n))
    mesh(name,verts,faces,material,True)
    line(name+' / seam',[(verts[i][0],verts[i][1],center[2]) for i in per],'Sand',.0012,True)
pillow('Bedding / full pillow',(-1.80,3.93,1.10),(1.02,.57,.20),'WhiteCloth')
# Shelving within the bunk and purposeful, sparse personal objects.
box('Bunk / inset shelf',(-2.19,3.22,1.91),(.42,2.15,.045),'Ivory',.022)
tube('Bunk / shelf retaining lip',[(-1.963,2.14,1.96),(-1.963,4.25,1.96)],.011,'Sand')
for j in range(5):
    o=box('Books / clothbound',(-2.12,2.36+j*.065,2.035),(.16,.052,.23),['BlueDark','Book','Rust','Sand','Blue'][j],.004)
    outline('Book / spine rule','x',-2.036,(2.36+j*.065,2.035),(.043,.20),.002,'Ink',.0008)
box('Bunk / personal case',(-2.14,3.04,2.012),(.28,.48,.16),'Rust',.025)
outline('Case / lid','x',-1.995,(3.04,2.043),(.43,.028),.009,'Ink',.001)
tube('Case / handle',[(-2.15,2.97,2.094),(-2.15,2.97,2.125),(-2.15,3.12,2.125),(-2.15,3.12,2.094)],.007,'Rubber')
# Reading lamp: articulated metal and directional diffuser.
cyl('Reading lamp / wall disk',(-2.32,4.12,1.66),.075,.035,'Steel',(1,0,0))
tube('Reading lamp / elbow',[(-2.29,4.12,1.66),(-2.11,4.12,1.66),(-1.99,4.07,1.57)],.021,'BlueDark')
bpy.ops.mesh.primitive_cone_add(vertices=32,radius1=.095,radius2=.042,depth=.125,location=(-1.98,4.07,1.54));own(bpy.context.object,'Reading lamp / shade','Steel')
cyl('Reading lamp / lit face',(-1.98,4.07,1.475),.086,.003,'Light')
# Jacket on a hook, shaped hanging torso and two relaxed sleeves.
tube('Coat / hook',[(-2.3,4.79,1.94),(-2.17,4.79,1.94),(-2.15,4.79,2.0)],.009,'Steel')
verts=[];faces=[];nj,ni=26,20
for j in range(nj+1):
    t=j/nj;z=1.97-t*.91;width=.20+(.06*sin(pi*t))
    for i in range(ni+1):
        a=2*pi*i/ni;y=4.79+width*cos(a);x=-2.24+.085*sin(a)+.016*sin(t*25+a*3)
        verts.append((x,y,z+.022*cos(a*4)*(t**4)))
for j in range(nj):
    for i in range(ni):a=j*(ni+1)+i;faces.append((a,a+1,a+ni+2,a+ni+1))
mesh('Coat / hanging cloth',verts,faces,'Rust',True)
for side in [-1,1]:
    points=[(-2.20,4.79+side*.20,1.85),(-2.14,4.79+side*.31,1.64),(-2.10,4.79+side*.30,1.36),(-2.09,4.79+side*.28,1.17)]
    tube('Coat / relaxed sleeve',points,.07,'Rust')
    line('Coat / sleeve crease',[(x+.07,y,z) for x,y,z in points],'WarmShadow',.002)
line('Coat / central zip',[(-2.137,4.79,1.83),(-2.133,4.79,1.12)],'Ink',.002)
for o in COL.objects:
    if o.name.startswith('Coat /'):o.location.x+=1.02
# Desk and terminal at the window.
box('Desk / worktop',(-1.75,.04,.775),(1.24,1.79,.065),'Porcelain',.045);col('Desk',(-1.77,.04,.41),(1.24,1.80,.82))
outline('Desk / laminate edge','z',.812,(-1.75,.04),(1.22,1.76),.06,'Ink',.0015)
for yy in [-.73,.72]:
    box('Desk / side support',(-1.95,yy,.39),(.68,.08,.73),'Ivory',.025)
box('Desk / drawer pod',(-1.99,.29,.56),(.60,.68,.34),'Ivory',.03)
panel('Desk / drawer front','x',-1.674,(.29,.56),(.62,.28),'Porcelain',.03,.025);handle('Desk / drawer','x',-1.65,.29,.61,.18)
# CRT faces +X, angled modestly into room, using own geometrical picture.
box('CRT / stand',(-1.93,-.46,.87),(.34,.29,.11),'Steel',.025)
box('CRT / deep cabinet',(-2.01,-.46,1.15),(.46,.55,.55),'Ivory',.055)
frame('CRT / bezel','x',-1.759,(-.46,1.17),(.53,.52),(.424,.395),.065,'Porcelain',.055)
panel('CRT / phosphor face','x',-1.721,(-.46,1.18),(.416,.386),'CRT',.013,.03,False)
for i in range(25):line('CRT / fine scan', [(-1.711,-.652,1.006+i*.014),(-1.711,-.268,1.006+i*.014)],'BlueDark',.00055)
sphere('CRT / planet glyph',(-1.706,-.465,1.18),(.003,.074,.074),'Phosphor',40,20)
line('CRT / orbital ellipse',[(-1.70,-.465+.127*cos(i*2*pi/64),1.18+.021*sin(i*2*pi/64)+.027*cos(i*2*pi/64)) for i in range(64)],'Phosphor',.0016,True)
for yy in [-.64,-.59]:cyl('CRT / adjustment knob',(-1.702,yy,.954),.017,.016,'Steel',(1,0,0),20)
box('Keyboard / tray',(-1.37,-.41,.836),(.32,.51,.027),'Sand',.012)
for row in range(5):
    for key in range(12):
        box('Keyboard / key',(-1.485+row*.049,-.625+key*.039,.861),(.038,.031,.018),'Ivory',.004)
box('Keyboard / space',(-1.25,-.41,.861),(.035,.20,.020),'Ivory',.005)
# Printer to the desk rear; paper is a simple newly modeled sheet.
box('Printer / body',(-1.96,.32,.942),(.40,.33,.26),'Ivory',.04)
box('Printer / exit slot',(-1.744,.32,1.015),(.012,.19,.024),'Ink',.006)
verts=[(-2.08,.235,1.082),(-2.08,.405,1.082),(-2.08,.405,1.255),(-2.08,.235,1.255),(-1.985,.235,1.31),(-1.985,.405,1.31),(-1.91,.235,1.28),(-1.91,.405,1.28)]
mesh('Printer / paper curl',verts,[(0,1,2,3),(3,2,5,4),(4,5,7,6)],'Paper')
for j in range(3):
    box('Tape / cassette',(-1.64+j*.018,.67,.842+j*.035),(.20,.13,.031),['BlueDark','Rust','Sand'][j],.005)
# Mug has actual open inner wall and curved handle.
def mug(name,center,color='Rust',r=.048,h=.12):
    x,y,z=center;n=40;verts=[]
    for rad,zz in [(r,z),(r,z+h),(r-.006,z+h),(r-.006,z+.009)]:verts +=[(x+rad*cos(i*2*pi/n),y+rad*sin(i*2*pi/n),zz) for i in range(n)]
    faces=[]
    for k in range(3):
        for i in range(n):a=k*n+i;b=k*n+(i+1)%n;faces.append((a,b,b+n,a+n))
    faces +=[tuple(range(3*n,4*n))]
    mesh(name,verts,faces,color,True)
    line(name+' / rim',[(x+r*cos(i*2*pi/n),y+r*sin(i*2*pi/n),z+h) for i in range(n)],'WarmShadow',.0012,True)
    tube(name+' / handle',[(x+r+.032*cos(-pi/2+i*pi/20),y,z+h*.52+.044*sin(-pi/2+i*pi/20)) for i in range(21)],.009,color)
mug('Desk / ceramic mug',(-1.38,.45,.810))
# Chair with separate bent tubular frame, padded seat/back and five-star base.
cx,cy=-.72,-.04
cyl('Chair / column',(cx,cy,.28),.034,.42,'Steel')
for i in range(5):
    a=i*2*pi/5;ex=cx+.32*cos(a);ey=cy+.32*sin(a)
    tube('Chair / base spoke',[(cx,cy,.14),(ex,ey,.08)],.018,'Steel');sphere('Chair / foot',(ex,ey,.055),(.045,.038,.031),'Rubber')
box('Chair / seat pan',(cx,cy,.46),(.51,.50,.08),'Steel',.045)
pillow('Chair / upholstered seat',(cx,cy,.515),(.48,.48,.12),'Blue')
# Back faces away from the terminal towards +X.
box('Chair / back frame',(cx+.265,cy,.85),(.07,.49,.66),'Steel',.032)
box('Chair / back upholstery',(cx+.222,cy,.86),(.075,.44,.58),'Blue',.035)
outline('Chair / upholstery seam','x',cx+.175,(cy,.86),(.398,.53),.06,'BlueDark',.0014)
for sy in [-.20,.20]:tube('Chair / bent back support',[(cx+.1,cy+sy,.43),(cx+.31,cy+sy,.5),(cx+.31,cy+sy,1.1)],.014,'Steel')
col('Chair',(cx,cy,.58),(.62,.61,1.16))
# Starboard dining, anchored bench and single rounded table.
box('Dining / base',(2.07,.0,.23),(.59,1.89,.46),'Ivory',.05)
box('Dining / seat',(1.98,.0,.50),(.69,1.82,.13),'Rust',.065)
box('Dining / back',(2.34,.0,.88),(.17,1.85,.73),'Rust',.07)
for yy in [-.59,.0,.59]:outline('Dining / cushion seam','x',2.245,(yy,.88),(.56,.61),.045,'WarmShadow',.001)
col('Dining bench',(2.10,0,.56),(.73,1.9,1.12))
box('Dining / table',(1.49,.04,.79),(1.31,1.20,.065),'Porcelain',.06)
outline('Dining / laminate outline','z',.824,(1.49,.04),(1.28,1.17),.075,'Ink',.0015)
# Visible hinge and diagonal support of static fold-down furniture.
for yy in [-.40,.48]:
    cyl('Dining / hinge',(2.16,yy,.80),.024,.13,'Steel',(0,1,0));tube('Dining / folding brace',[(2.31,yy,.36),(1.16,yy,.75)],.020,'Steel')
col('Dining table',(1.49,.04,.43),(1.31,1.20,.86))
mug('Dining / ivory mug',(1.40,.15,.826),'Porcelain',.047,.115)
for j in range(2):box('Dining / books',(1.59,-.36,.845+j*.04),(.22,.30,.034),['Book','BlueDark'][j],.005)
# Galley: low cabinetry, a visibly recessed sink, oven, cupboards.
box('Galley / lower carcass',(2.00,3.13,.43),(.79,2.90,.86),'Ivory',.06);col('Galley counter',(1.97,3.12,.49),(.9,2.97,.98))
# Countertop with real rectangular cutout; basin depth visible.
box('Galley / forward counter',(1.94,2.14,.91),(.92,.94,.065),'Porcelain',.025)
box('Galley / aft counter',(1.94,3.99,.91),(.92,1.04,.065),'Porcelain',.025)
box('Galley / sink front lip',(1.56,3.08,.91),(.17,.94,.065),'Porcelain',.018)
box('Galley / sink back lip',(2.31,3.08,.91),(.19,.94,.065),'Porcelain',.018)
box('Sink / basin',(1.94,3.08,.73),(.57,.79,.04),'BlueDark',.08)
for xx in [1.665,2.215]:box('Sink / side',(xx,3.08,.818),(.035,.79,.17),'Steel',.012)
for yy in [2.70,3.46]:box('Sink / end',(1.94,yy,.818),(.57,.035,.17),'Steel',.012)
outline('Sink / rim','z',.949,(1.94,3.08),(.58,.80),.09,'Ink',.0016)
cyl('Sink / drain',(1.94,3.08,.756),.036,.003,'Steel')
# Gooseneck faucet, continuous swept path.
points=[(2.25,3.27,.946),(2.25,3.27,1.12)]
points +=[(2.25-.12*(1-cos(a)),3.27,1.12+.12*sin(a)) for a in [i*pi/20 for i in range(21)]]
points +=[(2.01,3.27,1.07)]
tube('Sink / faucet',points,.014,'Steel')
cyl('Sink / tap base',(2.25,3.27,.95),.036,.023,'Steel')
tube('Sink / handle',[(2.24,3.39,.96),(2.24,3.39,1.02),(2.24,3.45,1.04)],.010,'Steel')
for yy in [2.01,2.95,4.07]:
    panel('Galley / cabinet front','x',1.577,(yy,.44),(.84,.70),'Porcelain',.035,.05)
    handle('Galley / latch','x',1.545,yy,.66,.13)
# Oven front projects into aisle, has glass and tactile controls.
panel('Oven / outer fascia','x',1.54,(2.00,.52),(.73,.61),'Steel',.055,.06)
panel('Oven / dark gasket','x',1.50,(2.00,.43),(.64,.38),'Rubber',.018,.04)
panel('Oven / window','x',1.485,(2.00,.43),(.55,.29),'BlueDark',.008,.03)
tube('Oven / handle',[(1.495,1.73,.64),(1.44,1.73,.64),(1.44,2.27,.64),(1.495,2.27,.64)],.014,'Steel')
for yy in [1.79,2.21]:cyl('Oven / knob',(1.494,yy,.74),.031,.025,'Rubber',(1,0,0))
for j in range(4):line('Oven / vent',[(1.489,1.72,.245+j*.018),(1.489,2.28,.245+j*.018)],'Ink',.002)
# Small stovetop over oven, two restrained burner rings.
for yy in [1.96,2.32]:
    cyl('Hob / plate',(1.93,yy,.953),.145,.010,'Steel')
    for r in [.07,.115]:line('Hob / coil',[(1.93+r*cos(i*2*pi/48),yy+r*sin(i*2*pi/48),.961) for i in range(48)],'Ink',.002,True)
# Kettle turned profile with spout, lid and handle.
def lathe(name,center,profile,material,n=40):
    verts=[]
    for r,z in profile:verts +=[(center[0]+r*cos(i*2*pi/n),center[1]+r*sin(i*2*pi/n),center[2]+z) for i in range(n)]
    faces=[]
    for j in range(len(profile)-1):
        for i in range(n):a=j*n+i;b=j*n+(i+1)%n;faces.append((a,b,b+n,a+n))
    return mesh(name,verts,faces,material,True)
lathe('Kettle / body',(1.93,2.32,.965),[(.07,0),(.085,.02),(.086,.16),(.07,.19),(.02,.20),(0,.20)],'Steel')
tube('Kettle / handle',[(1.93,2.38,1.14),(1.93,2.40,1.24),(1.93,2.26,1.25),(1.93,2.24,1.14)],.014,'Rubber')
tube('Kettle / spout',[(1.87,2.30,1.025),(1.78,2.30,1.10),(1.77,2.30,1.14)],.019,'Steel')
# Upper glass/cup cabinet and service cupboard.
for yy in [2.0,3.02,4.07]:
    box('Galley / upper cabinet',(2.16,yy,2.10),(.50,.96,.70),'Ivory',.04)
    if yy==3.02:
        panel('Galley / open cup recess','x',1.896,(yy,2.10),(.83,.57),'WarmShadow',.014,.04)
        for zz in [1.87,2.10]:
            box('Galley / cup shelf',(1.93,yy,zz),(.26,.81,.028),'Ivory',.008)
            for j in range(3):mug('Cup / stored',(1.91,yy-.26+j*.24,zz+.02),'Porcelain',.042,.105)
        frame('Galley / open cupboard frame','x',1.856,(yy,2.10),(.91,.65),(.83,.57),.07,'Porcelain',.03)
    else:
        panel('Galley / upper enamel door','x',1.879,(yy,2.10),(.91,.64),'Blue' if yy==4.07 else 'Porcelain',.03,.04)
        handle('Galley / upper pull','x',1.853,yy,1.85,.14)
box('Galley / under cabinet lamp',(2.04,3.08,1.715),(.31,2.68,.025),'Light',.012)
# Cold locker at aft right, slightly taller and curved corners.
box('Cold locker / body',(2.08,4.75,1.07),(.64,.68,2.13),'Ivory',.095)
for zz,hh in [(.55,.98),(1.56,.96)]:
    panel('Cold locker / door','x',1.73,(4.75,zz),(.61,hh),'Porcelain',.055,.06)
    handle('Cold locker / recessed handle','x',1.695,4.60,zz+.25,.08)
col('Cold locker',(2.08,4.75,1.07),(.64,.68,2.13))
# Water filter with tube and tumbler; no textual labeling.
lathe('Water / filter',(2.20,3.87,.946),[(.06,0),(.07,.03),(.07,.29),(.06,.31),(0,.31)],'Sand')
tube('Water / outlet',[(2.20,3.80,1.02),(2.12,3.75,1.02),(2.12,3.75,.99)],.009,'Steel')
# Pot and restrained plant, each leaf sculpted as a folded pointed surface.
lathe('Plant / pot',(2.12,4.30,.946),[(.065,0),(.085,.16),(.09,.17),(.076,.17),(.071,.04)],'Rust')
cyl('Plant / soil',(2.12,4.30,1.09),.071,.01,'WarmShadow')
for i in range(13):
    a=i*2.399;start=Vector((2.12,4.30,1.10));end=start+Vector((.19*cos(a),.19*sin(a),.16+.12*(i%3)/3))
    tube('Plant / stem',[start,end],.0025,'Leaf')
    mid=start.lerp(end,.70);cross=Vector((-sin(a),cos(a),0))*.055
    mesh('Plant / pointed leaf',[tuple(start.lerp(end,.46)),tuple(mid+cross),tuple(end),tuple(mid-cross),tuple(mid+Vector((0,0,.022)))],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],'LeafLight' if i%3==0 else 'Leaf')
    line('Plant / vein',[start.lerp(end,.46),mid+Vector((0,0,.022)),end],'Leaf',.0008)
# Forward wall is also furnished so the reverse view remains considered.
for xx in [-1.65,-.75,.15]:
    panel('Forward / storage panel','y',-1.995,(xx,1.77),(.77,1.36),'Porcelain',.04,.05)
    # y-facing handles are built directly on the room side.
    box('Forward / locker pull',(xx+.22,-1.953,1.71),(.035,.035,.16),'Steel',.01)
    outline('Forward / locker ink','y',-1.953,(xx,1.77),(.73,1.31),.05,'Ink',.001)
box('Forward / utility chest',(.80,-1.67,.32),(1.08,.63,.62),'Blue',.055);col('Utility chest',(.8,-1.67,.32),(1.08,.63,.62))
outline('Forward / chest lid','z',.638,(.8,-1.67),(1.03,.58),.045,'Ink',.0014)
# Simple tactile distribution panel by passage: selective hardware, no labels.
panel('Services / cassette module','y',5.095,(-.98,1.55),(.49,.71),'Blue',.055,.04)
for i in range(3):
    panel('Services / cartridge','y',5.054,(-.98,1.32+i*.20),(.39,.16),'Porcelain',.022,.02)
    box('Services / cartridge grip',(-.98,5.025,1.31+i*.20),(.17,.025,.04),'Steel',.007)
# A small framed landscape, freshly modelled color shapes rather than copied art.
panel('Bunk / postcard frame','x',-2.383,(3.68,2.055),(.28,.19),'Sand',.02,.01)
panel('Bunk / postcard sky','x',-2.37,(3.68,2.055),(.255,.167),'Blue',.006,.004,False)
mesh('Bunk / postcard ridge',[(-2.361,3.56,1.98),(-2.361,3.79,1.98),(-2.361,3.79,2.018),(-2.361,3.73,2.025),(-2.361,3.70,2.102),(-2.361,3.65,2.028),(-2.361,3.59,2.049)],[(0,1,2,3,4,5,6)],'Book')
# Sparse panel fixings and short seam marks, rather than surface-wide dirt noise.
for yy in [1.80,4.43]:
    for zz in [.16,.76,2.04,2.55]:bolt('Bunk / flush fastener','x',-1.105,yy,zz,.009)
for yy in [-1.1,.2,1.4,2.6,3.8,4.9]:
    for xx in [-1.35,1.35]:bolt('Ceiling / captive fastener','z',2.660,xx,yy,.008)
# Flush hinge plates, recessed latches and sparse repair marks; no text labels.
for yy in [2.01,2.95,4.07]:
    for zz in [.21,.67]:
        panel('Galley / hinge plate','x',1.542,(yy-.34,zz),(.052,.095),'Steel',.012,.01)
        bolt('Galley / hinge rivet','x',1.530,yy-.34,zz-.028,.004)
    line('Galley / lower reveal',[(1.532,yy-.32,.139),(1.532,yy+.32,.139)],'Ink',.0012)
for yy in [2.,4.07]:
    for zz in [1.90,2.29]:
        panel('Galley / cupboard hinge','x',1.852,(yy-.37,zz),(.045,.075),'Steel',.012,.008)
for yy in [2.32,3.13,3.95]:
    for zz in [2.30,2.56]:
        panel('Bunk / cupboard hinge','x',-1.164,(yy-.32,zz),(.038,.065),'Steel',.009,.006)
for yy in [2.45,3.72]:
    for zz in [.17,.61]:
        for yoff in [-.50,.50]:bolt('Bunk / drawer screw','x',-1.161,yy+yoff,zz,.005)
# Shoulder strap on the bag, ventilation strips and a few enamel edge chips.
box('Bunk / travel bag',(-1.84,3.36,2.687),(.43,.77,.25),'BlueDark',.09)
for yy in [3.12,3.61]:
    tube('Bunk / bag strap',[(-2.08,yy,2.69),(-2.08,yy,2.79),(-1.65,yy,2.79),(-1.61,yy,2.69)],.014,'Sand')
for yy in [1.55,4.83]:
    panel('Services / flush inspection plate','x',-2.369,(yy,1.25),(.16,.32),'Sand',.018,.015)
    for j in range(5):line('Services / breather slot',[(-2.356,yy-.05,1.18+j*.03),(-2.356,yy+.05,1.18+j*.03)],'Ink',.0013)
for j in range(42):
    yy=rng.uniform(1.86,4.33);zz=rng.choice([.115,.685,2.255,2.615]);length=rng.uniform(.005,.02)
    line('Enamel / sparse edge chip',[(-1.069,yy,zz),(-1.069,yy+length,zz+.001)],'WarmShadow',.001)

for o in COL.objects:
    if o.name.startswith(('CRT /','Keyboard /')):o.location.y+=.89
    elif o.name.startswith('Printer /'):o.location.y-=.72
    elif o.name.startswith('Tape /'):o.location.y-=1.25
    elif o.name.startswith('Desk / ceramic mug'):o.location.y-=.62
# Export only authored geometry. Render camera/lights stay editable in .blend.
for o in list(COL.objects):
    if o.type=='CURVE':
        bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o.select_set(False)
# Apply modifiers before aggregating spatial room groups by material; fewer draw calls.
for o in list(COL.objects):
    if o.type!='MESH':continue
    bpy.context.view_layer.objects.active=o
    for mod in list(o.modifiers):
        try:bpy.ops.object.modifier_apply(modifier=mod.name)
        except RuntimeError:pass
# Keep editable source individual objects. Export joins a separate duplicate scene.
cam_data=bpy.data.cameras.new('Concept match / 28mm');cam=bpy.data.objects.new('Camera / concept match',cam_data);scene.collection.objects.link(cam)
cam.location=(1.0,-1.0,1.62);target=Vector((-1.30,3.0,1.25));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=23;scene.camera=cam
world=bpy.data.worlds.new('Cool cabin ambient');scene.world=world;world.use_nodes=True
world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.34,.46,.65,1);world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.30
ld=bpy.data.lights.new('Window daylight','AREA');lo=bpy.data.objects.new('Window daylight',ld);scene.collection.objects.link(lo);lo.location=(-2.18,.1,2.10);lo.rotation_euler=Vector((1,.65,-.50)).to_track_quat('-Z','Y').to_euler();ld.energy=180;ld.shape='RECTANGLE';ld.size=2.;ld.size_y=1.2
for loc,energy,color in [((-.4,1.2,2.52),80,(1,.86,.63)),((-1.98,4.07,1.48),8,(1,.76,.39)),((1.75,3.1,1.60),16,(1,.86,.63))]:
    ld=bpy.data.lights.new('Practical warm light','AREA');lo=bpy.data.objects.new('Practical warm light',ld);scene.collection.objects.link(lo);lo.location=loc;ld.energy=energy;ld.color=color;ld.size=.55
scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=1400;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard'
for area in bpy.context.screen.areas if bpy.context.screen else []:
    if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.clip_end=300
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art'/'illustrated_hab.blend'))
# Duplicate mesh objects for an optimized exported scene. Originals remain in blend.
bpy.ops.object.select_all(action='DESELECT')
originals=[o for o in COL.objects if o.type=='MESH'];copies=[]
for original in originals:
    c=original.copy();c.data=original.data.copy();scene.collection.objects.link(c);copies.append(c)
# Group by two-metre length band and material. This preserves culling and crisp normals.
groups={}
for o in copies:
    center=o.matrix_world @ sum((Vector(v) for v in o.bound_box),Vector())/8
    matname=o.data.materials[0].name;key=(int(center.y//2),matname);groups.setdefault(key,[]).append(o)
for (band,matname),obs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();obs[0].name=f'Room_{band}_{matname}'
bpy.ops.object.select_all(action='DESELECT')
for o in scene.objects:
    if o.name.startswith('Room_'):o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets'/'hab.glb'),export_format='GLB',use_selection=True,export_yup=True,export_extras=True,export_cameras=False,export_lights=False)
(ROOT/'assets'/'collision.json').write_text(json.dumps(collision,indent=2))
(ROOT/'art'/'build_report.json').write_text(json.dumps({'original_mesh_objects':len(originals),'export_meshes':len(groups),'colliders':len(collision),'fresh_source':True},indent=2))
print('HAB BUILD FINISHED',len(originals),'authored parts;',len(groups),'export batches')
