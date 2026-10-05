class_name Ship
extends CharacterBody3D
## The player's hauler. Assisted (Elite-style) flight, a walk-in hold with 16 snap slots,
## a rear cargo ramp, and a cockpit with three CRTs and the keypad nav computer.
## Local axes: forward is -Z, up is +Y. The hold floor top sits at y = 0.3.

signal pilot_exit_requested
signal pilot_seat_used
signal landed(station: Station)
signal took_off

enum State { LANDED, FLYING, AUTOLAND }

const MAX_SPEED := 70.0
const STRAFE_SPEED := 30.0
const ACCEL := 28.0
const CRUISE_SPEED := 650.0
const CRUISE_ACCEL := 140.0
const CRUISE_DECEL := 280.0
const CRUISE_DROP_DIST := 1500.0
const TURN := Vector3(1.1, 0.9, 1.8)
const LAND_MAX_SPEED := 14.0
const DOCK_RANGE := 5000.0
const CRUISE_MIN_DIST := 1500.0
const RAMP_LEN := 8.0
const RAMP_HINGE := Vector3(0, 0.3, 16)
const CAM_POS := Vector3(0, 2.55, -9.0)
const CAM_PITCH := -10.0
const NAV_PITCH := -54.0
const CAM_FOV := 72.0
## Directory view: lean toward the route printer, left of the keypad, and zoom in.
const DIR_EYE := Vector3(-0.79, 2.34, -9.55)
const DIR_LOOK := Vector3(-1.85, 0.7, -9.98)
const DIR_FOV := 38.0

var state := State.LANDED
var piloted := false
var nav_mode := false
var cruise := false
var ang := Vector3.ZERO
var mouse_turn := Vector2.ZERO
var landed_at: Station = null
var stations: Array[Station] = []
var hold_slots: Array[Slot] = []
var course_target = null # Vector3 or null
var course_station := ""
var comms := "STANDING BY"

var cam: Camera3D
var nav: NavComputer
var directory: NavDirectory
var dir_mode := false
var slip_clip: Node3D
var _cam_tween: Tween
var crt_scan: CrtScreen
var crt_nav: CrtScreen
var crt_cargo: CrtScreen

var _ramp_mesh: MeshInstance3D
var _ramp_shape: CollisionShape3D
var _engine_glow: Array[MeshInstance3D] = []
var _lamps := {}
var _autoland_from: Transform3D
var _autoland_to: Transform3D
var _autoland_station: Station
var _autoland_t := 0.0
var _crt_timer := 0.0


func build() -> void:
	name = "Ship"
	collision_layer = Vox.L_SHIP
	collision_mask = Vox.L_WORLD
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_build_hull()
	_build_hold()
	_build_cockpit()
	_set_ramp(true)
	_set_engines(false)


