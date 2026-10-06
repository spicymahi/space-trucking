extends Node3D
## Reusable cockpit art assembly. Consoles are illustrative until wired to flight state.
const IVORY = Color("b4ab91")
const EDGE = Color("615e50")
const BLACK = Color("252b29")
const ORANGE = Color("a65e27")
const GOLD = Color("af833a")
const GREEN = Color("94e7a8")
const AMBER = Color("efc06b")
var host: Node3D
const PILOT_Z := -11.55
var monitor_faces: Array[Node3D] = []

func build(owner_ship: Node3D) -> void:
	host = owner_ship
	_forward_assembly(_window, -1.4)
	_pilot_station()
	_rack(-1)
	_rack(1)
	_overhead()
	_forward_assembly(_chair, -1.05)
	_floor_and_trim()
	_compact_shell()
	_wall_systems(-1)
	_wall_systems(1)
	_rear_equipment()

func _forward_assembly(builder: Callable, distance: float) -> void:
	var first := get_child_count()
	builder.call()
	for i in range(first,get_child_count()):
		var child := get_child(i) as Node3D
		child.position.z += distance

func block(at: Vector3, size: Vector3, color: Color, solid := false, parent: Node3D = self, glow := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = at
	mesh.material_override = host._material(color, glow)
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collision.shape = box
		body.position = at
		body.add_child(collision)
		parent.add_child(body)
	return mesh

func lettering(value: String, pos: Vector3, scale_px := 0.0013, color := IVORY, parent: Node3D = self) -> void:
	var label := Label3D.new()
	label.font = host.font
	label.font_size = 64
	label.pixel_size = scale_px
	label.text = value
	label.modulate = color
	label.outline_size = 0
	label.position = pos
	parent.add_child(label)

func group(pos: Vector3, angles := Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	node.rotation_degrees = angles
	add_child(node)
	return node

func monitor(pos: Vector3, size: Vector2, content: String, tilt := Vector3.ZERO, color := ORANGE) -> Node3D:
	var panel := group(pos, tilt)
	panel.name = content.capitalize() + "Monitor"
	panel.set_meta("display_size",size)
	monitor_faces.append(panel)
	block(Vector3.ZERO, Vector3(size.x + 0.16, size.y + 0.16, 0.24), color, true, panel)
	block(Vector3(0,0,0.135), Vector3(size.x + 0.05, size.y + 0.055, 0.06), BLACK, false, panel)
	var screen := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = size
	screen.mesh = plane
	screen.position.z = 0.172
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/cockpit/" + content + ".png")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen.material_override = material
	panel.add_child(screen)
	for x in [-1, 1]:
		for y in [-1, 1]:
			block(Vector3(x*(size.x/2+0.052),y*(size.y/2+0.05),0.13),Vector3(0.024,0.024,0.015),BLACK,false,panel)
	block(Vector3(size.x/2-0.04,-size.y/2-0.049,0.137),Vector3(0.025,0.015,0.015),GREEN,false,panel,true)
	return panel

func keys(parent: Node3D, center: Vector3, columns: int, rows: int, spacing := 0.07) -> void:
	block(center, Vector3(columns*spacing+0.065,0.035,rows*spacing+0.045), BLACK, false, parent)
	for row in rows:
		for col in columns:
			block(center+Vector3((col-(columns-1)*0.5)*spacing,0.03,(row-(rows-1)*0.5)*spacing),Vector3(spacing*0.72,0.028,spacing*0.67),IVORY if col < columns-2 else GOLD,false,parent)

func switches(parent: Node3D, pos: Vector3, columns: int, rows: int) -> void:
	for row in rows:
		for col in columns:
			var p := pos + Vector3(col * 0.13, row * 0.17, 0)
			block(p,Vector3(0.08,0.11,0.018),BLACK,false,parent)
			block(p+Vector3(0,0.015,0.025),Vector3(0.025,0.064,0.032),IVORY if (row+col)%3 else AMBER,false,parent,(row+col)%3==0)

func _window() -> void:
	block(Vector3(0,0.49,-12.2),Vector3(3.30,0.98,0.22),EDGE,true)
	block(Vector3(0,2.30,-12.2),Vector3(3.30,0.24,0.22),IVORY,true)
	var glass := block(Vector3(0,1.62,-12.2),Vector3(3.12,1.22,0.035),Color("21353a"),true)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.13,0.23,0.25,0.07)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.material_override = mat
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-1.56,-0.82,0.82,1.56]:
		block(Vector3(x,1.62,-12.10),Vector3(0.075,1.26,0.13),BLACK)
	for y in [1.01,2.22]: block(Vector3(0,y,-12.09),Vector3(3.15,0.07,0.13),BLACK)
	# Sparse exterior set dressing visible through actual transparent glass.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9841
	for i in 100:
		var s := rng.randf_range(0.025,0.08)
		block(Vector3(rng.randf_range(-65,65),rng.randf_range(3,40),rng.randf_range(-110,-65)),Vector3(s,s,s),Color("a7b2c0"),false,self,true)
	block(Vector3(17,9,-85),Vector3(11,2.2,4),BLACK)
	block(Vector3(17,9,-85),Vector3(2.4,10,3),EDGE)
	for x in [12,15,19,22]:
		block(Vector3(x,9,-82.9),Vector3(0.6,0.5,0.03),AMBER,false,self,true)
		block(Vector3(x,8.2,-82.9),Vector3(0.35,0.15,0.03),AMBER,false,self,true)

