"""Production geometry: omit runtime text, indicators, printer and demo animations."""
import bpy, bmesh, json, os, math, contextlib, struct
OUT=os.path.dirname(os.path.abspath(__file__))
PROJECT=os.path.dirname(os.path.dirname(OUT))
D=json.load(open(os.path.join(OUT,'source/interior_layout.json')))
live=json.load(open(os.path.join(OUT,'source/live_visuals.json')))
def signature(p,s):return tuple(round(float(x),4) for x in p+s)
live_keys={signature(r['position'],r['size']) for r in live}
records={r['source_path']:r for r in D['meshes']}
excluded={r['source_path'] for r in D['meshes'] if r['type']=='box' and signature(r['transform'][3],r['size']) in live_keys}
interior=bpy.data.collections['INTERIOR | rooms and fitted equipment']
exterior=bpy.data.collections['EXTERIOR | fitted v3 shell']
interior_objects=set(interior.all_objects)
mover_names={r['name'] for r in D['pivots']}
# Remove exterior surfaces inside the approved room envelopes. Polygon clipping
# avoids Boolean failures on overlapping disconnected decorative box components.
from mathutils import Vector
voids=[((-1.70,8.95,-.02),(1.70,13.69,2.42)),
       ((-2.075,3.95,-.02),(2.075,9.04,2.42)),
       ((-2.81,.95,-.02),(2.81,4.04,2.42)),
       ((-3.025,-7.05,-.02),(3.025,1.04,2.82)),
       ((-3.025,-11.25,-.02),(3.025,-6.95,2.82))]
def half(poly,axis,bound,greater):
    out=[]
    for a,b in zip(poly,poly[1:]+poly[:1]):
        da=(a[axis]-bound)*(1 if greater else -1);db=(b[axis]-bound)*(1 if greater else -1)
        if da>=-1e-7:out.append(a)
        if (da>1e-7 and db< -1e-7) or (da< -1e-7 and db>1e-7):out.append(a+(b-a)*(da/(da-db)))
    return out
def subtract_box(poly,lo,hi):
    if any(max(v[i] for v in poly)<lo[i] or min(v[i] for v in poly)>hi[i] for i in range(3)):return [poly]
    output=[];remaining=poly
    for axis,bound,greater in [(i,lo[i],True) for i in range(3)]+[(i,hi[i],False) for i in range(3)]:
        outside=half(remaining,axis,bound,not greater)
        if len(outside)>=3:output.append(outside)
        remaining=half(remaining,axis,bound,greater)
        if len(remaining)<3:break
    return output

def clear_room_surfaces(mesh,world):
    vertices=[];faces=[];material_indices=[];inverse=world.inverted()
    for face in mesh.polygons:
        pieces=[[world@mesh.vertices[i].co for i in face.vertices]]
        for lo,hi in voids:pieces=[part for p in pieces for part in subtract_box(p,lo,hi)]
        for p in pieces:
            if len(p)<3:continue
            start=len(vertices);vertices.extend([inverse@v for v in p]);faces.append(tuple(range(start,start+len(p))));material_indices.append(face.material_index)
    result=bpy.data.meshes.new(mesh.name+'_room_clearance');result.from_pydata(vertices,[],faces);result.update()
    for mat in mesh.materials:result.materials.append(mat)
    for face,index in zip(result.polygons,material_indices):face.material_index=index
    return result
original=bpy.context.window.scene
source=bpy.data.scenes['LONGHAUL • Complete assembly'];bpy.context.window.scene=source;source.frame_set(1)
tmp=bpy.data.scenes.new('TEMP_Playable_Longhaul');mapping={};triangles=0;removed=0
for ob in list(interior.all_objects)+list(exterior.all_objects):
    if ob.type not in {'EMPTY','MESH','FONT'}:continue
    if ob.type=='FONT' and ob in interior_objects:continue
    ancestor=ob;skip=False
    while ancestor:
        if '10 Cargo ramp' in ancestor.name:skip=True
        ancestor=ancestor.parent
    if skip:continue
    cp=ob.copy();cp.animation_data_clear()
    if ob.type=='MESH':
        cp.data=ob.data.copy()
        paths=str(ob.get('source_paths','')).splitlines()
        indices=[];offset=0
        for path in paths:
            r=records[path];count=8 if r['type']=='box' else len(r['vertices'])
            if path in excluded:indices.extend(range(offset,offset+count));removed+=1
            offset+=count
        if indices:
            assert offset==len(cp.data.vertices),(ob.name,offset,len(cp.data.vertices))
            bm=bmesh.new();bm.from_mesh(cp.data);bm.verts.ensure_lookup_table()
            bmesh.ops.delete(bm,geom=[bm.verts[i] for i in indices],context='VERTS');bm.to_mesh(cp.data);bm.free()
        if not cp.data.polygons:
            bpy.data.objects.remove(cp);continue
    if ob.name in mover_names:cp['game_mover']=ob.name
    tmp.collection.objects.link(cp);mapping[ob]=cp
