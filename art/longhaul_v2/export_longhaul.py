"""Export a separate evaluated copy; keep original Blender labels and modifiers editable."""
import bpy, os, json, math
from mathutils import Vector

OUT=os.path.dirname(os.path.abspath(__file__))
original=bpy.context.window.scene
original.frame_set(1)
source=bpy.data.collections['LONGHAUL | authored exterior']
deps=bpy.context.evaluated_depsgraph_get()
temporary=bpy.data.scenes.new('TEMP_Longhaul_export')
mapping={}
triangles=0
points=[]
for ob in source.objects:
    copy=ob.copy() if ob.type!='FONT' else bpy.data.objects.new(ob.name, None)
    if ob.type in {'MESH','FONT'}:
        evaluated_mesh=bpy.data.meshes.new_from_object(ob.evaluated_get(deps),depsgraph=deps)
        if ob.type=='FONT':
            bpy.data.objects.remove(copy)
            copy=bpy.data.objects.new(ob.name,evaluated_mesh)
            copy.matrix_basis=ob.matrix_basis.copy()
        else:copy.data=evaluated_mesh
        copy.modifiers.clear()
        copy.data.calc_loop_triangles()
        triangles+=len(copy.data.loop_triangles)
        for v in copy.data.vertices:
            if not all(math.isfinite(n) for n in v.co):raise RuntimeError('Nonfinite vertex: '+ob.name)
        points.extend([ob.matrix_world@Vector(c) for c in ob.bound_box])
    mapping[ob]=copy
    temporary.collection.objects.link(copy)
for original_ob,copy in mapping.items():
    copy.parent=mapping.get(original_ob.parent)
root=mapping[bpy.data.objects['LONGHAUL_K01']]
root.location.z=-1.4
bpy.context.window.scene=temporary
temporary.frame_start=1;temporary.frame_end=80;temporary.render.fps=24
for ob in temporary.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=root
props=bpy.ops.export_scene.gltf.get_rna_type().properties
formats=[item.identifier for item in props['export_format'].enum_items]
if not formats:
    import io_scene_gltf2
    formats=[item[0] for item in io_scene_gltf2.get_format_items(None,bpy.context)]
assert 'GLB' in formats
file=os.path.join(OUT,'longhaul_v2.glb')
bpy.ops.export_scene.gltf(filepath=file,export_format='GLB',use_selection=True,use_active_scene=True,export_animations=True,export_cameras=False,export_lights=False,export_yup=True)
stats={'mesh_triangles':triangles,'objects':len(mapping),'blender_bounds_m':{'min':[round(min(v[i] for v in points),3) for i in range(3)],'max':[round(max(v[i] for v in points),3) for i in range(3)]},'export':os.path.basename(file),'game_alignment':'GLB is Y-up, nose -Z. Root shifted down 1.4m to match existing Godot deck origin.','animation':'Cargo_Ramp_Open, frames 1 closed to 80 lowered, 24fps.','scope':'Exterior study only; no collision shapes, working interior, or gameplay integration.'}
with open(os.path.join(OUT,'asset_stats.json'),'w') as f:json.dump(stats,f,indent=2)
bpy.context.window.scene=original
for ob in list(temporary.objects):bpy.data.objects.remove(ob,do_unlink=True)
bpy.data.scenes.remove(temporary)
original.camera=bpy.data.objects['CAM 01 • Forward three-quarter']
original.frame_set(1)
original.render.filepath=os.path.join(OUT,'renders','01-forward.png')
for a in bpy.context.screen.areas:
    if a.type=='VIEW_3D':
        space=a.spaces.active
        space.region_3d.view_perspective='CAMERA'
        space.shading.type='MATERIAL'
        space.overlay.show_overlays=False
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'longhaul_v2.blend'))
print(json.dumps(stats))