func _build_hull() -> void:
	Vox.solid(self, Vector3(0, 0, 1), Vector3(10, 0.6, 30), Vox.BEIGE3)
	for sx in [-1, 1]:
		Vox.solid(self, Vector3(5.2 * sx, 3.4, 1), Vector3(0.6, 6.8, 30), Vox.BEIGE)
		Vox.solid(self, Vector3(3.15 * sx, 3.4, -4), Vector3(3.7, 6.8, 0.4), Vox.BEIGE2)
		Vox.solid(self, Vector3(4.6 * sx, 3.9, -14), Vector3(1.2, 5.0, 0.4), Vox.BEIGE)
		Vox.box(self, Vector3(5.55 * sx, 4.2, 1), Vector3(0.1, 1.0, 30), Vox.ORANGE)
		Vox.box(self, Vector3(5.55 * sx, 3.4, 1), Vector3(0.1, 0.35, 30), Vox.MUSTARD)
		# Engine nacelles and landing legs
		Vox.solid(self, Vector3(6.9 * sx, 3, 11), Vector3(2.6, 2.8, 8), Vox.BEIGE3)
		_engine_glow.append(Vox.box(self, Vector3(6.9 * sx, 3, 15.1), Vector3(2, 2, 0.2), Color("ff9a3c"), true))
		for z in [-9, 11]:
			Vox.solid(self, Vector3(3.5 * sx, -0.85, z), Vector3(0.6, 1.7, 0.6), Vox.DBROWN)
			Vox.box(self, Vector3(3.5 * sx, -1.85, z), Vector3(1.4, 0.3, 1.4), Vox.DBROWN)
			# Foot collider stops 5 cm short of the pad so a landed ship isn't touching it.
			Vox.add_shape(self, Vector3(3.5 * sx, -1.825, z), Vector3(1.4, 0.25, 1.4))
	Vox.solid(self, Vector3(0, 6.8, 1), Vector3(11, 0.6, 30), Vox.BEIGE)
	Vox.solid(self, Vector3(0, 4.85, -4), Vector3(2.6, 3.9, 0.4), Vox.BEIGE2)
	Vox.solid(self, Vector3(0, 0.9, -14), Vector3(10.4, 1.2, 0.4), Vox.BEIGE)
	Vox.solid(self, Vector3(0, 1.0, -15), Vector3(8, 1.8, 1.6), Vox.BEIGE2)
	Vox.box(self, Vector3(0, 1.2, -15.82), Vector3(8, 0.3, 0.05), Vox.ORANGE)
	Vox.box(self, Vector3(0, 7.6, 4), Vector3(0.3, 1.4, 0.3), Vox.DBROWN)
	Vox.box(self, Vector3(0, 8.4, 4), Vector3(0.4, 0.4, 0.4), Color("ff4a2e"), true)
	Vox.label(self, "KESTREL-9", Vector3(5.56, 5.3, 4), 0.012, Vox.DBROWN, GameState.font_label).rotation.y = PI / 2
	# Rear ramp
	var rm := BoxMesh.new()
	rm.size = Vector3(10, RAMP_LEN, 0.4)
	_ramp_mesh = MeshInstance3D.new()
	_ramp_mesh.mesh = rm
	_ramp_mesh.material_override = Vox.mat(Vox.BEIGE3)
	add_child(_ramp_mesh)
	_ramp_shape = Vox.add_shape(self, Vector3.ZERO, rm.size)


func _build_hold() -> void:
	for x in [-2.5, 2.5]:
		Vox.box(self, Vector3(x, 6.45, 5), Vector3(0.6, 0.15, 18), Vox.LAMP, true)
	var l := OmniLight3D.new()
	l.position = Vector3(0, 5.6, 5)
	l.omni_range = 16
	l.light_energy = 1.2
	l.light_color = Color("ffe8c8")
	add_child(l)
	var n := 0
	for layer in 2:
		for side in [-1, 1]:
			for row in 4:
				n += 1
				var s := Slot.new(("L" if side < 0 else "R") + str(row + 1 + layer * 4), "hold")
				s.position = Vector3(3.0 * side, 1.1 + layer * 1.62, 0.6 + row * 2.7)
				add_child(s)
				hold_slots.append(s)
				if layer == 0:
					for e in [Vector3(1.15, 0, 0), Vector3(-1.15, 0, 0)]:
						Vox.box(self, Vector3(3.0 * side, 0.31, 0.6 + row * 2.7) + e, Vector3(0.08, 0.02, 2.3), Vox.MUSTARD)
					for e in [Vector3(0, 0, 1.15), Vector3(0, 0, -1.15)]:
						Vox.box(self, Vector3(3.0 * side, 0.31, 0.6 + row * 2.7) + e, Vector3(2.3, 0.02, 0.08), Vox.MUSTARD)
	Slot.link_stacks(hold_slots)
	Vox.label(self, "HOLD · 32 SCU", Vector3(0, 5.2, -3.78), 0.008, Vox.DBROWN, GameState.font_label)


