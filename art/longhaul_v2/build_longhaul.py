"""Longhaul exterior design study. Run through Blender MCP or Blender's Python editor.
Creates a separate scene; never removes the user's other scenes or game assets.
Blender X=Godot X, Blender Y=-Godot Z, Blender Z=Godot Y+1.4m.
"""
import bpy, math, os
from mathutils import Vector, Matrix
from collections import defaultdict

OUT = os.path.dirname(os.path.abspath(__file__))
SCENE_NAME = 'LONGHAUL • Exterior study'
if SCENE_NAME in bpy.data.scenes:
    raise RuntimeError('Design scene already exists; edit it rather than rebuilding over it.')
scene = bpy.data.scenes.new(SCENE_NAME)
bpy.context.window.scene = scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
ship_col = bpy.data.collections.new('LONGHAUL | authored exterior')
scene.collection.children.link(ship_col)
stage_col = bpy.data.collections.new('PRESENTATION | excluded from export')
scene.collection.children.link(stage_col)
root = bpy.data.objects.new('LONGHAUL_K01', None)
ship_col.objects.link(root)
root['design'] = 'Cassette futurism / voxel-derived hard-surface exterior'
root['game_alignment'] = 'Blender X=Godot X; Y=-Godot Z; Z=Godot Y+1.4. Subtract 1.4 from imported Godot Y.'
root['scope'] = 'Exterior review asset. Existing game interiors and flight systems are unchanged.'
groups = {}
def group(name, loc=(0,0,0)):
    o=bpy.data.objects.new(name,None);ship_col.objects.link(o);o.parent=root;o.location=loc;groups[name]=o
    return name
for name in ['01 Flight deck','02 Living hab','03 Service and airlock','04 Cargo shell','05 Engineering','06 Engines','07 Underframe','08 Landing gear','09 Markings']:
    group(name)
group('10 Cargo ramp',(0,-11.42,1.43))

def linear(v): return v/12.92 if v<=0.04045 else ((v+0.055)/1.055)**2.4
def material(name,h,metal=0,rough=.65,emit=0):
    rgb=[linear(int(h[i:i+2],16)/255) for i in (0,2,4)]
    m=bpy.data.materials.new(name);m.diffuse_color=(*rgb,1);m.use_nodes=True
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*rgb,1)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    if emit:
        p.inputs['Emission Color'].default_value=(*rgb,1);p.inputs['Emission Strength'].default_value=emit
    return m
M={
 'ivory':material('Hull • warm ivory','b4ab91',.12),
 'light':material('Replacement panels • pale cream','d4c7a7',.12),
 'shade':material('Aged panels • olive grey','8f8d78',.18),
 'orange':material('Safety enamel • burnt orange','a95e2b',.15),
 'dark':material('Frame • charcoal green','292e2a',.35),
 'black':material('Gaskets and cavities','121b1d',.1),
 'metal':material('Hardware • brushed steel','676e6b',.65,.43),
 'gold':material('Fuel lines • ochre','af833a',.45),
 'glass':material('Cockpit • smoked blue glass','24434b',.65,.24),
 'window':material('Hab • warm glass','866c40',.25,.4),
 'amber':material('Work lights • amber','ffe0a0',.05,.38,3),
 'green':material('Status • phosphor green','9bdfa6',.1,.4,2),
 'red':material('Port navigation • red','e77449',.1,.4,2),
 'white':material('Stencil • warm white','ece0be'),
}
buf=defaultdict(lambda:[[],[]])
def poly(name,mat,verts,faces):
    vs,fs=buf[(name,mat)];offset=len(vs);vs.extend([tuple(v) for v in verts]);fs.extend([tuple(offset+i for i in f) for f in faces])
