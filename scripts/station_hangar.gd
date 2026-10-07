extends Node3D
## Runtime bindings for the metre-scale Blender bay; art and gameplay stay separate.
const BAY = preload("res://assets/stations/industrial_keel/standard_hangar.glb")
const FONT = preload("res://assets/fonts/VT323-Regular.ttf")
const FLOOR_Y := -1.315
var controller: Node3D
var art: Node3D
var targets: Dictionary = {}
var terminals: Dictionary = {}
var screens: Dictionary = {}
var doors: Array[Node3D] = []
var closed_positions: Array[Vector3] = []
var geometry_bodies: Array[StaticBody3D] = []
var door_open_progress := 0.0
var door_requested := false
var door_clear_for_flight: bool:
	get: return door_open_progress >= 0.999

func build(host: Node3D) -> Dictionary:
	controller = host
	name = "BlenderStationHangar"
	position.y = FLOOR_Y
	art = BAY.instantiate(); add_child(art)
	_solid("Deck", Vector3(0,-0.1,7), Vector3(30,0.2,56))
	_solid("Ceiling", Vector3(0,10.2,7), Vector3(28,0.4,52))
	_solid("ForwardWall", Vector3(0,5,-19.2), Vector3(28,10,0.4))
	for side in [-1,1]:
		_solid("SideWall", Vector3(side*14.2,5,7), Vector3(0.4,10,52))
		_solid("WallEquipment", Vector3(side*13.75,1.25,7), Vector3(0.5,2.5,52))
		_solid("DoorJamb", Vector3(side*12,4.5,34), Vector3(6,9,2))
	_solid("DoorHeader", Vector3(0,11.1,34), Vector3(30,3.8,2.8))
	_solid("DispatchBooth", Vector3(12.8,1.4,11.1), Vector3(1.7,2.8,9.6))
	_solid("DispatchCounter", Vector3(11.4,0.6,11.1), Vector3(0.85,1.2,9.5))
	_solid("DeparturePedestal", Vector3(-3.4,0.6,17.7), Vector3(0.85,1.2,0.55))
	for i in 4:
		var leaf: Node3D = art.find_child("HangarDoorLeaf_%d" % (i+1),true,false)
		doors.append(leaf); closed_positions.append(leaf.position)
		_solid("DoorCollision",Vector3.ZERO,Vector3(17.95,2.235,0.5),leaf)
	var bindings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/stations/industrial_keel/bindings.json"))
	for key in bindings.screens:
		var definition: Dictionary = bindings.screens[key]
		var at: Array = definition.front_center
		var action: String = "contract" if key == "contracts" else key
		_terminal(action, definition.node, Vector3(at[0],at[1],at[2]))
	for z in [-13.0,-1.0,11.0,25.0]:
		for x in [-8.0,8.0]:
			var light := OmniLight3D.new(); add_child(light)
			light.position = Vector3(x,7.7,z); light.light_color = Color("ffe6bc")
			light.light_energy = 1.6; light.omni_range = 14; light.omni_attenuation = 1.15
			light.shadow_enabled = false
	var pickup: Array[Vector3] = []; var delivery: Array[Vector3] = []
	for kind in ["PICKUP", "DELIVERY"]:
		for i in 12:
			var p: Array = bindings.markers["%s_%02d" % [kind,i+1]].position
			# Authored anchors are the minimum grid corner; gameplay accepts its centre.
			var center := Vector3(p[0]+0.9,FLOOR_Y,p[2]+0.9)
			if kind == "PICKUP": pickup.append(center)
			else: delivery.append(center)
	return {"terminal":terminals.contract,"completion":terminals.complete,"transit":terminals.depart,"pickup_positions":pickup,"drop_positions":delivery}

func _solid(label:String,at:Vector3,size:Vector3,parent:Node3D=null) -> StaticBody3D:
	var body := StaticBody3D.new(); body.name = label
	(parent if parent else self).add_child(body); body.position = at
	body.collision_layer = 1; body.collision_mask = 0
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = size
	shape.shape = box; body.add_child(shape); geometry_bodies.append(body)
	return body