func _build_cockpit() -> void:
	var l := OmniLight3D.new()
	l.position = Vector3(0, 4.5, -8.5)
	l.omni_range = 7
	l.light_energy = 0.6
	l.light_color = Color("ffd9a0")
	add_child(l)
	# Seat
	Vox.solid(self, Vector3(0, 0.8, -8), Vector3(1.3, 0.5, 1.3), Vox.BROWN)
	Vox.solid(self, Vector3(0, 1.75, -7.35), Vector3(1.3, 1.7, 0.3), Vox.ORANGE)
	Vox.add_shape(self, Vector3(0, 0.5, -8), Vector3(1.3, 0.6, 1.3)) # seat base down to the floor
	var seat := Interactable.new("Fly ship", Vector3(1.6, 2.2, 1.6))
	seat.position = Vector3(0, 1.3, -7.9)
	add_child(seat)
	seat.used.connect(func(_by): pilot_seat_used.emit())
	# Dashboard
	Vox.solid(self, Vector3(0, 0.9, -12.4), Vector3(9.6, 1.2, 1.6), Vox.BEIGE)
	Vox.add_shape(self, Vector3(0, 0.85, -11.4), Vector3(6.8, 1.3, 0.4)) # CRT bank
	Vox.box(self, Vector3(0, 1.53, -12.4), Vector3(9.6, 0.06, 1.7), Vox.DBROWN)
	for i in 10:
		Vox.box(self, Vector3(-2.25 + i * 0.5, 1.57, -11.75), Vector3(0.25, 0.02, 0.12), Vox.MUSTARD if i % 2 == 0 else Color("1a1410"))
	# Shelf for the keypad, the route printer (left) and the slip clipboard (right)
	Vox.box(self, Vector3(-0.45, 0.3, -10.2), Vector3(4.0, 0.1, 1.7), Vox.BEIGE3)
	Vox.add_shape(self, Vector3(-0.45, 0.5, -10.2), Vector3(4.0, 0.6, 1.7)) # no walking over the keys
	# Canopy frame
	for sx in [-1, 1]:
		Vox.solid(self, Vector3(4.15 * sx, 3.9, -13.75), Vector3(0.7, 5.0, 0.5), Vox.DBROWN)
		Vox.solid(self, Vector3(4.7 * sx, 1.8, -12.0), Vector3(0.5, 0.5, 4), Vox.DBROWN)
	Vox.box(self, Vector3(0, 6.15, -13.75), Vector3(9, 0.6, 0.5), Vox.DBROWN)
	# CRTs
	crt_scan = CrtScreen.new(Vector2(1.8, 1.3), Vector2i(512, 384), Vox.PHOS_GREEN, 28)
	crt_nav = CrtScreen.new(Vector2(1.8, 1.3), Vector2i(512, 384), Vox.PHOS_AMBER, 28)
	crt_cargo = CrtScreen.new(Vector2(1.8, 1.3), Vector2i(512, 384), Vox.PHOS_GREEN, 26)
	for pair in [[crt_scan, -2.3, "NAV SCANNER"], [crt_nav, 0.0, "NAV COMPUTER"], [crt_cargo, 2.3, "CARGO"]]:
		var c: CrtScreen = pair[0]
		c.position = Vector3(pair[1], 0.85, -11.45)
		c.rotation.x = deg_to_rad(-12)
		add_child(c)
		var tag := Vox.label(self, pair[2], Vector3(pair[1], 0.07, -11.48), 0.0022, Vox.CREAM, GameState.font_label)
		tag.outline_size = 0
		Vox.box(self, Vector3(pair[1], 0.07, -11.5), Vector3(0.9, 0.14, 0.02), Color("16130f"))
	# Lamps
	var lamp_specs := [["GEAR", Color("7dff8a"), 1.25], ["DOCK", Vox.PHOS_AMBER, 0.95], ["CRUISE", Color("7dff8a"), 0.65]]
	for spec in lamp_specs:
		var lm := Vox.box(self, Vector3(4.1, spec[2], -11.58), Vector3(0.55, 0.24, 0.05), Color("3a3029"))
		lm.set_meta("on", spec[1])
		_lamps[spec[0]] = lm
		Vox.label(self, spec[0], Vector3(4.1, spec[2], -11.55), 0.0012, Vox.DBROWN, GameState.font_label)
	for i in 3:
		Vox.box(self, Vector3(-4.1, 1.25 - i * 0.3, -11.55), Vector3(0.12, 0.12, 0.3), Color("e8e0d0"))
	# Keypad
	nav = NavComputer.new()
	nav.position = Vector3(0, 0.47, -10.15)
	nav.rotation.x = deg_to_rad(12)
	add_child(nav)
	nav.build(crt_nav)
	nav.course_set.connect(_on_course_set)
	nav.exit_requested.connect(exit_nav)
	nav.directory_requested.connect(enter_directory)
	# Route printer and the clipboard its slips land on
	slip_clip = Node3D.new()
	slip_clip.name = "SlipClip"
	slip_clip.position = Vector3(1.08, 0.58, -10.2)
	slip_clip.rotation = Vector3(deg_to_rad(35), deg_to_rad(-15), 0)
	add_child(slip_clip)
	Vox.box(slip_clip, Vector3(0, -0.018, 0.0), Vector3(0.68, 0.025, 0.8), Vox.DBROWN)
	Vox.box(slip_clip, Vector3(0, 0.012, -0.36), Vector3(0.28, 0.035, 0.07), Vox.MUSTARD)
	Vox.box(slip_clip, Vector3(0, -0.15, -0.12), Vector3(0.4, 0.25, 0.35), Vox.DBROWN) # stand, under the board
	directory = NavDirectory.new()
	directory.position = Vector3(-1.9, 0.35, -10.0)
	directory.rotation.y = deg_to_rad(68)
	add_child(directory)
	directory.clip = slip_clip
	directory.build()
	directory.exit_requested.connect(enter_nav)
	directory.printed.connect(_on_slip_printed)
	# Camera
	cam = Camera3D.new()
	cam.position = CAM_POS
	cam.rotation_degrees = Vector3(CAM_PITCH, 0, 0)
	cam.fov = 72
	cam.near = 0.05
	cam.far = 60000
	add_child(cam)
	nav.camera = cam
	directory.camera = cam


