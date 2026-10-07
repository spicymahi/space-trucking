extends Node3D
## Save-isolated cargo loop trial. Flight is skipped by an explicit dock transfer.
const Packing = preload("res://scripts/cargo_trial_packing.gd")
const Economy = preload("res://scripts/cargo_trial_economy.gd")
const Art = preload("res://scripts/cargo_trial_visuals.gd")
const System = preload("res://scripts/longhaul_system.gd")
const FONT = preload("res://assets/fonts/VT323-Regular.ttf")
const CELL := Packing.CELL
const FLOOR_GRID := Vector3i(4, 3, 4)

class TrialShip extends "res://scripts/longhaul_flight.gd":
	func _ready() -> void:
		_build_environment()
		hull = StaticBody3D.new()
		add_child(hull)
		_build_ship()
		for child in get_children():
			if child.get_script() == preload("res://scripts/longhaul_cockpit.gd"): cockpit_module = child
		preload("res://scripts/longhaul_blender_assets.gd").install(self, cockpit_module)
		cargo_module.hide()
		for body in cargo_module.find_children("*", "CollisionObject3D", true, false): body.collision_layer = 0
		for node in get_node("BlenderLonghaul").find_children("*", "Node3D", true, false):
			if node.get_meta("extras", {}).get("room", "") == "Cargo" and "Equipment" in String(node.name): node.hide()
		for body in find_children("*", "CollisionObject3D", true, false):
			body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
		process_mode = Node.PROCESS_MODE_DISABLED
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func _unhandled_input(_event: InputEvent) -> void: pass

var packing := Packing.new()
var floor_packing := Packing.new()
var economy := Economy.new()
var ship: Node3D
var dock: Dictionary
var racks: Array[Node3D] = []
var stage_positions := [Vector3(-1.9,0.05,0.65), Vector3(1.9,0.05,0.65), Vector3(-1.9,0.05,6.0), Vector3(1.9,0.05,6.0)]
var parcels: Dictionary = {}
var cases: Dictionary = {}
var jobs: Array = []
var held := -1
var held_size := Vector3i.ONE
var locked := false
var walker: CharacterBody3D
var camera: Camera3D
var carry_shape: CollisionShape3D
var pitch := 0.0
var ghost: MeshInstance3D
var ghost_material: StandardMaterial3D
var candidate: Dictionary = {}
var depth_mode := 0
var current_hit: Dictionary = {}
var hud: Label
var prompt: Label
var toast: Label
var toast_timer := 0.0
var panel: PanelContainer
var readout: RichTextLabel
var command: LineEdit
var terminal_mode := "contract"
var output := ""
var economy_timer := 0.0
var ready_for_input := false
var test_walk_input := Vector3.ZERO
var tool: Node3D
var lock_lamp: MeshInstance3D
var completion_receipt := ""

func _ready() -> void:
	DisplayServer.window_set_title("Space Trucking — Cargo Loop Test")
	economy.setup()
	ship = TrialShip.new()
	add_child(ship)
	dock = Art.dock(self)
	floor_packing.grid = FLOOR_GRID
	floor_packing.bin_count = stage_positions.size() + dock.pickup_positions.size() + dock.drop_positions.size()
	floor_packing.open_sides.assign([Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK])
	floor_packing.area_name = "floor grid"
	_build_racks()
	_build_player()
	_build_ui()
	_build_ghost()
	jobs = economy.offers(0)
	_refresh_station()
	ready_for_input = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	message("Welcome to Ceres Yard. Walk to the green CONTRACTS computer and press F.")
	if "--cargo-trial-test" in OS.get_cmdline_user_args():
		_run_tests.call_deferred()
	elif "--cargo-trial-capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _build_racks() -> void:
	for z in range(-1,7):
		for x in 6:
			Art.box(self,Vector3(x-2.5,0.013,z+0.5),Vector3(0.978,0.024,0.978),Color("716a5c").lightened(0.02*((x+z+8)%3)))
	for index in 2:
		var rack := Art.rack()
		add_child(rack)
		rack.name = "PackingRack%d" % index
		rack.position = Vector3(1.7,0.08,2.5) if index == 0 else Vector3(-1.7,0.08,4.3)
		rack.rotation.y = 0 if index == 0 else PI
		racks.append(rack)
		Art.label(self, "RACK %s / 24 CELLS" % ("A" if index == 0 else "B"),Vector3(2.15 if index==0 else -2.15,1.75,3.4),0.0017).rotation.y = -PI/2 if index==0 else PI/2
	for i in stage_positions.size():
		var at: Vector3 = stage_positions[i]
		Art.box(self,at-Vector3(0,0.025,0),Vector3(1.84,0.035,1.84),Color("393b35"))
		Art.floor_grid(self,at,Color("c89c52"))
		var text := Art.label(self,"STAGING %d / 3 LAYERS / CLEAR FOR FLIGHT" % (i+1),at+Vector3(0,0.012,0.99),0.0010)
		text.rotation.x = -PI/2
	var console := Node3D.new()
	add_child(console)
	console.position = Vector3(-2.55,0,-0.5)
	Art.box(console,Vector3(0,0.75,0),Vector3(0.65,1.5,0.42),Color("b3aa92"),true)
	lock_lamp = Art.box(console,Vector3(0,1.4,0.235),Vector3(0.48,0.10,0.04),Color("dbaf59"))
	Art.label(console,"CARGO LOCK\n[F] SECURE / RELEASE",Vector3(0,1.07,0.23),0.00135)
	for node in console.get_children():
		if node is StaticBody3D:node.set_meta("action","lock")
	for z in [0.0,3.0,6.0]:
		var light:=OmniLight3D.new();light.position=Vector3(0,2.4,z);light.omni_range=4.2;light.light_energy=0.65;light.light_color=Color("ffdfaa");light.shadow_enabled=true;add_child(light)

