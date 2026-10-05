class_name Player
extends CharacterBody3D
## First-person on foot: walk, look, use terminals and the pilot seat,
## and carry crates with the tractor tool, snapping them into hold or pallet slots.

const WALK := 5.0
const SPRINT := 8.5
const GRAVITY := 18.0
const REACH := 4.0
const LOOK_SENS := 0.0025
const STICK_LOOK := 2.6
## A carried crate is held at waist height, front right of you (yaw only, so it never hides your aim), and becomes
## part of your collision, so it can't pass through walls, crates or the ramp.
const CARRY_POS := Vector3(0.8, 1.0, -1.3)
const CARRY_SCALE := 0.45

var active := true
var cam: Camera3D
var ray: RayCast3D
var carried: Crate = null
var prompt := ""
var _pitch := 0.0
var _ghost: MeshInstance3D
var _tool: Node3D
var _beam: MeshInstance3D
var _carry_shape: CollisionShape3D


func build() -> void:
	name = "Player"
	collision_layer = Vox.L_PLAYER
	collision_mask = Vox.L_WORLD | Vox.L_SHIP | Vox.L_INTERIOR | Vox.L_CRATE | Vox.L_BARRIER
	# Keep this under ~53 deg: that is the angle at which the capsule meets the 0.14 m cockpit
	# desk edge (Cockpit._desk). Raise it and the player can walk up onto the desk and keypad.
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	_carry_shape = CollisionShape3D.new()
	var cb := BoxShape3D.new()
	cb.size = Slot.CRATE_SIZE * CARRY_SCALE
	_carry_shape.shape = cb
	_carry_shape.position = CARRY_POS
	_carry_shape.disabled = true
	add_child(_carry_shape)
	cam = Camera3D.new()
	cam.position = Vector3(0, 1.62, 0)
	cam.fov = 74
	cam.near = 0.05
	cam.far = 60000
	add_child(cam)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -REACH)
	ray.collide_with_areas = true
	cam.add_child(ray)
	_build_tool()
	_ghost = MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Slot.CRATE_SIZE + Vector3.ONE * 0.06
	_ghost.mesh = gm
	_ghost.material_override = Vox.mat(Vox.PHOS_GREEN, true, 0.28)
	_ghost.top_level = true
	_ghost.visible = false
	add_child(_ghost)


func _build_tool() -> void:
	# Handheld tractor tool in the lower right of the view.
	_tool = Node3D.new()
	_tool.position = Vector3(0.36, -0.3, -0.62)
	_tool.scale = Vector3.ONE * 0.55
	_tool.rotation_degrees = Vector3(4, 8, 0)
	cam.add_child(_tool)
	Vox.box(_tool, Vector3(0, 0, 0), Vector3(0.14, 0.12, 0.42), Vox.BEIGE)
	Vox.box(_tool, Vector3(0, -0.12, 0.1), Vector3(0.08, 0.18, 0.1), Vox.ORANGE)
	Vox.box(_tool, Vector3(0, 0.02, -0.23), Vector3(0.1, 0.08, 0.06), Vox.DBROWN)
	Vox.box(_tool, Vector3(0, 0.075, -0.02), Vector3(0.09, 0.02, 0.12), Color("2a1806"))
	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.07
	cyl.height = 1.0
	_beam.mesh = cyl
	_beam.material_override = Vox.mat(Vox.PHOS_AMBER, true, 0.18)
	_beam.top_level = true
	_beam.visible = false
	add_child(_beam)
	for m in _tool.get_children():
		if m is GeometryInstance3D:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_active(v: bool) -> void:
	active = v
	visible = v
	cam.current = v
	process_mode = Node.PROCESS_MODE_INHERIT if v else Node.PROCESS_MODE_DISABLED
	collision_layer = Vox.L_PLAYER if v else 0
	if v:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_ghost.visible = false


func spawn_at(t: Transform3D) -> void:
	global_position = t.origin
	var f := -t.basis.z
	rotation = Vector3(0, atan2(-f.x, -f.z), 0)
	_pitch = 0.0
	cam.rotation = Vector3.ZERO
	velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not active or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(Vector2(event.relative.x, event.relative.y) * LOOK_SENS)
	elif event.is_action_pressed("interact"):
		use()
		get_viewport().set_input_as_handled()


