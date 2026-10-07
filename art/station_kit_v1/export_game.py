"""Export the approved metric station kit without changing its .blend source.

Run in a fresh Blender background process opened on industrial_keel_and_hangar.blend.
Outputs are one playable bay, station structure without bays, and a distant shell.
"""
import bpy
import json
import math
import os
import struct
from collections import defaultdict
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(os.path.dirname(HERE))
DEST = os.path.join(PROJECT, 'assets', 'stations', 'industrial_keel')
os.makedirs(DEST, exist_ok=True)
KIT = bpy.data.collections['HANGAR • reusable module']
EXT = bpy.data.collections['STATION • industrial keel']
GUIDE = bpy.data.collections['INTEGRATION • markers and clearance volumes']
SOURCE = bpy.data.scenes.new('EXPORT_SOURCE')
for collection in (KIT, EXT, GUIDE):
    SOURCE.collection.children.link(collection)
bpy.context.window.scene = SOURCE
SOURCE.frame_set(1)
bpy.context.view_layer.update()
DEPS = bpy.context.evaluated_depsgraph_get()
CACHE = {}

def godot(p):
    return [round(float(p[0]), 6), round(float(p[2]), 6), round(float(-p[1]), 6)]

def ancestor_leaf(obj):
    cursor = obj
    while cursor:
        if cursor.name.startswith('HangarDoorLeaf_'):
            return cursor
        cursor = cursor.parent
    return None

def evaluation(obj, detailed=True):
    key = (obj.name, detailed)
    if key in CACHE:
        return CACHE[key]
    # The near asset keeps the source's small manufactured bevels. The distant
    # silhouette uses the same topology without subpixel bevel multiplication.
    if not detailed and obj.type == 'MESH':
        mesh = obj.data
        own = False
    else:
        mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(DEPS), depsgraph=DEPS)
        own = True
    matrix = obj.matrix_world
    result = (
        [tuple(matrix @ v.co) for v in mesh.vertices],
        [tuple(p.vertices) for p in mesh.polygons],
        [p.material_index for p in mesh.polygons],
        list(mesh.materials),
    )
    if own:
        bpy.data.meshes.remove(mesh)
    CACHE[key] = result
    return result

def assembly(scene, name, objects, parent=None, local_origin=(0, 0, 0), shift=(0, 0, 0), detailed=True):
    """Batch same-material static parts while keeping explicit moving assemblies."""
    verts, faces, material_indices, materials = [], [], [], []
    lookup = {}
    offset = Vector(shift) - Vector(local_origin)
    for obj in objects:
        v, f, mi, mats = evaluation(obj, detailed)
        base = len(verts)
        verts.extend(tuple(Vector(p) + offset) for p in v)
        faces.extend(tuple(base + i for i in face) for face in f)
        mapping = {}
        for i, mat in enumerate(mats):
            if mat.name not in lookup:
                lookup[mat.name] = len(materials)
                materials.append(mat)
            mapping[i] = lookup[mat.name]
        material_indices.extend(mapping[i] for i in mi)
    if not faces:
        return None
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    for mat in materials:
        mesh.materials.append(mat)
    for poly, index in zip(mesh.polygons, material_indices):
        poly.material_index = index
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = local_origin
    obj['asset_role'] = 'station_art'
    return obj

def empty(scene, name, location=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = location
    return obj

def screen_plane(scene, name, position, size, facing, material, parent):
    """Replace a glass box with a readable UV rectangle for ViewportTexture."""
    x, z, minus_y = position
    y = -minus_y
    w, h = size
    if facing == '-X':
        vertices = [(x, y+w/2, z-h/2), (x, y-w/2, z-h/2),
                    (x, y-w/2, z+h/2), (x, y+w/2, z+h/2)]
    else:  # Godot +Z is Blender -Y.
        vertices = [(x-w/2, y, z-h/2), (x+w/2, y, z-h/2),
                    (x+w/2, y, z+h/2), (x-w/2, y, z+h/2)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], [(0, 1, 2, 3)])
    mesh.materials.append(material)
    uv = mesh.uv_layers.new(name='UVMap')
    for loop, coord in zip(mesh.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
        uv.data[loop.index].uv = coord
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    obj.parent = parent
    obj['asset_role'] = 'live_display'
    return obj

def export(scene, filename):
    bpy.context.window.scene = scene
    bpy.context.view_layer.update()
    for obj in scene.objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(DEST, filename), export_format='GLB',
        use_selection=True, use_active_scene=True, export_animations=False,
        export_extras=True, export_cameras=False, export_lights=False,
        export_yup=True, export_texcoords=True, export_normals=True,
        export_materials='EXPORT', export_apply=False,
    )
    low = [math.inf] * 3
    high = [-math.inf] * 3
    triangles = 0
    meshes = 0
    for obj in scene.objects:
        if obj.type != 'MESH':
            continue
        meshes += 1
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        for vert in obj.data.vertices:
            p = godot(obj.matrix_world @ vert.co)
            assert all(math.isfinite(x) for x in p)
            for i in range(3):
                low[i] = min(low[i], p[i])
                high[i] = max(high[i], p[i])
    raw = open(os.path.join(DEST, filename), 'rb').read()
    json_size = struct.unpack_from('<I', raw, 12)[0]
    gltf = json.loads(raw[20:20 + json_size])
    assert not gltf.get('animations')
    assert not gltf.get('cameras')
    assert 'KHR_lights_punctual' not in gltf.get('extensions', {})
    return {
        'file': filename, 'bytes': len(raw), 'meshes': meshes,
        'triangles': triangles, 'nodes': len(gltf['nodes']),
        'materials': len(gltf.get('materials', [])),
        'draw_surfaces': sum(len(m['primitives']) for m in gltf.get('meshes', [])),
        'godot_bounds': {'min': low, 'max': high},
    }

