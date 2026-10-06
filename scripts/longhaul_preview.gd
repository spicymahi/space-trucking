extends "res://scripts/hab_preview.gd"
## Full-scale Longhaul layout study; independent of the gameplay slice.
const SERVICE_SCRIPT := preload("res://scripts/longhaul_service.gd")
var room_label: Label
var seated := false
var cockpit_hint: Label
var hab_module: Node3D
var service_module: Node3D
var cargo_module: Node3D
var engineering_module: Node3D
var loading_module: Node3D
var hab_seated := false

func _ready() -> void:
	DisplayServer.window_set_title("Longhaul — Walkable Ship")
	_build_environment()
	hull = StaticBody3D.new()
	add_child(hull)
	_build_ship()
	_controller()
	player.position = Vector3(0, 0.06, -0.45)
	player.rotation.y = PI
	_ui()
	room_label = overlay.get_child(0)
	cockpit_hint = Label.new()
	cockpit_hint.add_theme_font_override("font", font)
	cockpit_hint.add_theme_font_size_override("font_size", 23)
	cockpit_hint.position = Vector2(24, 80)
	cockpit_hint.modulate = Color("edcf94")
	overlay.add_child(cockpit_hint)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if "--longhaul-test" in OS.get_cmdline_user_args(): _tour_test.call_deferred()
	if "--longhaul-capture" in OS.get_cmdline_user_args(): _take_picture.call_deferred()

func wall(p: Vector3, s: Vector3, c := CREAM) -> void:
	_box(p, s, c, true)

func bulkhead(z: float, title: String, width := 1.5, span := 6.0, height := 2.8) -> void:
	var side := (span - width) / 2
	for sign_x in [-1, 1]:
		wall(Vector3(sign_x * (width / 2 + side / 2), height / 2, z), Vector3(side, height, 0.18))
		_box(Vector3(sign_x * (width / 2 + 0.04), (height - 0.4) / 2, z), Vector3(0.09, height - 0.4, 0.24), ORANGE)
	wall(Vector3(0, height - 0.2, z), Vector3(width, 0.4, 0.2))
	_text(title, Vector3(0, height - 0.21, z + 0.12), 0.0021, DARK)
	_text(title, Vector3(0, height - 0.21, z - 0.12), 0.0021, DARK, PI)

func ceiling_light(z: float, warm := true) -> void:
	_box(Vector3(0, 2.73, z), Vector3(1.4, 0.1, 0.65), DARK)
	_box(Vector3(0, 2.67, z), Vector3(1.2, 0.03, 0.5), Color("ffe1a0") if warm else Color("cde5db"), false, true)
	_lamp(Vector3(0, 2.42, z), 1.0, 4.4, Color("ffe0ac") if warm else Color("d3e4df"), true)

func _build_ship() -> void:
	wall(Vector3(0, -0.16, 5.1), Vector3(6.2, 0.32, 12.2), DARK)
	wall(Vector3(0, 2.98, 5.1), Vector3(6.3, 0.36, 12.2), CREAM)
	for z in range(-1, 11):
		for x in 6:
			_box(Vector3(x - 2.5, 0.012, z + 0.5), Vector3(0.978, 0.024, 0.978), FLOOR.lightened(0.02 * ((x + z + 12) % 3)))
	for x in [-3.1,3.1]:
		wall(Vector3(x,1.4,5),Vector3(0.2,2.8,12))
		_box(Vector3(x*1.04,0.7,5.1),Vector3(0.09,0.65,12.0),ORANGE)
	for z in [-9.0, -4.0, -1.0, 7.0]:
		# Both ends meet the corridor's inner wall faces, sealing the side rooms.
		var opening := SERVICE_SCRIPT.PASSAGE_WIDTH if z in [-4.0,-1.0] else (2.6 if z==7 else 1.5)
		bulkhead(z, { -9.0: "01 / FLIGHT DECK", -4.0: "02 / LIVING HAB", -1.0: "05 / CARGO", 7.0: "06 / ENGINEERING" }[z], opening,4.0 if z == -9 else (5.56 if z == -4 else 6.0),2.4 if z <= -1 else 2.8)
	wall(Vector3(0,2.6,-1),Vector3(6.0,0.4,0.18))
	_cockpit_room()
	_living_room()
	_service_rooms()
	_cargo_room()
	_engine_room()
	_exterior()
	_finish_details()