func _look(d: Vector2) -> void:
	rotate_y(-d.x)
	_pitch = clampf(_pitch - d.y, deg_to_rad(-85), deg_to_rad(85))
	cam.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick.length() > 0.0:
		_look(stick * STICK_LOOK * delta)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (global_basis * Vector3(input.x, 0, input.y))
	dir.y = 0
	var speed := SPRINT if Input.is_action_pressed("sprint") else WALK
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_update_aim()


func _aim_mask() -> int:
	if carried:
		return Vox.L_WORLD | Vox.L_SHIP | Vox.L_INTERIOR | Vox.L_SLOT | Vox.L_CRATE
	return Vox.L_WORLD | Vox.L_SHIP | Vox.L_INTERIOR | Vox.L_CRATE | Vox.L_INTERACT


## Aiming anywhere at a stack (one of its slots, or a crate in it) targets the
## lowest free slot in that stack, so you stack by pointing at the crate below.
static func stack_target(hit: Object) -> Slot:
	var s: Slot = null
	if hit is Slot:
		s = hit
	elif hit is Crate:
		s = hit.slot
	if s == null:
		return null
	while s.below:
		s = s.below
	while s and not s.is_free():
		s = s.above
	return s


## Aiming at any crate in a stack lifts the one on top.
static func stack_top(c: Crate) -> Crate:
	while c.slot and c.slot.above and c.slot.above.occupant:
		c = c.slot.above.occupant
	return c


func _update_aim() -> void:
	ray.collision_mask = _aim_mask()
	ray.force_raycast_update()
	var hit := ray.get_collider() if ray.is_colliding() else null
	_ghost.visible = false
	_beam.visible = carried != null
	prompt = ""
	if carried:
		_update_beam()
		var target := stack_target(hit)
		if target:
			_ghost.global_transform = target.global_transform
			_ghost.visible = true
			prompt = "Place crate in " + target.describe()
		elif hit is Slot or hit is Crate:
			prompt = "That stack is full"
		elif hit is Interactable:
			prompt = hit.prompt
		else:
			prompt = "Aim at a slot or a crate in your hold or on the pallet"
	elif hit is Crate:
		var top := stack_top(hit)
		if top != hit:
			_ghost.global_transform = top.global_transform
			_ghost.visible = true
		prompt = "Lift crate · " + top.display_name()
	elif hit is Interactable:
		prompt = hit.prompt


func _update_beam() -> void:
	var a := _tool.global_transform * Vector3(0, 0.02, -0.26)
	var b := carried.global_position
	var d := b - a
	if d.length() < 0.1:
		return
	_beam.global_transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT) * Basis(Vector3.RIGHT, -PI / 2), a + d / 2)
	(_beam.mesh as CylinderMesh).height = d.length()


func use() -> void:
	ray.collision_mask = _aim_mask()
	ray.force_raycast_update()
	var hit := ray.get_collider() if ray.is_colliding() else null
	if carried:
		var target := stack_target(hit)
		if target:
			place(target)
		elif hit is Interactable:
			hit.interact(self)
		elif hit is Slot or hit is Crate:
			GameState.say("That stack is full. Try another slot.")
		else:
			GameState.say("Aim at a slot or a crate in your hold or on the pallet to set the crate down.")
		return
	if hit is Crate:
		pick_up(stack_top(hit))
	elif hit is Interactable:
		hit.interact(self)


func pick_up(c: Crate) -> void:
	c.remove_from_slot()
	c.get_parent().remove_child(c)
	add_child(c)
	c.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * CARRY_SCALE), CARRY_POS)
	c.set_carried(true)
	carried = c
	_carry_shape.disabled = false


## Hands the carried crate over when it's sold at an exchange.
func give_up_carried() -> void:
	if carried:
		carried.queue_free()
	carried = null
	_carry_shape.disabled = true
	_beam.visible = false
	_ghost.visible = false


func place(s: Slot) -> void:
	var c := carried
	carried = null
	_carry_shape.disabled = true
	c.place_in(s)
	_beam.visible = false
	_ghost.visible = false