func _build_player() -> void:
	walker = CharacterBody3D.new()
	walker.name = "CargoHandler"
	walker.collision_layer = 2
	walker.collision_mask = 1
	walker.floor_snap_length = 0.3
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.7
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.85
	walker.add_child(shape)
	carry_shape = CollisionShape3D.new()
	carry_shape.shape = BoxShape3D.new()
	carry_shape.disabled = true
	walker.add_child(carry_shape)
	camera = Camera3D.new()
	camera.position.y = 1.62
	camera.near = 0.035
	camera.fov = 78
	walker.add_child(camera)
	add_child(walker)
	walker.position = Vector3(-3,-1.13,20.7)
	camera.current = true
	tool = Node3D.new()
	camera.add_child(tool)
	tool.position = Vector3(0.35,-0.30,-0.65)
	Art.box(tool,Vector3.ZERO,Vector3(0.12,0.12,0.30),Color("b5aa91"))
	Art.box(tool,Vector3(0,-0.10,0.02),Vector3(0.08,0.16,0.10),Color("a36835"))
	Art.box(tool,Vector3(0,0,-0.16),Vector3(0.08,0.07,0.025),Color("8dbfab"))

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	for kind in 3:
		var label := Label.new()
		label.add_theme_font_override("font",FONT)
		label.add_theme_font_size_override("font_size",23 if kind != 1 else 25)
		label.add_theme_color_override("font_color",Color("e4d4af"))
		label.add_theme_color_override("font_shadow_color",Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x",2)
		label.add_theme_constant_override("shadow_offset_y",2)
		canvas.add_child(label)
		if kind == 0:
			hud = label;label.position=Vector2(20,16)
		elif kind == 1:
			prompt=label;label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);label.offset_left=20;label.offset_right=-20;label.offset_top=-105;label.offset_bottom=-5
		else:
			toast=label;label.position=Vector2(20,145);label.size=Vector2(1190,110);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var dot := Label.new();dot.text="+";dot.add_theme_font_size_override("font_size",24)
	canvas.add_child(dot);dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER);dot.position-=Vector2(6,15)
	panel=PanelContainer.new();canvas.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left=45;panel.offset_top=45;panel.offset_right=-45;panel.offset_bottom=-45
	var style := StyleBoxFlat.new();style.bg_color=Color("101d18");style.border_color=Color("aa8650");style.set_border_width_all(3);style.content_margin_left=24;style.content_margin_right=24;style.content_margin_top=18;style.content_margin_bottom=18
	panel.add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new();panel.add_child(column)
	var title:=Label.new();title.text="K-01 / FREIGHT OPERATIONS                         ESC / CLOSE"
	title.add_theme_font_override("font",FONT);title.add_theme_font_size_override("font_size",30);title.modulate=Color("e9c17e");column.add_child(title)
	readout=RichTextLabel.new();readout.size_flags_vertical=Control.SIZE_EXPAND_FILL
	readout.add_theme_font_override("normal_font",FONT);readout.add_theme_font_size_override("normal_font_size",25);readout.add_theme_color_override("default_color",Color("acd8b7"));column.add_child(readout)
	command=LineEdit.new();command.placeholder_text="Type jobs, accept 1, status, plan, or depart and press Enter"
	command.add_theme_font_override("font",FONT);command.add_theme_font_size_override("font_size",27);column.add_child(command)
	command.text_submitted.connect(_command)
	panel.hide()

