extends Node3D
## Compact service rooms for the walkable study, with usable doors and fittings.
const CREAM := Color("b4ab91")
const LIGHT := Color("d4c7a7")
const DARK := Color("292e2a")
const EDGE := Color("676454")
const ORANGE := Color("a95e2b")
const GREEN := Color("9bdfa6")
const PASSAGE_WIDTH := 1.32
const PARTITION_THICKNESS := 0.16
const PARTITION_CENTER_X := (PASSAGE_WIDTH + PARTITION_THICKNESS) / 2.0
var host: Node3D
var use_targets: Dictionary = {}
var doors: Dictionary = {}
var notice := ""
var notice_until := 0
var shower_flow: Node3D
var tap_flow: Node3D
var shower_on := false
var tap_on := false
var pressure_busy := false
var pressure_checked := false
var pressure_label: Label3D
var pressure_lamp: MeshInstance3D

func build(ship: Node3D) -> void:
	host = ship
	name = "LonghaulService"
	_shell()
	_partitions()
	preload("res://scripts/longhaul_washroom.gd").new().build(self)
	_airlock()
	_corridor()
	_ceiling()

func box(pos: Vector3, size: Vector3, color: Color, solid := false, parent: Node3D = self, glow := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = size
	mesh.mesh = geometry
	mesh.position = pos
	mesh.material_override = host._material(color,glow)
	parent.add_child(mesh)
	if solid: collider(pos,size,parent)
	return mesh

func collider(pos: Vector3, size: Vector3, parent: Node3D, action := "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	if action != "":
		body.set_meta("service_action",action)
		use_targets[action] = body
	return body

func group(pos: Vector3, yaw := 0.0) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = yaw
	add_child(node)
	return node

func label(words: String, pos: Vector3, scale_px := 0.0015, color := DARK, parent: Node3D = self) -> Label3D:
	var text := Label3D.new()
	text.font = host.font
	text.font_size = 64
	text.pixel_size = scale_px
	text.text = words
	text.modulate = color
	text.outline_size = 0
	text.position = pos
	parent.add_child(text)
	return text

func vent(pos: Vector3, width: float, parent: Node3D = self) -> void:
	box(pos,Vector3(width,0.25,0.055),EDGE,false,parent)
	for i in 4: box(pos+Vector3(0,-0.083+i*0.055,0.036),Vector3(width-0.08,0.023,0.025),DARK,false,parent)

func cabinet_face(pos: Vector3, size: Vector2, parent: Node3D, tint := CREAM) -> void:
	box(pos,Vector3(size.x,size.y,0.05),tint,false,parent)
	for x in [-size.x*0.39,size.x*0.39]:
		for y in [-size.y*0.39,size.y*0.39]:box(pos+Vector3(x,y,0.031),Vector3(0.024,0.024,0.012),EDGE,false,parent)
	box(pos+Vector3(0,-size.y*0.31,0.05),Vector3(size.x*0.35,0.033,0.045),DARK,false,parent)

func _shell() -> void:
	box(Vector3(0,-0.15,-2.5),Vector3(5.56,0.3,3),DARK,true)
	box(Vector3(0,2.5,-2.5),Vector3(5.56,0.2,3),CREAM,true)
	for x in [-2.70,2.70]:
		box(Vector3(x,1.2,-2.5),Vector3(0.16,2.4,3),CREAM,true)
		box(Vector3(x*1.04,0.68,-2.5),Vector3(0.06,0.46,2.83),ORANGE)
		for z in [-3.91,-1.09]:box(Vector3(x*1.04,1.2,z),Vector3(0.09,2.42,0.12),EDGE)
	for x in [-2.56,2.56]:
		box(Vector3(x,0.10,-2.5),Vector3(0.07,0.15,2.8),DARK)
		box(Vector3(x,2.26,-2.5),Vector3(0.07,0.09,2.8),ORANGE)
	for x in range(-3,3):
		for z in range(-4,-1):box(Vector3((x+0.5)*0.88,0.013,z+0.5),Vector3(0.855,0.025,0.975),Color("777162"))
	# Door-side module shoulders are fitted to the narrower hab, not hollow wings.
	for x in [-2.35,2.35]:
		box(Vector3(x,2.61,-2.5),Vector3(0.51,0.16,2.5),EDGE)
	# A sealed outer hatch sits directly in the pressure hull.
	var outer := group(Vector3(2.81,1.12,-2.5),PI/2)
	box(Vector3.ZERO,Vector3(1.48,2.24,0.12),DARK,false,outer)
	cabinet_face(Vector3(0,0,0.08),Vector2(1.24,2.0),outer,LIGHT)
	label("04 / AIRLOCK",Vector3(0,0.51,0.115),0.0018,DARK,outer)
	label("DOCK COLLAR",Vector3(0,0.30,0.115),0.0011,DARK,outer)

func _partitions() -> void:
	for side in [-1,1]:
		var x: float = side*PARTITION_CENTER_X
		for z in [-3.54,-1.46]:box(Vector3(x,1.2,z),Vector3(PARTITION_THICKNESS,2.4,0.92),CREAM,true)
		box(Vector3(x,2.28,-2.5),Vector3(0.18,0.24,1.16),DARK,true)
		for z in [-3.08,-1.92]:box(Vector3(x,1.08,z),Vector3(0.22,2.16,0.06),ORANGE)
		# Flat threshold and exposed track occupy no foot or shoulder clearance.
		box(Vector3(x,0.029,-2.5),Vector3(0.26,0.009,1.12),EDGE)
		var key := "wash" if side<0 else "air"
		var leaves: Array[Node3D] = []
		for sign_z in [-1,1]:
			var leaf := group(Vector3(x,1.085,-2.5+sign_z*0.88))
			box(Vector3.ZERO,Vector3(0.075,2.10,0.57),EDGE,true,leaf)
			for face in [-1,1]:
				box(Vector3(face*0.043,0,0),Vector3(0.018,1.94,0.49),LIGHT,false,leaf)
				box(Vector3(face*0.056,0.64,0),Vector3(0.012,0.12,0.43),ORANGE,false,leaf)
				box(Vector3(face*0.056,-0.60,0),Vector3(0.013,0.035,0.42),DARK,false,leaf)
			leaves.append(leaf)
		doors[key] = {"open":true,"moving":false,"leaves":leaves,"x":x,"tween":null}
		for face in [-1,1]:
			var sign_x: int = side*face
			var mount := group(Vector3(x+sign_x*0.111,1.42,-1.62),PI/2 if sign_x>0 else -PI/2)
			box(Vector3.ZERO,Vector3(0.30,0.42,0.055),DARK,false,mount)
			box(Vector3(0,0.11,0.035),Vector3(0.21,0.085,0.018),GREEN,false,mount,true)
			box(Vector3(0,-0.08,0.043),Vector3(0.17,0.15,0.036),ORANGE,false,mount)
			var action := key+"_door" if face<0 else key+"_inside"
			collider(Vector3(0,0,0.04),Vector3(0.30,0.42,0.075),mount,action)
			label("DOOR",Vector3(0,-0.09,0.065),0.00105,LIGHT,mount)
		var title := group(Vector3(x-side*0.115,2.26,-2.5),-PI/2 if side>0 else PI/2)
		label("03 / WASH" if side<0 else "04 / AIRLOCK",Vector3(0,0,0.015),0.0015,LIGHT,title)

func _airlock() -> void:
	# Hatch stays sealed in the art study; a separate seal-check control tests the interlock.
	var hatch := group(Vector3(2.56,1.11,-2.5),-PI/2)
	box(Vector3.ZERO,Vector3(1.39,2.20,0.09),DARK,false,hatch)
	collider(Vector3(0,0,0.06),Vector3(1.42,2.22,0.24),hatch)
	cabinet_face(Vector3(0,0,0.07),Vector2(1.19,1.99),hatch,LIGHT)
	box(Vector3(0,0.17,0.107),Vector3(0.07,1.38,0.045),EDGE,false,hatch)
	for x in [-0.52,0.52]:
		for y in [-0.69,0,0.69]:
			box(Vector3(x,y,0.12),Vector3(0.15,0.17,0.10),ORANGE,false,hatch)
	box(Vector3(0,0.52,0.115),Vector3(0.43,0.32,0.035),DARK,false,hatch)
	box(Vector3(0,0.52,0.139),Vector3(0.33,0.23,0.016),Color("173a42"),false,hatch)
	label("OUTER\nHATCH",Vector3(-0.265,-0.08,0.141),0.00125,DARK,hatch)
	label("SEALED\nNO DOCK",Vector3(0.265,-0.08,0.141),0.0011,DARK,hatch)
	# Inset floor grid gives room to turn with a suit on and nothing to step over.
	box(Vector3(1.70,0.030,-2.5),Vector3(1.45,0.01,1.12),DARK)
	for i in 10:box(Vector3(1.12+i*0.13,0.037,-2.5),Vector3(0.055,0.006,1.02),EDGE)
	# A fitted suit rack on the forward bulkhead keeps the outer hatch approach clear.
	var rack := group(Vector3(1.73,0,-3.83))
	box(Vector3(0,1.16,0.05),Vector3(1.59,2.28,0.14),DARK,true,rack)
	for x in [-0.78,0.78]:box(Vector3(x,1.13,0.15),Vector3(0.065,2.22,0.22),EDGE,false,rack)
	box(Vector3(0,0.20,0.21),Vector3(1.49,0.35,0.42),EDGE,true,rack)
	label("SUIT / READY RACK",Vector3(0,2.23,0.22),0.00125,LIGHT,rack)
	# Chunky pressure suit retained by a visible harness; removable gear has a home.
	box(Vector3(-0.23,1.34,0.26),Vector3(0.52,0.61,0.33),ORANGE,false,rack)
	box(Vector3(-0.23,1.67,0.25),Vector3(0.29,0.10,0.28),EDGE,false,rack)
	box(Vector3(-0.23,1.87,0.25),Vector3(0.45,0.38,0.37),LIGHT,false,rack)
	box(Vector3(-0.23,1.88,0.445),Vector3(0.34,0.19,0.035),Color("15323a"),false,rack)
	for x in [-0.39,-0.07]:
		box(Vector3(x,0.80,0.25),Vector3(0.23,0.52,0.30),ORANGE,false,rack)
		box(Vector3(x,0.76,0.41),Vector3(0.19,0.16,0.025),EDGE,false,rack)
		box(Vector3(x,0.47,0.31),Vector3(0.25,0.20,0.44),DARK,false,rack)
	for x in [-0.57,0.11]:
		box(Vector3(x,1.27,0.27),Vector3(0.16,0.50,0.25),ORANGE,false,rack)
		box(Vector3(x,1.055,0.27),Vector3(0.17,0.10,0.27),DARK,false,rack)
	box(Vector3(-0.23,1.41,0.445),Vector3(0.27,0.28,0.035),LIGHT,false,rack)
	box(Vector3(-0.23,1.45,0.467),Vector3(0.20,0.09,0.013),DARK,false,rack)
	label("O2 / 100",Vector3(-0.23,1.45,0.478),0.00055,GREEN,rack)
	for x in [-0.30,-0.22,-0.14]:box(Vector3(x,1.345,0.471),Vector3(0.044,0.045,0.025),EDGE,false,rack)
	for x in [-0.43,-0.03]:box(Vector3(x,1.35,0.465),Vector3(0.05,0.59,0.022),DARK,false,rack)
	for y in [0.64,1.22,1.80]:
		cabinet_face(Vector3(0.50,y,0.17),Vector2(0.38,0.50),rack)
		label({0.64:"TOOLS",1.22:"O2",1.80:"COMMS"}[y],Vector3(0.50,y+0.055,0.205),0.00095,DARK,rack)
	# Physical restraint envelope matches the rack rather than dozens of tiny colliders.
	collider(Vector3(-0.23,1.20,0.28),Vector3(0.87,1.68,0.40),rack)
	# Aft service bank: scrubber below, diagnostic CRT and valves at standing height.
	var bank := group(Vector3(1.74,0,-1.17),PI)
	box(Vector3(0,1.10,0.055),Vector3(1.54,2.20,0.15),DARK,true,bank)
	box(Vector3(0,0.51,0.17),Vector3(1.45,0.86,0.23),EDGE,true,bank)
	for x in [-0.36,0.36]:
		cabinet_face(Vector3(x,0.44,0.30),Vector2(0.65,0.60),bank)
		label("AIR" if x<0 else "FILTER",Vector3(x,0.50,0.332),0.00125,DARK,bank)
	vent(Vector3(0,0.96,0.13),1.39,bank)
	box(Vector3(-0.26,1.55,0.16),Vector3(0.89,0.64,0.23),CREAM,false,bank)
	collider(Vector3(-0.26,1.55,0.16),Vector3(0.89,0.64,0.23),bank)
	box(Vector3(-0.26,1.57,0.282),Vector3(0.76,0.48,0.026),Color("0b211a"),false,bank)
	pressure_label = label("CABIN / 101 kPa\nINNER OPEN\nOUTER SEALED",Vector3(-0.26,1.58,0.304),0.00115,GREEN,bank)
	for x in [-0.53,-0.26,0.01]:box(Vector3(x,1.19,0.21),Vector3(0.18,0.07,0.12),EDGE,false,bank)
	label("SEAL TEST",Vector3(0.49,1.77,0.17),0.0011,LIGHT,bank)
	pressure_lamp = box(Vector3(0.49,1.57,0.19),Vector3(0.17,0.10,0.05),GREEN,false,bank,true)
	box(Vector3(0.49,1.35,0.20),Vector3(0.25,0.23,0.07),ORANGE,false,bank)
	collider(Vector3(0.49,1.35,0.20),Vector3(0.27,0.26,0.09),bank,"pressure")
	label("TEST",Vector3(0.49,1.35,0.241),0.0012,LIGHT,bank)
	vent(Vector3(0,2.10,0.12),1.35,bank)

func _corridor() -> void:
	# Narrow distribution cabinets on the fixed partition wings, clear of door pockets.
	for side in [-1,1]:
		for z in [-3.60,-1.42]:
			var plate := group(Vector3(side*0.641,1.09,z),PI/2 if side<0 else -PI/2)
			var low: bool = z > -2
			cabinet_face(Vector3(0,-0.34 if low else 0,0),Vector2(0.58,0.58 if low else 1.08),plate)
			label("WATER" if side<0 else "POWER",Vector3(0,-0.22 if low else 0.30,0.037),0.0011,DARK,plate)
			vent(Vector3(0,-0.45 if low else -0.32,0.04),0.49,plate)
			# Handhold and small circuit cover above the main access door.
			box(Vector3(0,0.79,0.045),Vector3(0.42,0.035,0.05),ORANGE,false,plate)
			box(Vector3(0,1.01,0.012),Vector3(0.55,0.17,0.03),DARK,false,plate)
			for i in 4:box(Vector3(-0.18+i*0.12,1.01,0.037),Vector3(0.035,0.08,0.026),LIGHT,false,plate)
	for z in [-3.80,-1.20]:
		box(Vector3(0,0.034,z),Vector3(1.05,0.009,0.08),ORANGE)
	for x in [-0.48,0.48]:box(Vector3(x,0.028,-2.5),Vector3(0.025,0.006,2.55),EDGE)

func _ceiling() -> void:
	for x in [-1.73,0,1.73]:
		box(Vector3(x,2.34,-2.5),Vector3(0.66,0.12,0.83),DARK)
		box(Vector3(x,2.268,-2.5),Vector3(0.49,0.025,0.63),Color("e8e3c3"),false,self,true)
		host._lamp(Vector3(x,2.12,-2.5),0.72 if x!=0 else 0.46,2.6,Color("e1e9db") if x<0 else Color("ffe0ac"),true)
		for z in [-3.35,-1.78]:
			box(Vector3(x,2.34,z),Vector3(0.82,0.12,0.58),EDGE)
			for i in 6:box(Vector3(x-0.29+i*0.115,2.267,z),Vector3(0.05,0.025,0.44),DARK)
	for x in [-2.38,-1.03,-0.48,0.48,1.03,2.38]:
		var room_run: bool = absf(x) > 1.0
		box(Vector3(x,2.32,-2.5),Vector3(0.08,0.09,1.70 if room_run else 2.80),DARK)
		for z in ([-3.27,-2.5,-1.73] if room_run else [-3.67,-2.5,-1.33]):
			box(Vector3(x,2.258,z),Vector3(0.13,0.04,0.08),EDGE)

func interaction(camera: Camera3D, player: CharacterBody3D) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*2.1,1,[player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.has_meta("service_action"): return {}
	var action: String = hit.collider.get_meta("service_action")
	var prompt := ""
	if action.begins_with("wash_") or action.begins_with("air_"):
		var key := "wash" if action.begins_with("wash_") else "air"
		prompt = ("Close " if doors[key].open else "Open ") + ("washroom door" if key=="wash" else "inner airlock hatch")
	elif action=="shower": prompt = "Stop shower" if shower_on else "Run shower"
	elif action=="tap": prompt = "Stop tap" if tap_on else "Run tap"
	elif action=="pressure": prompt = "Check airlock seals"
	return {"action":action,"label":prompt}

func use(action: String) -> void:
	notice = ""
	if action.begins_with("wash_") or action.begins_with("air_"):
		_toggle_door("wash" if action.begins_with("wash_") else "air")
	elif action=="shower":
		shower_on = not shower_on
		shower_flow.visible = shower_on
	elif action=="tap":
		tap_on = not tap_on
		tap_flow.visible = tap_on
	elif action=="pressure":
		_check_seals()

func _toggle_door(key: String) -> void:
	var door: Dictionary = doors[key]
	if door.moving: return
	if key=="air" and pressure_busy:
		_explain("Seal check running — wait for the green light")
		return
	if door.open and _occupied(Vector3(door.x,1.08,-2.5),Vector3(0.65,2.18,1.22)):
		_explain("Step clear of the doorway to close it")
		return
	door.open = not door.open
	door.moving = true
	if key=="air":
		pressure_checked = false
		_update_pressure()
	var tween := create_tween().set_parallel(true)
	door.tween = tween
	for i in 2:
		var offset := 0.88 if door.open else 0.285
		tween.tween_property(door.leaves[i],"position:z",-2.5+(-1 if i==0 else 1)*offset,0.40)
	tween.chain().tween_callback(func(): door.moving = false)

func _physics_process(_delta: float) -> void:
	# Re-open if someone enters the sweep after pressing the close button.
	for key in doors:
		var door: Dictionary = doors[key]
		if door.moving and not door.open and _occupied(Vector3(door.x,1.08,-2.5),Vector3(0.65,2.18,1.22)):
			door.tween.kill()
			door.moving = false
			_toggle_door(key)
			_explain("Doorway occupied — reopening")

func _occupied(center: Vector3, size: Vector3) -> bool:
	var shape := BoxShape3D.new()
	shape.size = size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = global_transform * Transform3D(Basis.IDENTITY,center)
	query.collision_mask = 2
	return not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _check_seals() -> void:
	if pressure_busy: return
	if doors.air.open or doors.air.moving:
		_explain("Close the inner hatch before checking the seals")
		return
	pressure_busy = true
	pressure_checked = false
	_update_pressure()
	await get_tree().create_timer(2.4,false,true).timeout
	pressure_busy = false
	pressure_checked = true
	_update_pressure()

func _update_pressure() -> void:
	if pressure_label==null: return
	pressure_label.text = "CABIN / 101 kPa\n" + ("CHECKING SEALS..." if pressure_busy else ("SEALS / OK" if pressure_checked else ("INNER OPEN" if doors.air.open else "INNER SEALED"))) + "\nOUTER SEALED"
	pressure_lamp.material_override = host._material(ORANGE if pressure_busy else GREEN,true)

func _explain(message: String) -> void:
	notice = message
	notice_until = Time.get_ticks_msec()+2600
