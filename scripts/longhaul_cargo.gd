extends "res://scripts/longhaul_room.gd"
## Fitted freight room, with restrained loads and one manually transferable case.
var carrying := false
var held_crate: Node3D
var crate_body: StaticBody3D
var slots: Dictionary = {}
var locked := true
var crate_slot := 0
var manifest: Label3D
var lock_label: Label3D
var lock_lamps: Array[MeshInstance3D] = []
var carry_shape: CollisionShape3D
var last_safe_yaw := 0.0
var last_safe_position := Vector3.ZERO
var turn_notice_until := 0
const CRATE_SIZE := Vector3(0.50,0.50,0.50)
const CARRY_OFFSET := Vector3(0,1.05,-0.49)

func build(ship: Node3D) -> void:
	host = ship
	name = "LonghaulCargo"
	process_physics_priority = 1
	_structure()
	_racks()
	_forward_equipment()
	_receiving_berths()
	_ceiling()
	_update_manifest()

func _structure() -> void:
	# Structural rails stop at bulkhead faces. Freight and controls fit within them.
	for side in [-1,1]:
		var wall_x: float = side*2.94
		box(Vector3(wall_x,0.12,3),Vector3(0.10,0.22,7.72),DARK)
		box(Vector3(wall_x,2.54,3),Vector3(0.10,0.11,7.70),ORANGE)
		for z in [-0.83,1.61,3.62,6.83]:
			box(Vector3(side*2.91,1.34,z),Vector3(0.14,2.60,0.105),EDGE)
		# Exposed lash rails between bays have real attachment sockets.
		for height in [0.52,1.66]:
			box(Vector3(side*2.895,height,3.0),Vector3(0.105,0.13,7.5),EDGE)
			for j in 28:
				box(Vector3(side*2.831,height,-0.55+j*0.26),Vector3(0.023,0.055,0.084),DARK)
	# Rear bulkhead shoulders house restraint spares and the loading power feeds.
	for side in [-1,1]:
		var cabinet := group(Vector3(side*2.16,0,6.84),PI)
		box(Vector3(0,1.23,0),Vector3(1.37,2.28,0.12),DARK,true,cabinet)
		cabinet_face(Vector3(0,1.71,0.085),Vector2(1.21,0.92),cabinet)
		label("TIE-DOWN / SPARES" if side<0 else "LOAD POWER / 24V",Vector3(0,1.82,0.121),0.00098,DARK,cabinet)
		for x in [-0.40,0,0.40]:
			box(Vector3(x,1.54,0.14),Vector3(0.24,0.16,0.06),EDGE,false,cabinet)
			box(Vector3(x,1.55,0.18),Vector3(0.12,0.036,0.026),ORANGE,false,cabinet)
		cabinet_face(Vector3(0,0.71,0.085),Vector2(1.21,0.91),cabinet,EDGE)
		vent(Vector3(0,0.76,0.13),1.09,cabinet)
		vent(Vector3(0,2.27,0.065),1.24,cabinet)
	# Lane edges and flush anchor cups never become trip hazards.
	for x in [-1.29,1.29]:
		for i in 12:box(Vector3(x,0.029,-0.48+i*0.61),Vector3(0.048,0.009,0.33),ORANGE)
		for z in [0.25,1.65,3.05,4.45,5.85]:
			box(Vector3(x*1.13,0.029,z),Vector3(0.14,0.01,0.20),DARK)
			box(Vector3(x*1.13,0.034,z),Vector3(0.075,0.007,0.11),EDGE)
	var floor_text := label("KEEP AISLE CLEAR",Vector3(0,0.035,5.03),0.0018,ORANGE)
	floor_text.rotation.x = -PI/2