func _build_ghost() -> void:
	ghost=MeshInstance3D.new();ghost.mesh=BoxMesh.new()
	ghost_material=StandardMaterial3D.new();ghost_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.material_override=ghost_material
	ghost.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ghost);ghost.hide()

func message(words: String) -> void:
	toast.text=words;toast_timer=7.0

func _process(delta: float) -> void:
	if not ready_for_input:return
	toast_timer=maxf(0,toast_timer-delta);toast.visible=toast_timer>0 and not panel.visible
	if not panel.visible:economy_timer+=delta
	if economy_timer>=30 and not panel.visible:
		economy.tick(0.10);economy_timer=0
	var contract_name: String="NO ACTIVE CONTRACT"
	if not economy.active.is_empty():contract_name="%s / %s" % [economy.active.id,String(economy.active.commodity).to_upper()]
	hud.text="CARGO LOOP TEST / %s\n%s\nRACKED %d/%d   STAGED %d CASES   %s   %d CR\nWASD WALK / SHIFT HURRY / F USE / P PACKING PLAN / ESC MOUSE" % [System.NAMES[economy.station].to_upper(),contract_name,packing.placements.size(),parcels.size(),stage_count(),"LOCKED" if locked else "UNLOCKED",economy.credits]
	if panel.visible:ghost.hide();prompt.text="";return
	_update_aim()

func _physics_process(delta: float) -> void:
	if not ready_for_input:return
	var move:=Vector3.ZERO
	if not panel.visible and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		move=Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	if "--cargo-trial-test" in OS.get_cmdline_user_args():move=test_walk_input
	move=walker.basis*move.normalized()
	var speed:=3.7 if Input.is_physical_key_pressed(KEY_SHIFT) and held<0 else 2.4
	walker.velocity.x=move.x*speed;walker.velocity.z=move.z*speed
	walker.velocity.y=-0.5 if walker.is_on_floor() else walker.velocity.y-18*delta
	walker.move_and_slide()
	if walker.position.y < -8:
		walker.position=Vector3(0,-1.1,18);walker.velocity=Vector3.ZERO
		message("Returned to the dock walkway.")

func _unhandled_input(event: InputEvent) -> void:
	if not ready_for_input:return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if panel.visible:panel.hide();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		else:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		return
	if panel.visible:return
	if event is InputEventMouseButton and event.pressed:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		var previous:=walker.rotation.y
		walker.rotate_y(-event.relative.x*0.0025)
		if held>=0 and _carry_blocked():walker.rotation.y=previous
		pitch=clampf(pitch-event.relative.y*0.0025,-1.4,1.4);camera.rotation.x=pitch
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F: _use()
			KEY_R: _rotate_case(1)
			KEY_T: _rotate_case(0)
			KEY_Z: depth_mode=(depth_mode+1)%3
			KEY_P: open_terminal("plan")

func _update_aim() -> void:
	var ray:=PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*3.8,1,[walker.get_rid()])
	current_hit=get_world_3d().direct_space_state.intersect_ray(ray)
	candidate={};ghost.hide()
	if held>=0:
		candidate=_placement_target()
		if not candidate.is_empty():
			if _placement_blocked(candidate):candidate.reason="Placement blocked by the ship or your body. Step back into the working aisle."
			ghost.mesh.size=Vector3(held_size)*CELL-Vector3.ONE*0.012
			ghost.global_transform=candidate.transform
			ghost_material.albedo_color=Color(0.35,0.95,0.57,0.30) if candidate.reason.is_empty() else Color(1,0.24,0.14,0.35)
			ghost.show()
			var controls:String="R TURN / T TIP / Z DEPTH: "+["AUTO","REAR","FRONT"][depth_mode] if candidate.kind=="rack" else "R TURN / T TIP / AIM AT BOX TOP TO STACK"
			prompt.text=("[F] PLACE / "+candidate.label if candidate.reason.is_empty() else candidate.reason)+"\n"+controls
		else:prompt.text="CARRYING #%02d / %d × %d × %d\nAim at a grid cell or the top of a box to stack. R turn / T tip" % [held,held_size.x,held_size.y,held_size.z]
		return
	prompt.text="Walk to a box or computer and press F."
	if current_hit.is_empty():return
	var hit:Node=current_hit.collider
	if hit.has_meta("parcel"):
		var id:int=hit.get_meta("parcel")
		if not parcels.has(id):return
		prompt.text="[F] LIFT #%02d / %s" % [id,parcels[id].location.to_upper()]
		var model = packing if parcels[id].location=="rack" else floor_packing
		var reason:String="Cargo locked. Release at the CARGO LOCK button." if locked and parcels[id].location=="rack" else model.can_remove(id)
		if not reason.is_empty():prompt.text=reason
	elif hit.has_meta("action"):
		prompt.text={"contract":"[F] CONTRACTS / JOB BOARD","complete":"[F] COMPLETE DELIVERY","depart":"[F] DEPARTURE / TEST TRANSFER","lock":"[F] RELEASE CARGO" if locked else "[F] LOCK CARGO"}.get(hit.get_meta("action"),"[F] USE")