# ---------------------------------------------------------------- states

func _set_ramp(open: bool) -> void:
	var t: Transform3D
	# Open, the ramp reaches the station floor; closed, it fills the hull's rear opening.
	var length := RAMP_LEN if open else 6.8
	(_ramp_mesh.mesh as BoxMesh).size.y = length
	(_ramp_shape.shape as BoxShape3D).size.y = length
	if open:
		# The top face runs from the hold floor at the hinge down to the station
		# floor (2.3 m lower), so there is no lip to step over at either end.
		var a := asin(2.3 / RAMP_LEN)
		var b := Basis(Vector3.RIGHT, PI / 2 + a)
		t = Transform3D(b, RAMP_HINGE + b * Vector3(0, RAMP_LEN / 2, 0.2))
	else:
		t = Transform3D(Basis.IDENTITY, RAMP_HINGE + Vector3(0, length / 2, 0))
	_ramp_mesh.transform = t
	_ramp_shape.transform = t


func _set_engines(on: bool) -> void:
	for g in _engine_glow:
		g.material_override = Vox.mat(Color("ff9a3c"), true) if on else Vox.mat(Color("3a2a20"))


func _set_lamp(lamp: String, on: bool) -> void:
	var lm: MeshInstance3D = _lamps[lamp]
	lm.material_override = Vox.mat(lm.get_meta("on"), true) if on else Vox.mat(Color("3a3029"))


func place_landed(st: Station) -> void:
	global_transform = st.pad_transform()
	_set_landed(st)


func _set_landed(st: Station) -> void:
	state = State.LANDED
	velocity = Vector3.ZERO
	ang = Vector3.ZERO
	cruise = false
	landed_at = st
	_set_ramp(true)
	_set_engines(false)
	comms = st.display_name.to_upper() + " PAD 07 · LANDED"
	landed.emit(st)


func take_off() -> void:
	if landed_at:
		landed_at.docking_granted = false
	landed_at = null
	state = State.FLYING
	_set_ramp(false)
	_set_engines(true)
	velocity = global_basis.y * 3.0
	comms = "CLEAR OF PAD · FLY SAFE"
	took_off.emit()


func set_piloted(v: bool) -> void:
	piloted = v
	cam.current = v
	if v:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not v and nav_mode:
		exit_nav()


func enter_nav() -> void:
	nav_mode = true
	dir_mode = false
	directory.set_active(false)
	nav.set_active(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cam_to(CAM_POS, Vector3(NAV_PITCH, 0, 0), CAM_FOV)


## The station directory and route printer, left of the keypad.
func enter_directory() -> void:
	nav_mode = true
	dir_mode = true
	nav.set_active(false)
	directory.set_active(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var d := DIR_LOOK - DIR_EYE
	var look := Vector3(rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length())), rad_to_deg(atan2(-d.x, -d.z)), 0)
	_cam_to(DIR_EYE, look, DIR_FOV)


func exit_nav() -> void:
	nav_mode = false
	dir_mode = false
	nav.set_active(false)
	directory.set_active(false)
	if piloted:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_cam_to(CAM_POS, Vector3(CAM_PITCH, 0, 0), CAM_FOV)


func _cam_to(pos: Vector3, rot_deg: Vector3, fov: float) -> void:
	if _cam_tween:
		_cam_tween.kill()
	_cam_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	_cam_tween.tween_property(cam, "position", pos, 0.35)
	_cam_tween.tween_property(cam, "rotation_degrees", rot_deg, 0.35)
	_cam_tween.tween_property(cam, "fov", fov, 0.35)


func _on_slip_printed(station_id: String) -> void:
	nav.status = "SLIP: KEY IN %s" % GameState.station_name(station_id).to_upper()
	if dir_mode:
		enter_nav()