screen_bindings = {}
leaf_bindings = []
H = bpy.data.scenes.new('StandardHangar')
root = empty(H, 'StandardHangar')
root['units'] = 'metres'
root['integration_offset_y'] = -1.315
root['floor_y'] = 0.0
root['nose_direction'] = '-Z'
statics, roofs = [], []
terminal_map = {'CONTRACTS': 'contracts', 'PROVISIONS': 'provisions', 'REPAIRS': 'repairs', 'REFUEL': 'refuel', 'DELIVERY': 'complete'}
for obj in list(KIT.all_objects):
    if obj.type not in {'MESH', 'FONT'} or ancestor_leaf(obj):
        continue
    collection_names = [c.name for c in obj.users_collection]
    terminal = next((c[len('Terminal / '):] for c in collection_names if c.startswith('Terminal / ')), None)
    # Keep housing labels but remove the two fake CRT lines. Runtime UI replaces them.
    if obj.type == 'FONT':
        if terminal and obj.location.x > 11.0:
            continue
        if obj.data.body in {'BERTH CONTROL', 'SEAL / DEPART'}:
            continue
    action = None
    if terminal and 'Screen surface' in obj.name:
        action = terminal_map[terminal]
        pos, size, rotation = (11.048, 1.52, -obj.data.vertices[0].co.y), [.77, .53], [0, -90, 0]
        # Geometry is batched in world coordinates in the Blender source.
        center = sum((v.co for v in obj.data.vertices), Vector()) / len(obj.data.vertices)
        pos = [11.048, 1.52, -center.y]
    elif 'Berth-control screen' in obj.name:
        action = 'depart'
        pos, size, rotation = [-3.4, 1.46, 17.997], [.72, .41], [0, 0, 0]
    if action:
        screen = screen_plane(H, 'Screen_' + action, pos, size,
                              '+Z' if action == 'depart' else '-X',
                              obj.data.materials[0], root)
        screen['binding'] = action
        screen_bindings[action] = {'node': screen.name, 'front_center': pos, 'size_m': size, 'plane_rotation_degrees': rotation}
    elif '03 Removable ceiling and overhead services' in collection_names:
        roofs.append(obj)
    else:
        statics.append(obj)
assembly(H, 'HangarStatic', statics, root)
assembly(H, 'HangarRoof', roofs, root)
for i in range(1, 5):
    old = bpy.data.objects['HangarDoorLeaf_' + str(i)]
    leaf = empty(H, 'HangarDoorLeaf_' + str(i), tuple(old.location), root)
    # Source nodes have these names too, so Blender adds .001. Name normalization
    # below restores stable runtime IDs in the GLB without touching source data.
    leaf['binding'] = 'hangar_door_leaf'
    leaf['closed_height_m'] = old['closed_height_m']
    leaf['open_height_m'] = old['open_height_m']
    children = [o for o in KIT.all_objects if o.type in {'MESH', 'FONT'} and ancestor_leaf(o) == old]
    assembly(H, 'DoorMesh_' + str(i), children, leaf, shift=tuple(-old.location))
    leaf_bindings.append({'node': 'HangarDoorLeaf_' + str(i), 'closed_position': godot(old.location), 'open_position': godot((old.location.x, old.location.y, 10.60)), 'size_m': [17.95, 2.235, .5]})