func _placement_target() -> Dictionary:
	var origin:=camera.global_position;var direction:Vector3=-camera.global_basis.z
	# Use the actual touched box face so aiming at its top stacks directly above it.
	if not current_hit.is_empty():
		var hit_id:int=current_hit.collider.get_meta("parcel",-1)
		if floor_packing.placements.has(hit_id):
			var data:Dictionary=parcels[hit_id]
			if _floor_available(data.location):
				var base:=_floor_origin(data.location,data.slot)
				var local:Vector3=(current_hit.position-base)/CELL
				var cell:=Vector3i(floori(local.x-held_size.x*0.5+0.5),floori(local.y),floori(local.z-held_size.z*0.5+0.5))
				cell.x=clampi(cell.x,0,maxi(0,FLOOR_GRID.x-held_size.x))
				cell.z=clampi(cell.z,0,maxi(0,FLOOR_GRID.z-held_size.z))
				var placed:Dictionary=floor_packing.placements[hit_id]
				var normal:Vector3=current_hit.normal
				if normal.y>0.5:cell.y=placed.cell.y+placed.size.y
				elif absf(normal.x)>0.5:
					cell.x=placed.cell.x+placed.size.x if normal.x>0 else placed.cell.x-held_size.x
					cell.y=placed.cell.y
				else:
					cell.z=placed.cell.z+placed.size.z if normal.z>0 else placed.cell.z-held_size.z
					cell.y=placed.cell.y
				return floor_target(data.location,data.slot,cell,held_size)
	for index in racks.size():
		var rack:Node3D=racks[index]
		var local_origin:Vector3=rack.to_local(origin)
		var local_direction:Vector3=rack.global_basis.inverse()*direction
		if absf(local_direction.x)<0.001 or local_direction.x<=0:continue
		var distance:float=(-0.015-local_origin.x)/local_direction.x
		if distance<0 or distance>4.5:continue
		var at:=local_origin+local_direction*distance
		if at.y< -0.12 or at.y>1.6 or at.z< -0.12 or at.z>1.92:continue
		var y:=clampi(int(floor(at.y/CELL)),0,maxi(0,Packing.GRID.y-held_size.y))
		var z:=clampi(int(floor(at.z/CELL)),0,maxi(0,Packing.GRID.z-held_size.z))
		var max_depth:=maxi(0,Packing.GRID.x-held_size.x)
		var choices:Array=[max_depth,0] if depth_mode==0 else ([max_depth] if depth_mode==1 else [0])
		var cell:=Vector3i(choices[0],y,z);var reason:=""
		for x in choices:
			cell.x=x;reason=packing.can_place(held,index,cell,held_size)
			if reason.is_empty():break
		if locked:reason="Release the cargo locks before placing a case."
		return {"kind":"rack","bin":index,"cell":cell,"reason":reason,"label":"RACK "+("A" if index==0 else "B"),"transform":rack.global_transform*Transform3D(Basis.IDENTITY,(Vector3(cell)+Vector3(held_size)*0.5)*CELL)}
	if direction.y>=-0.02:return {}
	for kind in ["stage","pickup","drop"]:
		if not _floor_available(kind):continue
		var positions:Array=_floor_positions(kind)
		for index in positions.size():
			var base:=_floor_origin(kind,index)
			var t:float=(base.y-origin.y)/direction.y
			if t<0 or t>4.5:continue
			var at:Vector3=(origin+direction*t-base)/CELL
			if at.x<0 or at.x>FLOOR_GRID.x or at.z<0 or at.z>FLOOR_GRID.z:continue
			var cell:=Vector3i(clampi(floori(at.x-held_size.x*0.5+0.5),0,maxi(0,FLOOR_GRID.x-held_size.x)),0,clampi(floori(at.z-held_size.z*0.5+0.5),0,maxi(0,FLOOR_GRID.z-held_size.z)))
			return floor_target(kind,index,cell,held_size)
	return {}

func _floor_positions(kind:String) -> Array:
	match kind:
		"stage":return stage_positions
		"pickup":return dock.pickup_positions
		"drop":return dock.drop_positions
	return []

func _floor_available(kind:String) -> bool:
	if economy.active.is_empty():return false
	return kind=="stage" or (kind=="drop" and economy.active.phase=="unloading") or (kind=="pickup" and economy.active.phase=="loading")