func _on_course_set(target: Vector3, station_id: String) -> void:
	course_target = target
	course_station = station_id
	var nm := GameState.station_name(station_id) if station_id != "" else "waypoint"
	GameState.say("Course set to %s, %.1f km. Point the nose at the marker and press C / L3 for cruise." % [nm, (target - global_position).length() / 1000.0])


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not piloted or nav_mode or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_turn += Vector2(-event.relative.x, -event.relative.y) * 0.0035
		mouse_turn = mouse_turn.limit_length(1.0)
	elif event.is_action_pressed("nav_computer"):
		enter_nav()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("nav_directory"):
		enter_directory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		if state == State.LANDED:
			pilot_exit_requested.emit()
		else:
			GameState.say("Land before leaving the seat.")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("request_dock"):
		request_dock()
	elif event.is_action_pressed("cruise"):
		toggle_cruise()


func request_dock() -> void:
	if state != State.FLYING:
		return
	var st := nearest_station()
	if st == null or global_position.distance_to(st.global_position) > DOCK_RANGE:
		GameState.say("No station in comms range.")
		return
	if not st.docking_granted:
		st.docking_granted = true
		comms = st.display_name.to_upper() + ": PAD 07 CLEARED"
		GameState.say("%s control: pad 07 is yours. Fly in through the bay, hover over the pad and press dock again." % st.display_name)
		return
	if not st.in_landing_zone(global_position):
		GameState.say("Line up over pad 07 inside the hangar, then press dock again.")
	elif velocity.length() > LAND_MAX_SPEED:
		GameState.say("Too fast to land. Slow below %d m/s." % int(LAND_MAX_SPEED))
	else:
		start_autoland(st)


func start_autoland(st: Station) -> void:
	state = State.AUTOLAND
	cruise = false
	_autoland_station = st
	_autoland_from = global_transform
	_autoland_to = st.pad_transform()
	_autoland_t = 0.0
	comms = "LANDING ASSIST ENGAGED"
	GameState.say("Landing assist engaged. Gear down.")


func toggle_cruise() -> void:
	if state != State.FLYING:
		return
	if cruise:
		cruise = false
		GameState.say("Cruise off.")
		return
	var st := nearest_station()
	if st and global_position.distance_to(st.global_position) < CRUISE_MIN_DIST:
		GameState.say("Too close to %s for cruise. Get %.1f km clear first." % [st.display_name, CRUISE_MIN_DIST / 1000.0])
		return
	cruise = true
	GameState.say("Cruise engaged. It drops out automatically near your destination.")


func nearest_station() -> Station:
	var best: Station = null
	var bd := INF
	for s in stations:
		var d := global_position.distance_to(s.global_position)
		if d < bd:
			bd = d
			best = s
	return best


# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	match state:
		State.LANDED:
			if piloted and not nav_mode and (Input.get_action_strength("thrust_up") > 0.3 or Input.get_action_strength("throttle_up") > 0.3):
				take_off()
		State.AUTOLAND:
			_autoland_t = minf(1.0, _autoland_t + delta / 3.0)
			var e := smoothstep(0.0, 1.0, _autoland_t)
			var q := _autoland_from.basis.get_rotation_quaternion().slerp(_autoland_to.basis.get_rotation_quaternion(), e)
			global_transform = Transform3D(Basis(q), _autoland_from.origin.lerp(_autoland_to.origin, e))
			if _autoland_t >= 1.0:
				_set_landed(_autoland_station)
				GameState.say("Touchdown at %s, pad 07. Ramp down." % _autoland_station.display_name)
		State.FLYING:
			_fly(delta)
	_update_lamps()
	_crt_timer -= delta
	if _crt_timer <= 0.0:
		_crt_timer = 0.15
		_update_crts()