root=bpy.data.objects.new('LONGHAUL_GAME',None);tmp.collection.objects.link(root);root.location.z=-1.4
for ob,cp in mapping.items():
    cp.parent=mapping.get(ob.parent,root)
    cp.matrix_parent_inverse=ob.matrix_parent_inverse.copy()
    cp.matrix_basis=ob.matrix_basis.copy() if ob.parent in mapping else ob.matrix_world.copy()
bpy.context.window.scene=tmp;tmp.frame_set(1)
deps=bpy.context.evaluated_depsgraph_get()
for cp in list(tmp.objects):
    if cp.type not in {'MESH','FONT'}:continue
    mesh=bpy.data.meshes.new_from_object(cp.evaluated_get(deps),depsgraph=deps)
    if cp.type=='MESH' and cp.name.startswith('Exterior /'):mesh=clear_room_surfaces(mesh,cp.matrix_world)
    mesh.calc_loop_triangles();triangles+=len(mesh.loop_triangles)
    assert all(math.isfinite(x) for v in mesh.vertices for x in v.co)
    if cp.type=='FONT':
        new=bpy.data.objects.new(cp.name,mesh);tmp.collection.objects.link(new);new.parent=cp.parent;new.matrix_parent_inverse=cp.matrix_parent_inverse.copy();new.matrix_basis=cp.matrix_basis.copy();bpy.data.objects.remove(cp,do_unlink=True)
    else:cp.data=mesh;cp.modifiers.clear()
for ob in tmp.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=root
import io_scene_gltf2
assert 'GLB' in [i[0] for i in io_scene_gltf2.get_format_items(None,bpy.context)]
path=os.path.join(PROJECT,'assets/ships/longhaul/longhaul_playable.glb')
with open('/tmp/longhaul-production-export.log','w') as log,contextlib.redirect_stdout(log):
    bpy.ops.export_scene.gltf(filepath=path,export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_extras=True,export_cameras=False,export_lights=False,export_yup=True)
# glTF cannot translate a pure Transparent BSDF; express glazing as standard alpha.
transparent_names={m.name for m in bpy.data.materials if m.use_nodes and any(n.type=='BSDF_TRANSPARENT' for n in m.node_tree.nodes)}
raw=open(path,'rb').read();json_size=struct.unpack_from('<I',raw,12)[0]
gltf=json.loads(raw[20:20+json_size]);binary_chunks=raw[20+json_size:]
for material in gltf['materials']:
    if material.get('name') in transparent_names:
        material['alphaMode']='BLEND';material['doubleSided']=True
        material['pbrMetallicRoughness']={'baseColorFactor':[.12,.20,.24,.055],'metallicFactor':0,'roughnessFactor':.2}
encoded=json.dumps(gltf,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
with open(path,'wb') as f:f.write(struct.pack('<III',0x46546C67,2,20+len(encoded)+len(binary_chunks))+struct.pack('<II',len(encoded),0x4E4F534A)+encoded+binary_chunks)
stats={'triangles':triangles,'objects':len(tmp.objects),'runtime_surfaces_removed':removed,'bytes':os.path.getsize(path),'animations':0}
json.dump(stats,open(os.path.join(OUT,'playable_stats.json'),'w'),indent=2)
bpy.context.window.scene=original
for ob in list(tmp.objects):bpy.data.objects.remove(ob,do_unlink=True)
bpy.data.scenes.remove(tmp)
print(json.dumps(stats))