func _tabletop(parent: Node3D) -> void:
	# One connected U-shaped top: no floating angled desks or overlapping top faces.
	var outline := PackedVector2Array([
		Vector2(-1.42,0.96), Vector2(-0.69,0.96), Vector2(-0.69,-0.28),
		Vector2(-0.45,-0.76), Vector2(0.45,-0.76), Vector2(0.69,-0.28),
		Vector2(0.69,0.96), Vector2(1.42,0.96), Vector2(1.42,-0.59),
		Vector2(0.98,-1.35), Vector2(-0.98,-1.35), Vector2(-1.42,-0.59)])
	var indices := Geometry2D.triangulate_polygon(outline)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,indices.size(),3):
		var a := outline[indices[i]]
		var b := outline[indices[i+1]]
		var c := outline[indices[i+2]]
		var triangle := [Vector3(a.x,1.0,a.y),Vector3(b.x,1.0,b.y),Vector3(c.x,1.0,c.y)]
		# Godot front faces use clockwise winding, viewed from outside.
		if (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).y > 0: triangle.reverse()
		for vertex in triangle:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(vertex)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i+1)%outline.size()]
		var top_a := Vector3(a.x,1.0,a.y)
		var top_b := Vector3(b.x,1.0,b.y)
		var low_a := top_a - Vector3(0,0.11,0)
		var low_b := top_b - Vector3(0,0.11,0)
		var normal := Vector3(b.y-a.y,0,a.x-b.x).normalized()
		for vertex in [top_a,low_a,top_b,top_b,low_a,low_b]:
			surface.set_normal(normal)
			surface.add_vertex(vertex)
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	var material := host._material(ORANGE).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	parent.add_child(mesh)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = mesh.mesh.create_trimesh_shape()
	body.add_child(collision)
	parent.add_child(body)