func _racks() -> void:
	for side in [-1,1]:
		var yaw := PI/2 if side<0 else -PI/2
		for i in 2:
			var z: float = 1.75+i*2.16
			var rack := group(Vector3(side*2.38,0,z),yaw)
			# Front of local rack is +Z and faces the handling lane.
			box(Vector3(0,0.15,0),Vector3(1.98,0.26,1.14),DARK,true,rack)
			box(Vector3(0,2.22,-0.16),Vector3(1.98,0.10,0.93),EDGE,false,rack)
			for x in [-0.955,0.955]:
				box(Vector3(x,1.14,-0.48),Vector3(0.065,2.18,0.12),EDGE,false,rack)
				box(Vector3(x,1.20,0.49),Vector3(0.065,2.20,0.065),EDGE,false,rack)
				for y in [0.42,0.80,1.18,1.56,1.94]:box(Vector3(x,y,0.531),Vector3(0.035,0.095,0.018),DARK,false,rack)
			var code := "P-01" if side<0 else "S-01"
			if i==1:code = "P-02" if side<0 else "S-02"
			box(Vector3(0,2.23,0.48),Vector3(1.97,0.17,0.09),ORANGE,false,rack)
			label(code+" / SECURED FREIGHT",Vector3(0,2.235,0.53),0.00097,LIGHT,rack)
			if i==0:
				_fixed_case(rack,Vector3(-0.46,0.68,0.01),Vector3(0.79,0.89,0.86),Color("758783"),"FILTERS / 04")
				_fixed_case(rack,Vector3(0.44,0.68,0.01),Vector3(0.79,0.89,0.86),CREAM,"DRY STORES")
				box(Vector3(0,1.185,0),Vector3(1.88,0.075,1.09),EDGE,true,rack)
				_fixed_case(rack,Vector3(-0.43,1.65,0.01),Vector3(0.85,0.80,0.84),Color("7f7965"),"STATION / 18")
				_fixed_case(rack,Vector3(0.48,1.65,0.01),Vector3(0.77,0.80,0.84),Color("758783"),"MED / SEALED")
			else:
				_fixed_case(rack,Vector3(0,0.88,0),Vector3(1.72,1.27,0.92),Color("758783") if side<0 else Color("9c947e"),"INDUSTRIAL / SPARES")
				box(Vector3(0,1.62,-0.10),Vector3(1.76,0.13,0.86),DARK,true,rack)
				for x in [-0.56,0,0.56]:
					_fixed_case(rack,Vector3(x,1.90,0.03),Vector3(0.48,0.44,0.74),Color("a18449"),"FRAGILE")
			# Orange retention straps tie the faces back into the rack structure.
			for x in [-0.68,0.68]:
				box(Vector3(x,1.18,0.52),Vector3(0.057,1.98,0.042),ORANGE,false,rack)
				box(Vector3(x,0.69,0.555),Vector3(0.14,0.23,0.085),DARK,false,rack)
				box(Vector3(x,0.71,0.603),Vector3(0.08,0.12,0.021),EDGE,false,rack)

func _fixed_case(parent: Node3D, pos: Vector3, size: Vector3, color: Color, words: String) -> void:
	box(pos,size,color,true,parent)
	for x in [-size.x*0.41,size.x*0.41]:
		box(pos+Vector3(x,0,size.z/2+0.015),Vector3(0.043,size.y*0.90,0.043),EDGE,false,parent)
	box(pos+Vector3(0,size.y*0.25,size.z/2+0.028),Vector3(size.x*0.53,0.11,0.035),DARK,false,parent)
	box(pos+Vector3(0,size.y*0.25,size.z/2+0.05),Vector3(size.x*0.35,0.034,0.031),EDGE,false,parent)
	box(pos+Vector3(0,-size.y*0.17,size.z/2+0.025),Vector3(size.x*0.74,0.18,0.026),LIGHT,false,parent)
	label(words,pos+Vector3(0,-size.y*0.17,size.z/2+0.043),minf(0.00095,size.x/950.0),DARK,parent)
	for x in [-size.x*0.47,size.x*0.47]:
		for y in [-size.y*0.43,size.y*0.43]:box(pos+Vector3(x,y,size.z/2+0.034),Vector3(0.065,0.065,0.025),DARK,false,parent)

