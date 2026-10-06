"""Export evaluated meshes in Godot coordinates, preserving editable Blender originals."""
import bpy, os, json, math
from mathutils import Vector
OUT=os.path.dirname(os.path.abspath(__file__))
source_scene=bpy.data.scenes['LONGHAUL • Complete assembly']
bpy.context.window.scene=source_scene
source_scene.frame_set(1)
interior=bpy.data.collections['INTERIOR | rooms and fitted equipment']
exterior=bpy.data.collections['EXTERIOR | fitted v3 shell']
stats=[]
for name,collections in [('longhaul_interior',[interior]),('longhaul_complete',[interior,exterior])]:
    bpy.context.window.scene=source_scene
    source_scene.frame_set(1)
    deps=bpy.context.evaluated_depsgraph_get()
    source=set(ob for col in collections for ob in col.all_objects if ob.type in {'MESH','FONT','EMPTY'})
    temporary=bpy.data.scenes.new('TEMP_'+name)
    mapping={};triangles=0
    for ob in source:
        if ob.type in {'MESH','FONT'}:
            mesh=bpy.data.meshes.new_from_object(ob.evaluated_get(deps),depsgraph=deps)
            cp=bpy.data.objects.new(ob.name,mesh)
            for k in ob.keys():cp[k]=ob[k]
            mesh.calc_loop_triangles();triangles+=len(mesh.loop_triangles)
            assert all(math.isfinite(n) for v in mesh.vertices for n in v.co),ob.name
        else:
            cp=ob.copy()
        cp.matrix_basis=ob.matrix_basis.copy()
        cp.matrix_parent_inverse=ob.matrix_parent_inverse.copy()
        if ob.animation_data and ob.animation_data.action:
            cp.animation_data_create();cp.animation_data.action=ob.animation_data.action
        temporary.collection.objects.link(cp);mapping[ob]=cp
    root=bpy.data.objects.new('LONGHAUL_GODOT',None);temporary.collection.objects.link(root);root.location.z=-1.4
    for ob,cp in mapping.items():
        cp.parent=mapping.get(ob.parent,root)
        if ob.parent not in mapping:cp.matrix_basis=ob.matrix_world.copy()
    bpy.context.window.scene=temporary
    temporary.frame_start=1;temporary.frame_end=100;temporary.render.fps=24
    for ob in temporary.objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=root
    import io_scene_gltf2
    assert 'GLB' in [i[0] for i in io_scene_gltf2.get_format_items(None,bpy.context)]
    path=os.path.join(OUT,'exports',name+'.glb')
    bpy.ops.export_scene.gltf(filepath=path,export_format='GLB',use_selection=True,use_active_scene=True,export_animations=True,export_cameras=False,export_lights=False,export_yup=True,export_extras=True)
    stats.append({'asset':name,'objects':len(mapping),'triangles':triangles,'bytes':os.path.getsize(path)})
    bpy.context.window.scene=source_scene
    for ob in list(temporary.objects):bpy.data.objects.remove(ob,do_unlink=True)
    bpy.data.scenes.remove(temporary)
with open(os.path.join(OUT,'asset_stats.json'),'w') as f:json.dump(stats,f,indent=2)
s=bpy.data.scenes['LONGHAUL • Interior tour'];bpy.context.window.scene=s;s.frame_set(1);s.camera=bpy.data.objects['01 • Cockpit']
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'longhaul_full_ship.blend'))
print(json.dumps(stats))