func _pilot_station() -> void:
	var desk := group(Vector3(0,0,PILOT_Z))
	desk.name = "PilotConsole"
	_tabletop(desk)
	# Structural cabinets connect the tabletop to the floor; the middle is knee space.
	for side in [-1,1]:
		block(Vector3(side*1.09,0.45,0.18),Vector3(0.60,0.9,1.51),EDGE,true,desk)
		block(Vector3(side*0.98,0.45,-0.68),Vector3(0.68,0.9,0.55),EDGE,true,desk)
		for z in [-0.34,0.19,0.72]:
			block(Vector3(side*0.773,0.46,z),Vector3(0.026,0.7,0.46),IVORY,false,desk)
			block(Vector3(side*0.75,0.66,z),Vector3(0.035,0.033,0.20),BLACK,false,desk)
	block(Vector3(0,0.48,-1.16),Vector3(1.52,0.96,0.34),EDGE,true,desk)
	# Primary scan: three displays within the forward view, all aimed at the eye.
	var nav := monitor(Vector3(-0.71,1.34,PILOT_Z-1.04),Vector2(0.57,0.40),"nav",Vector3(-13,34,0))
	var flight := monitor(Vector3(0,1.34,PILOT_Z-1.26),Vector2(0.50,0.40),"dock",Vector3(-13,0,0),EDGE)
	var fuel := monitor(Vector3(0.71,1.34,PILOT_Z-1.04),Vector2(0.57,0.40),"fuel",Vector3(-13,-34,0))
	for item in [nav,flight,fuel]: item.set_meta("primary",true)
	# Compact secondary displays along the arms of the U, angled toward the chair.
	monitor(Vector3(-1.10,1.20,PILOT_Z-0.30),Vector2(0.40,0.27),"comms",Vector3(-20,74,0),EDGE)
	monitor(Vector3(1.10,1.20,PILOT_Z-0.30),Vector2(0.40,0.27),"drive",Vector3(-20,-74,0),EDGE)
	# Left-hand throttle quadrant, right-hand keypad and guarded ship controls.
	for dx in [-0.86,-1.02]:
		block(Vector3(dx,1.018,0.22),Vector3(0.105,0.032,0.34),BLACK,false,desk)
		block(Vector3(dx,1.12,0.17),Vector3(0.035,0.18,0.045),EDGE,false,desk)
		block(Vector3(dx,1.23,0.17),Vector3(0.13,0.07,0.10),ORANGE,false,desk)
	keys(desk,Vector3(0.97,1.015,0.20),4,4,0.065)
	keys(desk,Vector3(-0.90,1.015,-0.57),7,3,0.052)
	for dx in [0.84,1.04,1.24]:
		block(Vector3(dx,1.018,0.59),Vector3(0.13,0.03,0.24),BLACK,false,desk)
		block(Vector3(dx,1.065,0.59),Vector3(0.075,0.07,0.12),IVORY if dx<1.2 else ORANGE,false,desk)
	# Central yoke is within reach and below the primary display sightlines.
	block(Vector3(0,0.80,-0.72),Vector3(0.16,0.49,0.16),BLACK,false,desk)
	block(Vector3(0,1.07,-0.65),Vector3(0.20,0.18,0.14),EDGE,false,desk)
	block(Vector3(0,1.03,-0.61),Vector3(0.55,0.065,0.075),BLACK,false,desk)
	for x in [-0.25,0.25]:
		block(Vector3(x,1.14,-0.61),Vector3(0.085,0.25,0.10),BLACK,false,desk)
		block(Vector3(x,1.26,-0.61),Vector3(0.10,0.035,0.115),EDGE,false,desk)
	block(Vector3(0,1.1,-0.57),Vector3(0.045,0.045,0.02),AMBER,false,desk,true)
	# Shared warning strip under the center screen.
	for x in [-0.18,-0.06,0.06,0.18]:
		block(Vector3(x,1.083,-0.98),Vector3(0.08,0.035,0.07),BLACK,false,desk)
		block(Vector3(x,1.105,-0.98),Vector3(0.05,0.012,0.04),AMBER,false,desk,true)
	# A cup holder behind the left controls, clear of the entry opening.
	block(Vector3(-1.12,1.02,0.75),Vector3(0.21,0.025,0.21),BLACK,false,desk)
	block(Vector3(-1.12,1.12,0.75),Vector3(0.12,0.18,0.12),IVORY,false,desk)
	block(Vector3(-1.12,1.215,0.75),Vector3(0.085,0.004,0.085),BLACK,false,desk)
	block(Vector3(-1.21,1.13,0.75),Vector3(0.055,0.09,0.06),IVORY,false,desk)
	lettering("LONGHAUL / FLIGHT",Vector3(0,0.78,-0.978),0.00125,IVORY,desk)