func _cockpit_room() -> void:
	var cockpit := preload("res://scripts/longhaul_cockpit.gd").new()
	add_child(cockpit)
	cockpit.build(self)


func _living_room() -> void:
	hab_module = preload("res://scripts/longhaul_hab.gd").new()
	add_child(hab_module)
	hab_module.build(self)

func _service_rooms() -> void:
	service_module = SERVICE_SCRIPT.new()
	add_child(service_module)
	service_module.build(self)

func _cargo_room() -> void:
	cargo_module = preload("res://scripts/longhaul_cargo.gd").new()
	add_child(cargo_module)
	cargo_module.build(self)

func _engine_room() -> void:
	engineering_module = preload("res://scripts/longhaul_engineering.gd").new()
	add_child(engineering_module)
	engineering_module.build(self)
	bulkhead(11.1, "07 / LOADING RAMP", 2.8)
	loading_module = preload("res://scripts/longhaul_loading.gd").new()
	add_child(loading_module)
	loading_module.build(self)

func _exterior() -> void:
	# Ramp descends from deck to the surrounding hangar apron.
	var ramp := StaticBody3D.new()
	ramp.position = Vector3(0, -0.63, 13.2)
	ramp.rotation.x = atan(1.2 / 4.2)
	add_child(ramp)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.8, 0.18, 4.4)
	mesh.mesh = box
	mesh.material_override = _material(SHADOW)
	ramp.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collision.shape = shape
	ramp.add_child(collision)
	for x in [-3.95, 3.95]:
		wall(Vector3(x, 1.0, 9.25), Vector3(1.6, 3.2, 4.7), CREAM)
		_box(Vector3(x, 1, 10.7), Vector3(1.65, 3.25, 0.6), ORANGE)
		_box(Vector3(x, 1, 11.63), Vector3(1.3, 2.5, 0.15), DARK)
		_box(Vector3(x, 1, 11.72), Vector3(0.8, 0.12, 0.03), Color("ffbe65"), false, true)
	for x in [-2.5, 2.5]:
		for z in [-9.5, 0, 8.5]:
			var support_x: float = signf(x) * 1.25 if z == -9.5 else x
			wall(Vector3(support_x, -0.7, z), Vector3(0.35, 1.05, 0.6), DARK)
			wall(Vector3(support_x, -1.12, z), Vector3(0.9, 0.2, 1.8), SHADOW)
	wall(Vector3(0, -1.45, 0), Vector3(48, 0.5, 56), Color("3e4545"))
	for x in [-8.0, 8.0]:
		_box(Vector3(x, -1.19, 0), Vector3(0.15, 0.02, 36), GOLD)
		for z in [-15, -5, 5, 16]:
			_box(Vector3(x, -1.1, z), Vector3(0.4, 0.15, 0.4), Color("b6d4d6"), false, true)
			_lamp(Vector3(x, 4.0, z), 1.2, 12, Color("b6c7dc"))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	add_child(sun)
	_text("LONGHAUL / K-01", Vector3(-3.22, 1.6, 2), 0.004, DARK, -PI / 2)

func _process(_delta: float) -> void:
	if room_label == null: return
	var z := player.position.z
	var room := "ENGINEERING"
	if z < -9: room = "COCKPIT"
	elif z < -4: room = "LIVING HAB"
	elif z < -1: room = "WASHROOM" if player.position.x < -0.74 else ("AIRLOCK" if player.position.x > 0.74 else "SERVICE CORRIDOR")
	elif z < 7: room = "CARGO HOLD"
	elif z > 11.1: room = "RAMP / HANGAR"
	room_label.text = "LONGHAUL / " + room + "\nWALKABLE DESIGN STUDY"
	cockpit_hint.text = "[F] LEAVE PILOT SEAT  /  MOUSE LOOK" if seated else ("[F] TAKE PILOT SEAT" if player.position.distance_to(Vector3(0,0,-10.45)) < 2.1 else "")
	if hab_seated:
		cockpit_hint.text = "[F] STAND   [T] FOLD / LOWER TABLE"
	elif not seated and z > -9 and z < -4:
		var target: Dictionary = hab_module.interaction(camera,player)
		cockpit_hint.text = "[F] " + target.label if not target.is_empty() else ""
		if not hab_module.notice.is_empty() and Time.get_ticks_msec() < hab_module.notice_until:
			cockpit_hint.text = hab_module.notice
	elif not seated and z >= -4 and z < -1:
		var target: Dictionary = service_module.interaction(camera,player)
		cockpit_hint.text = "[F] " + target.label if not target.is_empty() else ""
		if not service_module.notice.is_empty() and Time.get_ticks_msec() < service_module.notice_until:
			cockpit_hint.text = service_module.notice
	elif not seated and z >= -1:
		_update_aft_hint()
	if cargo_module.carrying:
		_update_aft_hint()
	if player.position.y < -5: player.position = Vector3(0, 0.05, -4.7)

