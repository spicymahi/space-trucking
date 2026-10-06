extends Node3D
## Compact liveaboard art module. Furniture interactions demonstrate clearance;
## survival simulation remains in the separate gameplay slice.
const CREAM := Color("b4ab91")
const LIGHT := Color("d4c7a7")
const DARK := Color("292e2a")
const EDGE := Color("676454")
const ORANGE := Color("a95e2b")
const CLOTH := Color("aa843e")
const GREEN := Color("9bdfa6")
var host: Node3D
var table_pivot: Node3D
var drawer: Node3D
var reading_light: OmniLight3D
var reading_lens: MeshInstance3D
var notice := ""
var notice_until := 0
var table_folded := false
var drawer_open := false
var lamp_on := true
var furniture_tween: Tween
var drawer_tween: Tween
var use_targets: Dictionary = {}

func build(ship: Node3D) -> void:
	host = ship
	name = "LonghaulHab"
	_shell()
	_bunk()
	_galley()
	_dinette()
	_utility()
	_bulkhead_equipment()
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
		body.set_meta("hab_action",action)
		use_targets[action] = body
	return body

func group(pos: Vector3, yaw := 0.0) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = yaw
	add_child(node)
	return node

func label(words: String, pos: Vector3, scale_px := 0.0015, color := DARK, parent: Node3D = self) -> void:
	var text := Label3D.new()
	text.font = host.font
	text.font_size = 64
	text.pixel_size = scale_px
	text.text = words
	text.modulate = color
	text.outline_size = 0
	text.position = pos
	parent.add_child(text)

func vent(pos: Vector3, width: float, parent: Node3D = self) -> void:
	box(pos,Vector3(width,0.25,0.055),EDGE,false,parent)
	for i in 4: box(pos+Vector3(0,-0.083+i*0.055,0.036),Vector3(width-0.08,0.023,0.025),DARK,false,parent)

func cabinet_face(pos: Vector3, size: Vector2, parent: Node3D, tint := CREAM) -> void:
	box(pos,Vector3(size.x,size.y,0.05),tint,false,parent)
	for x in [-size.x*0.39,size.x*0.39]:
		for y in [-size.y*0.39,size.y*0.39]:box(pos+Vector3(x,y,0.031),Vector3(0.024,0.024,0.012),EDGE,false,parent)
	box(pos+Vector3(0,-size.y*0.31,0.05),Vector3(size.x*0.35,0.033,0.045),DARK,false,parent)

func _shell() -> void:
	box(Vector3(0,-0.15,-6.5),Vector3(4.06,0.3,5.0),DARK,true)
	box(Vector3(0,2.5,-6.5),Vector3(4.06,0.2,5.0),CREAM,true)
	# Port has a bunk window and a smaller dining window. The galley wall is equipment.
	box(Vector3(2.0,1.2,-6.5),Vector3(0.16,2.4,5),CREAM,true)
	box(Vector3(-2.0,0.53,-6.5),Vector3(0.16,1.06,5),CREAM,true)
	box(Vector3(-2.0,2.19,-6.5),Vector3(0.16,0.42,5),CREAM,true)
	for segment in [Vector2(-8.73,0.54),Vector2(-6.03,0.86),Vector2(-4.34,0.68)]:
		box(Vector3(-2.0,1.52,segment.x),Vector3(0.16,0.92,segment.y),CREAM,true)
	for pane in [Vector2(-7.455,2.01),Vector2(-5.14,0.90)]:
		var glass := box(Vector3(-2,1.52,pane.x),Vector3(0.035,0.92,pane.y),Color("112c37"),true)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.08,0.16,0.20,0.13)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glass.material_override = material
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for y in [1.065,1.975]:box(Vector3(-1.90,y,pane.x),Vector3(0.10,0.065,pane.y+0.09),DARK)
		for z in [pane.x-pane.y/2,pane.x+pane.y/2]:box(Vector3(-1.90,1.52,z),Vector3(0.10,0.94,0.065),DARK)
		box(Vector3(-1.84,1.03,pane.x),Vector3(0.20,0.07,pane.y+0.1),ORANGE)
	for x in [-1.88,1.88]:
		box(Vector3(x,0.12,-6.5),Vector3(0.06,0.16,4.86),DARK)
		box(Vector3(x,2.28,-6.5),Vector3(0.055,0.08,4.87),ORANGE)
	for z in [-8.96,-6.25,-4.04]:
		for x in [-1.91,1.91]: box(Vector3(x,1.2,z),Vector3(0.065,2.4,0.06),EDGE)
	for x in range(-2,2):
		for z in range(-9,-4):box(Vector3(x+0.5,0.012,z+0.5),Vector3(0.975,0.024,0.975),Color("777162"))
	# Exterior follows the smaller hab, including the orange equipment belt.
	for x in [-2.10,2.10]:
		box(Vector3(x,0.70,-6.5),Vector3(0.035,0.50,4.89),ORANGE)
		for z in [-8.86,-6.25,-4.14]: box(Vector3(x,1.22,z),Vector3(0.055,2.4,0.10),EDGE)
	box(Vector3(0,2.68,-6.5),Vector3(1.7,0.18,1.5),EDGE)
	for i in 6:box(Vector3(0,2.80,-7.02+i*0.20),Vector3(1.43,0.045,0.055),DARK)