func _forward_equipment() -> void:
	var console := group(Vector3(-1.89,0,-0.76))
	box(Vector3(0,0.52,0.17),Vector3(1.37,1.00,0.35),EDGE,true,console)
	cabinet_face(Vector3(0,0.54,0.365),Vector2(1.23,0.84),console)
	vent(Vector3(0,0.29,0.41),1.03,console)
	box(Vector3(0,1.04,0.26),Vector3(1.45,0.13,0.60),ORANGE,true,console)
	box(Vector3(0,1.48,0.17),Vector3(1.32,0.80,0.34),DARK,true,console)
	box(Vector3(0,1.48,0.36),Vector3(1.12,0.62,0.05),EDGE,false,console)
	box(Vector3(0,1.48,0.392),Vector3(1.02,0.52,0.025),Color("102e26"),false,console)
	manifest = label("",Vector3(0,1.48,0.415),0.00087,GREEN,console)
	label("FREIGHT / MANIFEST",Vector3(0,2.14,0.04),0.00147,DARK,console)
	for i in 12:
		box(Vector3(-0.48+i*0.077,1.132,0.33),Vector3(0.062,0.041,0.085),LIGHT if i<9 else ORANGE,false,console)
	collider(Vector3(0,1.48,0.416),Vector3(1.03,0.53,0.045),console,"cargo_manifest")
	# Reader, paperwork slot and dedicated restraints controls occupy the other shoulder.
	var tools_rack := group(Vector3(1.98,0,-0.79))
	box(Vector3(0,1.23,0),Vector3(1.43,2.31,0.14),DARK,true,tools_rack)
	cabinet_face(Vector3(0,1.96,0.10),Vector2(1.29,0.54),tools_rack)
	label("RESTRAINT / EQUIPMENT",Vector3(0,1.97,0.14),0.00098,DARK,tools_rack)
	for i in 3:
		var x: float = -0.43+i*0.43
		box(Vector3(x,1.40,0.14),Vector3(0.20,0.45,0.10),ORANGE,false,tools_rack)
		box(Vector3(x,1.40,0.20),Vector3(0.075,0.31,0.06),DARK,false,tools_rack)
		box(Vector3(x,1.57,0.24),Vector3(0.27,0.08,0.08),EDGE,false,tools_rack)
	cabinet_face(Vector3(0,0.50,0.13),Vector2(1.28,0.67),tools_rack)
	label("LASH KITS / JACK",Vector3(0,0.55,0.17),0.00109,DARK,tools_rack)
	vent(Vector3(0,0.98,0.15),1.24,tools_rack)
	# Clamp control placed at the lane edge; crates never cover it.
	var control := group(Vector3(1.16,1.30,-0.79))
	box(Vector3.ZERO,Vector3(0.27,0.58,0.15),DARK,false,control)
	lock_lamps.append(box(Vector3(0,0.19,0.09),Vector3(0.16,0.09,0.025),GREEN,false,control,true))
	box(Vector3(0,-0.12,0.11),Vector3(0.16,0.22,0.055),ORANGE,false,control)
	collider(Vector3(0,0,0.12),Vector3(0.29,0.58,0.06),control,"cargo_clamps")
	lock_label = label("CLAMP\nLOCKED",Vector3(0,-0.13,0.145),0.00065,LIGHT,control)

func _receiving_berths() -> void:
	for index in 2:
		var side: int = -1 if index==0 else 1
		var pos := Vector3(side*1.93,0.085,5.68)
		slots[index] = pos+Vector3(0,0.32,0)
		box(pos,Vector3(1.02,0.09,1.19),DARK,true)
		for x in [-0.47,0.47]:box(pos+Vector3(x,0.055,0),Vector3(0.045,0.015,1.13),ORANGE)
		for z in [-0.55,0.55]:box(pos+Vector3(0,0.055,z),Vector3(0.93,0.015,0.045),ORANGE)
		# Clamp jaws remain below the carrying case and actuate visibly.
		for x in [-0.33,0.33]:
			var jaw := box(pos+Vector3(x,0.08,0),Vector3(0.12,0.10,0.43),EDGE)
			jaw.name = "ClampJaw_%s_%s" % [index,str(x)]
			jaw.set_meta("jaw_side",signf(x))
			jaw.set_meta("slot_center",pos.x)
			jaw.set_meta("slot_index",index)
		var control := group(Vector3(side*1.43,0.78,5.68),PI/2 if side<0 else -PI/2)
		box(Vector3(0,-0.41,0),Vector3(0.10,0.73,0.10),EDGE,true,control)
		box(Vector3.ZERO,Vector3(0.38,0.38,0.12),DARK,false,control)
		box(Vector3(0,0.04,0.076),Vector3(0.29,0.22,0.026),ORANGE,false,control)
		label("BERTH "+str(index+1)+"\nTRANSFER",Vector3(0,0.035,0.095),0.00063,LIGHT,control)
		collider(Vector3(0,0,0.08),Vector3(0.39,0.39,0.07),control,"cargo_berth_"+str(index))
		var wall := group(Vector3(side*2.91,0,5.68),PI/2 if side<0 else -PI/2)
		cabinet_face(Vector3(0,1.40,0),Vector2(1.72,1.49),wall,CREAM)
		label("RECEIVING / "+str(index+1),Vector3(0,2.08,0.04),0.00145,DARK,wall)
		label("35 KG\nMANUAL HANDLING",Vector3(0,1.67,0.04),0.00128,DARK,wall)
		for x in [-0.56,0.56]:
			box(Vector3(x,1.13,0.085),Vector3(0.12,0.38,0.11),ORANGE,false,wall)
			box(Vector3(x,1.13,0.153),Vector3(0.053,0.23,0.041),DARK,false,wall)
		vent(Vector3(0,2.42,0.02),1.73,wall)
	held_crate = group(slots[0])
	held_crate.name = "TransferCase"
	box(Vector3.ZERO,CRATE_SIZE,Color("ac8748"),false,held_crate)
	# Small rubber feet support the collision-clear case on either receiving plinth.
	for x in [-0.18,0.18]:
		for z in [-0.18,0.18]:box(Vector3(x,-0.2625,z),Vector3(0.085,0.025,0.085),DARK,false,held_crate)
	for side in [-1,1]:
		box(Vector3(side*0.21,0,0.253),Vector3(0.035,0.47,0.018),DARK,false,held_crate)
		box(Vector3(side*0.21,0,-0.253),Vector3(0.035,0.47,0.018),DARK,false,held_crate)
		box(Vector3(0,0,side*0.253),Vector3(0.34,0.16,0.015),LIGHT,false,held_crate)
		var tag := label("SERVICE / 35\nHAND CARRY",Vector3(0,0,side*0.266),0.00057,DARK,held_crate)
		if side<0:tag.rotation.y = PI
	box(Vector3(0,0.275,0),Vector3(0.23,0.05,0.095),DARK,false,held_crate)
	crate_body = collider(Vector3.ZERO,CRATE_SIZE,held_crate,"cargo_crate")

