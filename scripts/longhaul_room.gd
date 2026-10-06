extends Node3D
## Shared construction and aiming helpers for fitted cargo and engineering hardware.
const CREAM := Color("b4ab91")
const LIGHT := Color("d4c7a7")
const DARK := Color("292e2a")
const EDGE := Color("676454")
const ORANGE := Color("a95e2b")
const GREEN := Color("9bdfa6")
const AMBER := Color("e7ba68")
var host: Node3D
var use_targets: Dictionary = {}
var notice := ""
var notice_until := 0

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
		body.set_meta("room_action",action)
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

func interaction(camera: Camera3D, player: CharacterBody3D) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*2.3,1,[player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.has_meta("room_action"): return {}
	var action: String = hit.collider.get_meta("room_action")
	if not use_targets.has(action): return {}
	return {"action":action,"label":prompt(action)}

func prompt(action: String) -> String:
	return action

func explain(message: String) -> void:
	notice = message
	notice_until = Time.get_ticks_msec()+3000

func occupied(center: Vector3, size: Vector3, mask := 2) -> bool:
	var shape := BoxShape3D.new()
	shape.size = size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = global_transform * Transform3D(Basis.IDENTITY,center)
	query.collision_mask = mask
	return not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