func _floor_bin(kind:String,index:int) -> int:
	return index + (0 if kind=="stage" else stage_positions.size() + (dock.pickup_positions.size() if kind=="drop" else 0))

func _floor_origin(kind:String,index:int) -> Vector3:
	return _floor_positions(kind)[index]+Vector3(-FLOOR_GRID.x*CELL*0.5,0 if kind=="stage" else 0.04,-FLOOR_GRID.z*CELL*0.5)

func floor_target(kind:String,index:int,cell:Vector3i,size:Vector3i) -> Dictionary:
	var bin_index:=_floor_bin(kind,index)
	var reason:=floor_packing.can_place(held,bin_index,cell,size)
	if not _floor_available(kind):reason="This cargo area is not available at this contract stop."
	return {"kind":kind,"index":index,"bin":bin_index,"cell":cell,"reason":reason,"label":"%s %02d / LAYER %d" % [kind.to_upper(),index+1,cell.y+1],"transform":Transform3D(Basis.IDENTITY,_floor_origin(kind,index)+(Vector3(cell)+Vector3(size)*0.5)*CELL)}

func _placement_blocked(target: Dictionary) -> bool:
	var size:=Vector3(held_size)*CELL-Vector3.ONE*0.03
	var bounds:AABB=target.transform*AABB(-size*0.5,size)
	var player_bounds:=AABB(walker.global_position+Vector3(-0.24,0.02,-0.24),Vector3(0.48,1.66,0.48))
	if bounds.intersects(player_bounds):return true
	var aim:Vector3=target.transform.origin
	if target.kind=="rack":
		var local:Vector3=racks[target.bin].to_local(aim)
		local.x=-0.05
		aim=racks[target.bin].to_global(local)
	var ray:=PhysicsRayQueryParameters3D.create(camera.global_position,aim,1,[walker.get_rid(),_case_body(held).get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.position.distance_to(aim)>0.10

func _use() -> void:
	if held>=0:
		if candidate.is_empty():message("Aim at a marked rack or temporary staging pad.")
		elif not candidate.reason.is_empty():message(candidate.reason)
		else:place_held(candidate)
		return
	if current_hit.is_empty():return
	var node:Node=current_hit.collider
	if node.has_meta("parcel"):pick_case(node.get_meta("parcel"));return
	match node.get_meta("action",""):
		"contract":open_terminal("contract")
		"lock":toggle_lock()
		"complete":complete_delivery()
		"depart":open_terminal("depart")

func _make_case(data: Dictionary) -> void:
	var id:int=data.id
	var visual:=Art.crate(id,data.size,economy.active.commodity)
	visual.name="Parcel%02d"%id
	var body:=StaticBody3D.new();body.set_meta("parcel",id)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(data.size)*CELL-Vector3.ONE*0.025
	collision.shape=shape;body.add_child(collision);visual.add_child(body)
	add_child(visual);cases[id]=visual
	visual.position=_floor_origin("pickup",data.slot)+(Vector3(data.cell)+Vector3(data.size)*0.5)*CELL

func _replace_case_visual(id:int,size:Vector3i) -> void:
	var old:Node3D=cases[id];var parent:=old.get_parent();var pose:=old.transform
	parent.remove_child(old);old.queue_free()
	var visual:=Art.crate(id,size,economy.active.commodity)
	visual.name="Parcel%02d"%id
	var body:=StaticBody3D.new();body.set_meta("parcel",id)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(size)*CELL-Vector3.ONE*0.025
	collision.shape=shape;body.add_child(collision);visual.add_child(body)
	parent.add_child(visual);visual.transform=pose;cases[id]=visual
	if held==id:body.collision_layer=0

func _case_body(id:int) -> StaticBody3D:
	for child in cases[id].get_children():
		if child is StaticBody3D:return child
	return null

func pick_case(id:int) -> bool:
	if held>=0 or not parcels.has(id):return false
	var data:Dictionary=parcels[id]
	var lift_shape:=BoxShape3D.new();lift_shape.size=Vector3(data.size)*CELL-Vector3.ONE*0.04
	var lift_query:=PhysicsShapeQueryParameters3D.new();lift_query.shape=lift_shape
	lift_query.transform=walker.global_transform*Transform3D(Basis.IDENTITY,Vector3(0.18,1.05,-0.52-data.size.z*CELL*0.5))
	lift_query.collision_mask=1;lift_query.exclude=[walker.get_rid(),_case_body(id).get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(lift_query,1).is_empty():
		message("Step back into clear space before lifting this case.");return false
	if data.location=="rack":
		if locked:message("Release cargo at the cargo-lock button first.");return false
		var reason:=packing.can_remove(id)
		if not reason.is_empty():message(reason);return false
		packing.remove(id)
	elif floor_packing.placements.has(id):
		var reason:=floor_packing.can_remove(id)
		if not reason.is_empty():message(reason);return false
		floor_packing.remove(id)
	held=id;held_size=data.size
	var node:Node3D=cases[id]
	node.reparent(walker,false)
	node.rotation=Vector3.ZERO
	_case_body(id).collision_layer=0
	data.location="hand";data.slot=-1
	_update_carry()
	return true

func _update_carry() -> void:
	if held<0:return
	var node:Node3D=cases[held]
	node.position=Vector3(0.18,1.05,-0.52-held_size.z*CELL*0.5)
	carry_shape.position=node.position
	carry_shape.shape.size=Vector3(held_size)*CELL-Vector3.ONE*0.04
	carry_shape.disabled=false
	tool.visible=true

func _carry_blocked() -> bool:
	if held<0 or not walker.is_inside_tree():return false
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=carry_shape.shape;query.transform=carry_shape.global_transform;query.collision_mask=1;query.exclude=[walker.get_rid(),_case_body(held).get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _rotate_case(axis:int) -> void:
	if held<0:return
	var previous:=held_size
	held_size=Packing.rotated_size(held_size,axis)
	_update_carry()
	if _carry_blocked():
		held_size=previous;_update_carry();message("Not enough space to rotate. Step into the clear aisle.");return
	parcels[held].size=held_size
	_replace_case_visual(held,held_size)
	_update_carry()

func place_held(target:Dictionary) -> bool:
	if held<0 or not target.get("reason","").is_empty():return false
	if target.kind=="rack":
		if locked:return false
		var reason:=packing.place(held,target.bin,target.cell,held_size)
		if not reason.is_empty():message(reason);return false
	else:
		if target.kind not in ["stage","pickup","drop"] or not _floor_available(target.kind):return false
		if target.index<0 or target.index>=_floor_positions(target.kind).size():return false
		var reason:=floor_packing.place(held,_floor_bin(target.kind,target.index),target.cell,held_size)
		if not reason.is_empty():message(reason);return false
		# Resolve world pose from grid cells; the occupancy and visible box cannot drift apart.
		target.transform=Transform3D(Basis.IDENTITY,_floor_origin(target.kind,target.index)+(Vector3(target.cell)+Vector3(held_size)*0.5)*CELL)
	var id:=held;var node:Node3D=cases[id]
	carry_shape.disabled=true
	node.reparent(self,false);node.global_transform=target.transform
	_case_body(id).collision_layer=1
	parcels[id].location=target.kind;parcels[id].slot=target.get("index",-1);parcels[id].size=held_size;parcels[id].cell=target.cell
	held=-1
	ghost.hide()
	_refresh_station()
	return true

func stage_count() -> int:
	var count:=0
	for data in parcels.values():
		if data.location=="stage":count+=1
	return count

func load_readiness() -> String:
	if economy.active.is_empty() or economy.active.phase=="complete":return "Accept a contract at the dock computer."
	if economy.active.phase=="to_pickup":return "Collection contract: depart empty to pick up the employer's goods."
	if held>=0:return "Put down the case held in your tool."
	if stage_count()>0:return "Clear all four staging pads before departure."
	if packing.placements.size()!=parcels.size() or parcels.is_empty():return "Load every assigned case into the racks (%d/%d)." % [packing.placements.size(),parcels.size()]
	return ""

func toggle_lock() -> bool:
	if locked:
		locked=false;message("Cargo locks released. You can rearrange or unload cases.");_refresh_station();return true
	var reason:=load_readiness()
	if not reason.is_empty():message(reason);return false
	if economy.active.phase=="loading" and not economy.mark_collected(parcels.size()):message(economy.error);return false
	locked=true
	if economy.active.phase=="unloading":message("Cargo secured at destination. Unlock it when ready to unload.")
	else:message("ALL CARGO SECURED. Clear to depart for "+System.NAMES[economy.leg_destination()]+". Use the dock TRANSFER computer to skip the flight in this test.")
	_refresh_station();return true

func _spawn_manifest() -> void:
	var items:Array=packing.generate(int(economy.active.id.hash()),economy.active.full)
	economy.active.box_count=items.size()
	floor_packing.manifest=packing.manifest
	for i in items.size():
		var data:Dictionary=items[i].duplicate(true);data.location="pickup";data.slot=i
		# Initial orientation is carryable through the hatch; players still rotate to pack.
		var dims:Array=[data.size.x,data.size.y,data.size.z];dims.sort()
		data.size=Vector3i(dims[0],dims[1],dims[2])
		data.cell=Vector3i((FLOOR_GRID.x-data.size.x)/2,0,(FLOOR_GRID.z-data.size.z)/2)
		var error:=floor_packing.place(data.id,_floor_bin("pickup",i),data.cell,data.size)
		assert(error.is_empty(),error)
		parcels[data.id]=data;_make_case(data)
	message("%d assigned cases are ready in COLLECTION. Carry them up the ramp; pack RACK A/B. P shows the optional packing plan." % items.size())

func accept_job(index:int) -> bool:
	if index<0 or index>=jobs.size():output="Choose an offer number from jobs.";return false
	var contract:Dictionary=economy.accept(jobs[index].id)
	if contract.is_empty():output=economy.error;return false
	_clear_cases();locked=false;completion_receipt=""
	if contract.phase=="loading":_spawn_manifest()
	else:message("Collection contract signed. Your fuel advance covers both legs. Depart empty to "+System.NAMES[contract.source]+".")
	output="CONTRACT ACCEPTED / FUEL ADVANCE PAID\nPress Esc to return to the dock.\n\n"+_status();_refresh_station();return true

func depart() -> bool:
	if economy.active.is_empty():output="Accept a contract first.";return false
	if economy.active.phase not in ["to_pickup","delivery"]:
		output="Unload and complete this delivery first." if economy.active.phase=="unloading" else "Load and lock the consignment before departure."
		return false
	if economy.active.phase!="to_pickup":
		var reason:=load_readiness()
		if not reason.is_empty():output=reason;return false
		if not locked:output="Use the CARGO LOCK button inside the hold before departure.";return false
	var destination:int=economy.leg_destination()
	if destination<0 or not economy.travel_to(destination):output=economy.error;return false
	walker.position=Vector3(0,-1.13,18);walker.rotation=Vector3.ZERO;pitch=0;camera.rotation=Vector3.ZERO
	if economy.active.phase=="loading":_spawn_manifest()
	else:message("Arrived at "+System.NAMES[economy.station]+". Release the cargo locks, unload every case to DELIVERY, then press COMPLETE.")
	output="TEST TRANSFER COMPLETE / "+System.NAMES[economy.station]+"\nQuoted fuel charged; economy advanced by journey time.\n\n"+_status()
	_refresh_station();return true

func delivered_count() -> int:
	var count:=0
	for data in parcels.values():
		if data.location=="drop":count+=1
	return count

func complete_delivery() -> bool:
	if not economy.complete(delivered_count(),parcels.size(),economy.station):
		message(economy.error);return false
	completion_receipt="DELIVERY COMPLETE / %s\nTotal fee %d CR / Fuel advance %d CR / Balance paid %d CR\nWallet: %d CR" % [economy.active.id,economy.active.payout,economy.active.advance,economy.active.remaining_pay,economy.credits]
	message(completion_receipt)
	_clear_cases();locked=false
	jobs=economy.offers(economy.station)
	_refresh_station()
	return true

func _clear_cases() -> void:
	for node in cases.values():
		if is_instance_valid(node):
			for body in node.find_children("*", "CollisionObject3D", true, false):body.collision_layer=0
			node.queue_free()
	cases.clear();parcels.clear();packing.reset();floor_packing.reset();held=-1
	if carry_shape:carry_shape.disabled=true

func _refresh_station() -> void:
	if dock.is_empty():return
	var status:Label3D=dock.terminal.get_node_or_null("StatusText")
	if status:status.text=System.NAMES[economy.station].to_upper()+"\nCONTRACTS / [F]\n%d CR AVAILABLE" % economy.credits
	status=dock.completion.get_node_or_null("StatusText")
	if status:status.text="DELIVERY RECEIPT\n%d / %d CASES\n[F] COMPLETE" % [delivered_count(),parcels.size()]
	status=dock.transit.get_node_or_null("StatusText")
	if status:status.text="TEST TRANSFER\n"+("DEPARTURE CLEARED" if locked and economy.active.get("phase", "")=="delivery" else ("UNLOAD / COMPLETE" if economy.active.get("phase", "")=="unloading" else "CHECK LOAD / [F]"))+"\nFLIGHT SKIPPED"
	if lock_lamp:lock_lamp.material_override=Art._material(Color("8cd7a6") if locked else Color("dbaf59"),true)

func _status() -> String:
	if economy.active.is_empty():return "No active contract. Type jobs.\n\n"+completion_receipt
	var c:Dictionary=economy.active
	return "%s / %s\nEMPLOYER: %s\nCOLLECT: %s  >  DELIVER: %s\nCOMMODITY: %s / %s\nPHASE: %s\nRACKED %d/%d / STAGING %d / DELIVERED %d\n%s\n\nTOTAL FEE %d CR = FUEL %d + TIME %d + HANDLING %d + UPKEEP %d + PROFIT %d\nFUEL ADVANCE %d CR / BALANCE ON COMPLETION %d CR\nNo deadline. Stock and destination capacity reserved.\n\ncommands: jobs / status / plan / depart\nDeparture requires all cases racked, staging clear, and cargo locked.\nThis test skips flight and charges the quoted route fuel." % [c.id,c.kind.to_upper(),System.NAMES[c.employer],System.NAMES[c.source],System.NAMES[c.destination],c.commodity,"FULL HOLD" if c.full else "SMALL LOAD",c.phase.to_upper(),packing.placements.size(),parcels.size(),stage_count(),delivered_count(),"CARGO LOCKED / READY" if locked else "CARGO UNLOCKED",c.payout,c.fuel_cost,c.time_pay,c.handling_pay,c.upkeep,c.profit,c.advance,c.remaining_pay]

func _job_board() -> String:
	if not economy.active.is_empty() and economy.active.phase!="complete":return _status()
	jobs=economy.offers(economy.station)
	var text:="%s / CONTRACT BOARD\nSupply and demand determine available work. Choose a job; cargo belongs to the employer.\n\n" % System.NAMES[economy.station]
	for i in jobs.size():
		var c:Dictionary=jobs[i]
		text+="%d / %s / %s / %s\n    %s > %s\n    %d CR fee | fuel %d CR advanced | %.1f min route | %d CR after fuel\n\n" % [i+1,c.kind.to_upper(),"FULL HOLD / 8–12 CASES" if c.full else "SMALL / 4–6 CASES",c.commodity,System.NAMES[c.source],System.NAMES[c.destination],c.payout,c.advance,c.minutes,c.payout-c.fuel_cost]
	text+="accept <number> / jobs refreshes market / status / plan\n\nCollection jobs include the empty outward leg and loaded return.\nAll quotes include fuel, travel time, handling, upkeep, and profit.\nNo deadlines. One active job at a time."
	return text

func _packing_plan() -> String:
	if parcels.is_empty():return "Accept a contract and collect its cargo first.\nCollection jobs generate cases when you reach the supplier."
	var text:="OPTIONAL PACKING PLAN / ONE VALID LOAD ORDER\nEach cell is 0.45 m. Depth: 1 front / 2 rear. Height: bottom = 1.\nRack A is starboard; rack B is port. Length counts along each rack's base ticks.\nR turns width/length; T tips height/length. Rotate until dimensions match.\n\n"
	for id in packing.get_solution_order():
		var p:Dictionary=packing.manifest[id];var c:Vector3i=p.solution_cell;var s:Vector3i=p.solution_size
		text+="#%02d   RACK %s   DEPTH %d / HEIGHT %d / LENGTH %d   SIZE %d × %d × %d%s\n" % [id,"A" if p.solution_bin==0 else "B",c.x+1,c.y+1,c.z+1,s.x,s.y,s.z,"  [LOADED]" if packing.placements.has(id) else ""]
	text+="\nLoad in this order; unload in reverse. Other valid arrangements also work.\nFloor grids stack up to 3 layers; aim at box tops to stack.\nFour amber staging pads let you rearrange without returning to the dock.\nKeep the walking aisle clear. Close this screen with Esc."
	return text

func open_terminal(mode:String) -> void:
	terminal_mode=mode
	output=_packing_plan() if mode=="plan" else (_job_board() if mode=="contract" else _status()+"\n\nType depart to test the next leg without flying.")
	readout.text=output;panel.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	command.clear();command.grab_focus()

func _command(text:String) -> void:
	var words:=text.strip_edges().to_lower().split(" ",false)
	if words.is_empty():return
	match words[0]:
		"jobs","help":output=_job_board()
		"accept":
			if words.size()==2 and words[1].is_valid_int():accept_job(int(words[1])-1)
			else:output="Type accept 1, accept 2, or accept 3."
		"status":output=_status()
		"plan":output=_packing_plan()
		"depart":depart()
		_:output="Commands: jobs / accept <number> / status / plan / depart"
	readout.text=output;readout.scroll_to_line(0);command.clear()

func _run_tests() -> void:
	var suite=load("res://scripts/cargo_trial_integration_test.gd").new()
	var ok:bool=await suite.run(self)
	print("CARGO TRIAL INTEGRATION ","PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)

func _capture() -> void:
	open_terminal("contract")
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/cargo-trial-board.png")
	panel.hide()
	accept_job(0)
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/cargo-trial-dock.png")
	walker.position=Vector3(0,0.05,5.7);walker.rotation.y=0;camera.rotation.x=-0.12
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/cargo-trial-hold.png")
	open_terminal("contract")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/cargo-trial-computer.png")
	get_tree().quit()