def box(name,mat,p,s,rot=None):
    verts=[Vector((a*s[0]/2,b*s[1]/2,c*s[2]/2)) for a,b,c in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    if rot:
        from mathutils import Euler
        R=Euler(rot).to_matrix();verts=[R@v for v in verts]
    verts=[v+Vector(p) for v in verts]
    poly(name,mat,verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
def beam(name,mat,a,b,w,d=None):
    a,b=Vector(a),Vector(b);v=b-a;R=v.to_track_quat('Z','Y').to_matrix()
    verts=[R@Vector((x*w/2,y*(d or w)/2,z*v.length/2))+(a+b)/2 for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    poly(name,mat,verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
def cylinder(name,mat,p,r,depth,axis=(0,0,1),n=12,r2=None):
    R=Vector(axis).to_track_quat('Z','Y').to_matrix();verts=[]
    for z,rad in [(-depth/2,r),(depth/2,r if r2 is None else r2)]:
        verts += [R@Vector((rad*math.cos(2*math.pi*i/n),rad*math.sin(2*math.pi*i/n),z))+Vector(p) for i in range(n)]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    poly(name,mat,verts,faces)
def ring(name,mat,p,outer,inner,depth,axis=(0,0,1),n=12):
    R=Vector(axis).to_track_quat('Z','Y').to_matrix();verts=[]
    for z,r in [(-depth/2,outer),(depth/2,outer),(-depth/2,inner),(depth/2,inner)]:
        verts += [R@Vector((r*math.cos(2*math.pi*i/n),r*math.sin(2*math.pi*i/n),z))+Vector(p) for i in range(n)]
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces.extend([(i,j,j+n,i+n),(i+2*n,i+3*n,j+3*n,j+2*n),(i,i+2*n,j+2*n,j),(i+n,j+n,j+3*n,i+3*n)])
    poly(name,mat,verts,faces)
def section(w,lo,hi,c=.25):
    return [(-w/2+c,lo), (w/2-c,lo),(w/2,lo+c),(w/2,hi-c),(w/2-c,hi),(-w/2+c,hi),(-w/2,hi-c),(-w/2,lo+c)]
def hull(name,mat,stations):
    verts=[(x,y,z) for y,points in stations for x,z in points];n=len(stations[0][1]);faces=[tuple(reversed(range(n))),tuple(range((len(stations)-1)*n,len(stations)*n))]
    for k in range(len(stations)-1):
        for i in range(n):j=(i+1)%n;faces.append((k*n+i,k*n+j,(k+1)*n+j,(k+1)*n+i))
    # Ring order is clockwise when viewed from +Y; reverse for outward shell normals.
    poly(name,mat,verts,[tuple(reversed(f)) for f in faces])
def plate(name,mat,points,normal,thickness=.045):
    n=Vector(normal).normalized()*thickness/2;v=[Vector(p)-n for p in points]+[Vector(p)+n for p in points];k=len(points)
    f=[tuple(reversed(range(k))),tuple(range(k,2*k))]+[(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)]
    poly(name,mat,v,f)
def text(body,p,size=.23,mat='dark',side='right',name='09 Markings'):
    c=bpy.data.curves.new(body,'FONT');c.body=body;c.size=size;c.extrude=.001;c.space_character=1.12
    o=bpy.data.objects.new(body,c);ship_col.objects.link(o);o.parent=groups[name];o.location=p
    # Text local +Z points out of surface, local +X follows horizontal reading.
    if side=='right':o.rotation_euler=(math.pi/2,0,math.pi/2)
    elif side=='left':o.rotation_euler=(math.pi/2,0,-math.pi/2)
    elif side=='rear':o.rotation_euler=(math.pi/2,0,0)
    elif side=='front':o.rotation_euler=(math.pi/2,0,math.pi)
    c.materials.append(M[mat]);return o
def bolts(name,x,ys,zs):
    for y in ys:
        for z in zs:box(name,'dark',(x,y,z),(.038,.085,.085))
def vent(name,side,y,z,w=1.2,h=.6):
    x=side
    box(name,'dark',(x,y,z),(.09,w,h))
    for i in range(4):box(name,'metal',(x+math.copysign(.052,x),y,z-h/2+.11+i*(h-.2)/3),(.045,w-.14,.047))

# Cockpit: stepped nose and deliberately small inset glazing, not a glass canopy.
g='01 Flight deck'
hull(g,'ivory',[(9.0,section(4.5,1.45,4.5)),(12.55,section(4.5,1.45,4.5)),(14.6,section(3.5,1.55,2.5,.18))])
# Windshield strip lies on the nose slope; frames are independent slabs.
for x in [-1.28,0,1.28]:
    pts=[(x-.55,13.98,3.06),(x+.55,13.98,3.06),(x+.55,12.88,4.13),(x-.55,12.88,4.13)]
    plate(g,'dark',pts,(0,1,1),.10)
    pts=[(x-.44,13.88,3.18),(x+.44,13.88,3.18),(x+.44,13.02,4.02),(x-.44,13.02,4.02)]
    plate(g,'glass',pts,(0,1,1),.14)
    beam(g,'metal',(x-.43,13.86,3.2),(x+.43,13.86,3.2),.045)
    beam(g,'dark',(x-.35,13.82,3.28),(x+.16,13.42,3.69),.035)
for s in [-1,1]:
    # Small side panes in real rectangular frame assemblies.
    box(g,'dark',(s*2.265,11.8,3.6),(.09,1.12,.93))
    box(g,'glass',(s*2.32,11.8,3.6),(.035,.94,.74))
    box(g,'orange',(s*2.27,10.2,2.9),(.075,.78,2.12))
    box(g,'light',(s*2.27,11.83,2.39),(.065,1.08,.75))
    bolts(g,s*2.318,[11.38,12.28],[2.09,2.69])
    vent(g,s*2.29,10.15,1.97,.55,.33)
    box(g,'dark',(s*1.37,14.65,1.94),(.63,.12,.27))
    box(g,'amber',(s*1.37,14.725,1.96),(.44,.028,.10))
    for y in [10.6,11.0]:
        cylinder(g,'dark',(s*2.3,y,2.9),.14,.13,(s,0,0),8)
    text('K-01',(s*2.325,11.35 if s>0 else 12.25,2.65),.21,'dark','right' if s>0 else 'left')
box(g,'orange',(0,14.63,2.11),(1.8,.06,.52))
text('LONGHAUL',(1.0,14.676,2.05),.22,'dark','front')
box(g,'dark',(0,10.4,4.49),(2.7,1.05,.17))
for x in [-.95,-.48,0,.48,.95]:box(g,'shade',(x,10.4,4.60),(.3,.83,.09))

# Hab: wider shoulder, bolted access plates and blind-covered little windows.
g='02 Living hab'
hull(g,'dark',[(4.1,section(5.84,1.3,4.82,.3)),(8.97,section(5.84,1.3,4.82,.3))])
for s in [-1,1]:
    for j,y in enumerate([4.95,6.5,8.1]):
        box(g,'light' if j==1 else 'ivory',(s*2.947,y,3.07),(.10,1.45,2.82))
        bolts(g,s*3.01,[y-.59,y+.59],[1.91,4.2])
    box(g,'orange',(s*3.01,8.27,3.08),(.038,.65,2.68))
    for y in [5.4,7.0]:
        box(g,'dark',(s*3.018,y,3.57),(.10,.67,.81))
        box(g,'window',(s*3.08,y,3.57),(.035,.49,.62))
        for dz in [.20,.26]:box(g,'shade',(s*3.105,y,3.57+dz),(.025,.49,.035))
    vent(g,s*3.03,6.37,2.13,1.02,.50)
    text('02 / HAB',(s*3.015,4.42 if s>0 else 5.52,2.61),.19,'dark','right' if s>0 else 'left')
    beam(g,'metal',(s*2.80,4.47,4.72),(s*2.80,8.5,4.72),.07)
for y in [4.92,6.49,8.06]:box(g,'ivory',(0,y,4.84),(4.95,1.46,.10))
box(g,'dark',(0,6.7,4.94),(2,1.42,.12))
for y in [6.16+i*.15 for i in range(8)]:box(g,'shade',(0,y,5.03),(1.8,.07,.10))
cylinder(g,'dark',(0,8.38,5.0),.4,.12,n=8)
cylinder(g,'ivory',(0,8.38,5.19),.29,.32,n=8,r2=.16)
beam(g,'metal',(.8,7.9,4.89),(.8,7.9,5.66),.035)
box(g,'orange',(.8,7.9,5.67),(.07,.07,.15))

# Service module with a port maintenance panel and starboard docking/airlock collar.
g='03 Service and airlock'
hull(g,'shade',[(.95,section(6.25,1.25,4.74)),(4.06,section(6.0,1.3,4.74))])
for s in [-1,1]:
    box(g,'ivory',(s*3.15,2.55,3.01),(.12,2.55,2.58))
    ring(g,'dark',(s*3.26,2.57,2.93),1.08,.77,.30,(s,0,0),12)
    ring(g,'metal',(s*3.44,2.57,2.93),.99,.78,.12,(s,0,0),12)
    cylinder(g,'shade',(s*3.40,2.57,2.93),.77,.11,(s,0,0),12)
    box(g,'dark',(s*3.48,2.57,2.93),(.04,.045,1.37))
    for a in range(0,360,60):
        a=math.radians(a);box(g,'orange',(s*3.535,2.57+.90*math.cos(a),2.93+.9*math.sin(a)),(.1,.16,.18))
    box(g,'dark',(s*3.52,2.86,2.91),(.08,.18,.36))
    box(g,'green',(s*3.57,2.86,3.02),(.02,.1,.06))
    text('AIRLOCK' if s>0 else 'SERVICE',(s*3.23,1.8 if s>0 else 3.32,4.23),.18,'dark','right' if s>0 else 'left')
box(g,'ivory',(0,2.56,4.76),(5.6,2.68,.13))
for x in [-1.55,1.55]:
    box(g,'dark',(x,2.65,4.91),(1.12,1.65,.16))
    box(g,'orange',(x,2.65,5.01),(.95,1.5,.05))

# Cargo hold: four wall cassettes, seams and real clamp hardware.
g='04 Cargo shell'
box(g,'dark',(0,-3.0,1.40),(6.5,8.15,.28))
box(g,'dark',(0,-3.0,4.70),(6.5,8.15,.22))
for s in [-1,1]:
    box(g,'dark',(s*3.18,-3.0,3.05),(.23,8.15,3.26))
    for j in range(4):
        y=-6.05+j*2.0
        box(g,'light' if j==2 else 'ivory',(s*3.315,y,3.15),(.12,1.83,2.63))
        box(g,'orange',(s*3.385,y,2.07),(.025,1.83,.40))
        for yy in [y-.75,y+.75]:
            box(g,'shade',(s*3.39,yy,3.2),(.055,.045,2.23))
        bolts(g,s*3.39,[y-.66,y+.66],[2.37,4.22])
        box(g,'dark',(s*3.4,y-.5,2.66),(.045,.22,.10))
        box(g,'metal',(s*3.44,y-.5,2.66),(.02,.13,.033))
        text('%02d'%(j+1),(s*3.405,y+.48 if s>0 else y-.48,3.97),.19,'shade','right' if s>0 else 'left')
    for y in [-7.03,-5.04,-3.04,-1.04,1.02]:
        box(g,'dark',(s*3.41,y,3.08),(.16,.14,3.18))
        for z in [1.87,4.22]:
            box(g,'metal',(s*3.50,y,z),(.11,.28,.30))
            box(g,'dark',(s*3.57,y,z),(.04,.12,.13))
    box(g,'dark',(s*3.40,-4.05,3.32),(.048,1.68,.48))
    text('LONGHAUL',(s*3.43,-4.81 if s>0 else -3.29,3.23),.233,'white','right' if s>0 else 'left')
    text('K-01 / FREIGHT',(s*3.42,-4.75 if s>0 else -3.35,2.90),.139,'dark','right' if s>0 else 'left')
for y in [-6.05,-4.05,-2.05,-.05]:
    for x in [-1.57,1.57]:
        box(g,'ivory',(x,y,4.86),(2.94,1.82,.15))
        box(g,'shade',(x,y+.64,4.96),(1.55,.05,.03))
    box(g,'dark',(0,y,4.965),(.13,1.86,.12))
for y in [-7.03,-5.04,-3.04,-1.04,1.02]:box(g,'dark',(0,y,4.94),(6.47,.12,.12))

# Engineering has an actual hollow aft vestibule instead of a solid blocking box.
g='05 Engineering'
box(g,'dark',(0,-9.22,1.40),(6.48,4.35,.28))
box(g,'ivory',(0,-9.22,4.68),(6.48,4.35,.24))
for s in [-1,1]:
    box(g,'ivory',(s*3.14,-9.22,3.02),(.26,4.35,3.1))
    box(g,'dark',(s*2.76,-9.43,2.40),(.48,3.37,1.74))
    for y in [-10.4,-9.3,-8.2]:
        box(g,'shade',(s*2.48,y,2.75),(.12,.95,.98))
        box(g,'orange',(s*2.40,y,3.1),(.035,.72,.09))
    box(g,'orange',(s*3.295,-10.58,3.05),(.055,.62,2.85))
    # Doorway side jambs leave 2.8m passage.
    box(g,'ivory',(s*2.31,-11.4,3.07),(1.74,.24,3.14))
    box(g,'dark',(s*1.46,-11.57,2.85),(.18,.14,2.56))
    box(g,'orange',(s*1.61,-11.57,2.83),(.14,.16,2.6))
    box(g,'amber',(s*1.42,-11.64,3.5),(.045,.04,.57))
    vent(g,s*3.34,-8.42,3.59,1.7,.73)
box(g,'ivory',(0,-11.42,4.37),(2.94,.24,.51))
text('07 / CARGO ACCESS',(-1.24,-11.56,4.23),.18,'dark','rear')
# Inner bulkhead has a clear central doorway.
for s in [-1,1]:box(g,'shade',(s*2.1,-7.1,3.03),(1.25,.17,2.96))
box(g,'shade',(0,-7.1,4.25),(3,.17,.52))
for y in [-10.5,-9.45,-8.4]:
    box(g,'shade',(0,y,1.568),(2.7,.98,.045))
    for x in [-1.13,1.13]:box(g,'gold',(x,y,1.60),(.06,.94,.02))
    box(g,'dark',(0,y,4.49),(1.1,.36,.1))
    box(g,'amber',(0,y,4.425),(.88,.22,.025))
# Rooftop folded radiator banks.
for x in [-1.76,1.76]:
    box(g,'dark',(x,-9.15,4.93),(2.1,3.37,.22))
    for j in range(13):box(g,'metal',(x,-10.62+j*.244,5.06),(1.87,.075,.07))
    box(g,'orange',(x,-10.88,5.02),(1.85,.17,.16))

# Four squat octagonal engine pods with recessed nozzle interiors and service cartridges.
g='06 Engines'
for s in [-1,1]:
    for k,z in enumerate([1.64,3.69]):
        x=s*4.31
        box(g,'dark',(s*3.63,-9.04,z),(.85,2.16,.72))
        hull(g,'ivory',[(-6.93,[(a+x,b) for a,b in section(2.10,z-.93,z+.93,.3)]),(-10.86,[(a+x,b) for a,b in section(2.10,z-.93,z+.93,.3)])])
        hull(g,'orange',[(-9.64,[(a+x,b) for a,b in section(2.135,z-.95,z+.95,.3)]),(-10.28,[(a+x,b) for a,b in section(2.135,z-.95,z+.95,.3)])])
        # Front face heat exchanger, not an atmospheric intake.
        box(g,'dark',(x,-6.9,z),(1.55,.07,1.27))
        for i in range(5):box(g,'shade',(x,-6.85,z-.46+i*.23),(1.35,.07,.055))
        ring(g,'dark',(x,-11.06,z),.94,.71,.42,(0,1,0),12)
        ring(g,'metal',(x,-11.31,z),.89,.70,.14,(0,1,0),12)
        ring(g,'shade',(x,-11.39,z),.81,.70,.06,(0,1,0),12)
        cylinder(g,'black',(x,-11.04,z),.70,.02,(0,1,0),12)
        ring(g,'metal',(x,-11.08,z),.41,.33,.07,(0,1,0),12)
        cylinder(g,'black',(x,-11.13,z),.33,.06,(0,1,0),12)
        for a in range(0,360,60):
            a=math.radians(a)
            beam(g,'dark',(x+.83*math.cos(a),-10.74,z+.83*math.sin(a)),(x+.91*math.cos(a),-11.33,z+.91*math.sin(a)),.09)
        for y in [-7.6,-8.6]:
            box(g,'shade',(x+s*1.075,y,z),(.055,.63,1.2))
            box(g,'dark',(x+s*1.113,y,z+.36),(.03,.41,.11))
        text('D'+str((0 if s>0 else 2)+k+1),(x+s*1.115,-8.27 if s>0 else -7.55,z-.1),.28,'dark','right' if s>0 else 'left')
        for yy in [-7.15,-9.41,-10.58]:
            box(g,'dark',(x,yy,z+.944),(1.43,.06,.04))
        box(g,'dark',(x,-8.55,z+.99),(.66,1.13,.08))
        box(g,'orange',(x,-8.55,z+1.045),(.46,.93,.035))

# Exposed underframe: clear structural load paths, protected pipes, tank bands.
g='07 Underframe'
for s in [-1,1]:
    for z in [.86,1.36]:box(g,'dark',(s*2.56,-1.28,z),(.15,20.0,.17))
    for y in [8.3,6.4,4.5,2.6,.7,-1.2,-3.1,-5,-6.9,-8.8,-10.7]:
        if y>-10.5:beam(g,'shade',(s*2.56,y,.94),(s*2.56,y-1.65,1.30),.09)
        box(g,'metal',(s*2.56,y,1.10),(.24,.16,.55))
    for y in [-5.7,-2.0,1.25]:
        cylinder(g,'gold',(s*2.06,y,1.06),.25,2.65,(0,1,0),8)
        for dy in [-.94,.94]:ring(g,'dark',(s*2.06,y+dy,1.06),.28,.25,.13,(0,1,0),8)
    for xoff in [0,.2]:beam(g,'metal',(s*(2.82+xoff),-10.5,1.56),(s*(2.82+xoff),.55,1.56),.065)
    # Recessed RCS clusters at opposite ends of the vessel.
    for y in [12.36,-10.2]:
        x=s*(2.29 if y>0 else 3.33)
        box(g,'dark',(x,y,1.84),(.32,.68,.50))
        for dy in [-.18,.18]:
            ring(g,'metal',(x+s*.19,y+dy,1.86),.12,.072,.10,(s,0,0),8)
            cylinder(g,'black',(x+s*.17,y+dy,1.86),.074,.04,(s,0,0),8)
    box(g,'dark',(s*3.48,-5.9,1.65),(.30,.60,.19))
    box(g,'amber',(s*3.52,-5.9,1.57),(.24,.39,.032))
    box(g,'green' if s>0 else 'red',(s*3.48,.62,4.45),(.09,.2,.12))
for y in [8.2,4.4,.65,-3.1,-6.8,-10.5]:box(g,'dark',(0,y,1.06),(5.18,.15,.16))

# Six purposeful landing struts, broad feet, hinge cheeks and pistons.
g='08 Landing gear'
for s in [-1,1]:
    for y,x in [(10.2,1.52),(0,2.64),(-9.5,2.67)]:
        box(g,'dark',(s*x,y,1.31),(.72,1.0,.27))
        cylinder(g,'metal',(s*x,y,1.13),.23,.78,(1,0,0),8)
        beam(g,'shade',(s*x,y,1.12),(s*(x+.17),y+.26,.39),.31,.43)
        beam(g,'metal',(s*(x-.20),y-.18,1.06),(s*(x-.05),y+.1,.4),.11)
        box(g,'dark',(s*(x+.16),y+.2,.20),(1.08,1.54,.23))
        box(g,'shade',(s*(x+.16),y+.2,.34),(.87,1.20,.08))
        for dy in [-.4,0,.4]:box(g,'metal',(s*(x+.16),y+.2+dy,.389),(.76,.06,.035))

# Pivot-local ramp: closed at frame 1, safely lowered at frame 80.
g='10 Cargo ramp'
box(g,'dark',(0,-.02,1.50),(2.78,.20,3.0))
box(g,'shade',(0,.103,1.50),(2.47,.045,2.80))
for x in [-1.28,1.28]:box(g,'orange',(x,.14,1.5),(.11,.035,2.91))
for z in [.22+i*.27 for i in range(10)]:box(g,'metal',(0,.144,z),(2.30,.035,.045))
for x in [-1.05,1.05]:cylinder(g,'metal',(x,0,0),.15,.36,(1,0,0),8)
ramp=groups[g];ramp.rotation_euler=(0,0,0);ramp.keyframe_insert(data_path='rotation_euler',frame=1)
ramp.rotation_euler=(math.radians(115),0,0);ramp.keyframe_insert(data_path='rotation_euler',frame=80)
if ramp.animation_data and ramp.animation_data.action:ramp.animation_data.action.name='Cargo_Ramp_Open'

# Final readable hardware pass. Larger details have jobs; avoid texture-noise greebles.
g='01 Flight deck'
# Tapered shoulder bridges the narrower cockpit into the living module.
hull(g,'ivory',[(8.99,section(5.72,1.51,4.64,.27)),(9.47,section(4.54,1.51,4.48,.22))])
for s in [-1,1]:
    # Nose service cheeks follow the taper of the forward face.
    pts=[(s*2.07,12.76,2.22),(s*1.86,14.02,2.22),(s*1.86,14.02,2.62),(s*2.07,12.76,2.62)]
    plate(g,'shade',pts,(s,0,0),.038)
    # Panel seam and pull handle directly below each side window.
    box(g,'dark',(s*2.316,11.84,2.11),(.025,.69,.035))
    box(g,'metal',(s*2.335,11.84,2.53),(.04,.27,.065))
    box(g,'dark',(s*2.276,10.64,3.52),(.05,.18,.12))
    box(g,'amber',(s*2.308,10.64,3.52),(.018,.10,.058))
# Shallow nose maintenance plate follows the slope, with a visible small latch.
pts=[(-.65,14.27,2.79),(.65,14.27,2.79),(.65,14.03,3.02),(-.65,14.03,3.02)]
plate(g,'shade',pts,(0,1,1),.045)
beam(g,'dark',(-.10,14.22,2.85),(.10,14.22,2.85),.045)
g='04 Cargo shell'
for y in [-6.2,-.2]:
    for s in [-1,1]:
        # Recessed roof lifting eyes with a visibly open center.
        ring(g,'metal',(s*2.44,y,5.05),.17,.09,.08,(0,1,0),8)
        box(g,'dark',(s*2.44,y,4.99),(.42,.29,.07))
g='05 Engineering'
for s in [-1,1]:
    box(g,'dark',(s*2.25,-11.548,3.1),(.83,.05,1.64))
    box(g,'shade',(s*2.25,-11.583,3.1),(.69,.04,1.49))
    for z in [2.55,3.02,3.49]:box(g,'metal',(s*2.25,-11.616,z),(.43,.03,.045))
    box(g,'orange',(s*2.25,-11.62,3.62),(.48,.02,.10))
    box(g,'dark',(s*1.88,-11.59,1.84),(.35,.06,.17))
    box(g,'amber',(s*1.88,-11.63,1.84),(.24,.025,.08))
    text('KEEP CLEAR',(s*2.5 if s>0 else -2.75,-11.65,2.1),.11,'dark','rear')
box(g,'dark',(0,-11.59,4.05),(2.59,.14,.14))
box(g,'metal',(0,-11.68,4.05),(1.72,.08,.065))

# Convert batched authored surfaces into a small set of material meshes per subsystem.
for (name,mat),(verts,faces) in buf.items():
    mesh=bpy.data.meshes.new(name+' / '+mat);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name+' / '+mat,mesh);ship_col.objects.link(o);o.parent=groups[name];mesh.materials.append(M[mat])
    if mat not in ['glass','window','amber','green','red','black','white']:
        b=o.modifiers.new('Single-step edge highlight','BEVEL');b.width=.018;b.segments=1
        b.affect='EDGES'
        b=o.modifiers.new('Weighted face normals','WEIGHTED_NORMAL');b.keep_sharp=True;b.weight=30

# Presentation stage, cameras, and studio lighting are not part of the ship export.
def stage_obj(name,data):
    o=bpy.data.objects.new(name,data);stage_col.objects.link(o);return o
floor_mat=material('Stage • graphite','343e42',.05,.87)
mesh=bpy.data.meshes.new('Studio apron');mesh.from_pydata([(-200,-200,.075),(200,-200,.075),(200,200,.075),(-200,200,.075)],[],[(0,1,2,3)]);mesh.materials.append(floor_mat)
stage_obj('Studio apron',mesh)
def camera(name,p,target,lens=50,ortho=None):
    d=bpy.data.cameras.new(name);o=stage_obj(name,d);o.location=p;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.lens=lens;d.clip_end=500
    if ortho:d.type='ORTHO';d.ortho_scale=ortho
    return o
hero=camera('CAM 01 • Forward three-quarter',(28,35,23),(0,1.4,2.3),48)
rear=camera('CAM 02 • Loading and propulsion',(29,-33,19),(0,-.8,2.1),49)
profile=camera('CAM 03 • Side elevation',(40,0,9),(0,1.5,2.6),50,31)
def area(name,p,power,size,color,target):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=color
    o=stage_obj(name,d);o.location=p;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
area('KEY • warm softbox',(8,12,22),6000,13,(1,.88,.69),(0,0,0))
area('FILL • broad cool',(-12,4,13),4300,11,(.69,.82,1),(0,0,2))
area('RIM • aft overhead',(3,-17,18),6700,9,(.84,.9,1),(0,-5,2))
area('FRONT • soft',(18,20,9),2300,10,(1,.94,.83),(0,5,2))
area('AFT • doorway work lamp',(0,-10,4.25),110,1.2,(1,.72,.4),(0,-11.1,1.5))
world=bpy.data.worlds.new('Longhaul studio world');world.use_nodes=True
world.node_tree.nodes.get('Background').inputs[0].default_value=(.11,.14,.18,1)
world.node_tree.nodes.get('Background').inputs[1].default_value=.45;scene.world=world
scene.camera=hero;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1600;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
scene.render.fps=24;scene.frame_start=1;scene.frame_end=80;scene.frame_set(1)
scene.view_settings.view_transform='AgX';scene.view_settings.exposure=1.0
for a in bpy.context.screen.areas:
    if a.type=='VIEW_3D':
        a.spaces.active.region_3d.view_perspective='CAMERA'
        a.spaces.active.shading.type='MATERIAL'
        a.spaces.active.overlay.show_overlays=False
root.select_set(True);bpy.context.view_layer.objects.active=root
scene['review_notes']='Exterior only. Four drives, hollow aft ramp vestibule, no gameplay changes. Frame 1 ramp closed; frame 80 lowered. Z origin is hangar ground.'
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'longhaul_v2.blend'))
print('Built Longhaul:',len(ship_col.objects),'objects;',sum(len(o.data.polygons) for o in ship_col.objects if o.type=='MESH'),'base polygons')
print('Saved',bpy.data.filepath)