func _ceiling() -> void:
	for x in [-1.50,1.50]:
		box(Vector3(x,2.65,3),Vector3(0.22,0.22,7.70),DARK)
		for z in [-0.52,0.7,1.92,3.14,4.36,5.58,6.6]:box(Vector3(x,2.52,z),Vector3(0.30,0.055,0.08),EDGE)
		for offset in [-0.06,0.06]:box(Vector3(x+offset,2.53,3),Vector3(0.025,0.04,7.60),ORANGE)
	for z in [0.45,2.85,5.32]:
		box(Vector3(0,2.66,z),Vector3(2.49,0.14,0.42),DARK)
		box(Vector3(0,2.58,z),Vector3(2.20,0.022,0.25),Color("e7d7a3"),false,self,true)
		host._lamp(Vector3(0,2.35,z),0.68,4.2,Color("ffe5b0"))
	for side in [-1,1]:
		for z in [0.32,2.52,4.72]:
			var duct := group(Vector3(side*2.27,2.65,z))
			box(Vector3.ZERO,Vector3(1.10,0.13,1.65),EDGE,false,duct)
			for i in 9:box(Vector3(0,-0.075,-0.64+i*0.16),Vector3(0.87,0.035,0.054),DARK,false,duct)

func prompt(action: String) -> String:
	match action:
		"cargo_manifest":return "CHECK MANIFEST"
		"cargo_clamps":return "RELEASE RECEIVING CLAMPS" if locked else "LOCK RECEIVING CLAMPS"
		"cargo_crate":return "PICK UP SERVICE CASE" if not locked else "RELEASE RECEIVING CLAMPS FIRST"
		"cargo_berth_0", "cargo_berth_1":
			var index: int = int(action.right(1))
			if carrying:return "PLACE CASE IN BERTH "+str(index+1)
			return "PICK UP SERVICE CASE" if crate_slot==index and not locked else "BERTH "+str(index+1)+(" / CLAMPED" if crate_slot==index else " / EMPTY")
	return ""

func use(action: String) -> void:
	if action=="cargo_manifest":
		explain("MANIFEST: 16 secured freight cases. Service case: "+("being carried." if carrying else "berth "+str(crate_slot+1)+(" / clamped." if locked else " / unsecured.")))
	elif action=="cargo_clamps":
		if carrying:
			explain("Place the service case in a receiving berth before clamping.")
			return
		locked = not locked
		_update_manifest()
		explain("Receiving clamps locked." if locked else "Receiving clamps released. Service case ready for handling.")
	elif action=="cargo_crate":
		_pick_up()
	elif action.begins_with("cargo_berth_"):
		var index: int = int(action.right(1))
		if carrying:_place(index)
		elif crate_slot==index:_pick_up()
		else:explain("Empty receiving berth. Bring the service case here.")

