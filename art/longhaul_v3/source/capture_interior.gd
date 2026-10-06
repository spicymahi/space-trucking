extends SceneTree
## Read-only geometry snapshot: builds only ship modules, never loads or writes a save.
const OUT := "res://art/longhaul_v3/source/interior_layout.json"

class CaptureShip extends "res://scripts/longhaul_flight.gd":
	func _ready() -> void:
		hull=StaticBody3D.new()
		add_child(hull)
		_build_ship()
		camera=Camera3D.new()
		add_child(camera)
		for child in get_children():
			if child.get_script()==preload("res://scripts/longhaul_cockpit.gd"):
				cockpit_module=child
		var sheet=preload("res://scripts/longhaul_flight_sheet.gd").new()
		add_child(sheet)
		sheet.build(self,cockpit_module.monitor_faces[0])
	func _exterior() -> void: pass
	func _finish_details() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func _unhandled_input(_event: InputEvent) -> void: pass

var ship: Node3D
var roots: Dictionary={}
var pivots: Dictionary={}
var screens: Dictionary={}
var records: Array=[]
var materials: Dictionary={}
var collider_records: Array=[]
var light_records: Array=[]
var bindings: Array=[]

func v(p: Vector3) -> Array: return [p.x,p.y,p.z]
func xf(t: Transform3D) -> Array:
	return [v(t.basis.x),v(t.basis.y),v(t.basis.z),v(t.origin)]
func rgba(c: Color) -> Array: return [c.r,c.g,c.b,c.a]

func _initialize() -> void: call_deferred("capture")

func capture() -> void:
	ship=CaptureShip.new()
	root.add_child(ship)
	ship.process_mode=Node.PROCESS_MODE_DISABLED
	roots={ship.cockpit_module:"Cockpit",ship.hab_module:"Hab",ship.service_module:"Service",ship.cargo_module:"Cargo",ship.engineering_module:"Engineering",ship.loading_module:"Loading"}
	pivots[ship.hab_module.table_pivot]="Hab_FoldingTable"
	pivots[ship.hab_module.drawer]="Hab_Drawer"
	pivots[ship.engineering_module.service_cover]="Engineering_ServiceCover"
	pivots[ship.engineering_module.pump_rotor]="Engineering_PumpRotor"
	pivots[ship.cargo_module.held_crate]="Cargo_TransferCase"
	for key in ["wash","air"]:
		for i in 2:pivots[ship.service_module.doors[key].leaves[i]]="Service_%s_Door_%d" % [key,i]
	for i in 2:pivots[ship.loading_module.leaves[i]]="Loading_Hatch_%d" % i
	var roles=["CHART","NAV","CHECKLIST","COMMS","ENGINE","RADAR","VELOCITY","DISTANCE"]
	for i in ship.cockpit_module.monitor_faces.size():
		var panel:Node3D=ship.cockpit_module.monitor_faces[i]
		screens[panel.get_meta("screen_mesh")]="Display_%02d_%s" % [i,roles[i]]
		bindings.append({"kind":"terminal","name":screens[panel.get_meta("screen_mesh")],"role":roles[i],"transform":xf(panel.global_transform),"display_size":[panel.get_meta("display_size").x,panel.get_meta("display_size").y]})
	walk(ship,"Structure","")
	var pivot_data:Array=[]
	for node in pivots:pivot_data.append({"name":pivots[node],"transform":xf(node.global_transform),"room":room_for(node),"source_path":str(ship.get_path_to(node))})
	var result={"source":"Approved Longhaul procedural interior; static snapshot only","coordinate_system":"Godot right-handed Y-up; Blender conversion (x,-z,y+1.4)","meshes":records,"materials":materials,"colliders":collider_records,"lights":light_records,"pivots":pivot_data,"bindings":bindings}
	FileAccess.open(OUT,FileAccess.WRITE).store_string(JSON.stringify(result))
	print("INTERIOR SNAPSHOT: ",records.size()," objects, ",collider_records.size()," collision records, ",pivot_data.size()," movable roots, ",bindings.size()," screen bindings")
	ship.queue_free()
	quit()

func room_for(node: Node) -> String:
	var n:Node=node
	while n and n!=ship:
		if roots.has(n):return roots[n]
		n=n.get_parent()
	return "Structure"

func mat_key(mat: Material) -> String:
	if not mat is StandardMaterial3D:return "fallback"
	var m:StandardMaterial3D=mat
	var key=str(m.get_instance_id())
	if not materials.has(key):
		var tex=""
		if m.albedo_texture and not m.albedo_texture.resource_path.is_empty():tex=m.albedo_texture.resource_path
		materials[key]={"color":rgba(m.albedo_color),"roughness":m.roughness,"metallic":m.metallic,"emission":rgba(m.emission) if m.emission_enabled else [0,0,0,1],"emission_strength":m.emission_energy_multiplier if m.emission_enabled else 0,"unshaded":m.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED,"texture":tex,"transparent":m.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED}
	return key

func walk(n: Node,room: String,mover: String) -> void:
	if n==ship.loading_module.ramp_trim:return
	if roots.has(n):room=roots[n]
	if pivots.has(n):mover=pivots[n]
	if n is Node3D and not n.is_visible_in_tree():return
	var path=str(ship.get_path_to(n))
	if n is MeshInstance3D and n.mesh:
		var record={"source_path":path,"room":room,"mover":mover,"transform":xf(n.global_transform),"name":str(n.name),"type":"mesh","material":mat_key(n.material_override)}
		if screens.has(n):record["binding"]=screens[n]
		if n.mesh is BoxMesh:
			record["type"]="box";record["size"]=v(n.mesh.size)
		else:
			var ar=n.mesh.surface_get_arrays(0)
			var verts:Array=[];var uvs:Array=[];var indices:Array=[]
			for p in ar[Mesh.ARRAY_VERTEX]:verts.append(v(p))
			if ar[Mesh.ARRAY_TEX_UV]!=null:
				for uv in ar[Mesh.ARRAY_TEX_UV]:uvs.append([uv.x,uv.y])
			if ar[Mesh.ARRAY_INDEX]!=null:
				for idx in ar[Mesh.ARRAY_INDEX]:indices.append(idx)
			record["vertices"]=verts;record["uvs"]=uvs;record["indices"]=indices
		records.append(record)
	elif n is Label3D:
		records.append({"source_path":path,"room":room,"mover":mover,"transform":xf(n.global_transform),"name":str(n.name),"type":"text","text":n.text,"color":rgba(n.modulate),"size":n.pixel_size*n.font_size,"font":n.font.resource_path if n.font else "","line_spacing":n.line_spacing})
	elif n is CollisionShape3D and n.shape:
		var rec={"source_path":path,"room":room,"mover":mover,"transform":xf(n.global_transform),"shape":n.shape.get_class(),"metadata":{}}
		if n.shape is BoxShape3D:rec["size"]=v(n.shape.size)
		for meta in n.get_parent().get_meta_list():
			var value=n.get_parent().get_meta(meta)
			if typeof(value) in [TYPE_STRING,TYPE_INT,TYPE_BOOL,TYPE_FLOAT]:rec.metadata[str(meta)]=value
		collider_records.append(rec)
	elif n is OmniLight3D:
		light_records.append({"position":v(n.global_position),"color":rgba(n.light_color),"energy":n.light_energy,"range":n.omni_range})
	for child in n.get_children():walk(child,room,mover)