func _bunk() -> void:
	# 2.12m mattress, tucked against the window; drawers open toward the usable aisle.
	box(Vector3(-1.32,0.28,-7.47),Vector3(1.16,0.56,2.24),DARK,true)
	box(Vector3(-1.32,0.59,-7.47),Vector3(1.12,0.10,2.17),LIGHT,true)
	box(Vector3(-1.32,0.69,-7.30),Vector3(1.10,0.13,1.78),CLOTH)
	for z in [-7.93,-7.45,-6.98]:box(Vector3(-1.32,0.76,z),Vector3(1.08,0.012,0.025),Color("856d3f"))
	box(Vector3(-1.32,0.72,-8.20),Vector3(0.83,0.20,0.37),Color("e6dcc4"))
	box(Vector3(-1.32,1.0,-8.63),Vector3(1.16,0.93,0.13),EDGE,true)
	var headboard := group(Vector3(-1.32,1.0,-8.55))
	label("BUNK / 01",Vector3(0,0.29,0.045),0.0014,LIGHT,headboard)
	box(Vector3(-1.31,0.5,-8.83),Vector3(1.13,1.0,0.22),EDGE,true)
	# A shallow overhead locker cannot collide with the standing aisle.
	box(Vector3(-1.62,2.14,-7.46),Vector3(0.58,0.40,2.17),DARK,true)
	var top := group(Vector3(-1.305,2.14,-7.46),PI/2)
	for i in 3:
		var x := -0.71+i*0.71
		cabinet_face(Vector3(x,0,0),Vector2(0.68,0.35),top)
		label(["LINEN","PERSONAL","SPARES"][i],Vector3(x,0.035,0.032),0.0010,DARK,top)
	# One working drawer plus a second closed drawer; no full-depth hinged obstruction.
	drawer = group(Vector3(-0.715,0.27,-7.97),PI/2)
	box(Vector3(0,0,-0.26),Vector3(0.77,0.36,0.48),EDGE,false,drawer)
	cabinet_face(Vector3(0,0,0),Vector2(0.77,0.36),drawer)
	collider(Vector3(0,0,-0.21),Vector3(0.78,0.37,0.50),drawer,"drawer")
	var fixed_drawer := group(Vector3(-0.715,0.27,-6.91),PI/2)
	cabinet_face(Vector3.ZERO,Vector2(1.02,0.36),fixed_drawer)
	label("CLOTHES",Vector3(0,0.04,0.045),0.0012,DARK,drawer)
	label("TOOLS / LINEN",Vector3(0,0.04,0.045),0.0012,DARK,fixed_drawer)
	# Reading light and a physical switch reachable while beside the bed.
	var lamp := group(Vector3(-1.89,1.42,-8.34),PI/2)
	box(Vector3.ZERO,Vector3(0.18,0.30,0.08),DARK,false,lamp)
	reading_lens = box(Vector3(0,0.07,0.07),Vector3(0.13,0.11,0.08),Color("ffe0a3"),false,lamp,true)
	box(Vector3(0,-0.09,0.06),Vector3(0.06,0.065,0.045),ORANGE,false,lamp)
	collider(Vector3(0,0,0.06),Vector3(0.22,0.34,0.16),lamp,"lamp")
	reading_light = OmniLight3D.new()
	reading_light.position = Vector3(-1.54,1.42,-8.18)
	reading_light.light_color = Color("ffc57d")
	reading_light.light_energy = 0.34
	reading_light.omni_range = 1.7
	add_child(reading_light)