func _fly(delta: float) -> void:
	var fwd := 0.0
	var strafe := 0.0
	var vert := 0.0
	var pitch := 0.0
	var yaw := 0.0
	var roll := 0.0
	if piloted and not nav_mode:
		fwd = Input.get_action_strength("throttle_up") - Input.get_action_strength("throttle_down")
		strafe = Input.get_axis("strafe_left", "strafe_right")
		vert = Input.get_axis("thrust_down", "thrust_up")
		pitch = Input.get_axis("pitch_down", "pitch_up") + mouse_turn.y
		yaw = Input.get_axis("yaw_right", "yaw_left") + mouse_turn.x
		roll = Input.get_axis("roll_right", "roll_left")
	mouse_turn = mouse_turn.lerp(Vector2.ZERO, minf(1.0, delta * 6.0))
	var target := Vector3(clampf(pitch, -1, 1) * TURN.x, clampf(yaw, -1, 1) * TURN.y, roll * TURN.z)
	if cruise:
		target *= 0.45
	ang = ang.lerp(target, minf(1.0, delta * 4.0))
	rotate_object_local(Vector3.RIGHT, ang.x * delta)
	rotate_object_local(Vector3.UP, ang.y * delta)
	rotate_object_local(Vector3.BACK, ang.z * delta)
	transform = transform.orthonormalized()

	if cruise:
		if Input.get_action_strength("throttle_down") > 0.5:
			cruise = false
			GameState.say("Cruise off.")
		else:
			# Drop out near the course target, or near a station we are closing on,
			# never near the one we are leaving.
			var st := nearest_station()
			var near_st := st != null and global_position.distance_to(st.global_position) < CRUISE_DROP_DIST \
				and velocity.dot(st.global_position - global_position) > 0.0
			var near_target: bool = course_target != null and global_position.distance_to(course_target) < CRUISE_DROP_DIST
			if near_st or near_target:
				cruise = false
				var where := st.display_name if near_st else GameState.station_name(course_station)
				GameState.say("Cruise dropped. Approaching %s. Press L / X to request docking." % where)
	var desired_local := Vector3(0, 0, -CRUISE_SPEED) if cruise else Vector3(strafe * STRAFE_SPEED, vert * STRAFE_SPEED, -fwd * MAX_SPEED)
	var desired := global_basis * desired_local
	var accel := CRUISE_ACCEL if cruise else (CRUISE_DECEL if velocity.length() > MAX_SPEED * 1.2 else ACCEL)
	velocity = velocity.move_toward(desired, accel * delta)
	var speed_before := velocity.length()
	move_and_slide()
	if get_slide_collision_count() > 0 and speed_before > 25.0:
		cruise = false
		velocity *= 0.3
		GameState.say("Impact! Hull scraped at %d m/s." % int(speed_before))


func _update_lamps() -> void:
	_set_lamp("GEAR", state != State.FLYING)
	var st := nearest_station()
	_set_lamp("DOCK", st != null and st.docking_granted)
	_set_lamp("CRUISE", cruise)


func hold_count_of(commodity: String) -> int:
	var n := 0
	for s in hold_slots:
		if s.occupant and s.occupant.commodity == commodity:
			n += 1
	return n


## Removes every crate of a commodity from the hold (sold by the dock crew).
func take_from_hold(commodity: String) -> int:
	var n := 0
	for i in range(hold_slots.size() - 1, -1, -1):
		var c := hold_slots[i].occupant
		if c and c.commodity == commodity:
			c.remove_from_slot()
			c.queue_free()
			n += 1
	Slot.settle(hold_slots)
	return n


func hold_count() -> int:
	var n := 0
	for s in hold_slots:
		if s.occupant:
			n += 1
	return n


func mode_text() -> String:
	match state:
		State.LANDED: return "LANDED"
		State.AUTOLAND: return "AUTOLAND"
	return "CRUISE" if cruise else "ASSIST"


func _update_crts() -> void:
	var t := "SCANNER\nMODE   %s\nSPEED  %03d M/S\n--------------------------\n" % [mode_text(), int(velocity.length())]
	for s in stations:
		var d := global_position.distance_to(s.global_position)
		var tag := " DOCK" if s.docking_granted else ""
		t += "%-13s%5.1f KM%s\n" % [s.display_name.to_upper(), d / 1000.0, tag]
	t += "--------------------------\n" + comms
	crt_scan.set_text(t)
	var c := "CARGO HOLD   %02d/32 SCU\n--------------------------\n" % [hold_count() * GameState.CRATE_SCU]
	for row in 4:
		var line := ""
		for layer in 2:
			for side in 2:
				var s: Slot = hold_slots[layer * 8 + side * 4 + row]
				var code := "----" if s.occupant == null else String(GameState.COMMODITIES[s.occupant.commodity]["short"]).rpad(4)
				line += s.slot_label + " " + code + " "
		c += line.strip_edges() + "\n"
	c += "--------------------------\nRAMP %s" % ("DOWN" if state == State.LANDED else "SEALED")
	crt_cargo.set_text(c)
	nav.refresh_distance()
