extends "res://scripts/longhaul_room.gd"
## A sealed loading hatch with a fixed, walkable ramp outside it.
var hatch_open := true
var hatch_moving := false
var leaves: Array[Node3D] = []
var hatch_tween: Tween
var status_labels: Array[Label3D] = []
var status_lights: Array[MeshInstance3D] = []

func build(ship: Node3D) -> void:
	host = ship
	name = "LonghaulLoading"
	for side in [-1,1]:
		var leaf := group(Vector3(side*2.14,1.2,11.1))
		box(Vector3.ZERO,Vector3(1.40,2.34,0.10),EDGE,true,leaf)
		for face in [-1,1]:
			var front := Node3D.new()
			front.rotation.y = 0 if face>0 else PI
			leaf.add_child(front)
			box(Vector3(0,0,0.059),Vector3(1.31,2.20,0.015),CREAM,false,front)
			box(Vector3(0,0.42,0.071),Vector3(1.28,0.19,0.012),ORANGE,false,front)
			label("LOAD / 07",Vector3(0,0.08,0.080),0.0018,DARK,front)
			for y in [-0.75,0.75]:
				box(Vector3(0,y,0.072),Vector3(1.19,0.06,0.012),DARK,false,front)
		leaves.append(leaf)
	for outside in [false,true]:
		var mount := group(Vector3(1.66,1.52,11.215 if outside else 10.985),0 if outside else PI)
		box(Vector3.ZERO,Vector3(0.37,0.64,0.065),DARK,false,mount)
		var lens := box(Vector3(0,0.19,0.045),Vector3(0.26,0.085,0.025),GREEN,false,mount,true)
		status_lights.append(lens)
		status_labels.append(label("OPEN",Vector3(0,0.042,0.048),0.00115,LIGHT,mount))
		box(Vector3(0,-0.17,0.058),Vector3(0.24,0.16,0.055),ORANGE,false,mount)
		label("HATCH",Vector3(0,-0.165,0.089),0.0010,LIGHT,mount)
		collider(Vector3(0,0,0.053),Vector3(0.38,0.66,0.09),mount,"load_outer" if outside else "load_inner")
		label("LOADING",Vector3(0,0.43,0.018),0.00115,DARK,mount)
	# Hardware attached to the bulkhead; nothing narrows the ramp approach.
	for side in [-1,1]:
		var casing := group(Vector3(side*2.47,1.41,10.977),PI)
		cabinet_face(Vector3.ZERO,Vector2(0.76,1.20),casing)
		label("DOOR DRIVE",Vector3(0,0.33,0.032),0.0011,DARK,casing)
		vent(Vector3(0,0.06,0.036),0.63,casing)
		box(Vector3(0,-0.34,0.043),Vector3(0.33,0.095,0.046),ORANGE,false,casing)
	box(Vector3(0,0.035,11.03),Vector3(2.72,0.012,0.13),EDGE)
	for i in 12:
		box(Vector3(-1.26+i*0.23,0.043,10.91),Vector3(0.11,0.006,0.09),ORANGE)
	# Connected ramp surface ribs and side strips follow its existing slope.
	var trim := group(Vector3(0,-0.63,13.2))
	trim.rotation.x = atan(1.2/4.2)
	for x in [-1.32,1.32]:box(Vector3(x,0.101,0),Vector3(0.085,0.02,4.33),ORANGE,false,trim)
	for i in 13:
		box(Vector3(0,0.102,-2.01+i*0.33),Vector3(2.48,0.008,0.045),EDGE,false,trim)
	for x in [-1.16,1.16]:
		for z in [-1.83,0,1.83]:box(Vector3(x,0.111,z),Vector3(0.05,0.012,0.20),Color("d3dab0"),false,trim,true)

func prompt(_action: String) -> String:
	if hatch_moving: return "Loading hatch moving"
	return "Close loading hatch" if hatch_open else "Open loading hatch"

func use(_action: String) -> void:
	notice = ""
	if hatch_moving: return
	if hatch_open and _doorway_occupied():
		explain("Step clear of the loading hatch to close it")
		return
	hatch_open = not hatch_open
	_move_hatch()

func _move_hatch() -> void:
	hatch_moving = true
	if hatch_tween: hatch_tween.kill()
	hatch_tween = create_tween().set_parallel(true)
	for i in 2:
		var x: float = (-1 if i==0 else 1)*(2.14 if hatch_open else 0.70)
		hatch_tween.tween_property(leaves[i],"position:x",x,0.65)
	_update_status()
	hatch_tween.chain().tween_callback(func():
		hatch_moving = false
		_update_status())

func _doorway_occupied() -> bool:
	return occupied(Vector3(0,1.20,11.1),Vector3(2.88,2.44,0.80))

func _physics_process(_delta: float) -> void:
	if hatch_moving and not hatch_open and _doorway_occupied():
		hatch_open = true
		_move_hatch()
		explain("Loading hatch obstructed — reopening")

func _update_status() -> void:
	for text in status_labels:
		text.text = "MOVING" if hatch_moving else ("OPEN" if hatch_open else "SEALED")
	for lens in status_lights:
		lens.material_override = host._material(AMBER if hatch_moving else GREEN,true)