func _galley() -> void:
	# Counter ends before the aft utility bank, leaving a continuous working aisle.
	box(Vector3(1.46,0.46,-7.46),Vector3(0.91,0.92,2.45),DARK,true)
	box(Vector3(1.41,0.965,-7.46),Vector3(1.02,0.09,2.49),LIGHT,true)
	var base := group(Vector3(0.982,0.47,-7.46),-PI/2)
	for i in 3:
		var x := -0.83+i*0.83
		cabinet_face(Vector3(x,0,0),Vector2(0.78,0.83),base,ORANGE if i==1 else CREAM)
		label(["WATER","WASTE","STORES"][i],Vector3(x,0.12,0.036),0.0013,DARK,base)
	# Recessed sink with raised rim and a squared mixing tap.
	box(Vector3(1.40,1.016,-8.12),Vector3(0.64,0.016,0.55),DARK)
	box(Vector3(1.40,1.020,-8.12),Vector3(0.51,0.017,0.43),Color("637b78"))
	box(Vector3(1.77,1.19,-8.12),Vector3(0.065,0.34,0.065),EDGE)
	box(Vector3(1.64,1.35,-8.12),Vector3(0.29,0.065,0.065),EDGE)
	for z in [-8.32,-7.92]:box(Vector3(1.74,1.06,z),Vector3(0.11,0.055,0.11),DARK)
	# Induction/heating plate and coffee unit, with guarded physical controls.
	box(Vector3(1.42,1.023,-7.02),Vector3(0.63,0.025,0.62),DARK)
	for z in [-7.19,-6.87]:
		box(Vector3(1.43,1.04,z),Vector3(0.42,0.014,0.22),EDGE)
		box(Vector3(1.07,1.043,z),Vector3(0.08,0.035,0.08),ORANGE)
	box(Vector3(1.66,1.24,-6.48),Vector3(0.42,0.48,0.28),EDGE)
	box(Vector3(1.43,1.30,-6.48),Vector3(0.035,0.15,0.18),DARK)
	box(Vector3(1.43,1.40,-6.48),Vector3(0.045,0.045,0.045),GREEN,false,self,true)
	box(Vector3(1.40,1.09,-6.48),Vector3(0.14,0.18,0.14),ORANGE)
	# Appliance and food lockers stay above the counter footprint.
	box(Vector3(1.67,2.04,-7.46),Vector3(0.49,0.58,2.45),DARK,true)
	var upper := group(Vector3(1.41,2.04,-7.46),-PI/2)
	for x in [-0.83,0,0.83]:cabinet_face(Vector3(x,0,0),Vector2(0.78,0.52),upper)
	label("FOOD / DRY STORES",Vector3(0,0.03,0.038),0.0013,DARK,upper)
	box(Vector3(1.61,1.71,-7.46),Vector3(0.39,0.025,2.33),Color("ffe0a4"),false,self,true)
	host._lamp(Vector3(1.08,1.62,-7.5),0.32,2.0,Color("ffe0ac"))
	# Service backsplash: extractor, water filter and short connected feed lines.
	var back := group(Vector3(1.906,1.40,-7.36),-PI/2)
	box(Vector3.ZERO,Vector3(2.22,0.45,0.04),CREAM,false,back)
	vent(Vector3(-0.48,0,0.055),0.80,back)
	label("EXTRACT",Vector3(-0.48,0.18,0.065),0.0010,DARK,back)
	for x in [0.27,0.59,0.88]:
		box(Vector3(x,0.0,0.085),Vector3(0.15,0.29,0.13),LIGHT,false,back)
		box(Vector3(x,-0.16,0.10),Vector3(0.18,0.045,0.14),EDGE,false,back)
	box(Vector3(0.57,0.19,0.08),Vector3(0.78,0.045,0.06),ORANGE,false,back)