func _crate_intersects(transform: Transform3D, exclude: Array[RID] = []) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = CRATE_SIZE+Vector3(0.014,0.014,0.014)
	query.shape = shape
	query.transform = transform
	query.collision_mask = 1
	query.exclude = exclude
	return not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _pick_up() -> void:
	if carrying:return
	if locked:
		explain("Release the receiving clamps at the forward cargo control first.")
		return
	var actor: CharacterBody3D = host.player
	var desired := actor.global_transform*Transform3D(Basis.IDENTITY,CARRY_OFFSET)
	if _crate_intersects(desired,[crate_body.get_rid()]):
		explain("Step into the clear handling aisle to lift the case.")
		return
	carrying = true
	crate_body.collision_layer = 0
	crate_body.collision_mask = 0
	held_crate.reparent(actor,false)
	held_crate.position = CARRY_OFFSET
	held_crate.rotation = Vector3.ZERO
	carry_shape = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = CRATE_SIZE+Vector3(0.016,0.016,0.016)
	carry_shape.shape = shape
	carry_shape.position = CARRY_OFFSET
	actor.add_child(carry_shape)
	last_safe_yaw = actor.rotation.y
	last_safe_position = actor.global_position
	_update_manifest()
	explain("Carrying service case. Aim at a receiving berth and press F to place it.")

func _place(index: int) -> void:
	var pos: Vector3 = slots[index]
	var target := Transform3D(Basis.IDENTITY,pos)
	if _crate_intersects(target,[crate_body.get_rid()]):
		explain("The receiving berth is obstructed.")
		return
	# Never transfer through a bulkhead: the interaction ray must still reach its control.
	var actor: CharacterBody3D = host.player
	var control: StaticBody3D = use_targets["cargo_berth_"+str(index)]
	var distance := actor.global_position.distance_to(Vector3(control.global_position.x,actor.global_position.y,control.global_position.z))
	if distance>2.3:
		explain("Bring the case beside the receiving berth.")
		return
	carrying = false
	crate_slot = index
	if is_instance_valid(carry_shape):
		actor.remove_child(carry_shape)
		carry_shape.queue_free()
	carry_shape = null
	held_crate.reparent(self,false)
	held_crate.position = pos
	held_crate.rotation = Vector3.ZERO
	crate_body.collision_layer = 1
	crate_body.collision_mask = 1
	_update_manifest()
	explain("Service case placed in berth "+str(index+1)+". Lock the receiving clamps before flight.")

func _physics_process(_delta: float) -> void:
	validate_carry_rotation()

func validate_carry_rotation() -> void:
	if not carrying or not is_instance_valid(host.player):return
	var actor: CharacterBody3D = host.player
	var desired := actor.global_transform*Transform3D(Basis.IDENTITY,CARRY_OFFSET)
	if _crate_intersects(desired,[crate_body.get_rid()]):
		actor.rotation.y = last_safe_yaw
		desired = actor.global_transform*Transform3D(Basis.IDENTITY,CARRY_OFFSET)
		if _crate_intersects(desired,[crate_body.get_rid()]):actor.global_position = last_safe_position
		actor.velocity.x = 0
		actor.velocity.z = 0
		if Time.get_ticks_msec()>turn_notice_until:
			explain("The case needs more turning room.")
			turn_notice_until = Time.get_ticks_msec()+2200
	else:
		last_safe_yaw = actor.rotation.y
		last_safe_position = actor.global_position

func _update_manifest() -> void:
	if is_instance_valid(manifest):
		manifest.text = "LONGHAUL / FREIGHT REGISTER\n----------------------------\nRACKS     16 CASES / RESTRAINED\nHAND CASE "+("IN TRANSIT" if carrying else "BERTH 0"+str(crate_slot+1))+"\nCLAMPS    "+("LOCKED" if locked else "RELEASED")+"\n----------------------------\nHAND CASE / 0035 KG"
	if is_instance_valid(lock_label):lock_label.text = "CLAMP\n"+("LOCKED" if locked else "OPEN")
	for lamp in lock_lamps:lamp.material_override = host._material(GREEN if locked else AMBER,true)
	for child in get_children():
		if child.has_meta("jaw_side"):
			var side: float = child.get_meta("jaw_side")
			var center: float = child.get_meta("slot_center")
			var index: int = child.get_meta("slot_index")
			child.position.x = center+side*(0.285 if locked and crate_slot==index else 0.39)