func _rack(side: int) -> void:
	var rack := group(Vector3(side*1.32,0,-9.65),Vector3(0,-side*90,0))
	rack.scale.y = 0.83
	block(Vector3(0,1.35,0),Vector3(0.67,2.7,0.57),BLACK,true,rack)
	for y in [0.34,0.81,1.3,1.89,2.38]:
		block(Vector3(0,y,0.32),Vector3(0.60,0.40,0.11),IVORY,false,rack)
		for dx in [-0.245,0.245]:
			block(Vector3(dx,y,0.42),Vector3(0.035,0.26,0.045),BLACK,false,rack)
			for dy in [-0.14,0.14]: block(Vector3(dx,y+dy,0.387),Vector3(0.025,0.025,0.012),EDGE,false,rack)
	# Removable cartridges and matching sockets.
	for dx in [-0.13,0.13]:
		block(Vector3(dx,1.30,0.39),Vector3(0.19,0.32,0.05),BLACK,false,rack)
		block(Vector3(dx,1.30,0.47),Vector3(0.13,0.27,0.14),GOLD,false,rack)
		block(Vector3(dx,1.30,0.547),Vector3(0.028,0.19,0.025),BLACK,false,rack)
	for y in [0.26,0.34,0.42,0.73,0.81,0.89]:
		block(Vector3(0,y,0.39),Vector3(0.40,0.036,0.04),BLACK,false,rack)
	lettering("NAV" if side<0 else "DRIVE",Vector3(0,2.39,0.39),0.0016,BLACK,rack)
	lettering("DATA / 01" if side<0 else "COMMS",Vector3(0,1.9,0.39),0.0013,BLACK,rack)
	for dx in [-0.15,0,0.15]:
		block(Vector3(dx,1.64,0.35),Vector3(0.075,0.055,0.02),AMBER,false,rack,true)
	# Equipment labels and smaller status lamps break up the removable modules.
	for y in [0.58,1.06,2.15]:
		block(Vector3(0,y,0.35),Vector3(0.42,0.045,0.03),BLACK,false,rack)
	for y in [0.81,1.9,2.38]:
		block(Vector3(0.16,y,0.405),Vector3(0.027,0.04,0.012),AMBER,false,rack,true)

func _overhead() -> void:
	# Narrow eyebrow carries secondary status; the primary eye line stays below it.
	block(Vector3(0,2.20,-13.00),Vector3(2.66,0.30,0.38),EDGE)
	monitor(Vector3(-0.73,2.19,-12.83),Vector2(0.43,0.21),"radar",Vector3(14,0,0),IVORY)
	monitor(Vector3(0,2.19,-12.83),Vector2(0.50,0.21),"power",Vector3(14,0,0),IVORY)
	monitor(Vector3(0.73,2.19,-12.83),Vector2(0.43,0.21),"comms",Vector3(14,0,0),IVORY)
	for x in [-1.18,1.05]: switches(self,Vector3(x,2.14,-12.80),1,1)
	# Recessed lighting runs where wall modules meet the service ceiling.
	for x in [-1.40,1.40]:
		block(Vector3(x,2.32,-11.73),Vector3(0.21,0.10,2.44),BLACK)
		block(Vector3(x,2.26,-11.73),Vector3(0.12,0.025,2.28),AMBER,false,self,true)
		host._lamp(Vector3(x*0.85,2.10,-11.7),0.43,2.7,Color("ffd496"))
	# An accessible overhead relay box and removable service panels.
	for z in [-10.55,-11.35,-12.12]:
		block(Vector3(0,2.30,z),Vector3(1.23,0.16,0.61),EDGE)
		block(Vector3(0,2.204,z),Vector3(1.10,0.025,0.48),IVORY)
		for x in [-0.43,0.43]: block(Vector3(x,2.18,z),Vector3(0.13,0.055,0.05),BLACK)
		for x in [-0.18,0,0.18]:
			block(Vector3(x,2.18,z+0.08),Vector3(0.075,0.05,0.12),BLACK)
			block(Vector3(x,2.15,z+0.08),Vector3(0.034,0.018,0.06),AMBER,false,self,true)
	for x in [-1.04,-0.86,0.86,1.04]:
		block(Vector3(x,2.28,-11.65),Vector3(0.075,0.09,3.63),BLACK)
		for z in [-10.2,-11.0,-11.8,-12.6,-13.15]:
			block(Vector3(x,2.21,z),Vector3(0.105,0.05,0.07),EDGE)