func _dinette() -> void:
	# Bunk foot doubles as the work terminal wall; no extra desk room is needed.
	box(Vector3(-1.31,0.84,-6.24),Vector3(1.16,1.68,0.13),EDGE,true)
	var terminal_access := group(Vector3(-1.31,1.32,-6.323),PI)
	cabinet_face(Vector3.ZERO,Vector2(0.91,0.52),terminal_access)
	label("TERMINAL / SERVICE",Vector3(0,0.04,0.033),0.00105,DARK,terminal_access)
	vent(Vector3(0,-0.39,0.02),0.88,terminal_access)
	box(Vector3(-1.29,1.25,-6.15),Vector3(0.71,0.49,0.16),CREAM)
	box(Vector3(-1.29,1.25,-6.056),Vector3(0.60,0.37,0.035),DARK)
	var screen := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55,0.33)
	screen.mesh = quad
	screen.position = Vector3(-1.29,1.25,-6.032)
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/cockpit/status.png")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen.material_override = material
	add_child(screen)
	label("HAB / PERSONAL TERMINAL",Vector3(-1.29,1.55,-6.158),0.0011,LIGHT)
	vent(Vector3(-1.29,0.84,-6.157),0.87)
	# Bench cushions and under-seat provisions.
	box(Vector3(-1.24,0.25,-4.49),Vector3(1.18,0.50,0.51),DARK,true)
	box(Vector3(-1.24,0.54,-4.49),Vector3(1.13,0.14,0.48),CLOTH)
	collider(Vector3(-1.24,0.56,-4.49),Vector3(1.13,0.17,0.49),self,"bench")
	box(Vector3(-1.24,0.93,-4.23),Vector3(1.13,0.78,0.12),CLOTH,true)
	for x in [-1.53,-0.95]:box(Vector3(x,0.93,-4.158),Vector3(0.03,0.69,0.015),EDGE)
	label("PROVISIONS",Vector3(-1.24,0.23,-4.215),0.00125,LIGHT)
	# Wall-hinged table: folds upward into the window recess, never into the corridor.
	table_pivot = group(Vector3(-1.83,0.80,-5.18))
	table_pivot.name = "FoldingTable"
	box(Vector3(0.57,0,0),Vector3(1.14,0.07,0.67),LIGHT,false,table_pivot)
	box(Vector3(0.57,-0.052,0),Vector3(1.07,0.035,0.60),EDGE,false,table_pivot)
	collider(Vector3(0.57,0,0),Vector3(1.14,0.085,0.67),table_pivot,"table")
	box(Vector3(0.10,-0.15,0),Vector3(0.12,0.32,0.37),DARK,false,table_pivot)
	for z in [-0.23,0.23]:box(Vector3(0.06,-0.04,z),Vector3(0.12,0.13,0.11),ORANGE,false,table_pivot)
	# A retained rubber pad and integrated keys keep the foldaway surface unobstructed.
	box(Vector3(0.62,0.042,-0.14),Vector3(0.65,0.012,0.28),DARK,false,table_pivot)
	for row in 3:
		for col in 7:box(Vector3(0.36+col*0.083,0.057,-0.225+row*0.071),Vector3(0.062,0.023,0.048),CREAM,false,table_pivot)
	# Small secured personal shelf above the dining window.
	box(Vector3(-1.69,2.14,-5.13),Vector3(0.47,0.35,1.02),DARK,true)
	var shelf := group(Vector3(-1.44,2.14,-5.13),PI/2)
	for i in 6:box(Vector3(-0.36+i*0.13,0,0.02),Vector3(0.10,0.26,0.16),[CREAM,ORANGE,Color("708372")][i%3],false,shelf)
	box(Vector3(0,-0.06,0.14),Vector3(0.94,0.045,0.03),EDGE,false,shelf)

func _utility() -> void:
	bank = group(Vector3(1.43,0,-5.18),-PI/2)
	box(Vector3(0,1.18,-0.015),Vector3(1.62,2.36,0.93),DARK,true,bank)
	# Refrigeration and wardrobe share a cabinet grid and top service ventilation.
	cabinet_face(Vector3(-0.42,0.88,0.475),Vector2(0.76,1.46),bank,CREAM)
	cabinet_face(Vector3(0.42,0.88,0.475),Vector2(0.76,1.46),bank,ORANGE)
	label("COLD / 04 C",Vector3(-0.42,1.27,0.51),0.00125,DARK,bank)
	label("PERSONAL",Vector3(0.42,1.27,0.51),0.00125,DARK,bank)
	for x in [-0.42,0.42]:
		vent(Vector3(x,1.82,0.49),0.68,bank)
		cabinet_face(Vector3(x,2.16,0.48),Vector2(0.75,0.29),bank)
	box(Vector3(-0.40,1.49,0.51),Vector3(0.22,0.11,0.025),DARK,false,bank)
	label("04",Vector3(-0.4,1.49,0.529),0.0014,GREEN,bank)
	# 17cm gap is allocated to the insulated cabinet/frame, not a loose furniture aisle.
	box(Vector3(1.88,1.20,-6.09),Vector3(0.07,2.4,0.10),EDGE)

var bank: Node3D

