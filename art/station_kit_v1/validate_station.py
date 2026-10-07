"""Spatial asset checks in Blender; not a replacement for Godot playtesting."""
import bpy, json, math, os
from mathutils import Vector
from mathutils.bvhtree import BVHTree
OUT=os.path.dirname(os.path.abspath(__file__))
scene=bpy.data.scenes['02 • HANGAR / interior walkthrough']
bpy.context.window.scene=scene;scene.frame_set(80);bpy.context.view_layer.update()
kit=bpy.data.collections['HANGAR • reusable module']
ship=bpy.data.collections['REFERENCE • existing playable Longhaul']
checks=[]
def check(condition,name,details=None):
    checks.append({'check':name,'passed':bool(condition),'details':details})
    print(('PASS' if condition else 'FAIL'),name,details or '',flush=True)
def meshes(objects):
    deps=bpy.context.evaluated_depsgraph_get();verts=[];faces=[];owners=[]
    for o in objects:
        if o.type!='MESH' or o.hide_render:continue
        ev=o.evaluated_get(deps);me=ev.to_mesh();me.calc_loop_triangles();start=len(verts)
        verts.extend(ev.matrix_world@v.co for v in me.vertices)
        for t in me.loop_triangles:faces.append(tuple(start+i for i in t.vertices));owners.append(o.name)
        ev.to_mesh_clear()
    return verts,faces,owners
verts,faces,owners=meshes(kit.all_objects)
check(all(math.isfinite(a) for v in verts for a in v),'Finite hangar geometry')
substrate=[o for o in kit.all_objects if 'Deck substrate' in o.name]
plates=[o for o in kit.all_objects if 'Deck plates' in o.name]
substrate_top=max((o.matrix_world@v.co).z for o in substrate for v in o.data.vertices)
plate_top=min(max((o.matrix_world@v.co).z for v in o.data.vertices) for o in plates)
check(plate_top>substrate_top+.02,'Gray deck plates remain above structural substrate',{'plate_top_m':plate_top,'substrate_top_m':substrate_top})
tree=BVHTree.FromPolygons(verts,faces,all_triangles=True)
def cube(lo,hi):
    a,b,c=lo;x,y,z=hi
    v=[(a,b,c),(x,b,c),(x,y,c),(a,y,c),(a,b,z),(x,b,z),(x,y,z),(a,y,z)]
    f=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    return BVHTree.FromPolygons(v,f)
def clear(lo,hi,name):
    hits=tree.overlap(cube(lo,hi));names=sorted(set(owners[a] for a,b in hits))
    check(not names,name,names)
clear((-8.99,-35.70,.17),(8.99,-32.70,9.0),'Open doorway clear: 18 m wide and 9 m high above sill')
clear((-5.49,-36,2.0),(5.49,14.85,7.72),'Straight-in swept ship envelope at 2 m hover clearance')
clear((-5.49,-11.8,.03),(5.49,14.85,7.72),'Final vertical landing envelope clear')
for side,kind in [(-1,'pickup'),(1,'delivery')]:
    for row in range(4):
        for col in range(3):
            x=side*(5.35+col*2.6);y=-(21.05+row*2.55)
            clear((x-.90,y-.90,.03),(x+.90,y+.90,1.35),f'{kind} grid {row*3+col+1:02d} free of fixed equipment')
def path(points,name):
    minimum=999;bad=None
    for a,b in zip(points,points[1:]):
        a,b=Vector(a),Vector(b)
        for i in range(31):
            p=a.lerp(b,i/30)
            for z in [.39,.925,1.46]:
                v=Vector((p.x,p.y,z));loc,n,idx,d=tree.find_nearest(v)
                if d<minimum:minimum=d;bad=owners[idx]
    check(minimum>=.35,name,{'radius_clearance_m':round(minimum,4),'nearest':bad})
path([(0,-16.8,0),(0,-31,0)],'1.8 m person / central cargo walkway')
path([(0,-18.7,0),(9.9,-18.7,0),(9.9,-7.5,0)],'1.8 m person / ramp to every service terminal')
for side in [-1,1]:
    path([(0,-19.7,0),(side*10.55,-19.7,0)],'1.8 m person / front access to cargo side '+str(side))
    for row in range(3):
        y=-(21.05+row*2.55+1.275)
        path([(0,y,0),(side*10.55,y,0)],'1.8 m person / cargo row access '+str((side,row)))
# Verify moving leaves do not overlap each other or the stationary pocket.
roots=[o for o in kit.all_objects if o.get('binding')=='hangar_door_leaf']
check(len(roots)==4,'Four independent pressure-door leaves')
def descendant(o,root):
    while o:
        if o==root:return True
        o=o.parent
    return False
statics=[o for o in kit.all_objects if not any(descendant(o,r) for r in roots)]
sv,sf,so=meshes(statics);st=BVHTree.FromPolygons(sv,sf,all_triangles=True)
for frame in [1,40,80]:
    scene.frame_set(frame);bpy.context.view_layer.update();leafdata=[]
    for root in roots:
        v,f,on=meshes([o for o in kit.all_objects if descendant(o,root)])
        t=BVHTree.FromPolygons(v,f,all_triangles=True);leafdata.append(t)
        hits=st.overlap(t)
        check(not hits,f'{root.name} pocket clearance frame {frame}',sorted(set(so[a] for a,b in hits)))
    check(not any(a.overlap(b) for i,a in enumerate(leafdata) for b in leafdata[i+1:]),f'Door leaves mutually separated frame {frame}')
v,f,o=meshes(ship.all_objects)
lo=[min(p[i] for p in v) for i in range(3)];hi=[max(p[i] for p in v) for i in range(3)]
check(abs(lo[2])<.002,'Existing Longhaul landing feet meet hangar floor',lo[2])
check(hi[0]-lo[0]<18 and hi[2]-lo[2]+2<9,'Ship fits entrance at 2 m hover',{'min':lo,'max':hi})
instances=[o for o in bpy.data.collections['STATION • industrial keel'].objects if o.instance_collection==kit]
check(len(instances)==2,'Both station bays instance the same hangar collection')
check(len([o for o in bpy.data.collections['INTEGRATION • markers and clearance volumes'].objects if o.get('binding')=='pickup_grid'])==12,'Twelve pickup grid bindings')
check(len([o for o in bpy.data.collections['INTEGRATION • markers and clearance volumes'].objects if o.get('binding')=='delivery_grid'])==12,'Twelve delivery grid bindings')
report={'scope':'Blender mesh/clearance checks only; live Godot collisions, screen binding, cargo/flight/survival interactions remain to be integrated and tested.','checks':checks,'passed':sum(c['passed'] for c in checks),'total':len(checks),'hangar_evaluated_triangles':len(faces),'ship_bounds_m':{'min':lo,'max':hi}}
with open(os.path.join(OUT,'validation.json'),'w') as out:json.dump(report,out,indent=2)
print('VALIDATION_COMPLETE',report['passed'],'/',report['total'],flush=True)
if report['passed']!=report['total']:raise RuntimeError('Station asset clearance validation failed; inspect validation.json')