func _chair() -> void:
	block(Vector3(0,0.11,-10.22),Vector3(0.73,0.2,0.85),BLACK,true)
	block(Vector3(0,0.4,-10.22),Vector3(0.29,0.6,0.32),EDGE,true)
	block(Vector3(0,0.67,-10.22),Vector3(0.73,0.16,0.75),BLACK,true)
	block(Vector3(0,0.78,-10.22),Vector3(0.65,0.15,0.67),GOLD,true)
	block(Vector3(0,1.06,-9.91),Vector3(0.70,0.69,0.16),BLACK,true)
	for x in [-0.16,0.16]:
		for y in [0.97,1.18]:block(Vector3(x,y,-10.015),Vector3(0.305,0.19,0.12),GOLD)
	block(Vector3(0,1.45,-9.94),Vector3(0.52,0.2,0.18),GOLD,true)
	for x in [-0.43,0.43]:
		block(Vector3(x,0.84,-10.12),Vector3(0.075,0.33,0.08),BLACK)
		block(Vector3(x,1.01,-10.22),Vector3(0.13,0.10,0.55),EDGE)
	lettering("K-01",Vector3(0,1.17,-9.816),0.0015,IVORY)

func _floor_and_trim() -> void:
	for side in [-1,1]:
		# Every component shares the same local center, including the two grey uprights.
		var panel := group(Vector3(side*1.54,1.71,-11.02),Vector3(0,-side*90,0))
		panel.scale = Vector3(0.65,0.56,0.48)
		panel.name = "AuxPort" if side<0 else "AuxStarboard"
		block(Vector3(0,0,0.035),Vector3(1.16,2.10,0.10),BLACK,false,panel)
		block(Vector3(0,0,0.096),Vector3(1.02,1.94,0.045),IVORY,false,panel)
		for x in [-0.58,0.58]:
			block(Vector3(x,0,0.105),Vector3(0.075,2.20,0.11),EDGE,false,panel)
		block(Vector3(0,1.10,0.115),Vector3(1.30,0.08,0.10),ORANGE,false,panel)
		lettering("AUX / CIRCUITS",Vector3(0,0.77,0.135),0.00155,BLACK,panel)
		block(Vector3(0,0.32,0.15),Vector3(0.78,0.47,0.05),EDGE,false,panel)
		switches(panel,Vector3(-0.26,0.23,0.185),5,2)
		for y in [-0.23,-0.50]:
			block(Vector3(0,y,0.15),Vector3(0.78,0.18,0.05),EDGE,false,panel)
			for x in [-0.24,0,0.24]: block(Vector3(x,y,0.18),Vector3(0.12,0.045,0.02),BLACK,false,panel)
		lettering("HAB   AUX   BUS",Vector3(0,-0.79,0.135),0.0012,BLACK,panel)

	for x in [-0.94,0,0.94]:
		for z in [-9.5,-10.4,-11.3]:
			block(Vector3(x,0.034,z),Vector3(0.97,0.03,0.81),BLACK)
			for i in 9:
				block(Vector3(x,0.053,z-0.33+i*0.08),Vector3(0.87,0.015,0.027),EDGE)
			for dx in [-0.36,0,0.36]:block(Vector3(x+dx,0.063,z),Vector3(0.02,0.012,0.77),EDGE)
	for side in [-1,1]:
		for z in [-9.5,-10.5,-11.5]:
			block(Vector3(side*1.51,0.32,z),Vector3(0.09,0.46,0.82),EDGE)
			for i in 4:block(Vector3(side*1.45,0.22+i*0.065,z),Vector3(0.025,0.025,0.64),BLACK)