func _terminal(action:String,mesh_name:String,at:Vector3) -> void:
	var root := Node3D.new(); root.name = "Terminal_"+action; add_child(root); terminals[action] = root
	var status := Label3D.new(); status.name = "StatusText"; root.add_child(status); status.hide()
	var size := Vector3(0.12,0.66,0.87) if action != "depart" else Vector3(0.82,0.55,0.12)
	var target := _solid("InteractionBody",at,size,root)
	geometry_bodies.erase(target); targets[action] = target
	if action in ["provisions","repairs","refuel"]:
		target.set_meta("life_action",action); target.collision_layer = 5
	else: target.set_meta("action",action)
	var view := SubViewport.new(); view.size = Vector2i(640,400); view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ONCE; root.add_child(view)
	var background := ColorRect.new(); background.color = Color("071b15"); background.size = Vector2(640,400); view.add_child(background)
	var label := Label.new(); label.position = Vector2(24,18); label.size = Vector2(592,364)
	label.add_theme_font_override("font",FONT); label.add_theme_font_size_override("font_size",36)
	label.add_theme_color_override("font_color",Color("a6edb4")); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	view.add_child(label)
	var mesh: MeshInstance3D = art.find_child(mesh_name,true,false)
	var material := StandardMaterial3D.new(); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = view.get_texture(); material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mesh.material_override = material
	screens[action] = {"view":view,"label":label,"last":""}

func set_active(near:bool,docked:bool) -> void:
	visible = near
	for body in geometry_bodies: body.collision_layer = 1 if near else 0
	for action in targets: targets[action].collision_layer = (5 if action in ["provisions","repairs","refuel"] else 1) if docked else 0

func set_door_open(open:bool) -> void:
	door_requested = open

func advance_door(seconds:float) -> void:
	var open := door_requested
	# A closing door waits for the ship or pedestrian to clear the threshold.
	if not open and door_open_progress > 0:
		var ship_at := to_local(controller.ship.global_position)
		if absf(ship_at.x)<15 and absf(ship_at.z-34)<17 and ship_at.y<14: open = true
		if is_instance_valid(controller.walker):
			var walker_at := to_local(controller.walker.global_position)
			if absf(walker_at.x)<10 and absf(walker_at.z-34)<2 and walker_at.y<10: open = true
	door_open_progress = move_toward(door_open_progress,1.0 if open else 0.0,seconds/6.0)
	for i in doors.size():
		doors[i].position = closed_positions[i].lerp(Vector3(0,10.6,closed_positions[i].z),door_open_progress)

func refresh_screens() -> void:
	if not controller.life_ready: return
	var f = controller.ship.flight
	var values := {
		"contract": "CONTRACTS / BAY 01\n"+terminals.contract.get_node("StatusText").text+"\n\n[F] OPEN DISPATCH",
		"provisions": "PROVISIONS\n\nFOOD  %d DAYS\nWATER %d DAYS\n\n[F] ORDER STORES" % [controller.life.food_stock,controller.life.water_stock],
		"repairs": "SHIP SERVICES\n\nSENSOR REPAIR\nSTATION TECHNICIAN\n\n[F] INSPECT / QUOTE",
		"refuel": "FUEL SUPPLY\n\nTANK  %04d / 3000 KG\nTOP UP  %d CR\n\n[F] OPEN TERMINAL" % [int(f.fuel),controller._fuel_cost()],
		"complete": "DELIVERY RECEIPT\n\n%d / %d CASES\n\n[F] COMPLETE DELIVERY" % [controller.delivered_count(),controller.parcels.size()],
		"depart": "BERTH CONTROL\n\nBAY 01 / "+("DOOR CLEAR" if door_clear_for_flight else ("DOOR OPENING" if door_requested else "DOOR SECURED"))+"\n\n[F] FLIGHT / TEST CRUISE"
	}
	for action in screens:
		var screen: Dictionary = screens[action]
		if screen.last == values[action]: continue
		screen.label.text = values[action]; screen.last = values[action]
		screen.view.render_target_update_mode = SubViewport.UPDATE_ONCE