func _update_aft_hint() -> void:
	cockpit_hint.text = "CARRYING CASE / AIM AT A RECEIVING BERTH" if cargo_module.carrying else ""
	for module in [cargo_module,engineering_module,loading_module]:
		if cargo_module.carrying and module!=cargo_module: continue
		var target: Dictionary = module.interaction(camera,player)
		if not target.is_empty():
			cockpit_hint.text = "[F] " + target.label
			break
	var latest_notice := Time.get_ticks_msec()
	for module in [cargo_module,engineering_module,loading_module]:
		if not module.notice.is_empty() and latest_notice < module.notice_until:
			cockpit_hint.text = module.notice
			latest_notice = module.notice_until

func _walk_to(target: Vector3) -> bool:
	for i in 2400:
		var delta := target - player.position
		delta.y = 0
		if delta.length() < 0.14:
			Input.action_release("move_forward")
			return true
		player.rotation.y = atan2(-delta.x, -delta.z)
		Input.action_press("move_forward")
		await get_tree().physics_frame
	Input.action_release("move_forward")
	return false

func _tour_test() -> void:
	get_window().size = Vector2i(1280,800)
	await _frames(30)
	var ok := player.is_on_floor()
	for target in [Vector3(0,0,-9.4), Vector3(0.30,0,-9.4), Vector3(0.30,0,-10.35), Vector3(0.30,0,-9.4), Vector3(0,0,-9.4), Vector3(0,0,-2.5), Vector3(-1.45,0,-2.5), Vector3(0,0,-2.5), Vector3(2.1,0,-2.5), Vector3(0,0,-2.5), Vector3(0,0,9), Vector3(0,0,16), Vector3(0,0,9), Vector3(0,0,-4.7)]:
		var reached := await _walk_to(target)
		print("LONGHAUL walk ", target, ": ", reached)
		ok = ok and reached
	# Exercise the actual F binding, then verify walking resumes after standing.
	ok = (await _walk_to(Vector3(0,0,-9.4))) and ok
	var press := InputEventKey.new()
	press.physical_keycode = KEY_F
	press.keycode = KEY_F
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(3)
	var seat_ok := seated and player.position.z < -11.4
	for child in get_children():
		if child.has_method("validate_pilot_view"):
			seat_ok = child.validate_pilot_view(camera,player) and seat_ok
	Input.action_press("move_forward")
	var before := player.position
	await _frames(12)
	Input.action_release("move_forward")
	seat_ok = seat_ok and player.position.is_equal_approx(before)
	var release := InputEventKey.new()
	release.physical_keycode = KEY_F
	release.keycode = KEY_F
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)
	Input.parse_input_event(press)
	await _frames(3)
	seat_ok = seat_ok and not seated
	seat_ok = (await _walk_to(Vector3(0,0,-8.3))) and seat_ok
	ok = ok and seat_ok
	print("LONGHAUL seat input / fixed seated position / safe exit: ", seat_ok)
	var hab_checks := preload("res://scripts/longhaul_hab_test.gd").new()
	ok = (await hab_checks.run(self)) and ok
	var service_checks := preload("res://scripts/longhaul_service_test.gd").new()
	ok = (await service_checks.run(self)) and ok
	var aft_checks := preload("res://scripts/longhaul_aft_test.gd").new()
	ok = (await aft_checks.run(self)) and ok
	print("LONGHAUL TOUR ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)

func _take_picture() -> void:
	set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var args := OS.get_cmdline_user_args()
	var idx := args.find("--longhaul-capture")
	var view := args[idx + 1] if idx + 1 < args.size() else "hab"
	player.rotation = Vector3.ZERO
	if view == "service":
		player.position = Vector3(0,0.05,-3.73)
		player.rotation.y = PI
	elif view == "cargo_service":
		player.position = Vector3(0,0.05,0.60)
		camera.rotation.x = -0.04
	elif view == "hab_service":
		player.position = Vector3(0,0.05,-5.15)
		player.rotation.y = PI
		camera.rotation.x = -0.04
	elif view == "wash":
		player.position = Vector3(-0.24,0.05,-2.5)
		player.rotation.y = PI/2
		camera.rotation.x = -0.14
	elif view == "wash_shower":
		player.position = Vector3(-1.63,0.05,-2.15)
		player.rotation.y = 0.26
		camera.rotation.x = -0.13
	elif view == "wash_basin":
		player.position = Vector3(-1.72,0.05,-2.74)
		player.rotation.y = PI
		camera.rotation.x = -0.18
	elif view == "airlock":
		player.position = Vector3(0.24,0.05,-2.5)
		player.rotation.y = -PI/2
		camera.rotation.x = -0.08
	elif view == "airlock_suit":
		player.position = Vector3(1.73,0.05,-2.00)
		camera.rotation.x = -0.13
	elif view == "airlock_console":
		player.position = Vector3(1.73,0.05,-2.96)
		player.rotation.y = PI
		camera.rotation.x = -0.06
	elif view == "cargo":
		player.position = Vector3(0,0.05,-0.45)
		player.rotation.y = PI
		camera.rotation.x = -0.04
	elif view == "cargo_console":
		player.position = Vector3(-1.78,0.05,0.28)
		camera.rotation.x = -0.12
	elif view == "cargo_berths":
		player.position = Vector3(0,0.05,4.35)
		player.rotation.y = PI
		camera.rotation.x = -0.16
	elif view == "engineering":
		player.position = Vector3(0,0.05,7.36)
		player.rotation.y = PI
		camera.rotation.x = -0.05
	elif view == "engineering_port":
		player.position = Vector3(0,0.05,9.05)
		player.rotation.y = PI/2
		camera.rotation.x = -0.10
	elif view == "engineering_starboard":
		player.position = Vector3(0,0.05,9.05)
		player.rotation.y = -PI/2
		camera.rotation.x = -0.10
	elif view == "loading" or view == "loading_closed":
		player.position = Vector3(0,0.05,9.25)
		player.rotation.y = PI
		camera.rotation.x = -0.12
		if view == "loading_closed":
			loading_module.use("load_inner")
			await _frames(50)
	elif view == "cockpit":
		player.position = Vector3(0,0.05,-10.27)
		pitch = 0.06
		camera.rotation.x = pitch
	elif view == "wall_left" or view == "wall_right":
		player.position = Vector3(0,0.05,-10.38)
		player.rotation.y = PI / 2 if view == "wall_left" else -PI / 2
		pitch = 0
		camera.rotation.x = pitch
	elif view in ["pilot", "pilot_left", "pilot_right"]:
		_take_seat()
		if view != "pilot": player.rotation.y = 0.9 if view == "pilot_left" else -0.9
	elif view == "hab_sink":
		player.position = Vector3(0,0.05,-7.46)
		player.rotation.y = -PI/2
		camera.rotation.x = -0.62
	elif view == "hab_bunk" or view == "hab_galley":
		player.position = Vector3(0,0.05,-7.45 if view == "hab_bunk" else -6.48)
		player.rotation.y = PI/2 if view == "hab_bunk" else -PI/2
		camera.rotation.x = -0.08
	elif view == "hab_dinette":
		_sit_dinette()
	elif view == "hab_aft":
		player.position = Vector3(0,0.05,-8.15)
		player.rotation.y = PI
		camera.rotation.x = -0.03
	elif view == "rear":
		_take_seat()
		player.rotation.y = PI
	elif view == "ceiling":
		_take_seat()
		camera.rotation.x = 0.7
	elif view == "exterior":
		player.position = Vector3(9,5,-21)
		camera.look_at(Vector3(0,1,-8))
		set_physics_process(false)
	else:
		player.position = Vector3(0,0.05,-4.7)
	await _frames(40)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../longhaul-" + view + ".png"))
	get_tree().quit()

func _finish_details() -> void:
	# Hull armor panels, dark joining bands, and roof service modules.
	for x in [-3.23, 3.23]:
		for z in [0.3, 3.1, 5.9]:
			_box(Vector3(x, 1.6, z), Vector3(0.14, 2.5, 2.65), LIGHT)
			_box(Vector3(x * 1.026, 1.3, z), Vector3(0.035, 0.55, 2.65), ORANGE)
			_box(Vector3(x * 1.03, 2.45, z), Vector3(0.04, 0.08, 0.7), DARK)
		for z in [-1.0, 7.0]:
			_box(Vector3(x, 1.45, z), Vector3(0.2, 3.25, 0.24), DARK)
			_box(Vector3(0, 3.18, z), Vector3(6.65, 0.15, 0.24), DARK)
	for z in [0, 6.5]:
		_box(Vector3(0, 3.24, z), Vector3(2.5, 0.24, 1.5), SHADOW)
		_box(Vector3(0, 3.4, z), Vector3(1.9, 0.1, 1.0), DARK)
		for i in 5: _box(Vector3(0, 3.47, z - 0.4 + i * 0.2), Vector3(1.75, 0.035, 0.06), SHADOW)
	# Nose bumper and stepped front armor give the cab a distinct profile.
	for i in 4:
		wall(Vector3(0, 0.12 + i * 0.2, -13.75 - (3-i) * 0.15), Vector3(3.1 - (3-i)*0.13, 0.2, 0.3 + (3-i)*0.3), SHADOW if i == 0 else CREAM)
	for x in [-1.08, 1.08]:
		_box(Vector3(x, 0.65, -14.1), Vector3(0.65, 0.3, 0.1), DARK)
		_box(Vector3(x, 0.65, -14.16), Vector3(0.45, 0.12, 0.03), Color("ffdf9b"), false, true)

func _take_seat() -> void:
	camera.position.y = 1.63
	seated = true
	player.position = Vector3(0,0.04,-11.55)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	pitch = -0.08
	camera.rotation = Vector3(pitch,0,0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T and hab_seated:
		hab_module.use("table")
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		if hab_seated:
			hab_seated = false
			player.position = Vector3(0,0.05,-4.65)
			player.rotation = Vector3.ZERO
			camera.position.y = 1.63
			pitch = 0
			camera.rotation = Vector3.ZERO
			return
		if cargo_module.carrying:
			var carry_target: Dictionary = cargo_module.interaction(camera,player)
			if not carry_target.is_empty(): cargo_module.use(carry_target.action)
			else: cargo_module.explain("Aim at a receiving berth to set the case down.")
			return
		if not seated:
			for module in [cargo_module,engineering_module,loading_module]:
				var aft_target: Dictionary = module.interaction(camera,player)
				if not aft_target.is_empty():
					module.use(aft_target.action)
					return
			var service_target: Dictionary = service_module.interaction(camera,player)
			if not service_target.is_empty():
				service_module.use(service_target.action)
				return
			var target: Dictionary = hab_module.interaction(camera,player)
			if not target.is_empty():
				if target.action == "bench": _sit_dinette()
				else: hab_module.use(target.action)
				return
		if seated:
			seated = false
			player.position = Vector3(0,0.05,-10.32)
			player.rotation = Vector3.ZERO
			pitch = 0
			camera.rotation = Vector3.ZERO
		elif player.position.z < -9 and player.position.distance_to(Vector3(0,0,-10.45)) < 2.1:
			_take_seat()
		return
	super._unhandled_input(event)
	if cargo_module.carrying: cargo_module.validate_carry_rotation()
	if seated or hab_seated:
		player.rotation.y = clampf(wrapf(player.rotation.y,-PI,PI),-1.45,1.45)
		pitch = clampf(pitch,-0.7,0.8)
		camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	if cargo_module.carrying: cargo_module.validate_carry_rotation()
	if not seated and not hab_seated: super._physics_process(delta)

func _sit_dinette() -> void:
	hab_seated = true
	player.position = Vector3(-1.24,0.05,-4.57)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	camera.position.y = 1.22
	pitch = -0.10
	camera.rotation = Vector3(pitch,0,0)