func validate_pilot_view(view_camera: Camera3D, viewer: CharacterBody3D) -> bool:
	var ok := true
	var extent := view_camera.get_viewport().get_visible_rect().size
	for panel in monitor_faces:
		if not panel.has_meta("primary"): continue
		var center := panel.to_global(Vector3(0,0,0.19))
		var distance := view_camera.global_position.distance_to(center)
		var readable := distance < 1.5
		var size: Vector2 = panel.get_meta("display_size")
		for x in [-0.5,0.5]:
			for y in [-0.5,0.5]:
				var corner := panel.to_global(Vector3(x*size.x,y*size.y,0.178))
				var projected := view_camera.unproject_position(corner)
				readable = readable and not view_camera.is_position_behind(corner) and Rect2(Vector2(8,8),extent-Vector2(16,16)).has_point(projected)
		var ray := PhysicsRayQueryParameters3D.create(view_camera.global_position,center,1,[viewer.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		readable = readable and hit.is_empty()
		print("COCKPIT primary ",panel.name," visible / unobstructed / within 1.5 m: ",readable)
		ok = ok and readable
	return ok

func _compact_shell() -> void:
	# The exterior itself narrows to the cockpit; there is no unused room behind lining.
	block(Vector3(0,-0.15,-11.30),Vector3(3.30,0.30,4.6),EDGE,true)
	block(Vector3(0,2.47,-11.30),Vector3(3.30,0.18,4.6),IVORY,true)
	for side in [-1,1]:
		block(Vector3(side*1.64,1.19,-11.30),Vector3(0.16,2.38,4.6),IVORY,true)
		block(Vector3(side*1.74,0.65,-11.32),Vector3(0.035,0.52,4.45),ORANGE)
		for z in [-9.13,-10.13,-11.42,-12.76]:
			block(Vector3(side*1.57,1.2,z),Vector3(0.05,2.37,0.055),BLACK)
			block(Vector3(side*1.75,1.2,z),Vector3(0.045,2.35,0.08),EDGE)
	# Roof hatch and forward ventilation identify the module from outside.
	block(Vector3(0,2.60,-11.8),Vector3(1.60,0.13,1.65),EDGE)
	for i in 7: block(Vector3(0,2.69,-12.35+i*0.18),Vector3(1.35,0.05,0.055),BLACK)
	# Rear entry is just wide enough for walking, with equipment on either side.
	for x in [-1.02,1.02]:
		block(Vector3(x,1.18,-10.12),Vector3(1.08,2.36,0.12),EDGE,true)
	for x in [-0.48,0.48]:
		block(Vector3(x,1.03,-10.12),Vector3(0.065,2.06,0.19),ORANGE)
	block(Vector3(0,2.23,-10.12),Vector3(1.02,0.30,0.16),EDGE,true)
	lettering("FLIGHT / K-01",Vector3(0,2.23,-10.015),0.00145,IVORY)
	for x in [-0.45,0.45]:
		block(Vector3(x,0.038,-10.16),Vector3(0.035,0.02,0.48),AMBER)

func _wall_systems(side: int) -> void:
	# Modules occupy the wall above the consoles, with separate, legible functions.
	var module := group(Vector3(side*1.54,1.72,-12.20),Vector3(0,-side*90,0))
	module.name = "InertialNavigation" if side<0 else "LifeSupportRegulator"
	block(Vector3.ZERO,Vector3(1.27,1.15,0.11),BLACK,false,module)
	block(Vector3(0,0.01,0.072),Vector3(1.16,1.04,0.055),IVORY,false,module)
	lettering("NAV / INERTIAL" if side<0 else "AIR / REGULATOR",Vector3(0,0.43,0.108),0.0014,BLACK,module)
	for x in [-0.38,0,0.38]:
		block(Vector3(x,0.16,0.11),Vector3(0.30,0.29,0.055),EDGE,false,module)
		block(Vector3(x,0.18,0.145),Vector3(0.24,0.18,0.035),BLACK,false,module)
		# Bar gauges and set-point markers use the same hardware module size.
		for i in 5: block(Vector3(x-0.075+i*0.038,0.18,0.168),Vector3(0.018,0.07+0.01*i,0.008),GREEN if side<0 else AMBER,false,module,true)
		block(Vector3(x,-0.06,0.14),Vector3(0.09,0.06,0.055),ORANGE,false,module)
	for x in [-0.33,0.33]:
		block(Vector3(x,-0.32,0.112),Vector3(0.49,0.27,0.055),EDGE,false,module)
		for i in 4: block(Vector3(x,-0.40+i*0.06,0.147),Vector3(0.40,0.025,0.025),BLACK,false,module)
	# Forward strip: alarm relays and isolation controls at the window jamb.
	var relay := group(Vector3(side*1.54,1.70,-13.15),Vector3(0,-side*90,0))
	block(Vector3.ZERO,Vector3(0.44,1.13,0.10),EDGE,false,relay)
	lettering("ISOLATE",Vector3(0,0.45,0.065),0.0010,IVORY,relay)
	switches(relay,Vector3(-0.13,-0.35,0.075),3,4)
	# The last gap next to the entry is a spare-filter/cartridge cubby.
	var storage := group(Vector3(side*1.54,1.7,-10.40),Vector3(0,-side*90,0))
	block(Vector3.ZERO,Vector3(0.31,1.12,0.12),BLACK,false,storage)
	for y in [-0.30,0,0.30]:
		block(Vector3(0,y,0.085),Vector3(0.23,0.24,0.11),GOLD,false,storage)
		block(Vector3(0,y,0.15),Vector3(0.035,0.15,0.035),BLACK,false,storage)
	# No void between desk and wall: the cable plinth supports removable wall modules.
	block(Vector3(side*1.49,0.63,-11.64),Vector3(0.16,1.20,2.51),EDGE,true)
	for z in [-10.85,-11.48,-12.11]:
		block(Vector3(side*1.395,0.63,z),Vector3(0.035,0.80,0.52),IVORY)

func _rear_equipment() -> void:
	for side in [-1,1]:
		var bay := group(Vector3(side*1.01,1.17,-10.21),Vector3(0,180,0))
		block(Vector3.ZERO,Vector3(0.95,2.19,0.075),BLACK,false,bay)
		lettering("O2 / SCRUBBER" if side<0 else "DC / BACKUP",Vector3(0,0.94,0.05),0.00125,IVORY,bay)
		for y in [0.50,-0.22]:
			block(Vector3(0,y,0.06),Vector3(0.82,0.56,0.09),IVORY,false,bay)
			for i in 5:block(Vector3(0,y-0.16+i*0.08,0.115),Vector3(0.65,0.035,0.025),BLACK,false,bay)
			block(Vector3(0.28,y+0.22,0.12),Vector3(0.05,0.025,0.016),GREEN,false,bay,true)
		block(Vector3(0,-0.81,0.06),Vector3(0.80,0.36,0.10),EDGE,false,bay)
		lettering("FILTER ACCESS" if side<0 else "BATTERY ACCESS",Vector3(0,-0.80,0.12),0.0011,IVORY,bay)
	# Hatch header has the local cabin pressure readout and door equipment.
	var header := group(Vector3(0,2.12,-10.23),Vector3(0,180,0))
	block(Vector3.ZERO,Vector3(0.94,0.23,0.05),IVORY,false,header)
	lettering("CABIN / 101 kPa",Vector3(0,0,0.04),0.00125,BLACK,header)
	# Small entry roof carries the duct transition into the living module.
	for z in [-9.4,-9.8]:
		block(Vector3(0,2.28,z),Vector3(1.2,0.18,0.30),EDGE)
		for x in [-0.38,-0.19,0,0.19,0.38]:block(Vector3(x,2.177,z),Vector3(0.08,0.025,0.20),BLACK)
	host._lamp(Vector3(0,2.0,-9.6),0.38,1.7,Color("ffe4b1"))