markers = empty(H, 'IntegrationMarkers', parent=root)
marker_bindings = {}
for old in list(GUIDE.objects):
    obj = empty(H, old.name, tuple(old.location), markers)
    for key in old.keys():
        obj[key] = old[key]
    marker_bindings[old.name] = {'position': godot(old.location), 'binding': old.get('binding', '')}

E = bpy.data.scenes.new('IndustrialKeelStructure')
eroot = empty(E, 'IndustrialKeelStructure')
ext_objects = [o for o in EXT.all_objects if o.type in {'MESH', 'FONT'}]
assembly(E, 'StationStructure', ext_objects, eroot)
for i, x in enumerate([-27, 27], 1):
    bay = empty(E, 'BayAnchor_' + str(i), (x, 0, 0), eroot)
    bay['binding'] = 'standard_hangar_instance'

D = bpy.data.scenes.new('IndustrialKeelDistant')
droot = empty(D, 'IndustrialKeelDistant')
assembly(D, 'DistantStructure', [o for o in ext_objects if o.type == 'MESH'], droot, detailed=False)
shell = []
for obj in list(KIT.all_objects):
    if obj.type != 'MESH':
        continue
    collections = [c.name for c in obj.users_collection]
    if any(c in collections for c in ['06 Exterior armor and structure', '04 Animated pressure door and header']) or ancestor_leaf(obj):
        shell.append(obj)
    elif any(part in obj.name for part in ['Deck substrate', 'Pressure shell', 'End pressure wall /', 'Roof structure']):
        shell.append(obj)
for i, x in enumerate([-27, 27], 1):
    assembly(D, 'DistantBay_' + str(i), shell, droot, shift=(x, 0, 0), detailed=False)

stats = {'standard_hangar': export(H, 'standard_hangar.glb'), 'station_structure': export(E, 'station_structure.glb'), 'station_distant': export(D, 'station_distant.glb')}

def normalize_names(path):
    raw = open(path, 'rb').read()
    size = struct.unpack_from('<I', raw, 12)[0]
    data = json.loads(raw[20:20 + size])
    suffix_names = set(marker_bindings) | {x['node'] for x in leaf_bindings}
    for node in data['nodes']:
        name = node.get('name', '')
        if name.rsplit('.', 1)[0] in suffix_names and name.rsplit('.', 1)[-1].isdigit():
            node['name'] = name.rsplit('.', 1)[0]
    chunk = json.dumps(data, separators=(',', ':')).encode()
    chunk += b' ' * ((-len(chunk)) % 4)
    tail = raw[20 + size:]
    with open(path, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, 20 + len(chunk) + len(tail)))
        f.write(struct.pack('<II', len(chunk), 0x4E4F534A))
        f.write(chunk)
        f.write(tail)
    return data

for result in stats.values():
    path = os.path.join(DEST, result['file'])
    data = normalize_names(path)
    result['bytes'] = os.path.getsize(path)
    assert all(not n.get('name', '').startswith(('REFERENCE', 'REVIEW', 'LONGHAUL /')) for n in data['nodes'])
data = normalize_names(os.path.join(DEST, 'standard_hangar.glb'))
names = [n['name'] for n in data['nodes']]
assert len(names) == len(set(names))
assert len(screen_bindings) == 6, screen_bindings
assert all(s['node'] in names for s in screen_bindings.values())
assert all(d['node'] in names for d in leaf_bindings)
for node in data['nodes']:
    if node['name'].startswith('Screen_'):
        primitive = data['meshes'][node['mesh']]['primitives'][0]
        assert 'TEXCOORD_0' in primitive['attributes'], node['name']
metadata = {
    'units': 'metres', 'coordinate_system': 'Godot: Y up, ship nose -Z',
    'blender_to_godot': ['x', 'z', '-y'], 'game_root_offset': [0, -1.315, 0],
    'hangar_clear_bounds': {'min': [-14, 0, -19], 'max': [14, 10, 33]},
    'door_clear_bounds': {'min': [-9, 0, 33], 'max': [9, 9, 35]},
    'bay_origins': [[-27, 0, 0], [27, 0, 0]],
    'doors': leaf_bindings, 'screens': screen_bindings, 'markers': marker_bindings,
    'assets': stats, 'excluded': ['reference ship and ramp', 'example cargo', 'human scale figure', 'review cameras', 'all Blender lights', 'demonstration animations', 'fake terminal screen text'],
}
with open(os.path.join(DEST, 'bindings.json'), 'w') as f:
    json.dump(metadata, f, indent=2)
with open(os.path.join(HERE, 'export_stats.json'), 'w') as f:
    json.dump(stats, f, indent=2)
print('STATION_EXPORT_COMPLETE ' + json.dumps(stats))