func _bulkhead_equipment() -> void:
	for z in [-8.87,-4.13]:
		for side in [-1,1]:
			var panel := group(Vector3(side*1.40,1.70,z),0 if z<-6 else PI)
			box(Vector3.ZERO,Vector3(0.92,0.95,0.055),DARK,false,panel)
			cabinet_face(Vector3(0,0.15,0.045),Vector2(0.83,0.54),panel)
			label("HAB / AIR" if side<0 else "WATER / HEAT",Vector3(0,0.16,0.079),0.0011,DARK,panel)
			vent(Vector3(0,-0.29,0.055),0.79,panel)
	# Door-side lamp, isolation lever and local status; no buttons hidden behind furniture.
	for z in [-8.87,-4.13]:
		var control := group(Vector3(0.82,1.40,z),0 if z<-6 else PI)
		box(Vector3.ZERO,Vector3(0.15,0.47,0.055),EDGE,false,control)
		for y in [-0.12,0.03,0.18]:box(Vector3(0,y,0.05),Vector3(0.07,0.06,0.05),GREEN if y>0 else ORANGE,false,control,y>0)
	# Runner stops short of both doors; its edges align to the central circulation lane.
	box(Vector3(0,0.028,-6.48),Vector3(1.18,0.025,3.83),Color("796443"))
	for z in [-8.30,-4.66]:box(Vector3(0,0.046,z),Vector3(1.12,0.01,0.045),ORANGE)

func _ceiling() -> void:
	for z in [-8.08,-6.41,-4.79]:
		box(Vector3(0,2.34,z),Vector3(0.93,0.13,0.53),DARK)
		box(Vector3(0,2.265,z),Vector3(0.74,0.025,0.38),Color("ffe0aa"),false,self,true)
		host._lamp(Vector3(0,2.12,z),0.65,3.0,Color("ffdfa9"),true)
	for x in [-0.79,0.79]:
		box(Vector3(x,2.34,-6.5),Vector3(0.10,0.10,4.87),DARK)
		for z in [-8.5,-7.5,-6.5,-5.5,-4.5]:box(Vector3(x,2.275,z),Vector3(0.16,0.05,0.085),EDGE)
	for x in [-1.37,1.37]:
		for z in [-8.36,-7.05,-5.74,-4.42]:
			box(Vector3(x,2.34,z),Vector3(0.76,0.12,0.66),EDGE)
			for i in 6:box(Vector3(x-0.26+i*0.105,2.268,z),Vector3(0.05,0.025,0.49),DARK)
	for z in [-8.8,-7.9,-7.0,-6.1,-5.2,-4.3]:box(Vector3(0,2.386,z),Vector3(3.80,0.025,0.04),EDGE)

func interaction(camera: Camera3D, player: CharacterBody3D) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*2.3,1,[player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.has_meta("hab_action"): return {}
	var action: String = hit.collider.get_meta("hab_action")
	var prompts := {"bench":"Sit at the dining nook","table":"Fold table" if not table_folded else "Lower table","drawer":"Close bunk drawer" if drawer_open else "Open bunk drawer","lamp":"Switch reading light"}
	return {"action":action,"label":prompts[action]}

func use(action: String) -> void:
	notice = ""
	match action:
		"table":
			if _occupied(Vector3(-1.26,1.35,-5.18),Vector3(1.23,1.23,0.67)):
				_explain_clearance("Step clear of the table to fold or lower it")
				return
			table_folded = not table_folded
			if furniture_tween: furniture_tween.kill()
			furniture_tween = create_tween()
			furniture_tween.tween_property(table_pivot,"rotation:z",PI/2 if table_folded else 0.0,0.3)
		"drawer":
			if not drawer_open and _occupied(Vector3(-0.765,0.27,-7.97),Vector3(0.84,0.39,0.80)):
				_explain_clearance("Step back to open the bunk drawer")
				return
			drawer_open = not drawer_open
			if drawer_tween: drawer_tween.kill()
			drawer_tween = create_tween()
			drawer_tween.tween_property(drawer,"position:x",-0.395 if drawer_open else -0.715,0.25)
		"lamp":
			lamp_on = not lamp_on
			reading_light.visible = lamp_on
			reading_lens.material_override = host._material(Color("ffe0a3") if lamp_on else Color("8d8570"),lamp_on)

func _occupied(center: Vector3, size: Vector3) -> bool:
	# Include the sweep, not just the end position, so folding hardware stays safe.
	var shape := BoxShape3D.new()
	shape.size = size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = global_transform * Transform3D(Basis.IDENTITY,center)
	query.collision_mask = 2
	return not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _explain_clearance(message: String) -> void:
	notice = message
	notice_until = Time.get_ticks_msec() + 2500
